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

	public struct function parseExecutionLogs(required string executionLogDir, struct options = {}) {
		// add an exclusive cflock here
		cflock(name="lcov-parse:#arguments.executionLogDir#", timeout=0, type="exclusive", throwOnTimeout=true) {
			return _parseExecutionLogs(arguments.executionLogDir, arguments.options);
		}
	}

	private struct function _parseExecutionLogs(required string executionLogDir, struct options = {}) {
		var parseStartTime = getTickCount();

		if (!directoryExists(arguments.executionLogDir)) {
			throw(message="Execution log directory does not exist: " & arguments.executionLogDir);
		}

		variables.logger.info("parseExecutionLogs: Processing execution logs from: " & arguments.executionLogDir);

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
		var allFiles = {}; // Collect all files from all results
		var options = arguments.options; // Cache for closure access

		// Process small files in parallel
		if (arrayLen(smallFiles) > 0) {
			var smallTotalSizeMb = 0;
			for (var f in smallFiles) {
				smallTotalSizeMb += f.sizeMb;
			}
			var smallStartTime = getTickCount();
			variables.logger.info("parseExecutionLogs: Processing " & arrayLen(smallFiles) & " small .exl files (" & numberFormat(smallTotalSizeMb) & "MB) in parallel");
			var smallFileResults = arrayMap(smallFiles, function(fileInfo) {
				return processExlFile(fileInfo.path, fileInfo.name, fileInfo.sizeMb, options, sharedAstCache);
			}, true);  // parallel=true

			cfloop( array=smallFileResults, item="local.parsingResult" ) {
				arrayAppend(jsonFilePaths, parsingResult.jsonPath);
				// Merge files into allFiles struct
				for (var fileIdx in parsingResult.files) {
					var fileInfo = parsingResult.files[fileIdx];
					if (structKeyExists(fileInfo, "path")) {
						allFiles[fileInfo.path] = fileInfo;
					}
				}
			}
			var smallElapsedTime = getTickCount() - smallStartTime;
			variables.logger.info("parseExecutionLogs: Completed " & arrayLen(smallFiles) & " small .exl files in " & numberFormat(smallElapsedTime) & "ms");
		}

		// Process large files sequentially (they use internal parallelism)
		if (arrayLen(largeFiles) > 0) {
			var largeTotalSizeMb = 0;
			for (var f in largeFiles) {
				largeTotalSizeMb += f.sizeMb;
			}
			var largeStartTime = getTickCount();
			var largeFileCount = arrayLen(largeFiles);
			variables.logger.info("Phase parseExecutionLogs: Processing " & largeFileCount & " large .exl files (" & numberFormat(largeTotalSizeMb) & "MB) sequentially in parallel chunks");
			var largeFileIndex = 0;
			for (var fileInfo in largeFiles) {
				largeFileIndex++;
				variables.logger.info("Phase parseExecutionLogs: Processing large file " & largeFileIndex & "/" & largeFileCount & ": " & fileInfo.name & " (" & numberFormat(fileInfo.sizeMb) & "MB)");
				var parsingResult = processExlFile(fileInfo.path, fileInfo.name, fileInfo.sizeMb, arguments.options, sharedAstCache);
				arrayAppend(jsonFilePaths, parsingResult.jsonPath);
				// Merge files into allFiles struct
				for (var fileIdx in parsingResult.files) {
					var fileInfo = parsingResult.files[fileIdx];
					if (structKeyExists(fileInfo, "path")) {
						allFiles[fileInfo.path] = fileInfo;
					}
				}
			}
			var largeElapsedTime = getTickCount() - largeStartTime;
			variables.logger.info("Phase parseExecutionLogs: Completed " & largeFileCount & " large .exl files in " & numberFormat(largeElapsedTime) & "ms");
		}

		var phase1ElapsedTime = getTickCount() - parseStartTime;
		variables.logger.info("Phase parseExecutionLogs: Completed processing " & arrayLen(jsonFilePaths) & " valid .exl files in " & numberFormat(phase1ElapsedTime) & "ms");

		return {
			jsonFilePaths: jsonFilePaths,
			allFiles: allFiles
		};
	}

	private struct function processExlFile(required string exlPath, required string fileName, required numeric sizeMb, required struct options, required struct sharedAstCache) {
		var logger = new lucee.extension.lcov.Logger( level=arguments.options.logLevel ?: "none" );
		var exlParser = new lucee.extension.lcov.ExecutionLogParser( options=arguments.options, sharedAstCache=arguments.sharedAstCache );

		variables.logger.debug("Processing " & arguments.fileName & " (" & decimalFormat(arguments.sizeMb) & " Mb)");

		// includeSourceCode: false for separateFiles=true (we hydrate later), true for separateFiles=false (HTML needs it now)
		var includeSourceCode = !(arguments.options.separateFiles ?: false);

		var result = exlParser.parseExlFile(
			arguments.exlPath,
			arguments.options.allowList ?: [],
			arguments.options.blocklist ?: [],
			false,  // writeJsonCache - we handle JSON writing after stats
			false,  // includeCallTree - not needed for parseExecutionLogs minimal JSONs
			includeSourceCode  // CRITICAL: false for separateFiles=true to reduce JSON from 2MB to ~1KB
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

		return {
			jsonPath: jsonPath,
			files: result.getFiles()
		};
	}

}