<cfscript>
/**
 * Generate JSON reports
 * @executionLogDir Directory containing .exl execution log files (required)
 * @outputDir Directory where JSON files will be saved (required)
 * @options Configuration options struct (optional)
 * @return Struct with generated file paths and statistics
 */
function lcovGenerateJson(required string executionLogDir, required string outputDir, struct options = {}) {
	var lcovFunctions = new lucee.extension.lcov.LcovFunctions();
	return lcovFunctions.lcovGenerateJson(
		executionLogDir = arguments.executionLogDir,
		outputDir = arguments.outputDir,
		options = arguments.options
	);
}
</cfscript>