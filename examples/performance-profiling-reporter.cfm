<cfscript>
	setting requesttimeout="100000";
	codeCoverageReportDir = getDirectoryFromPath( getCurrentTemplatePath() ) & "artifacts/codeCoverageReports/";
	if ( !directoryExists( codeCoverageReportDir ) )
		directoryCreate( codeCoverageReportDir );
	
	// when reporting during a test suite run, we want to exclude testbox and specs folders, and lucee config files
	blocklist = [expandPath("/testbox"), expandPath("/specs"), expandPath("{lucee-config}")];
	allowList = [];
	systemOutput("allowList: " & allowList.toJson(), true );
	systemOutput("blocklist: " & blockList.toJson(), true );

	// Use extension functions for all report generation
	var options = {
		verbose: true,
		allowList: allowList,
		blocklist: blocklist
	};

	// Generate all report types
	var result = lcovGenerateAllReports(
		executionLogDir = url.codeCoverageDir,
		outputDir = codeCoverageReportDir,
		options = options
	);

	systemOutput("Generated reports:", true);
	systemOutput("- LCOV file: " & result.lcovFile, true);
	systemOutput("- HTML reports: " & serializeJson(var=result.htmlFiles, compact=false), true);
	systemOutput("- JSON files: " & serializeJson(var=result.jsonFiles, compact=false), true);
	systemOutput("- Coverage: " & result.stats.coveragePercentage & "%", true);
</cfscript>