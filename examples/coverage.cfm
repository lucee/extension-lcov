<cfscript>
	setting requesttimeout="100000";
	systemOutput("Running test suite with code coverage", true );
	paths = [ "root.test.suite" ];
	codeCoverageDir = getDirectoryFromPath( getCurrentTemplatePath() ) & "artifacts/codeCoverageRawLogs/";
	if ( directoryExists( codeCoverageDir ) )
		directoryDelete( codeCoverageDir, true ); // fresh each time
	directoryCreate( codeCoverageDir, true );

	systemOutput("enableExecutionLog", true );

	exeLogger = new lucee.extension.lcov.exeLogger(request.SERVERADMINPASSWORD);
	exeLogger.enableExecutionLog(
		class = "lucee.runtime.engine.ResourceExecutionLog",
		args = {
			"unit": "micro"
			, "min-time": 0
			, "directory": codeCoverageDir
		},
		maxlogs = 0 // default is just 10! 
	);

	testRunner = getDirectoryFromPath( getCurrentTemplatePath() ) & "index.cfm";
	testRunner = "/test/index.cfm";

	// once ResourceExecutionLog is enabled, it won't be enabled for the current request, so we use testRunner, which will regenerate logs
	// with ResourceExecutionLog enabled
	systemOutput("Including test runner: #testRunner#", true );
	internalRequest(template=testRunner);

	systemOutput("disableExecutionLog", true );
	exeLogger.disableExecutionLog(class="lucee.runtime.engine.ResourceExecutionLog");

	// lucee.runtime.engine.ConsoleExecutionLog is useful for profiling code performance
	/*
	exeLogger.enableExecutionLog(
		class = "lucee.runtime.engine.ConsoleExecutionLog",
		args = {
			"min-time": 1000000, // ns
			"snippet": false,
			"stream-type": "out",
			"unit": "micro"
		},
		maxLogs = 0
	);
	*/
	systemOutput("generate coverage report", true );
	internalRequest(template=ExpandPath("/.coverageReporter.cfm"),
		url={
			codeCoverageDir=codeCoverageDir
		}
	);
</cfscript>