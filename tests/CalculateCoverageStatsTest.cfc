component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.parser = new lucee.extension.lcov.codeCoverageExlParser();
		variables.utils = new lucee.extension.lcov.codeCoverageUtils();
		variables.testDataGenerator = new GenerateTestData();
		
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
	}
	
	function testParserExists() {
		expect(variables.parser).toBeInstanceOf("codeCoverageExlParser");
	}

	function testParseFiles(){
		expect(directoryExists(variables.testData.coverageDir)).toBeTrue("Coverage directory should exist");

		var files = directoryList(variables.testData.coverageDir, false, "path", "*.exl");
		expect(arrayLen(files)).toBeGT(0, "Should find some .exl files");
		for (var file in files) {

			var result = variables.parser.parseExlFile(file);

			var resultJsonFile = replace(file, ".exl", "-fileCoverage.json", "all");
			expect( fileExists (resultJsonFile) ).toBeTrue();
			expect( fileRead( resultJsonFile ) ).toBeJson();
			var resultStruct = deserializeJson( fileRead( resultJsonFile ) );
			expect( resultStruct ).toBeStruct();

			var stats = variables.utils.calculateCoverageStats(resultStruct);
			expect( stats ).toBeStruct();

			var statsKeys = ["totalLinesFound", "totalLinesHit", "totalExecutions", "totalExecutionTime", "files"];
			for (var key in statsKeys) {
				expect( stats ).toHaveKey( key );
			}

		}
	}
}