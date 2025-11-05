<cfscript>
	// Test cross-file UDF calls through CFC methods
	// Template → ServiceA.method() → ServiceB.method() → BIF

	serviceA = new ServiceA();

	// Call the service method multiple times
	for (i = 1; i <= 5; i++) {
		result = serviceA.processData("test data " & i);
		writeOutput("Result " & i & ": " & result & "<br>");
	}

	writeOutput("Cross-file CFC chain test completed");
</cfscript>
