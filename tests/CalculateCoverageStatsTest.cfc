component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe("check codeCoverage stats", function() {
			it("test CalculateCoverageStatsTest", function() {
				var parser = new lucee.extension.lcov.ExecutionLogParser();
				var statsComponent = new lucee.extension.lcov.CoverageStats();
				var testDataGenerator = new GenerateTestData(testName="CalculateCoverageStatsTest-stable");
				var testData = testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);

				testParseFiles(parser, statsComponent, testData, "CalculateCoverageStatsTest-stable");
			});

			it("test CalculateCoverageStatsTest-develop", function() {
				var parser = new lucee.extension.lcov.develop.ExecutionLogParser();
				var statsComponent = new lucee.extension.lcov.develop.CoverageStats();
				var testDataGenerator = new GenerateTestData(testName="CalculateCoverageStatsTest-develop");
				var testData = testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);

				testParseFiles(parser, statsComponent, testData, "CalculateCoverageStatsTest-develop");
			});
		});
	}

	private function testParseFiles(parser, statsComponent, testData, testName){
		expect(directoryExists(testData.coverageDir)).toBeTrue("Coverage directory should exist");

		var files = directoryList(testData.coverageDir, false, "path", "*.exl");
		expect(arrayLen(files)).toBeGT(0, "Should find some .exl files");
		for (var file in files) {

			var result = parser.parseExlFile(file);

			var resultJsonFile = replace(file, ".exl", ".json", "all");
			expect( fileExists (resultJsonFile) ).toBeTrue("JSON file missing for " & file);
			expect( fileRead( resultJsonFile ) ).toBeJson("Invalid JSON in " & resultJsonFile & " (from " & file & ")");
			var resultStruct = deserializeJson( fileRead( resultJsonFile ) );
			expect( resultStruct ).toBeStruct("Result struct not valid for " & file);


			var stats = statsComponent.calculateCoverageStats(resultStruct);
			expect( stats ).toBeStruct("Stats not valid for " & file);

			var statsKeys = ["totalLinesFound", "totalLinesHit", "totalExecutions", "totalExecutionTime", "files"];
			for (var key in statsKeys) {
				expect( stats ).toHaveKey( key, "Missing key '" & key & "' in stats for " & file );
			}

			// For each file, check linesHit and linesFound are <= linesCount (if linesCount > 0)
			for (var fileKey in stats.files) {
				var fileStats = stats.files[fileKey];
				if (structKeyExists(fileStats, "linesCount") && fileStats.linesCount > 0) {
					expect(fileStats.linesHit).toBeLTE(fileStats.linesCount, "linesHit should not exceed linesCount for " & fileKey);
					expect(fileStats.linesFound).toBeLTE(fileStats.linesCount, "linesFound should not exceed linesCount for " & fileKey);
				}
			}

			// Assert that totalLinesHit does not exceed totalLinesFound
			expect(stats.totalLinesHit).toBeLTE(stats.totalLinesFound, "totalLinesHit should not exceed totalLinesFound for " & file);

			// If percentage is calculated, check it is between 0 and 100
			if (structKeyExists(stats, "coveragePercentage")) {
				expect(stats.coveragePercentage).toBeGTE(0, "coveragePercentage should be >= 0 for " & file);
				expect(stats.coveragePercentage).toBeLTE(100, "coveragePercentage should be <= 100 for " & file);
			}

		}
	}
}