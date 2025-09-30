/**
 * Component responsible for processing execution log (.exl) files
 */
component {

	/**
	 * Initialize the execution log processor with options
	 * @options Configuration options struct (optional)
	 */
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
		variables.componentFactory = new lucee.extension.lcov.CoverageComponentFactory();
		// Optionally allow per-instance override
		variables.useDevelop = structKeyExists(arguments.options, "useDevelop") ? arguments.options.useDevelop : variables.componentFactory.getUseDevelop();
		return this;
	}

	/**
	 * Private logging function that respects verbose setting
	 * @message The message to log
	 */
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	 * Parse execution logs from a directory and return processed results
	 * @executionLogDir Directory containing .exl files
	 * @options Processing options including allowList and blocklist
	 * @return Struct of parsed results keyed by .exl file path
	 */

	public array function parseExecutionLogs(required string executionLogDir, struct options = {}) {
		// add an exclusive cflock here
		cflock(name="lcov-parse:#arguments.executionLogDir#", timeout=0, type="exclusive", throwOnTimeout=true) {
			return _parseExecutionLogs(arguments.executionLogDir, arguments.options);
		}
	}

	private array function _parseExecutionLogs(required string executionLogDir, struct options = {}) {
		if (!directoryExists(arguments.executionLogDir)) {
			throw(message="Execution log directory does not exist: " & arguments.executionLogDir);
		}

		logger("Processing execution logs from: " & arguments.executionLogDir);

		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var exlParser = factory.getComponent(name="ExecutionLogParser", initArgs=arguments.options);

		var files = directoryList(arguments.executionLogDir, false, "query", "*.exl", "datecreated");
		var jsonFilePaths = [];

		logger("Found " & files.recordCount & " .exl files to process");

		for (var file in files) {
			var exlPath = file.directory & "/" & file.name;
			var info = getFileInfo( exlPath );
			logger("Processing .exl file: " & exlPath
				& " (" & decimalFormat( info.size/1024 ) & " Kb)");
			var result = exlParser.parseExlFile(
				exlPath,
				arguments.options.allowList ?: [],
				arguments.options.blocklist ?: [],
				false  // writeJsonCache - we handle JSON writing after stats
			);
			result = factory.getComponent(name="CoverageStats").calculateCoverageStats(result);
			// Set outputFilename (without extension) for downstream consumers (e.g., HTML reporter)
			// Include unique identifier from .exl filename to avoid overlaps between multiple execution runs
			var fileName = getFileFromPath(exlPath);
			var fileNameWithoutExt = listFirst(fileName, ".");  // Remove .exl extension
			var scriptName = result.getMetadataProperty("script-name");
			scriptName = reReplace(scriptName, "[^a-zA-Z0-9_-]", "_", "all");
			var outputFilename = "request-" & fileNameWithoutExt & "-" & scriptName;
			result.setOutputFilename(outputFilename);

			// Write JSON cache after stats are calculated (includes complete stats)
			// Write next to the .exl file for permanent caching
			var jsonPath = reReplace(exlPath, "\.exl$", ".json");
			fileWrite(jsonPath, result.toJson(pretty=false, excludeFileCoverage=true));
			arrayAppend(jsonFilePaths, jsonPath);
			///logger("Successfully processed: " & exlPath);

		}

		logger("Completed processing " & arrayLen(jsonFilePaths) & " valid .exl files");
		return jsonFilePaths;
	}

}