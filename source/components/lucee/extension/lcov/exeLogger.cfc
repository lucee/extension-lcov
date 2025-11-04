component  {

	/**
	 * Initialize execution logger with admin password
	 * @adminPassword Lucee server admin password
	 * @return This instance
	 */
	function init(required string adminPassword){
		variables.adminPassword = arguments.adminPassword;
	};

	/**
	 * Enable execution logging with specified class and configuration
	 * @class Execution log class name
	 * @args Configuration arguments for the execution log
	 * @maxLogs Maximum number of logs to retain
	 */
	function enableExecutionLog( string class, struct args, numeric maxLogs ){
		// Validate unit is supported by Lucee ExecutionLogSupport
		var processedArgs = structCopy(arguments.args);
		if (structKeyExists(processedArgs, "unit")) {
			var supportedUnits = ["micro", "μs", "milli", "ms", "nano", "ns"];
			if (!arrayContains(supportedUnits, processedArgs.unit)) {
				throw("Unsupported execution log unit: " & processedArgs.unit & ". Lucee ExecutionLogSupport only supports: " & arrayToList(supportedUnits), "UnsupportedUnitError");
			}
		}

		admin action="UpdateExecutionLog" type="server" password="#variables.adminPassword#"
			class="#arguments.class#" enabled= true
			arguments=processedArgs;
		admin action="updateDebug" type="server" password="#variables.adminPassword#" debug="true" template="true"; // template needs to be enabled to produce debug logs
		admin action="updateDebugSetting" type="server" password="#variables.adminPassword#" maxLogs="#arguments.maxLogs#";
	}

	/**
	 * Disable execution logging
	 * @class Execution log class to disable
	 */
	function disableExecutionLog(class="lucee.runtime.engine.ConsoleExecutionLog"){
		admin action="updateDebug" type="server" password="#variables.adminPassword#" debug="false";

		admin action="UpdateExecutionLog" type="server" password="#variables.adminPassword#" arguments={}
			class="#arguments.class#" enabled=false;
		purgeExecutionLog();
	}

	/**
	 * Purge all logged debug data from the debug pool
	 */
	function purgeExecutionLog(){
		admin action="PurgeDebugPool" type="server" password="#variables.adminPassword#";
	}

	/**
	 * Retrieve all logged debug data from Lucee
	 * @return Array of logged debug data entries
	 */
	function getLoggedDebugData(){
		var logs = [];
		admin action="getLoggedDebugData" type="server" password="#variables.adminPassword#" returnVariable="logs";
		return logs;
	}

	/**
	 * Get combined debug logs from all requests, cleaned up and aggregated
	 * @baseDir Base directory for path normalization
	 * @raw If true, return raw query without aggregation
	 * @return Query containing combined debug log data
	 */
	function getDebugLogsCombined( string baseDir, boolean raw=false ){
		var logs = getLoggedDebugData();
		var parts = QueryNew( "ID,COUNT,MIN,MAX,AVG,TOTAL,PATH,START,END,STARTLINE,ENDLINE,SNIPPET,KEY" );
		var baseDir = arguments.baseDir;
		arrayEach( logs, function( log ){
			log.pageParts = cleanUpExeLog( log.pageParts, baseDir );
		}, true);
		arrayEach( logs, function( log ){
			parts = queryAppend( parts, log.pageParts );
		});
		purgeExecutionLog();
		// avoid qoq problems with reserved words
		loop list="min,max,avg,count,total" index="local.col" {
			QueryRenameColumn( parts, col, "_#col#" );
		}
		if ( arguments.raw || parts.recordCount == 0 ) {
			return parts;
		}
		```
		<cfquery name="local.q" dbtype="query">
			select 	sum(_COUNT) as _count, min(_MIN) as _min, max(_MAX) as _max, avg(_AVG) as _avg, sum(_TOTAL) as _total,
					PATH,SNIPPET,KEY, startLine, endLine
			FROM	parts
			group	BY PATH,SNIPPET,KEY
			order	BY path, startLine
		</cfquery>
		```
		// remove them as they are only needed to order the query
		//queryDeleteColumn(q, "startLine");
		//queryDeleteColumn(q, "endLine");
		return q;
	}

	/**
	 * Clean up execution log data by normalizing paths and adding keys
	 * @pageParts Query containing raw page part data
	 * @baseDir Base directory to strip from file paths
	 * @return Cleaned query with normalized paths and added key column
	 */
	function cleanUpExeLog( query pageParts, string baseDir ){
		var parts = duplicate( pageParts );
		queryAddColumn( parts, "key" ); //  this is synchronized 
		var r = 0;
		loop query=parts {
			var r = parts.currentrow;
			querySetCell( parts, "path", mid( parts.path[ r ], len( arguments.baseDir ) ), r ); // less verbose
			querySetCell( parts, "key", parts.path[ r ] & ":" & parts.startLine[ r ] & ":" & parts.endLine[ r ], r );
		}
		//var st = QueryToStruct(parts, "key");
		return parts;
	}

	/**
	 * Get debug logs for a specific request (cached within request scope)
	 * @return Array of debug log entries
	 */
	function getDebugLogs() cachedwithin="request" {
		disableExecutionLog();
		enableExecutionLog( "lucee.runtime.engine.DebugExecutionLog",{
			"unit": "milli"
			//"min-time": 100
		});
		local.result = _InternalRequest(
			template : "#uri#/ldev5206.cfm",
			url: "pagePoolClear=true" // TODO cfcs aren't recompiled like cfm templates?
		);
		return getLoggedDebugData();
	}
}
