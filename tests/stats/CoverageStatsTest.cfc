component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" displayname="CoverageStatsTest" {

	function run() {
		describe("check codeCoverage stats", function() {
			it("test CoverageStatsTest", function() {
				var logger = new lucee.extension.lcov.Logger( level="none" );
				var parser = new lucee.extension.lcov.ExecutionLogParser( options={ logLevel: "none" } );
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=logger );
				var testDataGenerator = new "../GenerateTestData"( testName="CoverageStatsTest" );
				var testData = testDataGenerator.generateExlFilesForArtifacts( request.SERVERADMINPASSWORD );

				testParseFiles( parser, statsComponent, testData, "CoverageStatsTest" );
			});

			it("throws error if linesHit exceeds linesFound (fail-fast policy)", function() {
				var logger = new lucee.extension.lcov.Logger( level="none" );
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=logger );
				// Create a synthetic mergedResults struct with invalid stats
				var mergedResults = {
					0: {
						stats: {
							linesFound: 5,
							linesHit: 7, // Invalid: linesHit > linesFound
							linesSource: 10
						},
						files: {
							0: {
								path: "/tmp/Invalid.cfm",
								linesFound: 5,
								linesHit: 7,
								linesSource: 10
							}
						}
					}
				};
				expect(function() {
					statsComponent.validateStatsForMergedResults(mergedResults);
				}).toThrow();
			});
		});
	}

	private function testParseFiles(parser, statsComponent, testData, testName){
		expect(directoryExists(testData.coverageDir)).toBeTrue("Coverage directory should exist");

		var files = directoryList(testData.coverageDir, false, "path", "*.exl");
		expect(arrayLen(files)).toBeGT(0, "Should find some .exl files");
		for (var file in files) {

			var result = parser.parseExlFile(exlPath=file, allowList=[], blocklist=[], writeJsonCache=true);

			var resultJsonFile = replace(file, ".exl", ".json", "all");
			expect( fileExists (resultJsonFile) ).toBeTrue("JSON file missing for " & file);
			expect( fileRead( resultJsonFile ) ).toBeJson("Invalid JSON in " & resultJsonFile & " (from " & file & ")");
			var resultStruct = deserializeJson( fileRead( resultJsonFile ) );
			expect( resultStruct ).toBeStruct("Result struct not valid for " & file);


			// Wrap resultStruct in a result model for strict API
			var resultModel = new lucee.extension.lcov.model.result();
			if (structKeyExists(resultStruct, "metadata")) resultModel.setMetadata(resultStruct.metadata);
			if (structKeyExists(resultStruct, "stats")) resultModel.setStats(resultStruct.stats);
			if (structKeyExists(resultStruct, "coverage")) resultModel.setCoverage(resultStruct.coverage);
			if (structKeyExists(resultStruct, "files")) resultModel.setFiles(resultStruct.files);
			var stats = statsComponent.calculateCoverageStats(resultModel);
			var statsStruct = stats.getStats();
			expect( statsStruct ).toBeStruct("Stats not valid for " & file);

			var statsKeys = ["totalLinesFound", "totalLinesHit", "totalExecutions", "totalExecutionTime", "totalLinesSource"];
			for (var key in statsKeys) {
				expect( statsStruct ).toHaveKey( key, "Missing key '" & key & "' in stats for " & file );
			}

			var files = resultModel.getFiles();
			// For each file, check linesHit and linesFound are <= totalLinesSource (if totalLinesSource > 0)
			for (var fileKey in files) {
				var fileStats = files[fileKey];
				if (structKeyExists(fileStats, "linesSource") && fileStats.linesSource > 0) {
					expect(fileStats.linesHit).toBeLTE(fileStats.linesSource, "linesHit should not exceed linesSource for " & fileKey);
					expect(fileStats.linesFound).toBeLTE(fileStats.linesSource, "linesFound should not exceed linesSource for " & fileKey);
				}
			}

			// Assert that totalLinesHit does not exceed totalLinesFound
			expect(statsStruct.totalLinesHit).toBeLTE(statsStruct.totalLinesFound, "totalLinesHit should not exceed totalLinesFound for " & file);

			// If percentage is calculated, check it is between 0 and 100
			if (structKeyExists(statsStruct, "coveragePercentage")) {
				expect(statsStruct.coveragePercentage).toBeGTE(0, "coveragePercentage should be >= 0 for " & file);
				expect(statsStruct.coveragePercentage).toBeLTE(100, "coveragePercentage should be <= 100 for " & file);
			}

		}
	}
}
