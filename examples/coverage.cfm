<cfscript>
	setting requesttimeout="100000";
	
	SERVERADMINPASSWORD = "admin"; // script-runner default password

	systemOutput("==========================================", true);
	systemOutput("LUCEE LCOV COVERAGE EXAMPLE", true);
	systemOutput("==========================================", true);
	systemOutput("This example shows how to generate code coverage reports using the LCOV extension", true);
	systemOutput("", true);
	
	// STEP 1: Setup coverage directory - this is where .exl execution log files will be stored
	systemOutput("STEP 1: Setting up coverage directory for .exl execution logs", true);
	codeCoverageDir = getDirectoryFromPath( getCurrentTemplatePath() ) & "artifacts/codeCoverageRawLogs/";
	systemOutput("Coverage directory: " & codeCoverageDir, true);
	
	if ( directoryExists( codeCoverageDir ) ) {
		systemOutput("Cleaning existing coverage directory for fresh run", true);
		directoryDelete( codeCoverageDir, true ); // fresh each time
	}
	directoryCreate( codeCoverageDir, true );
	systemOutput("✓ Coverage directory ready", true);
	systemOutput("", true);

	// STEP 2: Enable execution logging - THIS IS CRITICAL for generating .exl files
	systemOutput("STEP 2: Enabling Lucee ResourceExecutionLog - THIS GENERATES THE .EXL FILES!", true);
	systemOutput("Without this step, NO coverage data will be captured!", true);
	
	exeLogger = new lucee.extension.lcov.exeLogger(SERVERADMINPASSWORD);
	exeLogger.enableExecutionLog(
		class = "lucee.runtime.engine.ResourceExecutionLog", // This class writes .exl files
		args = {
			"unit": "micro",        // Time unit for execution times
			"min-time": 0,          // Capture ALL executions (even 0 microseconds)
			"directory": codeCoverageDir  // Where to write .exl files
		},
		maxlogs = 0 // IMPORTANT: 0 means unlimited logs (default is only 10!)
	);
	systemOutput("✓ ResourceExecutionLog enabled - .exl files will now be generated", true);
	systemOutput("", true);

	// STEP 3: Run your application/tests - execution logging captures what code runs
	systemOutput("STEP 3: Running application code to capture execution data", true);
	testRunner = "/test/index.cfm";  // Change this to YOUR application entry point



	// IMPORTANT: internalRequest() is required to generate .exl files!
	// The ResourceExecutionLog only works on NEW requests after enableExecutionLog()
	// If you run code directly in this request, NO .exl files will be created!


	systemOutput("CRITICAL: Using internalRequest() to run code with logging enabled", true);
	systemOutput("The ResourceExecutionLog only works on NEW requests after enableExecutionLog()", true);
	systemOutput("Running: " & testRunner, true);
	
	// THIS internalRequest() call is what actually generates the .exl files!
	// Use throwonerror=true for fail-fast behavior if tests don't exist
	internalRequest(
		template = testRunner,
		throwonerror = true
	);
	systemOutput("✓ Code execution complete - .exl files should now exist", true);
	systemOutput("", true);

	// STEP 4: Disable execution logging to clean up
	systemOutput("STEP 4: Disabling ResourceExecutionLog", true);
	exeLogger.disableExecutionLog(class="lucee.runtime.engine.ResourceExecutionLog");
	systemOutput("✓ Execution logging disabled", true);
	systemOutput("", true);

	// STEP 5: Generate LCOV coverage reports from the .exl files
	systemOutput("STEP 5: Generating LCOV coverage reports from .exl files", true);
	systemOutput("Using LCOV extension functions to process the execution logs", true);
	systemOutput("codeCoverageDir = " & codeCoverageDir, true);
	systemOutput("", true);
	
	// Generate LCOV format file (for VS Code Coverage Gutters)
	lcovFile = codeCoverageDir & "LCOV.info"
	lcovGenerateLcov(
		executionLogDir = codeCoverageDir,
		outputFile = lcovFile
	);
	systemOutput("✓ LCOV file generated: " & lcovFile, true);
	
	// Generate HTML reports (for browser viewing)
	htmlFiles = lcovGenerateHtml(
		executionLogDir = codeCoverageDir,
		outputDir = codeCoverageDir & "html-reports/"
	);

	systemOutput("✓ HTML reports generated: " & serializeJson(var=htmlFiles, compact=false), true);

	// Generate JSON data (for programmatic use)
	jsonFile = lcovGenerateJson(
		executionLogDir = codeCoverageDir,
		outputDir = codeCoverageDir & "coverage.json"
	);
	systemOutput("✓ JSON files generated: " & serializeJson(var=jsonFile, compact=false), true);
	
	systemOutput("", true);
	systemOutput("==========================================", true);
	systemOutput("COVERAGE GENERATION COMPLETE!", true);

	
	// NOTE: For performance profiling (separate from coverage), see performance-profiling.cfm example
</cfscript>