/**
 * ReportGenerator.cfc
 *
 * Handles common report generation operations.
 * Each public method does ONE thing and does it well.
 */
component {

	/**
	 * Initialize report generator with logger and dependencies
	 * @logger Logger instance for debugging and tracing
	 * @return This instance
	 */
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
	 * Phase extractAstMetadata: Extract AST metadata from unique source files
	 * @executionLogDir Directory containing .exl files and minimal JSONs
	 * @allFiles Struct of all files from parseExecutionLogs phase
	 * @options Processing options
	 * @return Path to ast-metadata.json
	 */
	public string function extractAstMetadata( required string executionLogDir, required struct allFiles, required struct options ) {
		var astMetadataGenerator = new lucee.extension.lcov.ast.AstMetadataGenerator( logger=variables.logger );
		return astMetadataGenerator.generate( arguments.executionLogDir, arguments.allFiles );
	}

	/**
	 * Phase earlyMergeToSourceFiles: Stream merge request-level JSONs to source-level results
	 * This eliminates the need to load all JSONs into memory at once (7.8GB → 500MB)
	 * @jsonFilePaths Array of JSON file paths to merge
	 * @options Processing options
	 * @return Struct of merged result objects keyed by canonical index
	 */
	public struct function earlyMergeToSourceFiles( required array jsonFilePaths, required struct options ) {
		var streamingMerger = new lucee.extension.lcov.StreamingMerger( logger=variables.logger );
		return streamingMerger.streamMergeToSourceFiles(
			jsonFilePaths = arguments.jsonFilePaths,
			parallel = true,
			chunkSize = 100
		);
	}

	/**
	 * Phase buildLineCoverage: Build line coverage from aggregated blocks
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json (optional)
	 * @options Processing options
	 * @return Array of JSON file paths
	 */
	public array function buildLineCoverage( required array jsonFilePaths, string astMetadataPath, required struct options, boolean buildWithCallTree = false ) {
		var coverageBuilder = new lucee.extension.lcov.coverage.LineCoverageBuilder( logger=variables.logger );
		return coverageBuilder.buildCoverage( arguments.jsonFilePaths, arguments.astMetadataPath, arguments.buildWithCallTree );
	}

	/**
	 * Phase buildLineCoverageFromResults: Build line coverage from in-memory results
	 * NEW: Works with already-merged in-memory results (Stage 2 optimization)
	 * @mergedResults Struct of merged result objects keyed by canonical index
	 * @astMetadataPath Path to ast-metadata.json
	 * @options Processing options
	 * @buildWithCallTree Whether to mark blocks with isChild flags
	 * @return Struct of results with coverage added
	 */
	public struct function buildLineCoverageFromResults(
		required struct mergedResults,
		string astMetadataPath,
		required struct options,
		boolean buildWithCallTree = false
	) {
		var coverageBuilder = new lucee.extension.lcov.coverage.LineCoverageBuilder( logger=variables.logger );
		return coverageBuilder.buildCoverageFromResults( arguments.mergedResults, arguments.astMetadataPath, arguments.buildWithCallTree );
	}

	/**
	 * Phase annotateCallTree: Annotate CallTree (mark blocks with isChildTime flags)
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
		var loadEvent = arguments.logger.beginEvent( "Merge: Load #arrayLen(arguments.jsonFilePaths)# JSON files" );
		var resultFactory = new lucee.extension.lcov.model.result();
		var validResults = {};

		for ( var jsonPath in arguments.jsonFilePaths ) {
			var result = resultFactory.fromJson( fileRead( jsonPath ), false );
			if ( structCount( result.getFiles() ) > 0 ) {
				validResults[jsonPath] = result;
			}
			result = nullValue(); // Allow GC
		}
		arguments.logger.commitEvent( loadEvent, 0, "info" );

		var mappingEvent = arguments.logger.beginEvent( "Merge: Build file mappings for #structCount(validResults)# results" );
		var mappings = utils.buildFileIndexMappings( validResults );
		var mergedResults = utils.initializeMergedResults( validResults, mappings.filePathToIndex, mappings.indexToFilePath );
		arguments.logger.commitEvent( mappingEvent, 0, "info" );

		var mergeEvent = arguments.logger.beginEvent( "Merge: Merge coverage for #structCount(mappings.indexToFilePath)# unique files" );
		var sourceFileStats = merger.createSourceFileStats( mappings.indexToFilePath );
		merger.mergeAllCoverageDataFromResults( validResults, mergedResults, mappings, sourceFileStats );
		arguments.logger.commitEvent( mergeEvent, 0, "info" );

		// Clear validResults to free memory
		// Note: CallTree aggregation now happens during merge (above), no need to reload files!
		validResults = {};

		var statsEvent = arguments.logger.beginEvent( "Merge: Calculate stats for #structCount(mergedResults)# files" );
		new lucee.extension.lcov.CoverageStats( logger=arguments.logger ).calculateStatsForMergedResults( mergedResults );
		arguments.logger.commitEvent( statsEvent, 0, "info" );

		// Hydrate source code back into mergedResults before writing per-file JSONs
		// This is needed because parseExecutionLogs minimal JSONs don't include source code/AST
		var hydrateEvent = arguments.logger.beginEvent( "Merge: Hydrate source code for #structCount(mergedResults)# files" );
		hydrateSourceCodeForMergedResults( mergedResults, arguments.logger );
		arguments.logger.commitEvent( hydrateEvent, 0, "info" );

		// Write per-file JSONs
		var writeEvent = arguments.logger.beginEvent( "Merge: Write #structCount(mergedResults)# per-file JSONs" );
		var sourceFileJsons = new lucee.extension.lcov.CoverageMergerWriter().writeMergedResultsToFiles( mergedResults, arguments.outputDir, arguments.logLevel );
		arguments.logger.commitEvent( writeEvent, 0, "info" );

		// Also write merged.json that contains all coverage aggregated together
		// This is needed by tests and for overall coverage reporting
		var mergedJsonEvent = arguments.logger.beginEvent( "Merge: Build merged.json from memory" );
		var mergedByFile = merger.buildMergedJsonFromMergedResults( mergedResults );
		var mergedFile = arguments.outputDir & "/merged.json";
		fileWrite( mergedFile, serializeJSON( var=mergedByFile, compact=false ) );
		arguments.logger.commitEvent( mergedJsonEvent, 0, "info" );

		return sourceFileJsons;
	}

	/**
	 * Hydrate source code back into merged results
	 * parseExecutionLogs minimal JSONs exclude source code/AST to save space (~2MB → ~1KB)
	 * This function loads source code from disk using the file path
	 * @mergedResults Struct of merged result objects (modified in place)
	 * @logger Logger instance
	 */
	public void function hydrateSourceCodeForMergedResults( required struct mergedResults, required any logger ) {
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
