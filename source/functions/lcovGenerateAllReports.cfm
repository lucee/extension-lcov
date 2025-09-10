<cfscript>
/**
 * Generate all report types (HTML, JSON, and LCOV)
 * @executionLogDir Directory containing .exl execution log files (required)
 * @outputDir Base directory for all generated reports (required)
 * @options Configuration options struct (optional)
 * @return Struct with generated file paths and statistics
 */
function lcovGenerateAllReports(required string executionLogDir, required string outputDir, struct options = {}) {
	var lcovFunctions = new lucee.extension.lcov.LcovFunctions();
	return lcovFunctions.lcovGenerateAllReports(
		executionLogDir = arguments.executionLogDir,
		outputDir = arguments.outputDir,
		options = arguments.options
	);
}
</cfscript>