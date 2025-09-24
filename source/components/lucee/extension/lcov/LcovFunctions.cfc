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
		// Validate required directories exist
		if (!directoryExists(arguments.executionLogDir)) {
			throw(type="DirectoryNotFound", message="Execution log directory does not exist: [" & arguments.executionLogDir & "]");
		}

		// Validate output directory exists - throw error if missing
		if (!directoryExists(arguments.outputDir)) {
			throw(message="Output directory does not exist: [" & arguments.outputDir & "]");
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
			var factory = new lucee.extension.lcov.CoverageComponentFactory();
			factory.getComponent(name="CoverageBlockProcessor").ensureDirectoryExists(getDirectoryFromPath(arguments.outputFile));
			fileWrite(arguments.outputFile, lcovContent);
			if (mergedOptions.verbose) {
				systemOutput("LCOV file written to: " & arguments.outputFile, true);
			}
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
			throw(type="DirectoryNotFound", message="Execution log directory does not exist: [" & arguments.executionLogDir & "]");
		}

		// Validate output directory exists - throw error if missing
		if (!directoryExists(arguments.outputDir)) {
			throw(message="Output directory does not exist: [" & arguments.outputDir & "]");
		}

		// Set default options
		var defaultOptions = {
			verbose: false,
			displayUnit: "milli",
			allowList: [],
			blocklist: [],
			separateFiles: false
		};
		var mergedOptions = mergeDefaultOptions(defaultOptions, arguments.options);

		var startTime = getTickCount();

		if (mergedOptions.verbose) {
			systemOutput("Generating HTML reports from: " & arguments.executionLogDir, true);
		}

		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		factory.getComponent(name="CoverageBlockProcessor").ensureDirectoryExists(arguments.outputDir);

		// Parse execution logs using ExecutionLogProcessor
		var logProcessor = new ExecutionLogProcessor(mergedOptions);
		var results = logProcessor.parseExecutionLogs(arguments.executionLogDir, mergedOptions);

		// Generate HTML reports using focused HTML reporter
		var htmlReporter = new reporter.HtmlReporter(mergedOptions.displayUnit, mergedOptions.verbose);
		htmlReporter.setOutputDir(htmlDir); // Set output directory for individual HTML files
		var htmlIndex = "";

		// Process results based on separateFiles option
		if (mergedOptions.separateFiles) {
			// Merge by source file and write directly to file-*.json files
			if (mergedOptions.verbose) {
				systemOutput("Merging " & structCount(results) & " execution logs by source file", true);
			}
			var merger = new lucee.extension.lcov.CoverageMerger();
					   var mergedResults = merger.mergeResults(results, arguments.outputDir, mergedOptions.verbose); // now returns mergedResults
			var sourceFileJsons = new CoverageMergerWriter().writeMergedResultsToFiles(mergedResults, arguments.outputDir, mergedOptions.verbose);

			// Generate HTML reports for each source file JSON
			if (mergedOptions.verbose) {
				systemOutput("Processing " & arrayLen(sourceFileJsons) & " source file JSONs for HTML generation", true);
			}
			var resultFactory = new lucee.extension.lcov.model.result();
			for (var jsonFile in sourceFileJsons) {
				// Use result model's fromJson to ensure all required fields and validation
				var sourceResult = resultFactory.fromJson(fileRead(jsonFile), true);
				sourceResult.validate();

				// Set exeLog to the source file path for separated files mode
				// This tells HtmlReporter to use source file naming instead of request-based naming
				var sourceFilePath = getFileFromPath(jsonFile);
				sourceFilePath = reReplace(sourceFilePath, "^file-[^-]+-", ""); // Remove file-{hash}- prefix
				sourceFilePath = reReplace(sourceFilePath, "\.json$", ""); // Remove .json extension
				sourceResult.setExeLog(sourceFilePath);

				if (mergedOptions.verbose) {
					systemOutput("Processing JSON file: " & jsonFile, true);
					systemOutput("  - Set exeLog to: " & sourceFilePath, true);
					systemOutput("  - Attempting HTML report generation", true);
				}
				var htmlPath = htmlReporter.generateHtmlReport(sourceResult);
				if (mergedOptions.verbose) {
					systemOutput("  - HTML report generated: " & htmlPath, true);
				}
			}
		}

		// For regular mode, generate HTML reports for each request-based result
		if (!mergedOptions.separateFiles) {
			// Write request-based JSON files and generate HTML reports
			for (var resultKey in results) {
				var result = results[resultKey];
				// Always use fileIndex (typically 0) for coverage and files
				var coverage = result.getCoverage();
				if (structKeyExists(coverage, "0") && !structIsEmpty(coverage["0"])) {
					// Write request JSON file
					var fileName = getFileFromPath(resultKey);
					var numberPrefix = listFirst(fileName, "-");
					var scriptName = result.getMetadataProperty("script-name");
					scriptName = reReplace(scriptName, "[^a-zA-Z0-9_-]", "_", "all");
					var jsonFileName = "request-" & numberPrefix & "-" & scriptName & ".json";
					fileWrite(arguments.outputDir & "/" & jsonFileName, serializeJSON(var=result, compact=false));

					// Generate HTML report
					htmlReporter.generateHtmlReport(result);
				}
			}
		}

		// Generate index HTML
		htmlIndex = htmlReporter.generateIndexHtml(htmlDir);


		// Calculate aggregated stats from all results
		var statsComponent = variables.factory.getComponent(name="CoverageStats");
		var totalStats = statsComponent.calculateDetailedStats(results, getTickCount() - startTime);

		// Get list of generated HTML files (excluding index.html)
		var generatedHtmlFiles = [];
		var allHtmlFiles = directoryList(arguments.outputDir, false, "name", "*.html");
		for (var htmlFile in allHtmlFiles) {
			if (htmlFile != "index.html") {
				arrayAppend(generatedHtmlFiles, htmlFile);
			}
		}

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

			var factory = new lucee.extension.lcov.CoverageComponentFactory();
			factory.getComponent(name="CoverageBlockProcessor").ensureDirectoryExists(arguments.outputDir);

			// Parse execution logs using ExecutionLogProcessor
			var logProcessor = new ExecutionLogProcessor(mergedOptions);
			var results = logProcessor.parseExecutionLogs(arguments.executionLogDir, mergedOptions);

			// Generate JSON files directly from parsed results
			var jsonFiles = {};
			var totalStats = {
				totalLinesSource: 0,
				totalLinesHit: 0,
				totalLinesFound: 0,
				coveragePercentage: 0,
				totalFiles: 0,
				processingTimeMs: 0
			};

			// Create results JSON
			var resultsFile = arguments.outputDir & "/results.json";
			fileWrite(resultsFile, serializeJSON(var=results, compact=mergedOptions.compact));
			jsonFiles.results = resultsFile;

			// Create merged coverage data
			var merged = new lucee.extension.lcov.CoverageMerger().mergeResultsByFile(results);
			var mergedFile = arguments.outputDir & "/merged.json"; 
			fileWrite(mergedFile, serializeJSON(var=merged, compact=mergedOptions.compact));
			jsonFiles.merged = mergedFile;

			// Calculate aggregated stats from all results using CoverageStats
			var statsComponent = variables.factory.getComponent(name="CoverageStats");
			var totalStats = statsComponent.calculateDetailedStats(results, getTickCount() - startTime);

			var statsFile = arguments.outputDir & "/summary-stats.json";
			fileWrite(statsFile, serializeJSON(var=totalStats, compact=mergedOptions.compact));
			jsonFiles.stats = statsFile;

			// Generate separate files if requested
			if (mergedOptions.separateFiles) {
				// Merge by source file and write directly to file-*.json files
				var merger = new lucee.extension.lcov.CoverageMerger();
				var mergedResults = merger.mergeResults(results, arguments.outputDir, mergedOptions.verbose); // now returns mergedResults
				var sourceFileJsons = new CoverageMergerWriter().writeMergedResultsToFiles(mergedResults, arguments.outputDir, mergedOptions.verbose);
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
						fileWrite(jsonFilePath, serializeJSON(var=result, compact=mergedOptions.compact));
						jsonFiles[jsonFileName] = jsonFilePath;
					}
				}
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
			var statsComponent = variables.factory.getComponent(name="CoverageStats");
			var stats = statsComponent.calculateDetailedStats(results, getTickCount() - startTime);

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
		var merged = new lucee.extension.lcov.CoverageMerger().mergeResultsByFile(arguments.results);
		
		// Create LCOV writer with options and build LCOV format
		var lcovWriter = new reporter.LcovWriter(arguments.options);
		return lcovWriter.buildLCOV(merged.mergedCoverage, arguments.options.useRelativePath ?: false);
	}
}