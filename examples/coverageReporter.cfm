<cfscript>
	setting requesttimeout="100000";
	codeCoverageReportDir = getDirectoryFromPath( getCurrentTemplatePath() ) & "artifacts/codeCoverageReports/";
	if ( !directoryExists( codeCoverageReportDir ) )
		directoryCreate( codeCoverageReportDir );
	reportFile = codeCoverageReportDir & "lcov.info";
	
	// when reporting during a test suite run, we want to exclude testbox and specs folders, and lucee config files
	blocklist = [expandPath("/testbox"), expandPath("/specs"), expandPath("{lucee-config}")];
	allowList = [];
	systemOutput("allowList: " & allowList.toJson(), true );
	systemOutput("blocklist: " & blockList.toJson(), true );

	codeCoverageReporter = new lucee.extension.lcov.codeCoverageReporter();
	codeCoverageReporter.generateCodeCoverage( url.codeCoverageDir, reportFile, true, allowList, blocklist );
</cfscript>