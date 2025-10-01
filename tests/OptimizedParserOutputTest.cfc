component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	// BDD-style parser comparison tests

	function beforeAll() {
		variables.logLevel = "info";
		// Process all artifacts - no file filter
		variables.fileFilter = "";
	}

	function run() {
		describe("Parser Optimization Comparison", function() {

			describe("Test Data Setup", function() {

				it("should generate stable parser test data", function() {
					variables.testDataGenerator = new GenerateTestData(testName="developParserOutputTest-stable");
					variables.stableTestData = variables.testDataGenerator.generateExlFilesForArtifacts(
						adminPassword = request.SERVERADMINPASSWORD,
						fileFilter = variables.fileFilter
					);

					expect(directoryExists(variables.stableTestData.coverageDir)).toBeTrue();
				});

				it("should generate develop parser test data", function() {
					variables.testDataGenerator = new GenerateTestData(testName="developParserOutputTest-develop");
					variables.developTestData = variables.testDataGenerator.generateExlFilesForArtifacts(
						adminPassword = request.SERVERADMINPASSWORD,
						fileFilter = variables.fileFilter
					);

					expect(directoryExists(variables.developTestData.coverageDir)).toBeTrue();
				});

				it("should have matching EXL files in both directories", function() {
					var stableFiles = directoryList(variables.stableTestData.coverageDir, false, "path", "*.exl");
					var developFiles = directoryList(variables.developTestData.coverageDir, false, "path", "*.exl");

					expect(arrayLen(stableFiles)).toBeGT(0);
					expect(arrayLen(developFiles)).toBeGT(0);
					expect(stableFiles).toHaveLength(arrayLen(developFiles));
				});
			});

			describe("Parser Execution", function() {

					it("should execute stable parser on all files successfully", function() {
						var stableParser = new lucee.extension.lcov.ExecutionLogParser({"logLevel": "info"});
						var testFiles = directoryList(variables.stableTestData.coverageDir, false, "path", "*.exl");

						for (var testExlFile in testFiles) {
							var parserResult = stableParser.parseExlFile(exlPath=testExlFile, allowList=[], blocklist=[], writeJsonCache=true);

							expect(isInstanceOf(parserResult, "lucee.extension.lcov.model.result")).toBeTrue();
							expect(parserResult.getMetadata()).notToBeEmpty();
							expect(parserResult.getFiles()).notToBeEmpty();
							expect(parserResult.getCoverage()).notToBeEmpty();
						}
					});

					it("should execute develop parser on all files successfully", function() {
						var developParser = new lucee.extension.lcov.develop.ExecutionLogParser({"logLevel": "info"});
						var testFiles = directoryList(variables.developTestData.coverageDir, false, "path", "*.exl");

						for (var testExlFile in testFiles) {
							var parserResult = developParser.parseExlFile(exlPath=testExlFile, allowList=[], blocklist=[], writeJsonCache=true);

							expect(isInstanceOf(parserResult, "lucee.extension.lcov.model.result")).toBeTrue();
							expect(parserResult.getMetadata()).notToBeEmpty();
							expect(parserResult.getFiles()).notToBeEmpty();
							expect(parserResult.getCoverage()).notToBeEmpty();
						}
					});
			});

			describe("JSON File Output Verification", function() {

				it("should create JSON files for both parsers", function() {
					var stableJsonFiles = directoryList(variables.stableTestData.coverageDir, false, "path", "*.json");
					var developJsonFiles = directoryList(variables.developTestData.coverageDir, false, "path", "*.json");

					//systemOutput("stable JSON files: " & arrayLen(stableJsonFiles), true);
					//systemOutput("Optimized JSON files: " & arrayLen(developJsonFiles), true);

					expect(arrayLen(stableJsonFiles)).toBeGT(0);
					expect(arrayLen(developJsonFiles)).toBeGT(0);
					expect(stableJsonFiles).toHaveLength(arrayLen(developJsonFiles));
				});

				it("should process all JSON files and create script mappings", function() {
					var stableJsonFiles = directoryList(variables.stableTestData.coverageDir, false, "path", "*.json");
					var developJsonFiles = directoryList(variables.developTestData.coverageDir, false, "path", "*.json");

					// Process all stable JSON files and build script-name mapping
					var stableScriptMapping = {};
					variables.stableParsedData = {};
					for (var jsonFile in stableJsonFiles) {
						var jsonData = deserializeJSON(fileRead(jsonFile), false);
						expect(jsonData).toBeStruct();

						var scriptName = jsonData.metadata["script-name"];
						var queryString = structKeyExists(jsonData.metadata, "query-string") ? jsonData.metadata["query-string"] : "";
						var scriptKey = scriptName & (len(queryString) > 0 ? "?" & queryString : "");
						var fileName = listLast(replace(jsonFile, ".json", ".exl"), "/\");

						if (!structKeyExists(stableScriptMapping, scriptKey)) {
							stableScriptMapping[scriptKey] = [];
						}
						arrayAppend(stableScriptMapping[scriptKey], fileName);
						variables.stableParsedData[fileName] = jsonData;
					}

					// Process all optimized JSON files and build script-name mapping
					var developScriptMapping = {};
					variables.developParsedData = {};
					for (var jsonFile in developJsonFiles) {
						var jsonData = deserializeJSON(fileRead(jsonFile), false);
						expect(jsonData).toBeStruct();

						var scriptName = jsonData.metadata["script-name"];
						var queryString = structKeyExists(jsonData.metadata, "query-string") ? jsonData.metadata["query-string"] : "";
						var scriptKey = scriptName & (len(queryString) > 0 ? "?" & queryString : "");
						var fileName = listLast(replace(jsonFile, ".json", ".exl"), "/\");

						if (!structKeyExists(developScriptMapping, scriptKey)) {
							developScriptMapping[scriptKey] = [];
						}
						arrayAppend(developScriptMapping[scriptKey], fileName);
						variables.developParsedData[fileName] = jsonData;
					}

					// Write parsed-index.json files
					fileWrite(variables.stableTestData.coverageDir & "/parsed-index.json",
						serializeJSON(var=stableScriptMapping, compact=false));
					fileWrite(variables.developTestData.coverageDir & "/parsed-index.json",
						serializeJSON(var=developScriptMapping, compact=false));

					variables.stableScriptMapping = stableScriptMapping;
					variables.developScriptMapping = developScriptMapping;

					//systemOutput("stable scripts mapped: " & structCount(stableScriptMapping), true);
					//systemOutput("Optimized scripts mapped: " & structCount(developScriptMapping), true);
				});
			});

			describe("Output Comparison", function() {

				it("should validate all matching scripts between parsers", function() {
					var matchingScripts = [];
					var stableScripts = structKeyArray(variables.stableScriptMapping);
					var developScripts = structKeyArray(variables.developScriptMapping);

					// Find scripts that exist in both mappings
					for (var scriptKey in stableScripts) {
						if (structKeyExists(variables.developScriptMapping, scriptKey)) {
							arrayAppend(matchingScripts, scriptKey);
						}
					}

					expect(arrayLen(matchingScripts)).toBeGT(0, "No matching scripts found between stable and develop parsers");
					//systemOutput("Found " & arrayLen(matchingScripts) & " matching scripts to compare", true);

					var totalComparisons = 0;

					// Compare each matching script
					for (var scriptKey in matchingScripts) {
						var stableFiles = variables.stableScriptMapping[scriptKey];
						var developFiles = variables.developScriptMapping[scriptKey];

						// Compare first file from each script (should be same content)
						var stableFile = stableFiles[1];
						var developFile = developFiles[1];

						var stableData = variables.stableParsedData[stableFile];
						var developData = variables.developParsedData[developFile];

						//systemOutput("Comparing script: " & scriptKey & " (stable: " & stableFile & ", Optimized: " & developFile & ")", true);

						// Run all comparison tests for this script pair
						try {
							// Wrap in result model objects for strict API
							var stableModel = new lucee.extension.lcov.model.result();
							if (structKeyExists(stableData, "metadata")) stableModel.setMetadata(stableData.metadata);
							if (structKeyExists(stableData, "stats")) stableModel.setStats(stableData.stats);
							if (structKeyExists(stableData, "coverage")) stableModel.setCoverage(stableData.coverage);
							if (structKeyExists(stableData, "files")) stableModel.setFiles(stableData.files);
							if (structKeyExists(stableData, "exeLog")) stableModel.setExeLog(stableData.exeLog);
							var developModel = new lucee.extension.lcov.model.result();
							if (structKeyExists(developData, "metadata")) developModel.setMetadata(developData.metadata);
							if (structKeyExists(developData, "stats")) developModel.setStats(developData.stats);
							if (structKeyExists(developData, "coverage")) developModel.setCoverage(developData.coverage);
							if (structKeyExists(developData, "files")) developModel.setFiles(developData.files);
							if (structKeyExists(developData, "exeLog")) developModel.setExeLog(developData.exeLog);
							compareHighLevelStructure(stableModel, developModel);
						} catch (any e) {
							systemOutput("High-level structure comparison failed for " & scriptKey & ": " & e.message, true);
							rethrow;
						}

						try {
							compareMetadata(stableModel.getMetadata(), developModel.getMetadata());
						} catch (any e) {
							systemOutput("Metadata comparison failed for " & scriptKey & ": " & e.message, true);
							rethrow;
						}

						try {
							compareFileStructure(stableModel.getFiles(), developModel.getFiles());
						} catch (any e) {
							systemOutput("File structure comparison failed for " & scriptKey & ": " & e.message, true);
							systemOutput("    stable files count: " & structCount(stableModel.getFiles()), true);
							systemOutput("    Develop files count: " & structCount(developModel.getFiles()), true);
							rethrow;
						}

						try {
							compareCoverageStructure(stableModel.getCoverage(), developModel.getCoverage());
						} catch (any e) {
							systemOutput("Coverage structure comparison failed for " & scriptKey & ": " & e.message, true);
							rethrow;
						}

						try {
							compareParserPerformance(stableModel, developModel);
						} catch (any e) {
							systemOutput("Parser performance comparison failed for " & scriptKey & ": " & e.message, true);
							rethrow;
						}

						totalComparisons++;
					}

					//systemOutput("Successfully compared " & totalComparisons & " script pairs", true);
				});
			});
		});
	}

	// Helper functions for BDD tests

	private function compareHighLevelStructure(required any stableData, required any developData) {
		//systemOutput("Comparing high-level structure...", true);

		// Check that model getters return expected data
		expect(stableData.getMetadata()).notToBeEmpty();
		expect(developData.getMetadata()).notToBeEmpty();
		expect(stableData.getFiles()).notToBeEmpty();
		expect(developData.getFiles()).notToBeEmpty();
		expect(stableData.getCoverage()).notToBeEmpty();
		expect(developData.getCoverage()).notToBeEmpty();
		// Skip fileCoverage check - this data is excluded from JSON cache for memory optimization (excludeFileCoverage=true)
		// expect(stableData.getFileCoverage()).notToBeEmpty();
		// expect(developData.getFileCoverage()).notToBeEmpty();
		expect(stableData.getExeLog()).notToBeEmpty();
		expect(developData.getExeLog()).notToBeEmpty();
		// Both should have files structure (files are indexed by file index, not nested under "files" key)
		var stableFiles = stableData.getFiles();
		var developFiles = developData.getFiles();
		expect(structCount(stableFiles)).toBeGT(0);
		expect(structCount(developFiles)).toBeGT(0);
		// File counts should match
		expect(structCount(stableFiles)).toBe(structCount(developFiles));
		// Coverage structures should have same number of file entries
		expect(structCount(stableData.getCoverage())).toBe(structCount(developData.getCoverage()));
	}

	private function compareMetadata(required struct stableMeta, required struct developMeta) {
		//systemOutput("Comparing metadata (excluding time-sensitive fields)...", true);

		// Compare time-insensitive fields that should be identical
		var compareFields = ["script-name", "context-path", "server-name", "server-port", "protocol", "query-string", "path-info", "unit"];
		for (var field in compareFields) {
			if (structKeyExists(stableMeta, field) && structKeyExists(developMeta, field)) {
				expect(stableMeta[field]).toBe(developMeta[field]);
			}
		}

		// Verify time-sensitive fields exist (values will differ between runs)
		expect(stableMeta).toHaveKey("execution-time");
		expect(developMeta).toHaveKey("execution-time");
	}

	private function compareFileStructure(required struct stableFiles, required struct developFiles) {
		//systemOutput("Comparing file structure...", true);

		// Compare each file's structure
		for (var fileIdx in stableFiles) {
			// develop parser should have same file indexes
			expect(developFiles).toHaveKey(fileIdx);

			var stableFile = stableFiles[fileIdx];
			var devFile = developFiles[fileIdx];

			// File paths should be identical
			expect(stableFile.path).toBe(devFile.path);

			   // Line counts should match
			   expect(stableFile.linesFound).toBe(devFile.linesFound);
			   expect(stableFile.linesSource).toBe(devFile.linesSource);

			// Note: executableLines field removed - coverage now contains all executable lines

			// Source code line arrays should match
			expect(stableFile.lines).toHaveLength(arrayLen(devFile.lines));
		}
	}

	private function compareCoverageStructure(required struct stableCoverage, required struct devCoverage) {
		//systemOutput("Comparing coverage structure...", true);

		// Coverage should be struct with file indexes as keys
		expect(stableCoverage).toBeStruct();
		expect(devCoverage).toBeStruct();

		// File count should match
		expect(structCount(stableCoverage)).toBe(structCount(devCoverage));

		// Compare each file's coverage data
		for (var fileIdx in stableCoverage) {
			// Both parsers should have coverage for the same files
			expect(devCoverage).toHaveKey(fileIdx);

			var stableFileCoverage = stableCoverage[fileIdx];
			var devFileCoverage = devCoverage[fileIdx];

			expect(stableFileCoverage).toBeStruct();
			expect(devFileCoverage).toBeStruct();
			/*
			systemOutput("", true);
			systemOutput("Comparing coverage for file index: " & fileIdx, true);
			systemOutput("  stable : " & serializeJSON(stableFileCoverage), true);
			systemOutput("  develop: " & serializeJSON(devFileCoverage), true);
			*/

			// Line count should match for each file
			expect(structCount(stableFileCoverage)).toBe(structCount(devFileCoverage));

			// Sample a few lines to verify structure
			var lineNumbers = structKeyArray(stableFileCoverage);
			var sampleSize = min(5, arrayLen(lineNumbers));

			for (var i = 1; i <= sampleSize; i++) {
				var lineNum = lineNumbers[i];
				// Both should have coverage data for the same lines
				expect(devFileCoverage).toHaveKey(lineNum);

				var stableLineData = stableFileCoverage[lineNum];
				var devLineData = devFileCoverage[lineNum];

				// Both should be arrays with 2 or 3 elements: [hitCount, executionTime] or [hitCount, executionTime, isChildTime]
				expect(stableLineData).toBeArray();
				expect(devLineData).toBeArray();
				// Allow 2 or 3 elements (3rd element is optional isChildTime flag)
				expect(arrayLen(stableLineData) >= 2 && arrayLen(stableLineData) <= 3).toBeTrue("stableLineData should have 2-3 elements");
				expect(arrayLen(devLineData) >= 2 && arrayLen(devLineData) <= 3).toBeTrue("devLineData should have 2-3 elements");

				// Hit counts should match (Lucee will handle string/number conversion)
				expect(stableLineData[1]).toBe(devLineData[1]);

				// Execution times should both be numeric (allow flexible comparison)
				expect(isNumeric(stableLineData[2])).toBeTrue();
				expect(isNumeric(devLineData[2])).toBeTrue();
			}
		}
	}

	private function compareParserPerformance(required any stableModel, required any developModel) {
		//systemOutput("Comparing parser performance metrics...", true);

		// Get parserPerformance data (may be empty for some test data)
		var stablePerf = stableModel.getParserPerformance();
		var devPerf = developModel.getParserPerformance();

		// Skip comparison if either has no performance data
		if (structIsEmpty(stablePerf) || structIsEmpty(devPerf)) {
			//systemOutput("Skipping parser performance comparison - no performance data available", true);
			return;
		}

		// Validate stable parser performance structure
		expect(stablePerf).toBeStruct();
		expect(stablePerf).toHaveKey("processingTime");
		expect(stablePerf).toHaveKey("timePerLine");
		expect(stablePerf).toHaveKey("totalLines");
		expect(stablePerf).toHaveKey("optimizationsApplied");
		expect(stablePerf.optimizationsApplied).toBeArray();
		
		// Validate develop parser performance structure
		expect(devPerf).toBeStruct();
		expect(devPerf).toHaveKey("processingTime");
		expect(devPerf).toHaveKey("timePerLine");
		expect(devPerf).toHaveKey("totalLines");
		expect(devPerf).toHaveKey("optimizationsApplied");
		expect(devPerf.optimizationsApplied).toBeArray();
		expect(devPerf.optimizationsApplied[1]).toBe("pre-aggregation");

		// Validate pre-aggregation metrics
		expect(devPerf).toHaveKey("preAggregation");
		expect(devPerf.preAggregation).toBeStruct();
		expect(devPerf.preAggregation).toHaveKey("originalEntries");
		expect(devPerf.preAggregation).toHaveKey("aggregatedEntries");
		expect(devPerf.preAggregation).toHaveKey("duplicatesFound");
		expect(devPerf.preAggregation).toHaveKey("reductionPercent");
		expect(devPerf.preAggregation).toHaveKey("aggregationTime");

		// Both should process the same number of total lines
		expect(stablePerf.totalLines).toBe(devPerf.totalLines);

		// Log performance comparison for visibility
		systemOutput("Performance comparison:", true);
		systemOutput("  stable: " & stablePerf.processingTime & "ms (" & stablePerf.timePerLine & "ms per line)", true);
		systemOutput("  develop: " & devPerf.processingTime & "ms (" & devPerf.timePerLine & "ms per line)", true);
		if (structKeyExists(devPerf, "preAggregation")) {
			systemOutput("  Pre-aggregation: " & devPerf.preAggregation.originalEntries & " -> " & devPerf.preAggregation.aggregatedEntries & " entries (" & devPerf.preAggregation.reductionPercent & "% reduction)", true);
		}
	}



}