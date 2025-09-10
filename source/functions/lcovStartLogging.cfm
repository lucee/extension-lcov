<cfscript>
/**
 * Enable execution logging for code coverage collection
 * @adminPassword Lucee server admin password (required)
 * @executionLogDir Directory for .exl files (optional - auto-generates if empty)
 * @options Configuration options struct (optional)
 * @return String path to the log directory being used
 */
function lcovStartLogging(required string adminPassword, string executionLogDir = "", struct options = {}) {
	lcovFunctions = new lucee.extension.lcov.LcovFunctions(arguments.adminPassword);
	return lcovFunctions.lcovStartLogging(
		adminPassword = arguments.adminPassword,
		executionLogDir = arguments.executionLogDir,
		options = arguments.options
	);
}
</cfscript>