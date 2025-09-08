component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.parser = new lucee.extension.lcov.codeCoverageExlParser();
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
			var keys = {
				"metadata": "struct",
				"source":"struct",
				"coverage": "struct", 
				"fileCoverage": "array",
				"exelog": "string"
			};
			expect(result).toBeStruct("Parsed EXL file should return a struct");
			for (var key in keys) {
				expect(structKeyExists(result, key)).toBeTrue("Parsed struct should have " & key & " for " & file);
				expect(result[key]).toBeTypeOf(keys[key], "Parsed struct should have correct type for " & key & " in " & file);
			}
		}
	}
}