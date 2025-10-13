/**
 * ReportGenerator.cfc
 *
 * Handles common report generation operations.
 * Each public method does ONE thing and does it well.
 */
component {

	public function init() {
		var logger = new lucee.extension.lcov.Logger( level="none" );
		variables.blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=logger );
		variables.coverageStats = new lucee.extension.lcov.CoverageStats( logger=logger );
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
	 * Parse execution logs and return JSON file paths
	 * @executionLogDir Directory containing .exl files
	 * @options Processing options
	 * @return Array of JSON file paths
	 */
	public array function parseExecutionLogs( required string executionLogDir, required struct options ) {
		var logProcessor = new lucee.extension.lcov.ExecutionLogProcessor( arguments.options );
		return logProcessor.parseExecutionLogs( arguments.executionLogDir, arguments.options );
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
	 * Create logger instance
	 * @logLevel Log level (none, info, debug, trace)
	 * @return Logger instance
	 */
	public any function createLogger( required string logLevel ) {
		return new lucee.extension.lcov.Logger( level=arguments.logLevel );
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
	 * @results Struct of results loaded from JSON files
	 * @logger Logger instance
	 * @outputDir Output directory for merged JSON files
	 * @logLevel Log level for CoverageMergerWriter
	 * @aggregateCallTree Whether to aggregate call tree metrics (for HTML reports)
	 * @return Array of generated source file JSON paths
	 */
	public array function generateSeparateFileMergedResults(
		required struct results,
		required any logger,
		required string outputDir,
		required string logLevel,
		boolean aggregateCallTree = false
	) {
		var merger = new lucee.extension.lcov.CoverageMerger( logger=arguments.logger );
		var utils = new lucee.extension.lcov.CoverageMergerUtils();
		var validResults = utils.filterValidResults( arguments.results );
		var mappings = utils.buildFileIndexMappings( validResults );
		var mergedResults = utils.initializeMergedResults( validResults, mappings.filePathToIndex, mappings.indexToFilePath );
		var sourceFileStats = merger.createSourceFileStats( mappings.indexToFilePath );
		merger.mergeAllCoverageDataFromResults( validResults, mergedResults, mappings, sourceFileStats );

		if ( arguments.aggregateCallTree ) {
			merger.aggregateCallTreeMetricsForMergedResults( mergedResults, arguments.results );
		}

		new lucee.extension.lcov.CoverageStats( logger=arguments.logger ).calculateStatsForMergedResults( mergedResults );
		return new lucee.extension.lcov.CoverageMergerWriter().writeMergedResultsToFiles( mergedResults, arguments.outputDir, arguments.logLevel );
	}

}
