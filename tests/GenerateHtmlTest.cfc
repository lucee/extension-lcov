component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new GenerateTestData(testName="GenerateHtmlTest");
		
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
		variables.outputDir = variables.testData.coverageDir & "/reports";
		directoryCreate(variables.outputDir);
	}
	
	// Leave test artifacts for inspection - no cleanup in afterAll

	/**
	 * @displayName "Given execution log data exists, When I generate all reports using extension functions, Then it should create LCOV, HTML, and JSON reports"
	 */
	function testGenerateHtmlReports() {
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