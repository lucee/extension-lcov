component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.parser = variables.factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false);
	variables.testDataGenerator = new "../GenerateTestData"(testName="ExecutionLogParserTest");
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
	}
	
	function testParserExists() {
		expect(variables.parser).toBeInstanceOf("ExecutionLogParser");
	}

	function testParseFiles(){
		expect(directoryExists(variables.testData.coverageDir)).toBeTrue("Coverage directory should exist");

		var files = directoryList(variables.testData.coverageDir, false, "path", "*.exl");
		expect(arrayLen(files)).toBeGT(0, "Should find some .exl files");
		for (var file in files) {
			var result = variables.parser.parseExlFile(file);
			// Manually calculate canonical stats for test parity with processor
			var statsComponent = new lucee.extension.lcov.CoverageComponentFactory().getComponent(name="CoverageStats");
			result = statsComponent.calculateCoverageStats(result);
			
			//expect(result.validate(throw=false)).toBeEmpty();
			expect(result.getFiles()).notToBeEmpty("Files should not be empty for " & file);
			expect(result.getCoverage()).notToBeEmpty("Coverage should not be empty for " & file);
			expect(result.getFileCoverage()).notToBeEmpty("File coverage should not be empty for " & file);
			expect(result.getExeLog()).notToBeEmpty("ExeLog should not be empty for " & file);
			expect(result.getMetadata()).notToBeEmpty("Metadata	 should not be empty for " & file);

			var keys = {
				"metadata": "struct",
				"coverage": "struct", 
				"fileCoverage": "array",
				"exelog": "string",
				"stats": "struct",
				"files": "struct"
			};

			var json = result.getData();

			for (var key in keys) {
				expect(json).toHaveKey(key, "Parsed struct should have [" & key & "] for " & file);
				expect(json[key]).toBeTypeOf(keys[key], "Parsed struct should have correct type for [" & key & "] in " & file);
			}

			var requiredStatsKeys = [
				"totalLinesFound", "totalLinesHit", "totalLinesSource", "totalExecutions", "totalExecutionTime"
			];
			for (var statKey in requiredStatsKeys) {
				expect(json.stats).toHaveKey(statKey, "[stats] should have key [" & statKey & "] for " & file);
			}

			var requiredFileStatsKeys = [
				"linesFound", "linesHit", "linesSource", "totalExecutions", "totalExecutionTime"
			];

			// There should be at least one file entry
			expect(structCount(json.files)).toBeGT(0, "[files] should not be empty for " & file);
			for (var fileKey in json.files) {
				var fileStats = json.files[fileKey];
				for (var statKey in requiredFileStatsKeys) {
					expect(fileStats).toHaveKey(statKey, "[files][" & fileKey & "] should have key [" & statKey & "] for " & file);
				}
			}

		}
	}
}