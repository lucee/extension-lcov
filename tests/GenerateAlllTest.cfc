component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.logLevel = "info";
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new GenerateTestData( testName="GenerateAllReportsTest" );

		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts( request.SERVERADMINPASSWORD );
		variables.outputDir = variables.testDataGenerator.getOutputDir( "reports" );
	}
	
	

	/**
	 * @displayName "Given execution log data exists, When I generate all reports using extension functions, Then it should create LCOV, HTML, and JSON reports"
	 */
	function testGenerateAllReports() {
		// Given
		var options = {
			allowList: [],
			blocklist: []
		};
		
		// When
		var result = lcovGenerateAllReports(
			executionLogDir = variables.testData.coverageDir,
			outputDir = variables.outputDir,
			options = options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("lcovFile");
		expect(result).toHaveKey("htmlIndex");
		expect(result).toHaveKey("stats");
		expect(fileExists(result.lcovFile)).toBeTrue("LCOV file should be created");
		expect(fileExists(result.htmlIndex)).toBeTrue("HTML index should be created");
		expect(result.stats.totalFiles).toBeGT(0, "Should have processed some files");
	}	
}