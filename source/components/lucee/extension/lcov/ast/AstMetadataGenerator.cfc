/**
 * Component responsible for generating AST metadata files (Phase 2).
 *
 * Extracts AST metadata (CallTree, executable lines, lineMapping) from source files
 * and writes individual metadata files plus an index for fast lookup.
 */
component {

	public function init(any logger) {
		variables.logger = arguments.logger;
		// Create components once in init, not in every function call
		variables.astMetadataExtractor = new lucee.extension.lcov.ast.AstMetadataExtractor( logger=variables.logger );
		variables.astParserHelper = new lucee.extension.lcov.parser.AstParserHelper(logger=variables.logger);
		variables.blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=variables.logger );
		return this;
	}

	/**
	 * Generate AST metadata for all unique files referenced in minimal JSONs.
	 *
	 * @executionLogDir Directory containing .exl files and minimal JSONs
	 * @allFiles Struct of all files from Phase 1 (avoids re-reading JSONs)
	 * @return Path to ast-metadata.json index file
	 */
	public string function generate(required string executionLogDir, required struct allFiles) localmode="modern" {
		var startTime = getTickCount();
		variables.logger.info( "Phase 2: Extracting AST metadata from unique source files" );

		// 1. Extract unique file paths from allFiles struct
		var uniqueFiles = {};
		for (var fileIdx in arguments.allFiles) {
			var fileInfo = arguments.allFiles[fileIdx];
			if (structKeyExists(fileInfo, "path")) {
				uniqueFiles[fileInfo.path] = true;
			}
		}
		variables.logger.info( "Phase 2: Found #structCount(uniqueFiles)# unique source files" );

		// 2. Create ast directory for individual metadata files
		var metadataDir = arguments.executionLogDir & "/ast";
		if ( !directoryExists( metadataDir ) ) {
			directoryCreate( metadataDir );
		}

		// 3. Extract and write metadata for each unique file IN PARALLEL
		var index = extractAndWriteMetadata( uniqueFiles, metadataDir );

		// 4. Write lightweight index file
		var indexJsonPath = arguments.executionLogDir & "/ast-metadata.json";
		fileWrite( indexJsonPath, serializeJSON( index, false ) );

		var elapsedTime = getTickCount() - startTime;
		variables.logger.info( "Phase 2: Wrote ast-metadata.json index and #structCount(index.files)# individual metadata files in #elapsedTime#ms" );

		return indexJsonPath;
	}

	/**
	 * Extract metadata for all unique files and write to individual JSON files.
	 * Processes files IN PARALLEL and reads each file only ONCE.
	 *
	 * @uniqueFiles Struct of unique file paths
	 * @metadataDir Directory to write individual metadata files
	 * @return Index struct with file metadata
	 */
	private struct function extractAndWriteMetadata(required struct uniqueFiles, required string metadataDir) localmode="modern" {
		var extractStartTime = getTickCount();
		var filePaths = structKeyArray( arguments.uniqueFiles );

		// Cache for closure access (components already created in init())
		var metadataDir = arguments.metadataDir;

		// Process all files in parallel - read ONCE, extract everything we need
		var results = arrayMap( filePaths, function( filePath ) {
			if ( !fileExists( filePath ) ) {
				variables.logger.warn( "Skipping metadata extraction for missing file: #filePath#" );
				return {success: false, filePath: filePath};
			}

			// Read file ONCE
			var fileContent = fileRead( filePath );
			var fileInfo = getFileInfo( filePath );
			var checksum = hash( fileContent, "MD5" );

			// Extract AST metadata (CallTree + executable lines)
			var ast = variables.astParserHelper.parseFileAst( filePath, fileContent );
			var metadata = variables.astMetadataExtractor.extractMetadata( ast, filePath );

			// Build lineMapping from same fileContent (no double read!)
			var lineMapping = variables.blockProcessor.buildCharacterToLineMapping( fileContent );

			// Generate safe filename from path using hash
			var safeFileName = hash( filePath, "MD5" ) & ".json";
			var metadataFilePath = metadataDir & "/" & safeFileName;

			// Write individual metadata file with all data
			var metadataContent = {
				"callTree": metadata.callTree,
				"executableLineCount": metadata.executableLineCount,
				"executableLines": metadata.executableLines,
				"lineMapping": lineMapping
			};
			fileWrite( metadataFilePath, serializeJSON( metadataContent, false ) );

			return {
				success: true,
				filePath: filePath,
				checksum: checksum,
				lastModified: fileInfo.lastModified,
				safeFileName: safeFileName
			};
		}, true ); // true = parallel processing!

		// Build index from results
		var index = {
			"cacheVersion": 1,
			"files": {}
		};

		var filesWritten = 0;
		for ( var result in results ) {
			if ( result.success ) {
				index.files[result.filePath] = {
					"checksum": result.checksum,
					"lastModified": result.lastModified,
					"metadataFile": result.safeFileName
				};
				filesWritten++;
			}
		}

		var extractElapsedTime = getTickCount() - extractStartTime;
		variables.logger.info( "Phase 2: Extracted and wrote #filesWritten# metadata files in #extractElapsedTime#ms (parallel processing)" );

		return index;
	}

}
