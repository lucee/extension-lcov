<cfscript>
/**
 * Disable execution logging
 * @adminPassword Lucee server admin password (required)
 * @className Log implementation class to disable (optional, defaults to lucee.runtime.engine.ResourceExecutionLog)
 */
function lcovStopLogging(required string adminPassword, string className = "lucee.runtime.engine.ResourceExecutionLog") {
	var lcovFunctions = new lucee.extension.lcov.LcovFunctions(arguments.adminPassword);
	lcovFunctions.lcovStopLogging(
		adminPassword = arguments.adminPassword,
		className = arguments.className
	);
}
</cfscript>