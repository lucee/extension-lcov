<cfscript>
/**
 * Generate coverage statistics only (no file generation)
 * @executionLogDir Directory containing .exl execution log files (required)
 * @options Configuration options struct (optional)
 * @return Struct with coverage statistics
 */
function lcovGenerateSummary(required string executionLogDir, struct options = {}) {
	var lcovFunctions = new lucee.extension.lcov.LcovFunctions();
	return lcovFunctions.lcovGenerateSummary(
		executionLogDir = arguments.executionLogDir,
		options = arguments.options
	);
}
</cfscript>