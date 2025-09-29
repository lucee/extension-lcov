component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	public void function beforeAll(){
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="ExecutionLogProcessorTest");

		// Generate test data
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
		variables.testExlDir = variables.testData.coverageDir;
	}

	public void function testParseExecutionLogsCreatesJsonFileNextToExlFile() {
		// Get the first .exl file from generated test data
		var exlFiles = directoryList(variables.testExlDir, false, "name", "*.exl");
		expect(arrayLen(exlFiles)).toBeGT(0, "Should have at least one .exl file");

		// Use expandPath to normalize path
		var testExlFile = expandPath(variables.testExlDir & "\" & exlFiles[1]);
		var expectedJsonFile = reReplace(testExlFile, "\.exl$", ".json");

		// Clean up any existing JSON file
		if (fileExists(expectedJsonFile)) {
			fileDelete(expectedJsonFile);
		}

		//systemOutput("Test EXL file: #testExlFile#");
		//systemOutput("Expected JSON file: #expectedJsonFile#");

		// Verify .exl file exists
		expect(fileExists(testExlFile)).toBeTrue("Test .exl file should exist");

		// Create ExecutionLogProcessor and parse the logs
		var processor = new lucee.extension.lcov.ExecutionLogProcessor();

		var jsonFilePaths = processor.parseExecutionLogs(variables.testExlDir);

		// Verify that JSON files array is returned
		expect(isArray(jsonFilePaths)).toBeTrue("parseExecutionLogs should return array of JSON file paths");
		expect(arrayLen(jsonFilePaths)).toBeGT(0, "Should return at least one JSON file path");

		// Verify the JSON file was created next to the .exl file
		expect(fileExists(expectedJsonFile)).toBeTrue("JSON file should be created next to .exl file at: #expectedJsonFile#");

		// Verify the returned paths include our expected JSON file
		var foundExpectedFile = false;
		var normalizedExpectedPath = expandPath(expectedJsonFile);

		for (var jsonPath in jsonFilePaths) {
			var normalizedJsonPath = expandPath(jsonPath);
			if (normalizedJsonPath == normalizedExpectedPath) {
				foundExpectedFile = true;
				break;
			}
		}

		if (!foundExpectedFile) {
			systemOutput("Expected: #normalizedExpectedPath#");
			systemOutput("Actual paths returned:");
			for (var i = 1; i <= arrayLen(jsonFilePaths); i++) {
				systemOutput("  [#i#]: #expandPath(jsonFilePaths[i])#");
			}
		}

		expect(foundExpectedFile).toBeTrue("Returned JSON file paths should include: #normalizedExpectedPath#");

		// Verify JSON file content is valid
		var jsonContent = fileRead(expectedJsonFile);
		expect(jsonContent).toBeJson("JSON file should contain valid JSON");

		var jsonData = deserializeJSON(jsonContent);
		expect(jsonData).toBeStruct("JSON should deserialize to struct");

		// Verify essential properties exist in the result
		expect(structKeyExists(jsonData, "metadata")).toBeTrue("JSON should have metadata");
		expect(structKeyExists(jsonData, "stats")).toBeTrue("JSON should have stats");
		expect(structKeyExists(jsonData, "coverage")).toBeTrue("JSON should have coverage");

		//systemOutput("✓ JSON file successfully created and validated at: #expectedJsonFile#");
	}

	public void function testJsonFileContainsExpectedStructure() {
		// Get the first .exl file from generated test data
		var exlFiles = directoryList(variables.testExlDir, false, "name", "*.exl");
		expect(arrayLen(exlFiles)).toBeGT(0, "Should have at least one .exl file");

		// Use expandPath to normalize path
		var testExlFile = expandPath(variables.testExlDir & "\" & exlFiles[1]);
		var expectedJsonFile = reReplace(testExlFile, "\.exl$", ".json");

		// Ensure the file was created by previous test
		if (!fileExists(expectedJsonFile)) {
			fail("JSON file not found - run testParseExecutionLogsCreatesJsonFileNextToExlFile first");
		}

		var jsonData = deserializeJSON(fileRead(expectedJsonFile));

		// Verify metadata structure
		expect(structKeyExists(jsonData.metadata, "script-name")).toBeTrue("Metadata should have script-name");
		expect(structKeyExists(jsonData.metadata, "execution-time")).toBeTrue("Metadata should have execution-time");

		// Verify stats structure
		expect(structKeyExists(jsonData.stats, "totalLinesFound")).toBeTrue("Stats should have totalLinesFound");
		expect(structKeyExists(jsonData.stats, "totalLinesHit")).toBeTrue("Stats should have totalLinesHit");
		expect(structKeyExists(jsonData.stats, "totalExecutions")).toBeTrue("Stats should have totalExecutions");

		// Verify stats values are numeric
		expect(isNumeric(jsonData.stats.totalLinesFound)).toBeTrue("totalLinesFound should be numeric");
		expect(isNumeric(jsonData.stats.totalLinesHit)).toBeTrue("totalLinesHit should be numeric");
		expect(isNumeric(jsonData.stats.totalExecutions)).toBeTrue("totalExecutions should be numeric");

		// Verify coverage structure exists
		expect(isStruct(jsonData.coverage)).toBeTrue("Coverage should be a struct");
		
	}

	
}