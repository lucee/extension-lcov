/**
 * ReportGenerator.cfc
 *
 * Handles common report generation operations.
 * Each public method does ONE thing and does it well.
 */
component {

	public function init(required any logger) {
		variables.logger = arguments.logger;
		variables.blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=variables.logger );
		variables.coverageStats = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
		return this;
	}

	/**
	 * Validate that execution log directory exists
	 * @executionLogDir Path to execution log directory
	 */
	public void function validateExecutionLogDir( required string executionLogDir ) {
		if ( !directoryExists( arguments.executionLogDir ) ) {
			throw(
				type = "DirectoryNotFound",
				message = "Execution log directory [executionLogDir] does not exist: [" & arguments.executionLogDir & "]"
			);
		}
	}

	/**
	 * Validate that output directory exists
	 * @outputDir Path to output directory
	 */
	public void function validateOutputDir( required string outputDir ) {
		if ( !directoryExists( arguments.outputDir ) ) {
			throw(
				type = "DirectoryNotFound",
				message = "Output directory [outputDir] does not exist: [" & arguments.outputDir & "]"
			);
		}
	}

	/**
	 * Prepare options by merging defaults with user options
	 * @userOptions User-provided options
	 * @defaultOptions Default options to merge with
	 * @return Merged options struct
	 */
	public struct function prepareOptions( required struct userOptions, required struct defaultOptions ) {
		var merged = duplicate( arguments.defaultOptions );
		structAppend( merged, arguments.userOptions );
		return merged;
	}

	/**
	 * Parse execution logs and return struct with jsonFilePaths and allFiles
	 * @executionLogDir Directory containing .exl files
	 * @options Processing options
	 * @return Struct with {jsonFilePaths: array, allFiles: struct}
	 */
	public struct function parseExecutionLogs( required string executionLogDir, required struct options ) {
		var logProcessor = new lucee.extension.lcov.ExecutionLogProcessor( arguments.options );
		return logProcessor.parseExecutionLogs( arguments.executionLogDir, arguments.options );
	}

	/**
	 * Phase 2: Extract AST metadata from unique source files
	 * @executionLogDir Directory containing .exl files and minimal JSONs
	 * @allFiles Struct of all files from Phase 1 (from parseExecutionLogs)
	 * @options Processing options
	 * @return Path to ast-metadata.json
	 */
	public string function extractAstMetadata( required string executionLogDir, required struct allFiles, required struct options ) {
		var astMetadataGenerator = new lucee.extension.lcov.ast.AstMetadataGenerator( logger=variables.logger );
		return astMetadataGenerator.generate( arguments.executionLogDir, arguments.allFiles );
	}

	/**
	 * Phase 3: Build line coverage from aggregated blocks
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json (optional)
	 * @options Processing options
	 * @return Array of JSON file paths
	 */
	public array function buildLineCoverage( required array jsonFilePaths, string astMetadataPath, required struct options ) {
		var coverageBuilder = new lucee.extension.lcov.coverage.LineCoverageBuilder( logger=variables.logger );
		return coverageBuilder.buildCoverage( arguments.jsonFilePaths, arguments.astMetadataPath );
	}

	/**
	 * Phase 4: Annotate CallTree (mark blocks with isChildTime flags)
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json
	 * @options Processing options
	 * @return Array of JSON file paths
	 */
	public array function annotateCallTree( required array jsonFilePaths, required string astMetadataPath, required struct options ) {
		var callTreeAnnotator = new lucee.extension.lcov.coverage.CallTreeAnnotator( logger=variables.logger );
		return callTreeAnnotator.annotate( arguments.jsonFilePaths, arguments.astMetadataPath );
	}

	/**
	 * Write content to output file, ensuring directory exists
	 * @outputFile Path to output file
	 * @content Content to write
	 */
	public void function writeOutputFile( required string outputFile, required string content ) {
		variables.blockProcessor.ensureDirectoryExists( getDirectoryFromPath( arguments.outputFile ) );
		fileWrite( arguments.outputFile, arguments.content );
	}

	/**
	 * Ensure output directory exists
	 * @outputDir Directory to ensure exists
	 */
	public void function ensureDirectoryExists( required string outputDir ) {
		variables.blockProcessor.ensureDirectoryExists( arguments.outputDir );
	}

	/**
	 * Load results from JSON file paths
	 * @jsonFilePaths Array of JSON file paths
	 * @includeValidation Whether to include validation when loading results
	 * @return Struct of results keyed by JSON path
	 */
	public struct function loadResultsFromJsonFiles( required array jsonFilePaths, boolean includeValidation = false ) {
		var results = {};
		var resultFactory = new lucee.extension.lcov.model.result();
		for ( var jsonPath in arguments.jsonFilePaths ) {
			var result = resultFactory.fromJson( fileRead( jsonPath ), arguments.includeValidation );
			results[ jsonPath ] = result;
			result = nullValue();
		}
		return results;
	}

	/**
	 * Create HTML reporter instance
	 * @logger Logger instance
	 * @displayUnit Display unit for execution times
	 * @return HtmlReporter instance
	 */
	public any function createHtmlReporter( required any logger, required string displayUnit ) {
		return new lucee.extension.lcov.reporter.HtmlReporter( logger=arguments.logger, displayUnit=arguments.displayUnit );
	}

	/**
	 * Aggregate coverage stats from JSON file paths
	 * @jsonFilePaths Array of JSON file paths
	 * @processingTimeMs Processing time in milliseconds
	 * @return Stats struct
	 */
	public struct function aggregateCoverageStats( required array jsonFilePaths, required numeric processingTimeMs ) {
		return variables.coverageStats.aggregateCoverageStats( arguments.jsonFilePaths, arguments.processingTimeMs );
	}

	/**
	 * Get list of generated HTML files from directory
	 * @outputDir Directory to search
	 * @excludeIndex Whether to exclude index.html
	 * @return Array of HTML filenames
	 */
	public array function getGeneratedHtmlFiles( required string outputDir, boolean excludeIndex = true ) {
		var generatedHtmlFiles = [];
		var allHtmlFiles = directoryList( arguments.outputDir, false, "name", "*.html" );
		for ( var htmlFile in allHtmlFiles ) {
			if ( !arguments.excludeIndex || htmlFile != "index.html" ) {
				arrayAppend( generatedHtmlFiles, htmlFile );
			}
		}
		return generatedHtmlFiles;
	}

	/**
	 * Generate separate file merged results using CoverageMerger workflow
	 * STREAMING VERSION - loads one file at a time to avoid OOM
	 * @jsonFilePaths Array of JSON file paths to merge
	 * @logger Logger instance
	 * @outputDir Output directory for merged JSON files
	 * @logLevel Log level for CoverageMergerWriter
	 * @aggregateCallTree Whether to aggregate call tree metrics (for HTML reports)
	 * @return Array of generated source file JSON paths
	 */
	public array function generateSeparateFileMergedResults(
		required array jsonFilePaths,
		required any logger,
		required string outputDir,
		required string logLevel,
		boolean aggregateCallTree = false
	) {
		var merger = new lucee.extension.lcov.CoverageMerger( logger=arguments.logger );
		var utils = new lucee.extension.lcov.CoverageMergerUtils();

		// Load files one-at-a-time to build mappings without loading all into memory
		var resultFactory = new lucee.extension.lcov.model.result();
		var validResults = {};
		arguments.logger.debug( "Loading #arrayLen(arguments.jsonFilePaths)# files for merge (streaming mode)" );

		for ( var jsonPath in arguments.jsonFilePaths ) {
			var result = resultFactory.fromJson( fileRead( jsonPath ), false );
			if ( structCount( result.getFiles() ) > 0 ) {
				validResults[jsonPath] = result;
			}
			result = nullValue(); // Allow GC
		}

		var mappings = utils.buildFileIndexMappings( validResults );
		var mergedResults = utils.initializeMergedResults( validResults, mappings.filePathToIndex, mappings.indexToFilePath );
		var sourceFileStats = merger.createSourceFileStats( mappings.indexToFilePath );
		merger.mergeAllCoverageDataFromResults( validResults, mergedResults, mappings, sourceFileStats );

		// Clear validResults to free memory before aggregation
		validResults = {};

		if ( arguments.aggregateCallTree ) {
			// Reload results one-at-a-time for CallTree aggregation
			for ( var jsonPath in arguments.jsonFilePaths ) {
				var result = resultFactory.fromJson( fileRead( jsonPath ), false );
				validResults[jsonPath] = result;
			}
			merger.aggregateCallTreeMetricsForMergedResults( mergedResults, validResults );
			validResults = {};
		}

		new lucee.extension.lcov.CoverageStats( logger=arguments.logger ).calculateStatsForMergedResults( mergedResults );

		// Hydrate source code back into mergedResults before writing per-file JSONs
		// This is needed because Phase 1 minimal JSONs don't include source code/AST
		hydrateSourceCodeForMergedResults( mergedResults, arguments.logger );

		// Write per-file JSONs
		var sourceFileJsons = new lucee.extension.lcov.CoverageMergerWriter().writeMergedResultsToFiles( mergedResults, arguments.outputDir, arguments.logLevel );

		// Also write merged.json that contains all coverage aggregated together
		// This is needed by tests and for overall coverage reporting
		var mergedByFile = merger.mergeResultsByFile( arguments.jsonFilePaths, arguments.logLevel );
		var mergedFile = arguments.outputDir & "/merged.json";
		fileWrite( mergedFile, serializeJSON( var=mergedByFile, compact=false ) );
		arguments.logger.debug( "Wrote merged.json with #structCount(mergedByFile.mergedCoverage.files)# files" );

		return sourceFileJsons;
	}

	/**
	 * Hydrate source code back into merged results
	 * Phase 1 minimal JSONs exclude source code/AST to save space (~2MB → ~1KB)
	 * This function loads source code from disk using the file path
	 * @mergedResults Struct of merged result objects (modified in place)
	 * @logger Logger instance
	 */
	private void function hydrateSourceCodeForMergedResults( required struct mergedResults, required any logger ) {
		arguments.logger.debug( "Hydrating source code for #structCount(arguments.mergedResults)# merged results" );
		var fileCacheHelper = new lucee.extension.lcov.parser.FileCacheHelper( logger=arguments.logger, blockProcessor=variables.blockProcessor );

		for ( var canonicalIndex in arguments.mergedResults ) {
			var entry = arguments.mergedResults[canonicalIndex];
			var files = entry.getFiles();

			// Each merged result should have exactly one file
			for ( var fileIdx in files ) {
				var fileInfo = files[fileIdx];
				var filePath = fileInfo.path;

				// Only hydrate if source code is missing
				if ( !structKeyExists( fileInfo, "lines" ) || !isArray( fileInfo.lines ) ) {
					arguments.logger.trace( "Hydrating source code for: " & filePath );

					// Read file from disk and convert to lines array
					var sourceLines = fileCacheHelper.readFileAsArrayBylines( filePath );
					fileInfo.lines = sourceLines;

					// Also store content as single string if needed
					fileInfo.content = arrayToList( sourceLines, chr(10) );

					arguments.logger.trace( "Hydrated " & arrayLen(sourceLines) & " lines for: " & filePath );
				}
			}
		}

		arguments.logger.debug( "Completed hydrating source code" );
	}

}
