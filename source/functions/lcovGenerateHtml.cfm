<cfscript>
/**
 * Generate HTML reports
 * @executionLogDir Directory containing .exl execution log files (required)
 * @outputDir Directory where HTML files will be generated (required)
 * @options Configuration options struct (optional)
 * @return Struct with generated file paths and statistics
 */
function lcovGenerateHtml(required string executionLogDir, required string outputDir, struct options = {}) {
	var lcovFunctions = new lucee.extension.lcov.LcovFunctions();
	return lcovFunctions.lcovGenerateHtml(
		executionLogDir = arguments.executionLogDir,
		outputDir = arguments.outputDir,
		options = arguments.options
	);
}
</cfscript>