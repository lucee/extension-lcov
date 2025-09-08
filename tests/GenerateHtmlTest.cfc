component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.parser = new lucee.extension.lcov.codeCoverageReporter();
		variables.testDataGenerator = new GenerateTestData();
		
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
	}
	
	function testParserExists() {
		expect(variables.parser).toBeInstanceOf("codeCoverageReporter");
	}

	function testParseFiles(){
		var allowList = [];
		var blocklist = [];
		var reportFile = variables.testData.coverageDir & "/lcov.info";
		variables.parser.generateCodeCoverage(variables.testData.coverageDir, reportFile, true, allowList, blocklist);
	}
}