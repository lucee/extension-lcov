<cfscript>
	// Execute DataProcessor.cfc with nested operations to test overlap filtering data loss
	processor = new testAdditional.artifacts.DataProcessor();

	// Test processMatrix with nested loops (4 levels deep)
	testMatrix = [
		[1, -5, 0, 10],
		[2, -3, 0, 20],
		[3, -1, 0, 30]
	];

	// Execute multiple times to get execution counts
	for (i = 1; i <= 10; i++) {
		result = processor.processMatrix(testMatrix);
	}

	// Test safeProcess with nested try-catch blocks
	for (i = 1; i <= 5; i++) {
		try {
			processor.safeProcess("test data " & i);
		} catch (any e) {
			// Expected to throw
		}
	}

	writeOutput("Test completed successfully");
</cfscript>
