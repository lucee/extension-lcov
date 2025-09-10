<cfscript>
/**
 * Generate LCOV format report
 * @executionLogDir Directory containing .exl execution log files (required)
 * @outputFile Path for LCOV output file (optional - if empty, returns string content)
 * @options Configuration options struct (optional)
 * @return String containing LCOV file content
 */
function lcovGenerateLcov(required string executionLogDir, string outputFile = "", struct options = {}) {
	var lcovFunctions = new lucee.extension.lcov.LcovFunctions();
	return lcovFunctions.lcovGenerateLcov(
		executionLogDir = arguments.executionLogDir,
		outputFile = arguments.outputFile,
		options = arguments.options
	);
}
</cfscript>