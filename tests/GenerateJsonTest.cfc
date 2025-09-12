component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new GenerateTestData(testName="GenerateJsonTest");
		
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
		variables.outputDir = variables.testData.coverageDir & "/reports";
		directoryCreate(variables.outputDir);
	}
	
	/**
	 * @displayName "Given execution log data exists, When I generate just LCOV report, Then it should create LCOV file"
	 */
	function testGenerateJsonOnly() {
		// Given
		var jsonFile = variables.outputDir & "/results.json";
		var options = {
			allowList: [],
			blocklist: []
		};
        
		// When
		var result = lcovGenerateJson(
			executionLogDir = variables.testData.coverageDir,
			outputDir = variables.outputDir,
			options = options
		);

		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("jsonFiles");
		expect(result.jsonFiles).notToBeEmpty();
		expect(fileExists(jsonFile)).toBeTrue("JSON file should be created: " & jsonFile);
	}
}