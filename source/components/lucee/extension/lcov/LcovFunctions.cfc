component {

	public function init(string adminPassword = "") {
		if (len(arguments.adminPassword)) {
			variables.exeLogger = new exeLogger(arguments.adminPassword);
		}
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		var useDev = arguments.useDevelop ?: false;
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
			var generator = new generator.ReportGenerator();

			var defaultOptions = {
				unit: "micro",
				minTime: 0,
				className: "lucee.runtime.engine.ResourceExecutionLog"
			};
			var _options = generator.prepareOptions( arguments.options, defaultOptions );

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
				maxlogs = _options.maxLogs ?: 0
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
		var generator = new generator.ReportGenerator();

		generator.validateExecutionLogDir( arguments.executionLogDir );
		generator.validateOutputDir( arguments.outputDir );

		var htmlDir = arguments.outputDir & "/html";
		var jsonDir = arguments.outputDir & "/json";
		generator.ensureDirectoryExists( htmlDir );
		generator.ensureDirectoryExists( jsonDir );

		var defaultOptions = {
			logLevel: "none",
			chunkSize: 50000,
			allowList: [],
			blocklist: [],
			displayUnit: "milli"
		};
		var _options = generator.prepareOptions( arguments.options, defaultOptions );

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
			"htmlFiles": htmlResult.htmlFiles ?: [],
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
		var generator = new generator.LcovReportGenerator();

		generator.validateExecutionLogDir( arguments.executionLogDir );

		var defaultOptions = {
			logLevel: "none",
			allowList: [],
			blocklist: [],
			useRelativePath: false
		};
		var _options = generator.prepareOptions( arguments.options, defaultOptions );

		var jsonFilePaths = generator.parseExecutionLogs( arguments.executionLogDir, _options );

		var lcovContent = generator.buildLcovContent( jsonFilePaths, _options );

		if ( len( arguments.outputFile ) ) {
			generator.writeOutputFile( arguments.outputFile, lcovContent );
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
		var generator = new generator.HtmlReportGenerator();

		generator.validateExecutionLogDir( arguments.executionLogDir );
		generator.validateOutputDir( arguments.outputDir );

		var defaultOptions = {
			logLevel: "none",
			displayUnit: "milli",
			allowList: [],
			blocklist: [],
			separateFiles: false
		};
		var _options = generator.prepareOptions( arguments.options, defaultOptions );

		var startTime = getTickCount();
		var logger = generator.createLogger( _options.logLevel );
		generator.ensureDirectoryExists( arguments.outputDir );

		var jsonFilePaths = generator.parseExecutionLogs( arguments.executionLogDir, _options );

		var htmlReporter = generator.createHtmlReporter( logger, _options.displayUnit );
		htmlReporter.setOutputDir( arguments.outputDir );
		var htmlIndex = "";

		// Process results based on separateFiles option
		if (_options.separateFiles) {
			var mergeFileEvent = logger.beginEvent("Merge File Reports");
			var results = generator.loadResultsFromJsonFiles( jsonFilePaths, false );
			var sourceFileJsons = generator.generateSeparateFileMergedResults( results, logger, arguments.outputDir, _options.logLevel, true );
			logger.commitEvent(mergeFileEvent);
			generator.renderSeparateFileHtmlReports( sourceFileJsons, htmlReporter, logger );
		}

		// For regular mode, generate HTML reports for each request-based result
		if (!_options.separateFiles) {
			var results = generator.loadResultsFromJsonFiles( jsonFilePaths, false );
			generator.renderRequestHtmlReports( jsonFilePaths, results, htmlReporter, arguments.outputDir, logger );
		}

		htmlIndex = htmlReporter.generateIndexHtml(arguments.outputDir);

		var statsEvent = logger.beginEvent("aggregateCoverageStats");
		var totalStats = generator.aggregateCoverageStats( jsonFilePaths, getTickCount() - startTime );
		logger.commitEvent(statsEvent);

		var generatedHtmlFiles = generator.getGeneratedHtmlFiles( arguments.outputDir, true );

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
			var generator = new generator.JsonReportGenerator();

			generator.validateExecutionLogDir( arguments.executionLogDir );
			generator.validateOutputDir( arguments.outputDir );

			var defaultOptions = {
				logLevel: "none",
				compact: false,
				includeStats: true,
				separateFiles: false,
				allowList: [],
				blocklist: []
			};
			var _options = generator.prepareOptions( arguments.options, defaultOptions );

			var startTime = getTickCount();
			var logger = generator.createLogger( _options.logLevel );
			generator.ensureDirectoryExists( arguments.outputDir );

			var jsonFilePaths = generator.parseExecutionLogs( arguments.executionLogDir, _options );
			var results = generator.loadResultsFromJsonFiles( jsonFilePaths, false );

			var jsonFiles = generator.writeCoreJsonFiles( results, jsonFilePaths, arguments.outputDir, _options.compact, logger, getTickCount() - startTime );
			var totalStats = generator.aggregateCoverageStats( jsonFilePaths, getTickCount() - startTime );

			// Generate separate files if requested
			if (_options.separateFiles) {
				var sourceFileJsons = generator.generateSeparateFileMergedResults( results, logger, arguments.outputDir, _options.logLevel, false );
				for (var jsonFile in sourceFileJsons) {
					jsonFiles[getFileFromPath(jsonFile)] = jsonFile;
				}
			} else {
				var requestFiles = generator.writeRequestJsonFiles( results, arguments.outputDir, _options.compact );
				structAppend( jsonFiles, requestFiles );
			}

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
			var generator = new generator.ReportGenerator();

			generator.validateExecutionLogDir( arguments.executionLogDir );

			var defaultOptions = {
				logLevel: "none",
				chunkSize: 50000,
				allowList: [],
				blocklist: []
			};
			var _options = generator.prepareOptions( arguments.options, defaultOptions );

			var startTime = getTickCount();

			var jsonFilePaths = generator.parseExecutionLogs( arguments.executionLogDir, _options );

			var stats = generator.aggregateCoverageStats( jsonFilePaths, getTickCount() - startTime );

			return stats;

		} catch (any e) {
			throw(message="Failed to generate coverage summary: " & e.message, detail=e.detail, cause=e);
		}
	}

}