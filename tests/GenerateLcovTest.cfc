component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new GenerateTestData( testName="GenerateLCOVTest" );

		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts( request.SERVERADMINPASSWORD );
		variables.outputDir = variables.testDataGenerator.getOutputDir( "reports" );
	}
	
	/**
	 * @displayName "Given execution log data exists, When I generate just LCOV report, Then it should create LCOV file"
	 */
	function testGenerateLcovOnly() {
		// Given
		var lcovFile = variables.outputDir & "/test-only.lcov";
		var options = {
			allowList: [],
			blocklist: []
		};
		
		// When
		var content = lcovGenerateLcov(
			executionLogDir = variables.testData.coverageDir,
			outputFile = lcovFile,
			options = options
		);
		
		// Then
		expect(content).toBeString();
		expect(content).notToBeEmpty();
		expect(fileExists(lcovFile)).toBeTrue("LCOV file should be created");
		expect(content).toInclude("SF:", "Should contain source file records");
		expect(content).toInclude("DA:", "Should contain data array records");
		expect(content).toInclude("end_of_record", "Should contain end of record markers");
	}
}