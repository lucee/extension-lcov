/**
 * Component responsible for processing execution log (.exl) files
 */
component {

	/**
	 * Initialize the execution log processor with options
	 * @options Configuration options struct (optional)
	 */
	public function init(struct options = {}) {
		// Store options and extract logLevel
		variables.options = arguments.options;
		var logLevel = variables.options.logLevel ?: "none";
		variables.logger = new lucee.extension.lcov.Logger(level=logLevel);
		return this;
	}

	/**
	 * Parse execution logs from a directory and return processed results
	 * @executionLogDir Directory containing .exl files
	 * @options Processing options including allowList and blocklist
	 * @return Struct of parsed results keyed by .exl file path
	 */

	public array function parseExecutionLogs(required string executionLogDir, struct options = {}) {
		// add an exclusive cflock here
		cflock(name="lcov-parse:#arguments.executionLogDir#", timeout=0, type="exclusive", throwOnTimeout=true) {
			return _parseExecutionLogs(arguments.executionLogDir, arguments.options);
		}
	}

	private array function _parseExecutionLogs(required string executionLogDir, struct options = {}) {
		if (!directoryExists(arguments.executionLogDir)) {
			throw(message="Execution log directory does not exist: " & arguments.executionLogDir);
		}

		variables.logger.debug("Processing execution logs from: " & arguments.executionLogDir);

		// Create shared AST cache for all parsers to avoid re-parsing same files 179+ times
		var sharedAstCache = {};
		var files = directoryList(arguments.executionLogDir, false, "query", "*.exl", "datecreated");

		variables.logger.debug("Found " & files.recordCount & " .exl files to process");

		// Adaptive parallelization: group files by size
		var smallFiles = [];  // < 10MB: process in parallel
		var largeFiles = [];  // >= 10MB: process sequentially (already internally parallel)
		var fileSizeThresholdMb = 10;

		for (var file in files) {
			var exlPath = file.directory & "/" & file.name;
			var info = getFileInfo(exlPath);
			var fileSizeMb = info.size / 1024 / 1024;

			if (fileSizeMb < fileSizeThresholdMb) {
				arrayAppend(smallFiles, {path: exlPath, name: file.name, sizeMb: fileSizeMb});
			} else {
				arrayAppend(largeFiles, {path: exlPath, name: file.name, sizeMb: fileSizeMb});
			}
		}

		variables.logger.debug("Small files (parallel): " & arrayLen(smallFiles) & ", Large files (sequential): " & arrayLen(largeFiles));

		var jsonFilePaths = [];
		var options = arguments.options; // Cache for closure access

		// Process small files in parallel
		if (arrayLen(smallFiles) > 0) {
			var smallFileResults = arrayMap(smallFiles, function(fileInfo) {
				return processExlFile(fileInfo.path, fileInfo.name, fileInfo.sizeMb, options, sharedAstCache);
			}, true);  // parallel=true

			for (var result in smallFileResults) {
				arrayAppend(jsonFilePaths, result);
			}
		}

		// Process large files sequentially (they use internal parallelism)
		for (var fileInfo in largeFiles) {
			var jsonPath = processExlFile(fileInfo.path, fileInfo.name, fileInfo.sizeMb, arguments.options, sharedAstCache);
			arrayAppend(jsonFilePaths, jsonPath);
		}

		variables.logger.debug("Completed processing " & arrayLen(jsonFilePaths) & " valid .exl files");
		return jsonFilePaths;
	}

	private string function processExlFile(required string exlPath, required string fileName, required numeric sizeMb, required struct options, required struct sharedAstCache) {
		var logger = new lucee.extension.lcov.Logger( level=arguments.options.logLevel ?: "none" );
		var exlParser = new lucee.extension.lcov.ExecutionLogParser( options=arguments.options, sharedAstCache=arguments.sharedAstCache );

		variables.logger.debug("Processing " & arguments.fileName & " (" & decimalFormat(arguments.sizeMb) & " Mb)");

		var result = exlParser.parseExlFile(
			arguments.exlPath,
			arguments.options.allowList ?: [],
			arguments.options.blocklist ?: [],
			false  // writeJsonCache - we handle JSON writing after stats
		);

		var statsComponent = new lucee.extension.lcov.CoverageStats( logger=logger );
		result = statsComponent.calculateCoverageStats( result );

		// Set outputFilename (without extension) for downstream consumers (e.g., HTML reporter)
		// Include unique identifier from .exl filename to avoid overlaps between multiple execution runs
		var fileNameWithoutExt = listFirst(arguments.fileName, ".");  // Remove .exl extension
		var scriptName = result.getMetadataProperty("script-name");
		scriptName = reReplace(scriptName, "[^a-zA-Z0-9_-]", "_", "all");
		var outputFilename = "request-" & fileNameWithoutExt & "-" & scriptName;
		result.setOutputFilename(outputFilename);

		// Write JSON cache after stats are calculated (includes complete stats)
		// Write next to the .exl file for permanent caching
		var jsonPath = reReplace(arguments.exlPath, "\.exl$", ".json");
		fileWrite(jsonPath, result.toJson(pretty=false, excludeFileCoverage=true));

		return jsonPath;
	}

	/**
	 * Phase 2: Extract AST metadata (CallTree + executable lines) from unique source files.
	 * Deduplicates files across all minimal JSONs and extracts metadata once per unique file.
	 *
	 * @executionLogDir Directory containing .exl files and minimal JSONs
	 * @jsonFilePaths Array of minimal JSON file paths from Phase 1
	 * @options Processing options
	 * @return Path to ast-metadata.json file
	 */
	public string function extractAstMetadata(required string executionLogDir, required array jsonFilePaths, struct options = {}) {
		var startTime = getTickCount();
		variables.logger.debug( "Phase 2: Extracting AST metadata from unique source files" );

		// 1. Load all minimal JSONs and find unique source files
		var uniqueFiles = {};
		for (var jsonPath in arguments.jsonFilePaths) {
			if ( !fileExists( jsonPath ) ) {
				variables.logger.warn( "Skipping missing JSON file: #jsonPath#" );
				continue;
			}

			var jsonContent = fileRead( jsonPath );
			var data = deserializeJSON( jsonContent );

			// Extract file paths from files section
			if ( structKeyExists( data, "files" ) && isStruct( data.files ) ) {
				for (var fileIdx in data.files) {
					var fileInfo = data.files[fileIdx];
					if ( structKeyExists( fileInfo, "path" ) ) {
						uniqueFiles[fileInfo.path] = true;
					}
				}
			}
		}

		var uniqueFileCount = structCount( uniqueFiles );
		variables.logger.debug( "Found #uniqueFileCount# unique source files across #arrayLen(arguments.jsonFilePaths)# minimal JSONs" );

		// 2. Extract metadata for each unique file
		var metadataExtractor = new lucee.extension.lcov.ast.AstMetadataExtractor( logger=variables.logger );
		var metadata = metadataExtractor.extractMetadataForFiles( structKeyArray( uniqueFiles ) );

		// 3. Build ast-metadata.json structure with checksums and timestamps
		var metadataData = {
			"cacheVersion": 1,
			"files": {}
		};

		for (var filePath in metadata) {
			if ( !fileExists( filePath ) ) {
				variables.logger.warn( "Skipping metadata for missing file: #filePath#" );
				continue;
			}

			var fileInfo = getFileInfo( filePath );
			var fileContent = fileRead( filePath );

			metadataData.files[filePath] = {
				"checksum": hash( fileContent, "MD5" ),
				"lastModified": fileInfo.lastModified,
				"callTree": metadata[filePath].callTree,
				"executableLineCount": metadata[filePath].executableLineCount,
				"executableLines": metadata[filePath].executableLines
			};
		}

		// 4. Write ast-metadata.json
		var metadataJsonPath = arguments.executionLogDir & "/ast-metadata.json";
		fileWrite( metadataJsonPath, serializeJSON( metadataData, false ) );

		var elapsedTime = getTickCount() - startTime;
		variables.logger.debug( "Phase 2: Wrote ast-metadata.json with #structCount(metadataData.files)# files in #elapsedTime#ms" );

		return metadataJsonPath;
	}

}