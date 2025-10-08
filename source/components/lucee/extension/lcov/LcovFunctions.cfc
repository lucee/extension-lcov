component {

	public function init(string adminPassword = "") {
		if (len(arguments.adminPassword)) {
			variables.exeLogger = new exeLogger(arguments.adminPassword);
		}
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		var useDev = structKeyExists(arguments, "useDevelop") ? arguments.useDevelop : false;
		variables.CoverageBlockProcessor = variables.factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=useDev);
		return this;
	}

	/**
	 * Enable execution logging for code coverage collection
	 * @adminPassword Lucee server admin password (required)
	 * @executionLogDir Directory for .exl files (optional - auto-generates if empty)
	 * @options Configuration options struct (optional)
	 * @return String path to the log directory being used
	 */
	public string function lcovStartLogging(required string adminPassword, required string executionLogDir = "", struct options = {}) {
		try {
			// Set default options
			var defaultOptions = {
				unit: "micro",
				minTime: 0,
				className: "lucee.runtime.engine.ResourceExecutionLog"
			};
			var _options = mergeDefaultOptions(defaultOptions, arguments.options);

			// Generate temp directory if not provided
			var logDir = len(arguments.executionLogDir) ? arguments.executionLogDir :
				getTempDirectory() & "lcov-execution-log-" & createUUID();

			// Validate user-specified directory exists, or create auto-generated directory
			if (len(arguments.executionLogDir)) {
				if (!directoryExists(logDir)) {
					throw(type="DirectoryNotFound", message="Execution log directory [executionLogDir] does not exist: [" & logDir & "]");
				}
			} else if (!directoryExists(logDir)) {
				directoryCreate(logDir, true);
			}

			// Enable execution logging
			var result = variables.exeLogger.enableExecutionLog(
				class = _options.className,
				args = {
					"unit": _options.unit,
					"min-time": _options.minTime,
					"directory": logDir
				},
				maxlogs = structKeyExists(_options, "maxLogs") ? _options.maxLogs : 0
			);

			return logDir;

		} catch (any e) {
			throw(message="Failed to start LCOV logging: " & e.message, detail=e.detail, cause=e);
		}
	}

	/**
	 * Disable execution logging
	 * @adminPassword Lucee server admin password (required)
	 * @className Log implementation class to disable (optional, defaults to ResourceExecutionLog)
	 */
	public void function lcovStopLogging(required string adminPassword, string className = "lucee.runtime.engine.ResourceExecutionLog") {
		try {
			variables.exeLogger.disableExecutionLog(class = arguments.className);
		} catch (any e) {
			throw(message="Failed to stop LCOV logging: " & e.message, detail=e.detail, cause=e);
		}
	}

	/**
	 * Generate all report types (HTML, JSON, and LCOV)
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @outputDir Base directory for all generated reports (required)
	 * @options Configuration options struct (optional)
	 * @return Struct with generated file paths and statistics
	 */
	public struct function lcovGenerateAllReports(required string executionLogDir, required string outputDir, struct options = {}) {
		// Validate required directories exist
		if (!directoryExists(arguments.executionLogDir)) {
			throw(type="DirectoryNotFound", message="Execution log directory [executionLogDir] does not exist: [" & arguments.executionLogDir & "]");
		}

		// Validate output directory exists - throw error if missing
		if (!directoryExists(arguments.outputDir)) {
			throw(message="Output directory [outputDir] does not exist: [" & arguments.outputDir & "]");
		}

		// Ensure required subdirectories exist
		var htmlDir = arguments.outputDir & "/html";
		var jsonDir = arguments.outputDir & "/json";
		if (!directoryExists(htmlDir)) {
			directoryCreate(htmlDir, true);
		}
		if (!directoryExists(jsonDir)) {
			directoryCreate(jsonDir, true);
		}

		// Set default options
		var defaultOptions = {
			logLevel: "none",
			chunkSize: 50000,
			allowList: [],
			blocklist: [],
			displayUnit: "milli"
		};
		var _options = mergeDefaultOptions(defaultOptions, arguments.options);

		var startTime = getTickCount();

		// Generate LCOV report
		var lcovFile = arguments.outputDir & "/lcov.info";
		var lcovContent = lcovGenerateLcov(
			executionLogDir = arguments.executionLogDir,
			outputFile = lcovFile,
			options = _options
		);

		// Generate HTML reports
		var htmlResult = lcovGenerateHtml(
			executionLogDir = arguments.executionLogDir,
			outputDir = arguments.outputDir & "/html",
			options = _options
		);

		// Generate JSON reports
		var jsonResult = lcovGenerateJson(
			executionLogDir = arguments.executionLogDir,
			outputDir = arguments.outputDir & "/json",
			options = _options
		);

		// Calculate overall stats
		var processingTime = getTickCount() - startTime;
		
		return {
			"lcovFile": lcovFile,
			"htmlIndex": htmlResult.htmlIndex,
			"htmlFiles": structKeyExists(htmlResult, "htmlFiles") ? htmlResult.htmlFiles : [],
			"jsonFiles": jsonResult.jsonFiles,
			"stats": {
				"totalLinesFound": htmlResult.stats.totalLinesFound,
				"totalLinesSource": htmlResult.stats.totalLinesSource,
				"totalLinesHit": htmlResult.stats.totalLinesHit,
				"coveragePercentage": htmlResult.stats.coveragePercentage,
				"totalFiles": htmlResult.stats.totalFiles,
				"processingTimeMs": processingTime
			}
		};
	}

	/**
	 * Generate LCOV format report
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @outputFile Path for LCOV output file (optional - if empty, returns string content)
	 * @options Configuration options struct (optional)
	 * @return String containing LCOV file content
	 */
	public string function lcovGenerateLcov(required string executionLogDir, string outputFile = "", struct options = {}) {
		// Validate required directories exist
		if (!directoryExists(arguments.executionLogDir)) {
			throw(type="DirectoryNotFound", message="Execution log directory [executionLogDir] does not exist: [" & arguments.executionLogDir & "]");
		}

		// Set default options
		var defaultOptions = {
			logLevel: "none",
			allowList: [],
			blocklist: [],
			useRelativePath: false
		};
		var _options = mergeDefaultOptions(defaultOptions, arguments.options);

		// Parse .exl files using ExecutionLogProcessor
		var logProcessor = new ExecutionLogProcessor(_options);
		var jsonFilePaths = logProcessor.parseExecutionLogs(arguments.executionLogDir, _options);

		// Generate LCOV content
		var lcovContent = buildLcovContent(jsonFilePaths, _options);

		// JSON files are now permanent cache files next to .exl files - no cleanup needed

		// Write to file if outputFile provided
		if (len(arguments.outputFile)) {
			var factory = new lucee.extension.lcov.CoverageComponentFactory();
			factory.getComponent(name="CoverageBlockProcessor").ensureDirectoryExists(getDirectoryFromPath(arguments.outputFile));
			fileWrite(arguments.outputFile, lcovContent);
		}

		return lcovContent;
	}

	/**
	 * Generate HTML reports
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @outputDir Directory where HTML files will be generated (required)
	 * @options Configuration options struct (optional)
	 * @return Struct with generated file paths and statistics
	 */
	public struct function lcovGenerateHtml(required string executionLogDir, required string outputDir, struct options = {}) {
		// Validate required directories exist
		if (!directoryExists(arguments.executionLogDir)) {
			throw(type="DirectoryNotFound", message="Execution log directory [executionLogDir] does not exist: [" & arguments.executionLogDir & "]");
		}

		// Validate output directory exists - throw error if missing
		if (!directoryExists(arguments.outputDir)) {
			throw(message="Output directory [outputDir] does not exist: [" & arguments.outputDir & "]");
		}

		// Set default options
		var defaultOptions = {
			logLevel: "none",
			displayUnit: "milli",
			allowList: [],
			blocklist: [],
			separateFiles: false
		};
		var _options = mergeDefaultOptions(defaultOptions, arguments.options);

		var startTime = getTickCount();
		var logger = new lucee.extension.lcov.Logger(level=_options.logLevel);
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		factory.getComponent(name="CoverageBlockProcessor").ensureDirectoryExists(arguments.outputDir);

		// Parse execution logs using ExecutionLogProcessor
		var logProcessor = new ExecutionLogProcessor( _options );
		var jsonFilePaths = logProcessor.parseExecutionLogs( arguments.executionLogDir, _options );

		// Generate HTML reports using focused HTML reporter
		var htmlReporter = new reporter.HtmlReporter( logger=logger, displayUnit=_options.displayUnit );
		htmlReporter.setOutputDir( arguments.outputDir ); // Set output directory for individual HTML files
		var htmlIndex = "";

		// Process results based on separateFiles option
		if (_options.separateFiles) {
			var mergeFileEvent = logger.beginEvent("Merge File Reports");
			// Load results from JSON files for per-file processing
			var results = {};
			var resultFactory = new lucee.extension.lcov.model.result();
			for (var jsonPath in jsonFilePaths) {
				var result = resultFactory.fromJson(fileRead(jsonPath), false);
				results[jsonPath] = result;
				result = nullValue(); // Clear reference immediately
			}

			// Create per-file merged results following the same pattern as CoverageMergerTest
			var merger = new lucee.extension.lcov.CoverageMerger( logger=logger );
			var utils = new lucee.extension.lcov.CoverageMergerUtils();
			var validResults = utils.filterValidResults(results);
			var mappings = utils.buildFileIndexMappings(validResults);
			var mergedResults = utils.initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
			logger.commitEvent(mergeFileEvent);
			var mergeStatsEvent = logger.beginEvent("Merge File Stats");
			// Merge results into per-file mergedResults struct
			// Aggregate call tree metrics before calculating stats
			merger.aggregateCallTreeMetricsForMergedResults(mergedResults, results);
			new lucee.extension.lcov.CoverageStats( logger=logger ).calculateStatsForMergedResults( mergedResults );
			var sourceFileJsons = new CoverageMergerWriter().writeMergedResultsToFiles( mergedResults, arguments.outputDir, _options.logLevel );
			logger.commitEvent(mergeStatsEvent);
			var fileEvent = logger.beginEvent("Render Per-File HTML Reports");
			// Generate HTML reports for each source file JSON
			var resultFactory = new lucee.extension.lcov.model.result();
			for (var jsonFile in sourceFileJsons) {
				var start 	= getTickCount();
				// Use result model's fromJson to ensure all required fields and validation
				var sourceResult = resultFactory.fromJson(fileRead(jsonFile), true);
				sourceResult.validate();

				// Set exeLog to the source file path for separated files mode
				// This tells HtmlReporter to use source file naming instead of request-based naming
				var sourceFilePath = getFileFromPath(jsonFile);
				sourceFilePath = reReplace(sourceFilePath, "^file-[^-]+-", ""); // Remove file-{hash}- prefix
				sourceFilePath = reReplace(sourceFilePath, "\.json$", ""); // Remove .json extension
				sourceResult.setExeLog(sourceFilePath);

				var htmlPath = htmlReporter.generateHtmlReport(sourceResult);
			}
			logger.commitEvent(fileEvent);
		}

		// For regular mode, generate HTML reports for each request-based result
		if (!_options.separateFiles) {
			var reqEvent = logger.beginEvent("Render Per-Request HTML Reports");
			// Load results from JSON paths and generate HTML reports
			var resultFactory = new lucee.extension.lcov.model.result();
			for (var jsonPath in jsonFilePaths) {
				var result = resultFactory.fromJson(fileRead(jsonPath), false);
				// Always use fileIndex (typically 0) for coverage and files
				var coverage = result.getCoverage();
				if (structKeyExists(coverage, "0") && !structIsEmpty(coverage["0"])) {
					// Write request JSON file to output directory using same filename as HTML
					var jsonFileName = result.getOutputFilename() & ".json";
					fileWrite(arguments.outputDir & "/" & jsonFileName, serializeJSON(var=result, compact=false));

					// Generate HTML report
					htmlReporter.generateHtmlReport(result);
				}
			}
			logger.commitEvent(reqEvent);
		}

		// Generate index HTML
		htmlIndex = htmlReporter.generateIndexHtml(arguments.outputDir);

		var statsEvent = logger.beginEvent("aggregateCoverageStats");

		// Calculate aggregated stats progressively
		var statsComponent = variables.factory.getComponent(name="CoverageStats");
		var totalStats = statsComponent.aggregateCoverageStats(jsonFilePaths, getTickCount() - startTime);

		logger.commitEvent(statsEvent);

		// Get list of generated HTML files (excluding index.html)
		var generatedHtmlFiles = [];
		var allHtmlFiles = directoryList(arguments.outputDir, false, "name", "*.html");
		for (var htmlFile in allHtmlFiles) {
			if (htmlFile != "index.html") {
				arrayAppend(generatedHtmlFiles, htmlFile);
			}
		}

		logger.debug("Generated HTML reports for " & totalStats.totalFiles & " files, in " & (getTickCount() - startTime) & "ms");

		return {
			"htmlIndex": htmlIndex,
			"htmlFiles": generatedHtmlFiles,
			"stats": totalStats
		};

	}


	/**
	 * Generate JSON reports
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @outputDir Directory where JSON files will be saved (required)
	 * @options Configuration options struct (optional)
	 * @return Struct with generated file paths and statistics
	 */
	public struct function lcovGenerateJson(required string executionLogDir, required string outputDir, struct options = {}) {
		try {
			// Validate required directories exist
			if (!directoryExists(arguments.executionLogDir)) {
				throw(type="DirectoryNotFound", message="Execution log directory does not exist: [" & arguments.executionLogDir & "]");
			}

			// Validate output directory exists - throw error if missing
			if (!directoryExists(arguments.outputDir)) {
				throw(message="Output directory does not exist: [" & arguments.outputDir & "]");
			}

			// Set default options
			var defaultOptions = {
				logLevel: "none",
				compact: false,
				includeStats: true,
				separateFiles: false,
				allowList: [],
				blocklist: []
			};
			var _options = mergeDefaultOptions(defaultOptions, arguments.options);

			var startTime = getTickCount();
			var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );

			var factory = new lucee.extension.lcov.CoverageComponentFactory();
			factory.getComponent( name="CoverageBlockProcessor" ).ensureDirectoryExists( arguments.outputDir );

			// Parse execution logs using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(_options);
			var jsonFilePaths = logProcessor.parseExecutionLogs(arguments.executionLogDir, _options);

			// Generate JSON files directly from parsed results (processed progressively)
			var jsonFiles = {};
			var totalStats = {
				totalLinesSource: 0,
				totalLinesHit: 0,
				totalLinesFound: 0,
				coveragePercentage: 0,
				totalFiles: 0,
				processingTimeMs: 0
			};

			// Create results JSON from individual JSON files
			var results = {};
			var resultFactory = new lucee.extension.lcov.model.result();
			for (var jsonPath in jsonFilePaths) {
				var result = resultFactory.fromJson(fileRead(jsonPath), false);
				results[jsonPath] = result;
				result = nullValue(); // Clear reference immediately
			}
			var resultsFile = arguments.outputDir & "/results.json";
			fileWrite(resultsFile, serializeJSON(var=results, compact=_options.compact));
			jsonFiles.results = resultsFile;

			// Create merged coverage data progressively from JSON files
			var merged = new lucee.extension.lcov.CoverageMerger( logger=logger ).mergeResultsByFile( jsonFilePaths );
			var mergedFile = arguments.outputDir & "/merged.json";
			fileWrite(mergedFile, serializeJSON(var=merged, compact=_options.compact));
			jsonFiles.merged = mergedFile;

			// Calculate aggregated stats from JSON files using CoverageStats
			var statsComponent = variables.factory.getComponent(name="CoverageStats");
			var totalStats = statsComponent.aggregateCoverageStats(jsonFilePaths, getTickCount() - startTime);

			var statsFile = arguments.outputDir & "/summary-stats.json";
			fileWrite(statsFile, serializeJSON(var=totalStats, compact=_options.compact));
			jsonFiles.stats = statsFile;

			// Generate separate files if requested
			if (_options.separateFiles) {
				// Create per-file merged results following the same pattern as CoverageMergerTest
				var merger = new lucee.extension.lcov.CoverageMerger( logger=logger );
				var utils = new lucee.extension.lcov.CoverageMergerUtils();
				var validResults = utils.filterValidResults( results );
				var mappings = utils.buildFileIndexMappings( validResults );
				var mergedResults = utils.initializeMergedResults( validResults, mappings.filePathToIndex, mappings.indexToFilePath );
				var sourceFileStats = merger.createSourceFileStats( mappings.indexToFilePath );
				merger.mergeAllCoverageDataFromResults( validResults, mergedResults, mappings, sourceFileStats );
				new lucee.extension.lcov.CoverageStats( logger=logger ).calculateStatsForMergedResults( mergedResults );
				var sourceFileJsons = new CoverageMergerWriter().writeMergedResultsToFiles( mergedResults, arguments.outputDir, _options.logLevel );
				for (var jsonFile in sourceFileJsons) {
					jsonFiles[getFileFromPath(jsonFile)] = jsonFile;
				}
			} else {
				// Write request-based JSON files
				for (var resultKey in results) {
					var result = results[resultKey];
					if (structKeyExists(result, "coverage") && !structIsEmpty(result.coverage)) {
						var fileName = getFileFromPath(resultKey);
						// Use outputFilename property set by the log processor
						var jsonFileName = result.getOutputFilename() & ".json";
						var jsonFilePath = arguments.outputDir & "/" & jsonFileName;
						fileWrite(jsonFilePath, serializeJSON(var=result, compact=_options.compact));
						jsonFiles[jsonFileName] = jsonFilePath;
					}
				}
			}

			// Clean up temp JSON files after consumption
			// JSON files are now permanent cache files next to .exl files - no cleanup needed

			return {
				"jsonFiles": jsonFiles,
				"stats": totalStats
			};

		} catch (any e) {
			throw(message="Failed to generate JSON reports: " & e.message, detail=e.detail, cause=e);
		}
	}

	/**
	 * Generate coverage statistics only (no file generation)
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @options Configuration options struct (optional)
	 * @return Struct with coverage statistics
	 */
	public struct function lcovGenerateSummary(required string executionLogDir, struct options = {}) {
		try {
			// Validate required directories exist
			if (!directoryExists(arguments.executionLogDir)) {
				throw(type="DirectoryNotFound", message="Execution log directory does not exist: [" & arguments.executionLogDir & "]");
			}

			// Set default options
			var defaultOptions = {
				logLevel: "none",
				chunkSize: 50000,
				allowList: [],
				blocklist: []
			};
			var _options = mergeDefaultOptions(defaultOptions, arguments.options);

			var startTime = getTickCount();

			// Parse execution logs for stats only using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(_options);
			var jsonFilePaths = logProcessor.parseExecutionLogs(arguments.executionLogDir, _options);

			// Calculate stats progressively without loading all results into memory
			var statsComponent = variables.factory.getComponent(name="CoverageStats");
			var stats = statsComponent.aggregateCoverageStats(jsonFilePaths, getTickCount() - startTime);

			// Clean up temp JSON files after consumption
			// JSON files are now permanent cache files next to .exl files - no cleanup needed

			return stats;

		} catch (any e) {
			throw(message="Failed to generate coverage summary: " & e.message, detail=e.detail, cause=e);
		}
	}

	// ========== Private Helper Methods ==========

	/**
	 * Utility method to merge default options with user-provided options
	 * @defaultOptions The default options struct
	 * @userOptions The user-provided options struct
	 * @return Merged options struct
	 */
	private struct function mergeDefaultOptions(required struct defaultOptions, struct userOptions = {}) {
		var merged = duplicate(arguments.defaultOptions);
		structAppend(merged, arguments.userOptions);
		return merged;
	}

	private string function buildLcovContent(required array jsonFilePaths, required struct options) {
		var logger = new lucee.extension.lcov.Logger( level=arguments.options.logLevel ?: "none" );

		// Process JSON files progressively without loading all into memory
		var merger = new lucee.extension.lcov.CoverageMerger( logger=logger );
		var merged = merger.mergeResultsByFile( arguments.jsonFilePaths );

		// NEW: Aggregate blocks to line coverage using BlockAggregator
		var blockAggregator = new lucee.extension.lcov.BlockAggregator();
		var lineCoverage = {};

		// Check if blocks exist in merged data
		if ( structKeyExists( merged.mergedCoverage, "blocks" ) && structCount( merged.mergedCoverage.blocks ) > 0 ) {
			// Use new block-based pipeline
			logger.debug( "Using block-based aggregation for LCOV generation" );
			lineCoverage = blockAggregator.aggregateMergedBlocksToLines(
				merged.mergedCoverage.blocks,
				merged.mergedCoverage.files
			);
		} else {
			// Fallback to old coverage data if no blocks
			logger.debug( "No blocks found, using existing line coverage" );
			lineCoverage = merged.mergedCoverage.coverage;
		}

		// Replace old coverage with new aggregated coverage
		var mergedForLcov = {
			"files": merged.mergedCoverage.files,
			"coverage": lineCoverage
		};

		// write out merged to a json file a log it
		var tempMerged = getTempFile( "", "lcov-merged-", ".json" );
		fileWrite( tempMerged, serializeJSON( var=merged, compact=false ) );

		// Create LCOV writer with logger and build LCOV format
		var lcovWriter = new reporter.LcovWriter( logger=logger, options=arguments.options );
		return lcovWriter.buildLCOV( mergedForLcov, arguments.options.useRelativePath ?: false );
	}

	/**
	 * Clean up temporary JSON files created by ExecutionLogProcessor
	 * @jsonFilePaths Array of temp JSON file paths to delete
	 */
	private void function cleanupTempJsonFiles(required array jsonFilePaths) {
		for (var jsonPath in arguments.jsonFilePaths) {
			try {
				if (fileExists(jsonPath)) {
					fileDelete(jsonPath);
				}
			} catch (any e) {
				// Log but don't fail - temp cleanup errors shouldn't break processing
				systemOutput("Warning: Could not delete temp JSON file: " & jsonPath & " - " & e.message, true);
			}
		}
	}

}