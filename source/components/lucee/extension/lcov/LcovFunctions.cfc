component {

	public function init(string adminPassword = "") {
		if (len(arguments.adminPassword)) {
			variables.exeLogger = new exeLogger(arguments.adminPassword);
		}
		variables.codeCoverageUtils = new codeCoverageUtils();
		return this;
	}

	/**
	 * Enable execution logging for code coverage collection
	 * @adminPassword Lucee server admin password (required)
	 * @executionLogDir Directory for .exl files (optional - auto-generates if empty)
	 * @options Configuration options struct (optional)
	 * @return String path to the log directory being used
	 */
	public string function lcovStartLogging(required string adminPassword, string executionLogDir = "", struct options = {}) {
		try {
			// Set default options
			var defaultOptions = {
				unit: "micro",
				minTime: 0,
				className: "lucee.runtime.engine.ResourceExecutionLog"
			};
			var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

			// Generate temp directory if not provided
			var logDir = len(arguments.executionLogDir) ? arguments.executionLogDir : 
				getTempDirectory() & "lcov-execution-log-" & createUUID();

			// Create directory if it was auto-generated (user-specified directories should already exist)
			if (!len(arguments.executionLogDir) && !directoryExists(logDir)) {
				directoryCreate(logDir, true);
			}

			// Enable execution logging
			var result = variables.exeLogger.enableExecutionLog(
				class = mergedOptions.className,
				args = {
					"unit": mergedOptions.unit,
					"min-time": mergedOptions.minTime,
					"directory": logDir
				},
				maxlogs = structKeyExists(mergedOptions, "maxLogs") ? mergedOptions.maxLogs : 0
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
		try {
			// Set default options
			var defaultOptions = {
				verbose: false,
				chunkSize: 50000,
				allowList: [],
				blocklist: [],
				displayUnit: "milli"
			};
			var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

			var startTime = getTickCount();

			// Generate LCOV report
			var lcovFile = arguments.outputDir & "/lcov.info";
			var lcovContent = lcovGenerateLcov(
				executionLogDir = arguments.executionLogDir,
				outputFile = lcovFile,
				options = mergedOptions
			);

			// Generate HTML reports
			var htmlResult = lcovGenerateHtml(
				executionLogDir = arguments.executionLogDir,
				outputDir = arguments.outputDir & "/html",
				options = mergedOptions
			);

			// Generate JSON reports
			var jsonResult = lcovGenerateJson(
				executionLogDir = arguments.executionLogDir,
				outputDir = arguments.outputDir & "/json",
				options = mergedOptions
			);

			// Calculate overall stats
			var processingTime = getTickCount() - startTime;
			
			return {
				"lcovFile": lcovFile,
				"htmlIndex": htmlResult.htmlIndex,
				"htmlFiles": structKeyExists(htmlResult, "htmlFiles") ? htmlResult.htmlFiles : [],
				"jsonFiles": jsonResult.jsonFiles,
				"stats": {
					"totalLines": htmlResult.stats.totalLines,
					"coveredLines": htmlResult.stats.coveredLines,
					"coveragePercentage": htmlResult.stats.coveragePercentage,
					"totalFiles": htmlResult.stats.totalFiles,
					"processingTimeMs": processingTime
				}
			};

		} catch (any e) {
			throw(message="Failed to generate all reports: " & e.message, detail=e.detail, cause=e);
		}
	}

	/**
	 * Generate LCOV format report
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @outputFile Path for LCOV output file (optional - if empty, returns string content)
	 * @options Configuration options struct (optional)
	 * @return String containing LCOV file content
	 */
	public string function lcovGenerateLcov(required string executionLogDir, string outputFile = "", struct options = {}) {
		try {
			// Set default options
			var defaultOptions = {
				verbose: false,
				allowList: [],
				blocklist: [],
				useRelativePath: false
			};
			var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

			if (mergedOptions.verbose) {
				systemOutput("Generating LCOV report from: " & arguments.executionLogDir, true);
			}

			// Parse .exl files using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(mergedOptions);
			var results = logProcessor.parseExecutionLogs(arguments.executionLogDir, mergedOptions);
			
			// Generate LCOV content
			var lcovContent = buildLcovContent(results, mergedOptions);

			// Write to file if outputFile provided
			if (len(arguments.outputFile)) {
				variables.codeCoverageUtils.ensureDirectoryExists(getDirectoryFromPath(arguments.outputFile));
				fileWrite(arguments.outputFile, lcovContent);
				if (mergedOptions.verbose) {
					systemOutput("LCOV file written to: " & arguments.outputFile, true);
				}
			}

			return lcovContent;

		} catch (any e) {
			throw(message="Failed to generate LCOV report: " & e.message, detail=e.detail, cause=e);
		}
	}

	/**
	 * Generate HTML reports
	 * @executionLogDir Directory containing .exl execution log files (required)
	 * @outputDir Directory where HTML files will be generated (required)
	 * @options Configuration options struct (optional)
	 * @return Struct with generated file paths and statistics
	 */
	public struct function lcovGenerateHtml(required string executionLogDir, required string outputDir, struct options = {}) {
		try {
			// Set default options
			var defaultOptions = {
				verbose: false,
				displayUnit: "milli",
				allowList: [],
				blocklist: []
			};
			var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

			var startTime = getTickCount();

			if (mergedOptions.verbose) {
				systemOutput("Generating HTML reports from: " & arguments.executionLogDir, true);
			}

			variables.codeCoverageUtils.ensureDirectoryExists(arguments.outputDir);

			// Parse execution logs using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(mergedOptions);
			var results = logProcessor.parseExecutionLogs(arguments.executionLogDir, mergedOptions);

			// Generate HTML reports using focused HTML reporter
			var htmlReporter = new reporter.HtmlReporter(mergedOptions.displayUnit, mergedOptions.verbose);
			htmlReporter.setOutputDir(arguments.outputDir); // Set output directory for individual HTML files
			var htmlIndex = "";
			var totalStats = {
				totalLines: 0,
				coveredLines: 0,
				coveragePercentage: 0,
				totalFiles: 0,
				processingTimeMs: 0
			};

			// Generate individual HTML reports for each result
			for (var exlPath in results) {
				var result = results[exlPath];
				if (structKeyExists(result, "coverage") && !structIsEmpty(result.coverage)) {
					htmlReporter.generateHtmlReport(result);
					
					// Accumulate stats
					if (structKeyExists(result, "stats")) {
						totalStats.totalLines += val(result.stats.totalLines ?: 0);
						totalStats.coveredLines += val(result.stats.coveredLines ?: 0);
						totalStats.totalFiles++;
					}
				}
			}

			// Generate index HTML
			htmlIndex = htmlReporter.generateIndexHtml(arguments.outputDir);

			// Calculate overall coverage percentage and processing time
			totalStats.coveragePercentage = totalStats.totalLines > 0 ? 
				(totalStats.coveredLines / totalStats.totalLines) * 100 : 0;
			totalStats.processingTimeMs = getTickCount() - startTime;

			return {
				"htmlIndex": htmlIndex,
				"stats": totalStats
			};

		} catch (any e) {
			throw(message="Failed to generate HTML reports: " & e.message, detail=e.detail, cause=e);
		}
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
			// Set default options
			var defaultOptions = {
				verbose: false,
				compact: false,
				includeStats: true,
				separateFiles: false,
				allowList: [],
				blocklist: []
			};
			var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

			var startTime = getTickCount();

			if (mergedOptions.verbose) {
				systemOutput("Generating JSON reports from: " & arguments.executionLogDir, true);
			}

			variables.codeCoverageUtils.ensureDirectoryExists(arguments.outputDir);

			// Parse execution logs using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(mergedOptions);
			var results = logProcessor.parseExecutionLogs(arguments.executionLogDir, mergedOptions);

			// Generate JSON files directly from parsed results
			var jsonFiles = {};
			var totalStats = {
				totalLines: 0,
				coveredLines: 0,
				coveragePercentage: 0,
				totalFiles: 0,
				processingTimeMs: 0
			};

			// Create results JSON
			var resultsFile = arguments.outputDir & "/results.json";
			fileWrite(resultsFile, serializeJSON(var=results, compact=mergedOptions.compact));
			jsonFiles.results = resultsFile;

			// Create merged coverage data
			var merged = variables.codeCoverageUtils.mergeResultsByFile(results);
			var mergedFile = arguments.outputDir & "/merged.json"; 
			fileWrite(mergedFile, serializeJSON(var=merged, compact=mergedOptions.compact));
			jsonFiles.merged = mergedFile;

			// Calculate and create stats
			for (var exlPath in results) {
				var result = results[exlPath];
				if (structKeyExists(result, "stats")) {
					totalStats.totalLines += val(result.stats.totalLines ?: 0);
					totalStats.coveredLines += val(result.stats.coveredLines ?: 0);
					totalStats.totalFiles++;
				}
			}
			
			totalStats.coveragePercentage = totalStats.totalLines > 0 ? 
				(totalStats.coveredLines / totalStats.totalLines) * 100 : 0;
			totalStats.processingTimeMs = getTickCount() - startTime;

			var statsFile = arguments.outputDir & "/stats.json";
			fileWrite(statsFile, serializeJSON(var=totalStats, compact=mergedOptions.compact));
			jsonFiles.stats = statsFile;

			// Generate separate files if requested
			if (mergedOptions.separateFiles) {
				// TODO: Implement separate file generation
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
			// Set default options
			var defaultOptions = {
				verbose: false,
				chunkSize: 50000,
				allowList: [],
				blocklist: []
			};
			var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

			if (mergedOptions.verbose) {
				systemOutput("Calculating coverage summary from: " & arguments.executionLogDir, true);
			}

			var startTime = getTickCount();

			// Parse execution logs for stats only using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(mergedOptions);
			var results = logProcessor.parseExecutionLogs(arguments.executionLogDir, mergedOptions);
			var stats = variables.codeCoverageUtils.calculateDetailedStats(results, getTickCount() - startTime);

			if (mergedOptions.verbose) {
				systemOutput("Summary complete: " & stats.coveragePercentage & "% coverage", true);
			}

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

	private string function buildLcovContent(required struct results, required struct options) {
		// Merge results by file
		var merged = variables.codeCoverageUtils.mergeResultsByFile(arguments.results);
		
		// Create LCOV writer with options and build LCOV format
		var lcovWriter = new reporter.LcovWriter(arguments.options);
		return lcovWriter.buildLCOV(merged.mergedCoverage, arguments.options.useRelativePath ?: false);
	}
}