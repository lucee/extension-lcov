/**
 * Component responsible for generating AST metadata files (extractAstMetadata phase).
 *
 * Extracts AST metadata (CallTree, executable lines, lineMapping) from source files
 * and writes individual metadata files plus an index for fast lookup.
 */
component {

	/**
	 * Initialize AST metadata generator
	 * @logger Logger instance for debugging and tracing
	 * @return This instance
	 */
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
	 * @allFiles Struct of all files from parseExecutionLogs (avoids re-reading JSONs)
	 * @return Path to ast-metadata.json index file
	 */
	public string function generate(required string executionLogDir, required struct allFiles) localmode=true {
		var event = variables.logger.beginEvent( "extractAstMetadata" );

		var uniqueFiles = structNew( "regular" );
		cfloop( collection=arguments.allFiles, key="local.fileIdx", value="local.fileInfo" ) {
			uniqueFiles[fileInfo.path] = true;
		}
		var metadataDir = arguments.executionLogDir & "/ast";
		if ( !directoryExists( metadataDir ) ) {
			directoryCreate( metadataDir );
		}

		var index = extractAndWriteMetadata( uniqueFiles, metadataDir );

		var indexJsonPath = arguments.executionLogDir & "/ast-metadata.json";
		fileWrite( indexJsonPath, serializeJSON( index, false ) );

		variables.logger.info( "Phase extractAstMetadata: Wrote ast-metadata.json index and #structCount(index.files)# individual metadata files" );
		variables.logger.commitEvent( event=event, minThresholdMs=0, logLevel="info" );

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
	private struct function extractAndWriteMetadata(required struct uniqueFiles, required string metadataDir) localmode=true {
		var filePaths = structKeyArray( arguments.uniqueFiles );

		// Cache for closure access (components already created in init())
		var metadataDir = arguments.metadataDir;

		// Process all files in parallel - read ONCE, extract everything we need
		var results = arrayMap( filePaths, function( filePath ) {
			if ( !fileExists( filePath ) ) {
				variables.logger.warn( "Skipping metadata extraction for missing file: #filePath#" );
				return {success: false, filePath: filePath};
			}

			var fileContent = fileRead( filePath );
			var fileInfo = FileInfo( filePath );

			// Extract AST metadata (CallTree + executable lines)
			var ast = variables.astParserHelper.parseFileAst( filePath, fileContent );
			var metadata = variables.astMetadataExtractor.extractMetadata( ast, filePath );
			var lineMapping = variables.blockProcessor.buildCharacterToLineMapping( fileContent );

			var safeFileName = fileInfo.checksum & ".json";
			var metadataFilePath = metadataDir & "/" & safeFileName;

			var metadataContent = {
				"callTree": metadata.callTree,
				"executableLineCount": metadata.executableLineCount,
				"executableLines": metadata.executableLines,
				"astNodes": metadata.astNodes,
				"lineMapping": lineMapping
			};
			fileWrite( metadataFilePath, serializeJSON( metadataContent, false ) );

			return {
				success: true,
				filePath: filePath,
				checksum: fileInfo.checksum,
				lastModified: fileInfo.dateLastModified,
				safeFileName: safeFileName
			};
		}, true );

		var index = {
			"cacheVersion": 1,
			"files": {}
		};

		var filesWritten = 0;
		cfloop( array=results, item="local.result" ) {
			if ( result.success ) {
				index.files[result.filePath] = {
					"checksum": result.checksum,
					"lastModified": result.lastModified,
					"metadataFile": result.safeFileName
				};
				filesWritten++;
			}
		}

		return index;
	}

}
