component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		// Use GenerateTestData with threads subfolder
		variables.testDataGenerator = new GenerateTestData(
			testName = "ParallelThreadsTest",
			artifactsSubFolder = "threads"
		);

		// Generate test data with parallel threads
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts( request.SERVERADMINPASSWORD );
		variables.outputDir = variables.testDataGenerator.getOutputDir( "reports" );
	}

	/**
	 * @displayName "Given parallel threads execute, When I check .exl files, Then they should have parent thread metadata"
	 */
	function testParallelThreadMetadata() {
		// Given - .exl files generated from parallel execution
		var exlFiles = directoryList( variables.testData.coverageDir, false, "path", "*.exl" );

		// Then - should have multiple .exl files (parent + children)
		expect( exlFiles ).toBeArray();
		expect( arrayLen( exlFiles ) ).toBeGT( 1, "Should have parent and child thread .exl files" );

		// Check for parent metadata in child thread files
		var childThreadFilesFound = 0;
		for ( var exlFile in exlFiles ) {
			var content = fileRead( exlFile );
			var lines = listToArray( content, chr( 10 ) );

			// Parse headers
			var hasParentPc = false;
			var hasParentRequest = false;
			var hasParentPath = false;
			var hasSpawnOffset = false;
			var hasRequestId = false;
			var hasPcId = false;

			for ( var line in lines ) {
				if ( line contains "parent-pc:" && !line.startsWith( "0:" ) ) {
					hasParentPc = true;
				}
				if ( line contains "parent-request:" ) {
					hasParentRequest = true;
				}
				if ( line contains "parent-path:" ) {
					hasParentPath = true;
				}
				if ( line contains "spawn-offset-nano:" ) {
					hasSpawnOffset = true;
				}
				if ( line contains "request-id:" ) {
					hasRequestId = true;
				}
				if ( line contains "pc-id:" ) {
					hasPcId = true;
				}
			}

			// All files should have request-id and pc-id
			expect( hasRequestId ).toBeTrue( "File should have request-id: " & exlFile );
			expect( hasPcId ).toBeTrue( "File should have pc-id: " & exlFile );

			// Child thread files should have parent metadata
			if ( hasParentPc && hasParentRequest ) {
				childThreadFilesFound++;
				expect( hasParentPath ).toBeTrue( "Child thread should have parent-path: " & exlFile );
				expect( hasSpawnOffset ).toBeTrue( "Child thread should have spawn-offset-nano: " & exlFile );
			}
		}

		// Should have found at least some child thread files
		expect( childThreadFilesFound ).toBeGT( 0, "Should have found child thread .exl files with parent metadata" );
	}
}
