component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" displayname="CoverageStatsSyntheticTest" {

	function beforeAll(){
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger(level=variables.logLevel);
	}

	function run() {
		describe("calculateLcovStats synthetic", function() {
			it("computes correct stats for synthetic merged data", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: {
						"A": { path: "/tmp/A.cfm", linesFound: 3, linesSource: 5 },
						"B": { path: "/tmp/B.cfm", linesFound: 2, linesSource: 4 }
					},
					coverage: {
						"A": { "10": [1, 2, 0], "11": [0, 0, 0], "12": [1, 1, 0] },
						"B": { "20": [1, 1, 0], "21": [0, 0, 0] }
					}
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(3);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(2);
				expect(stats["/tmp/A.cfm"].linesSource).toBe(5);
				expect(stats["/tmp/B.cfm"].linesFound).toBe(2);
				expect(stats["/tmp/B.cfm"].linesHit).toBe(1);
				expect(stats["/tmp/B.cfm"].linesSource).toBe(4);
			});

			it("computes correct stats for complex synthetic merged data", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: {
						"A": { path: "/tmp/A.cfm", linesFound: 5, linesSource: 10 },
						"B": { path: "/tmp/B.cfm", linesFound: 4, linesSource: 8 },
						"C": { path: "/tmp/C.cfm", linesFound: 6, linesSource: 12 }
					},
					coverage: {
						"A": { "10": [1, 2, 0], "11": [0, 0, 0], "12": [1, 1, 0], "13": [1, 1, 0], "14": [0, 0, 0] },
						"B": { "20": [1, 1, 0], "21": [0, 0, 0], "22": [1, 1, 0], "23": [1, 1, 0] },
						"C": { "30": [1, 2, 0], "31": [1, 1, 0], "32": [0, 0, 0], "33": [1, 1, 0], "34": [1, 1, 0], "35": [0, 0, 0] }
					}
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(5);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(3);
				expect(stats["/tmp/A.cfm"].linesSource).toBe(10);
				expect(stats["/tmp/B.cfm"].linesFound).toBe(4);
				expect(stats["/tmp/B.cfm"].linesHit).toBe(3);
				expect(stats["/tmp/B.cfm"].linesSource).toBe(8);
				expect(stats["/tmp/C.cfm"].linesFound).toBe(6);
				expect(stats["/tmp/C.cfm"].linesHit).toBe(4);
				expect(stats["/tmp/C.cfm"].linesSource).toBe(12);
			});
		});

		describe("calculateDetailedStats synthetic", function() {
			it("computes correct global stats for synthetic results", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var resultA = mockResult({
					files: { "/tmp/A.cfm": { path: "/tmp/A.cfm", linesFound: 3, linesSource: 5, executableLines: {"10": true, "11": true, "12": true} } },
					coverage: { "/tmp/A.cfm": { "10": [1, 2, 0], "11": [0, 0, 0], "12": [1, 1, 0] } }
				});
				var resultB = mockResult({
					files: { "/tmp/B.cfm": { path: "/tmp/B.cfm", linesFound: 2, linesSource: 4, executableLines: {"20": true, "21": true} } },
					coverage: { "/tmp/B.cfm": { "20": [1, 1, 0], "21": [0, 0, 0] } }
				});
				// Write results to temporary JSON files for progressive processing
				var tempDir = getTempDirectory() & "/stats-test-" & createUUID();
				directoryCreate(tempDir);
				var jsonFilePaths = [];
				var jsonPathA = tempDir & "/resultA.json";
				var jsonPathB = tempDir & "/resultB.json";
				fileWrite(jsonPathA, resultA.toJson(false, true));
				fileWrite(jsonPathB, resultB.toJson(false, true));
				arrayAppend(jsonFilePaths, jsonPathA);
				arrayAppend(jsonFilePaths, jsonPathB);
				var stats = statsComponent.aggregateCoverageStats(jsonFilePaths);
				variables.logger.debug("[DEBUG] fileStats keys: " & structKeyList(stats.fileStats));
				variables.logger.debug("[DEBUG] fileStats struct: " & serializeJSON(var=stats.fileStats, compact=false));
				expect(stats.totalLinesFound).toBe(5);
				expect(stats.totalLinesHit).toBe(3);
				expect(stats.totalLinesSource).toBe(9);
				expect(stats.fileStats).toHaveKey("/tmp/A.cfm");
				expect(stats.fileStats["/tmp/A.cfm"].linesFound).toBe(3);
				expect(stats.fileStats["/tmp/A.cfm"].linesHit).toBe(2);
				expect(stats.fileStats).toHaveKey("/tmp/B.cfm");
				expect(stats.fileStats["/tmp/B.cfm"].linesFound).toBe(2);
				expect(stats.fileStats["/tmp/B.cfm"].linesHit).toBe(1);
			});

			it("computes correct global stats for complex synthetic results", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var resultA = mockResult({
					files: { "/tmp/A.cfm": { path: "/tmp/A.cfm", linesFound: 5, linesSource: 10, executableLines: {"10": true, "11": true, "12": true, "13": true, "14": true} } },
					coverage: { "/tmp/A.cfm": { "10": [1, 2, 0], "11": [0, 0, 0], "12": [1, 1, 0], "13": [1, 1, 0], "14": [0, 0, 0] } }
				});
				var resultB = mockResult({
					files: { "/tmp/B.cfm": { path: "/tmp/B.cfm", linesFound: 4, linesSource: 8, executableLines: {"20": true, "21": true, "22": true, "23": true} } },
					coverage: { "/tmp/B.cfm": { "20": [1, 1, 0], "21": [0, 0, 0], "22": [1, 1, 0], "23": [1, 1, 0] } }
				});
				var resultC = mockResult({
					files: { "/tmp/C.cfm": { path: "/tmp/C.cfm", linesFound: 6, linesSource: 12, executableLines: {"30": true, "31": true, "32": true, "33": true, "34": true, "35": true} } },
					coverage: { "/tmp/C.cfm": { "30": [1, 2, 0], "31": [1, 1, 0], "32": [0, 0, 0], "33": [1, 1, 0], "34": [1, 1, 0], "35": [0, 0, 0] } }
				});
				// Write results to temporary JSON files for progressive processing
				var tempDir = getTempDirectory() & "/stats-test-" & createUUID();
				directoryCreate(tempDir);
				var jsonFilePaths = [];
				var jsonPathA = tempDir & "/resultA.json";
				var jsonPathB = tempDir & "/resultB.json";
				var jsonPathC = tempDir & "/resultC.json";
				fileWrite(jsonPathA, resultA.toJson(false, true));
				fileWrite(jsonPathB, resultB.toJson(false, true));
				fileWrite(jsonPathC, resultC.toJson(false, true));
				arrayAppend(jsonFilePaths, jsonPathA);
				arrayAppend(jsonFilePaths, jsonPathB);
				arrayAppend(jsonFilePaths, jsonPathC);
				var stats = statsComponent.aggregateCoverageStats(jsonFilePaths);
				expect(stats.totalLinesFound).toBe(15);
				expect(stats.totalLinesHit).toBe(10);
				expect(stats.totalLinesSource).toBe(30);
				expect(stats.fileStats).toHaveKey("/tmp/A.cfm");
				expect(stats.fileStats["/tmp/A.cfm"].linesFound).toBe(5);
				expect(stats.fileStats["/tmp/A.cfm"].linesHit).toBe(3);
				expect(stats.fileStats).toHaveKey("/tmp/B.cfm");
				expect(stats.fileStats["/tmp/B.cfm"].linesFound).toBe(4);
				expect(stats.fileStats["/tmp/B.cfm"].linesHit).toBe(3);
				expect(stats.fileStats).toHaveKey("/tmp/C.cfm");
				expect(stats.fileStats["/tmp/C.cfm"].linesFound).toBe(6);
				expect(stats.fileStats["/tmp/C.cfm"].linesHit).toBe(4);
			});
		});

		describe("calculateStatsForMergedResults synthetic", function() {
			it("sets stats on merged result objects", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var mergedResults = {
					0: mockResult({
						files: {
							1: {
								path: "/tmp/A.cfm",
								linesFound: 3,
								linesSource: 5,
								executableLines: { "10": true, "11": true, "12": true }
							}
						},
						coverage: { 1: { "10": [1, 2, 0], "11": [0, 0, 0], "12": [1, 1, 0] } }
					}),
					1: mockResult({
						files: {
							2: {
								path: "/tmp/B.cfm",
								linesFound: 2,
								linesSource: 4,
								executableLines: { "20": true, "21": true }
							}
						},
						coverage: { 2: { "20": [1, 1, 0], "21": [0, 0, 0] } }
					})
				};
				statsComponent.calculateStatsForMergedResults(mergedResults);
				expect(mergedResults[0].getStats().totalLinesFound).toBe(3);
				expect(mergedResults[0].getStats().totalLinesHit).toBe(2);
				expect(mergedResults[1].getStats().totalLinesFound).toBe(2);
				expect(mergedResults[1].getStats().totalLinesHit).toBe(1);
			});

			it("sets stats on complex merged result objects", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var mergedResults = {
					0: mockResult({
						files: {
							1: {
								path: "/tmp/A.cfm",
								linesFound: 5,
								linesSource: 10,
								executableLines: { "10": true, "11": true, "12": true, "13": true, "14": true }
							}
						},
						coverage: { 1: { "10": [1, 2, 0], "11": [0, 0, 0], "12": [1, 1, 0], "13": [1, 1, 0], "14": [0, 0, 0] } }
					}),
					1: mockResult({
						files: {
							2: {
								path: "/tmp/B.cfm",
								linesFound: 4,
								linesSource: 8,
								executableLines: { "20": true, "21": true, "22": true, "23": true }
							}
						},
						coverage: { 2: { "20": [1, 1, 0], "21": [0, 0, 0], "22": [1, 1, 0], "23": [1, 1, 0] } }
					}),
					2: mockResult({
						files: {
							3: {
								path: "/tmp/C.cfm",
								linesFound: 6,
								linesSource: 12,
								executableLines: { "30": true, "31": true, "32": true, "33": true, "34": true, "35": true }
							}
						},
						coverage: { 3: { "30": [1, 2, 0], "31": [1, 1, 0], "32": [0, 0, 0], "33": [1, 1, 0], "34": [1, 1, 0], "35": [0, 0, 0] } }
					})
				};
				statsComponent.calculateStatsForMergedResults(mergedResults);
				expect(mergedResults[0].getStats().totalLinesFound).toBe(5);
				expect(mergedResults[0].getStats().totalLinesHit).toBe(3);
				expect(mergedResults[1].getStats().totalLinesFound).toBe(4);
				expect(mergedResults[1].getStats().totalLinesHit).toBe(3);
				expect(mergedResults[2].getStats().totalLinesFound).toBe(6);
				expect(mergedResults[2].getStats().totalLinesHit).toBe(4);
			});
		});

		// ...existing code...
		describe("edge and error cases", function() {
			it("throws error if linesHit exceeds linesFound (synthetic aggregation bug)", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				// linesFound is 2, but 3 lines are covered (should error)
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 2, linesSource: 5 } },
					coverage: { "A": { "10": [1, 1, 0], "11": [1, 1, 0], "12": [1, 1, 0] } }
				};
				expect(function() {
					statsComponent.calculateLcovStats(fileCoverage);
				}).toThrow();
			});
			it("throws error if linesSource is missing", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 3 } },
					coverage: { "A": { "10": [1, 2, 0] } }
				};
				expect(function() {
					statsComponent.calculateLcovStats(fileCoverage);
				}).toThrow();
			});

			it("throws error if linesFound is missing", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesSource: 5 } },
					coverage: { "A": { "10": [1, 2, 0] } }
				};
				expect(function() {
					statsComponent.calculateLcovStats(fileCoverage);
				}).toThrow();
			});

			it("throws error if linesSource is negative", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 3, linesSource: -5 } },
					coverage: { "A": { "10": [1, 2, 0] } }
				};
				expect(function() {
					statsComponent.calculateLcovStats(fileCoverage);
				}).toThrow();
			});

			it("throws error if linesFound > linesSource", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 10, linesSource: 5 } },
					coverage: { "A": { "10": [1, 2, 0] } }
				};
				expect(function() {
					statsComponent.calculateLcovStats(fileCoverage);
				}).toThrow();
			});

			it("handles duplicate file entries by aggregating stats", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: {
						"A": { path: "/tmp/A.cfm", linesFound: 2, linesSource: 5 },
						"A_dup": { path: "/tmp/A.cfm", linesFound: 3, linesSource: 5 }
					},
					coverage: {
						"A": { "10": [1, 2, 0], "11": [0, 0, 0] },
						"A_dup": { "12": [1, 1, 0] }
					}
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(3); // max of both
				expect(stats["/tmp/A.cfm"].linesSource).toBe(5);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(2); // lines 10 and 12
			});

			it("handles file with zero executable lines", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 0, linesSource: 5 } },
					coverage: { "A": {} }
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(0);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(0);
				expect(stats["/tmp/A.cfm"].linesSource).toBe(5);
			});

			it("handles file with zero source lines", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 0, linesSource: 0 } },
					coverage: { "A": {} }
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(0);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(0);
				expect(stats["/tmp/A.cfm"].linesSource).toBe(0);
			});

			it("handles empty results struct", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var stats = statsComponent.aggregateCoverageStats([]);
				expect(stats.totalLinesFound).toBe(0);
				expect(stats.totalLinesHit).toBe(0);
				expect(stats.totalLinesSource).toBe(0);
				expect(stats.totalFiles).toBe(0);
			});

			it("handles file with only one line, all covered", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 1, linesSource: 1 } },
					coverage: { "A": { "1": [1, 1, 0] } }
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(1);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(1);
				expect(stats["/tmp/A.cfm"].linesSource).toBe(1);
			});

			it("handles file with only one line, none covered", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
				var fileCoverage = {
					files: { "A": { path: "/tmp/A.cfm", linesFound: 1, linesSource: 1 } },
					coverage: { "A": { "1": [0, 0, 0] } }
				};
				var stats = statsComponent.calculateLcovStats(fileCoverage);
				expect(stats["/tmp/A.cfm"].linesFound).toBe(1);
				expect(stats["/tmp/A.cfm"].linesHit).toBe(0);
				expect(stats["/tmp/A.cfm"].linesSource).toBe(1);
			});
		});

		describe("calculateDetailedStats merging bug reproduction", function() {

			it("should correctly handle multiple results covering same file (linesHit <= linesFound)", function() {
				var statsComponent = new lucee.extension.lcov.CoverageStats( logger=variables.logger );

				// Create two result objects that cover the SAME source file
				// This simulates multiple HTTP requests executing the same .cfm file
				var filePath = "/tmp/SameFile.cfm";

				// First execution covers lines 10, 12, 14 (3 lines)
				var result1 = mockResult({
					files: {
						"/tmp/SameFile.cfm": {
							path: filePath,
							linesFound: 5,  // Total executable lines in the file
							linesSource: 20,
							executableLines: {"10": true, "12": true, "14": true, "16": true, "18": true}
						}
					},
					coverage: {
						"/tmp/SameFile.cfm": {
							"10": [1, 100, 0], // line 10 hit once
							"12": [2, 200, 0]  // line 12 hit twice
						}
					}
				});

				// Second execution covers lines 14, 16, 18 (3 lines, with overlap on line 14)
				var result2 = mockResult({
					files: {
						"/tmp/SameFile.cfm": {
							path: filePath,
							linesFound: 5,  // Same total executable lines
							linesSource: 20,
							executableLines: {"10": true, "12": true, "14": true, "16": true, "18": true}
						}
					},
					coverage: {
						"/tmp/SameFile.cfm": {
							"14": [1, 150, 0], // line 14 hit once
							"16": [3, 300, 0], // line 16 hit 3 times
							"18": [1, 100, 0]  // line 18 hit once
						}
					}
				});

				// The bug: calculateDetailedStats counts union of covered lines: 10, 12, 14, 16, 18 = 5 lines hit
				// But linesFound is 5, so linesHit should be <= 5, which it is in this case
				// Let's create a case where it actually exceeds...

				// Third execution covers additional lines that shouldn't exist
				var result3 = mockResult({
					files: {
						"/tmp/SameFile.cfm": {
							path: filePath,
							linesFound: 5,  // Still claims only 5 executable lines
							linesSource: 20,
							executableLines: {"10": true, "12": true, "14": true, "16": true, "18": true, "20": true, "22": true} // BUG: 7 executable lines but linesFound=5
						}
					},
					coverage: {
						"/tmp/SameFile.cfm": {
							"20": [2, 400, 0], // extra line 20
							"22": [1, 200]  // extra line 22
						}
					}
				});

				// Write results to temporary JSON files for progressive processing
				var tempDir = getTempDirectory() & "/stats-test-" & createUUID();
				directoryCreate(tempDir);
				var jsonFilePaths = [];
				var jsonPath1 = tempDir & "/result1.json";
				var jsonPath2 = tempDir & "/result2.json";
				var jsonPath3 = tempDir & "/result3.json";
				fileWrite(jsonPath1, result1.toJson(false, true));
				fileWrite(jsonPath2, result2.toJson(false, true));
				fileWrite(jsonPath3, result3.toJson(false, true));
				arrayAppend(jsonFilePaths, jsonPath1);
				arrayAppend(jsonFilePaths, jsonPath2);
				arrayAppend(jsonFilePaths, jsonPath3);

				// After the fix:
				// linesHit = union of (10,12,14,16,18,20,22) = 7 lines
				// linesFound = union of all executableLines = 7 lines
				// 7 <= 7, satisfying the basic coverage rule
				//systemOutput("Testing calculateDetailedStats with overlapping coverage - should now handle correctly", true);

				var stats = statsComponent.aggregateCoverageStats(jsonFilePaths);

				// Verify the fix works - linesFound should now be calculated correctly
				expect(stats.fileStats).toHaveKey("/tmp/SameFile.cfm");
				var fileData = stats.fileStats["/tmp/SameFile.cfm"];

				// This demonstrates the fix: linesHit <= linesFound
				expect(fileData.linesHit).toBeLTE(fileData.linesFound,
					"Fix verified: linesHit (" & fileData.linesHit & ") should be <= linesFound (" & fileData.linesFound & ") after merging fix");

				// Expected specific values from our test data after the fix
				expect(fileData.linesFound).toBe(7, "linesFound should be 7 (union of all executableLines from all results)");
				expect(fileData.linesHit).toBe(7, "linesHit should be 7 (union of lines 10,12,14,16,18,20,22)");
			});

		});

	}

	private function mockResult(data) {
		var result = new lucee.extension.lcov.model.result();
		if (structKeyExists(data, "files")) result.setFiles(data.files);
		if (structKeyExists(data, "coverage")) result.setCoverage(data.coverage);
		return result;
	}
}
