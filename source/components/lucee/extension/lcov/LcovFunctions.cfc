component {

	/**
	 * Initialize LCOV functions with optional admin password
	 * @adminPassword Lucee server admin password (optional)
	 * @return This instance
	 */
	public function init(string adminPassword = "") {
		if (len(arguments.adminPassword)) {
			variables.exeLogger = new exeLogger(arguments.adminPassword);
		}
		// TODO not used?
		var logger = new lucee.extension.lcov.Logger( level="none" );
		variables.CoverageBlockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=logger );
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
			var defaultOptions = {
				logLevel: "none",
				unit: "micro",
				minTime: 0,
				className: "lucee.runtime.engine.ResourceExecutionLog"
			};
			var _options = structCopy( defaultOptions );
			structAppend( _options, arguments.options );

			var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );
			var generator = new generator.ReportGenerator( logger=logger );

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
		var defaultOptions = {
			logLevel: "none",
			chunkSize: 50000,
			allowList: [],
			blocklist: [],
			displayUnit: "milli"
		};
		var _options = structCopy( defaultOptions );
		structAppend( _options, arguments.options );

		var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );
		var generator = new generator.ReportGenerator( logger=logger );

		generator.validateExecutionLogDir( arguments.executionLogDir );
		generator.validateOutputDir( arguments.outputDir );

		var htmlDir = arguments.outputDir & "/html";
		var jsonDir = arguments.outputDir & "/json";
		generator.ensureDirectoryExists( htmlDir );
		generator.ensureDirectoryExists( jsonDir );

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
		var defaultOptions = {
			logLevel: "none",
			allowList: [],
			blocklist: [],
			useRelativePath: false
		};
		var _options = structCopy( defaultOptions );
		structAppend( _options, arguments.options );

		var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );
		var generator = new generator.LcovReportGenerator( logger=logger );

		generator.validateExecutionLogDir( arguments.executionLogDir );

		// Phase parseExecutionLogs: Parse .exl files → minimal JSON files
		var parseResult = generator.parseExecutionLogs( arguments.executionLogDir, _options );
		var jsonFilePaths = parseResult.jsonFilePaths;

		// Phase extractAstMetadata: Extract AST metadata (CallTree + executable lines)
		var astMetadataPath = generator.extractAstMetadata( arguments.executionLogDir, parseResult.allFiles, _options );

		// Phase buildLineCoverage: Build line coverage (lazy - skips if already done)
		generator.buildLineCoverage( jsonFilePaths, astMetadataPath, _options );

		// Phase annotateCallTree: Skip CallTree annotation (LCOV doesn't need it!)

		// Phase generateReports: Generate LCOV report
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
		var defaultOptions = {
			logLevel: "none",
			displayUnit: "milli",
			allowList: [],
			blocklist: [],
			separateFiles: false,
			markdown: {
				enabled: true,
				blockBased: false,
				sortBy: "time-desc",
				contextLines: 2,
				minTime: 0,
				minAvg: 0,
				minHitCount: 0
			}
		};
		var _options = structCopy( defaultOptions );
		structAppend( _options, arguments.options, true );

		// Merge markdown options specifically (deep merge)
		if (structKeyExists(arguments.options, "markdown")) {
			structAppend( _options.markdown, arguments.options.markdown, true );
		}

		var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );
		var generator = new generator.HtmlReportGenerator( logger=logger );

		generator.validateExecutionLogDir( arguments.executionLogDir );
		generator.validateOutputDir( arguments.outputDir );

		var startTime = getTickCount();
		generator.ensureDirectoryExists( arguments.outputDir );

		// Phase parseExecutionLogs: Parse .exl files → Raw Coverage JSON files
		var parseResult = generator.parseExecutionLogs( arguments.executionLogDir, _options );
		var jsonFilePaths = parseResult.jsonFilePaths;

		// Phase extractAstMetadata: Extract AST metadata (CallTree + executable lines)
		// Must happen BEFORE buildLineCoverage so AST data is available
		var astMetadataPath = generator.extractAstMetadata( arguments.executionLogDir, parseResult.allFiles, _options );

		// Phase generateReports: Generate HTML reports
		var htmlReporter = generator.createHtmlReporter( logger, _options.displayUnit );
		htmlReporter.setOutputDir( arguments.outputDir );
		htmlReporter.setMarkdownOptions( _options.markdown );
		var htmlIndex = "";

		if (_options.separateFiles) {
			// separateFiles: true → Per-file HTML (one per source file, aggregated across all requests)
			// Phase earlyMergeToSourceFiles: Stream merge Raw Coverage JSONs → per-file results (Stage 2)
			var mergedResults = generator.earlyMergeToSourceFiles( jsonFilePaths, _options );

			// Phase buildLineCoverageFromResults: Build coverage on merged results
			var resultsWithCoverage = generator.buildLineCoverageFromResults(
				mergedResults,
				astMetadataPath,
				_options,
				true  // buildWithCallTree=true for HTML reports
			);


			// Write JSON files (file-*.json) alongside HTML files
			generator.writeJsonFilesFromResults( resultsWithCoverage, arguments.outputDir, logger );

			// Write index.json with summary data
			generator.writeIndexJson( resultsWithCoverage, arguments.outputDir, logger );

			// Generate per-file HTML reports (file-*.html)
			generator.renderHtmlReportsFromResults( resultsWithCoverage, htmlReporter, logger );
		} else {
			// separateFiles: false → Per-request HTML (one per .exl request)
			// Load Raw Coverage JSON files (immutable, only aggregated data)
			var rawResults = generator.loadResultsFromJsonFiles( jsonFilePaths, false );

			// Phase buildLineCoverageFromResults: Build coverage in memory (don't write to disk)
			var resultsWithCoverage = generator.buildLineCoverageFromResults(
				rawResults,
				astMetadataPath,
				_options,
				true  // buildWithCallTree=true for HTML reports
			);

			// Generate per-request HTML reports (request-*.html)
			generator.renderRequestHtmlReports( jsonFilePaths, resultsWithCoverage, htmlReporter, arguments.outputDir, logger );
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
			var defaultOptions = {
				logLevel: "none",
				compact: false,
				includeStats: true,
				separateFiles: false,
				allowList: [],
				blocklist: []
			};
			var _options = structCopy( defaultOptions );
			structAppend( _options, arguments.options );

			var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );
			var generator = new generator.JsonReportGenerator( logger=logger );

			generator.validateExecutionLogDir( arguments.executionLogDir );
			generator.validateOutputDir( arguments.outputDir );

			var startTime = getTickCount();
			generator.ensureDirectoryExists( arguments.outputDir );

			// Phase parseExecutionLogs: Parse .exl files → minimal JSON files
			var parseResult = generator.parseExecutionLogs( arguments.executionLogDir, _options );
		var jsonFilePaths = parseResult.jsonFilePaths;

			// Phase extractAstMetadata: Extract AST metadata (CallTree + executable lines)
			var astMetadataPath = generator.extractAstMetadata( arguments.executionLogDir, parseResult.allFiles, _options );

			// Phase buildLineCoverage+annotateCallTree: Build line coverage WITH CallTree (combined)
			generator.buildLineCoverage( jsonFilePaths, astMetadataPath, _options, true );

			// Phase generateReports: Generate JSON reports
			var jsonFiles = {};
			var totalStats = generator.aggregateCoverageStats( jsonFilePaths, getTickCount() - startTime );

			// Generate separate files if requested
			if (_options.separateFiles) {
				var sourceFileJsons = generator.generateSeparateFileMergedResults( jsonFilePaths, logger, arguments.outputDir, _options.logLevel, false );
				for (var jsonFile in sourceFileJsons) {
					jsonFiles[getFileFromPath(jsonFile)] = jsonFile;
				}
			} else {
				// Load results only for non-separate files mode
				var results = generator.loadResultsFromJsonFiles( jsonFilePaths, false );
				var coreFiles = generator.writeCoreJsonFiles( results, jsonFilePaths, arguments.outputDir, _options.compact, logger, getTickCount() - startTime );
				var requestFiles = generator.writeRequestJsonFiles( results, arguments.outputDir, _options.compact );
				structAppend( jsonFiles, coreFiles );
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
			var defaultOptions = {
				logLevel: "none",
				chunkSize: 50000,
				allowList: [],
				blocklist: []
			};
			var _options = structCopy( defaultOptions );
			structAppend( _options, arguments.options );

			var logger = new lucee.extension.lcov.Logger( level=_options.logLevel );
			var generator = new generator.ReportGenerator( logger=logger );

			generator.validateExecutionLogDir( arguments.executionLogDir );

			var startTime = getTickCount();

			// Phase parseExecutionLogs: Parse .exl files → minimal JSON files
			var parseResult = generator.parseExecutionLogs( arguments.executionLogDir, _options );
		var jsonFilePaths = parseResult.jsonFilePaths;

			// Phase extractAstMetadata: Extract AST metadata (CallTree + executable lines)
			var astMetadataPath = generator.extractAstMetadata( arguments.executionLogDir, parseResult.allFiles, _options );

			// Phase buildLineCoverage: Build line coverage (lazy - skips if already done)
			generator.buildLineCoverage( jsonFilePaths, astMetadataPath, _options );

			// Phase annotateCallTree: Skip CallTree annotation (Summary doesn't need it!)

			// Phase generateReports: Aggregate stats
			var stats = generator.aggregateCoverageStats( jsonFilePaths, getTickCount() - startTime );

			return stats;

		} catch (any e) {
			throw(message="Failed to generate coverage summary: " & e.message, detail=e.detail, cause=e);
		}
	}

}