component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	// BDD-style parser comparison tests

	function beforeAll() {
		// Process all artifacts - no file filter
		variables.fileFilter = "";
	}

	function run() {
		describe("Parser Optimization Comparison", function() {
			

			describe("Test Data Setup", function() {
				
				it("should generate original parser test data", function() {
					variables.testDataGenerator = new GenerateTestData(testName="OptimizedParserOutputTest-original");
					variables.originalTestData = variables.testDataGenerator.generateExlFilesForArtifacts(
						adminPassword = request.SERVERADMINPASSWORD,
						fileFilter = variables.fileFilter
					);
					
					expect(directoryExists(variables.originalTestData.coverageDir)).toBeTrue();
					systemOutput("Original test data generated at: " & variables.originalTestData.coverageDir, true);
				});

				it("should generate optimized parser test data", function() {
					variables.testDataGenerator = new GenerateTestData(testName="OptimizedParserOutputTest-optimized");
					variables.optimizedTestData = variables.testDataGenerator.generateExlFilesForArtifacts(
						adminPassword = request.SERVERADMINPASSWORD,
						fileFilter = variables.fileFilter
					);
					
					expect(directoryExists(variables.optimizedTestData.coverageDir)).toBeTrue();
					systemOutput("Optimized test data generated at: " & variables.optimizedTestData.coverageDir, true);
				});
				
				it("should have matching EXL files in both directories", function() {
					var originalFiles = directoryList(variables.originalTestData.coverageDir, false, "path", "*.exl");
					var optimizedFiles = directoryList(variables.optimizedTestData.coverageDir, false, "path", "*.exl");
					
					expect(arrayLen(originalFiles)).toBeGT(0);
					expect(arrayLen(optimizedFiles)).toBeGT(0);
					expect(arrayLen(originalFiles)).toBe(arrayLen(optimizedFiles));
					
					systemOutput("Found " & arrayLen(originalFiles) & " EXL files in each directory", true);
				});
			});

			describe("Parser Execution", function() {
				
				it("should execute original parser on all files successfully", function() {
					var originalParser = new lucee.extension.lcov.ExecutionLogParser({"verbose": false});
					var testFiles = directoryList(variables.originalTestData.coverageDir, false, "path", "*.exl");
					
					systemOutput("Original parser processing " & arrayLen(testFiles) & " EXL files", true);
					
					for (var testExlFile in testFiles) {
						systemOutput("Processing: " & listLast(testExlFile, "/\"), true);
						var parserResult = originalParser.parseExlFile(testExlFile);
						
						expect(parserResult).toBeStruct();
						expect(parserResult).toHaveKey("metadata");
						expect(parserResult).toHaveKey("source");
						expect(parserResult).toHaveKey("coverage");
					}
					
					systemOutput("Original parser completed successfully on all files", true);
				});

				it("should execute optimized parser on all files successfully", function() {
					var optimizedParser = new lucee.extension.lcov.ExecutionLogParserOptimized({"verbose": false});
					var testFiles = directoryList(variables.optimizedTestData.coverageDir, false, "path", "*.exl");
					
					systemOutput("Optimized parser processing " & arrayLen(testFiles) & " EXL files", true);
					
					for (var testExlFile in testFiles) {
						systemOutput("Processing: " & listLast(testExlFile, "/\"), true);
						var parserResult = optimizedParser.parseExlFile(testExlFile);
						
						expect(parserResult).toBeStruct();
						expect(parserResult).toHaveKey("metadata");
						expect(parserResult).toHaveKey("source");
						expect(parserResult).toHaveKey("coverage");
					}
					
					systemOutput("Optimized parser completed successfully on all files", true);
				});
			});

			describe("JSON File Output Verification", function() {
				
				it("should create JSON files for both parsers", function() {
					var originalJsonFiles = directoryList(variables.originalTestData.coverageDir, false, "path", "*.json");
					var optimizedJsonFiles = directoryList(variables.optimizedTestData.coverageDir, false, "path", "*.json");
					
					systemOutput("Original JSON files: " & arrayLen(originalJsonFiles), true);
					systemOutput("Optimized JSON files: " & arrayLen(optimizedJsonFiles), true);
					
					expect(arrayLen(originalJsonFiles)).toBeGT(0);
					expect(arrayLen(optimizedJsonFiles)).toBeGT(0);
					expect(arrayLen(originalJsonFiles)).toBe(arrayLen(optimizedJsonFiles));
				});

				it("should process all JSON files and create script mappings", function() {
					var originalJsonFiles = directoryList(variables.originalTestData.coverageDir, false, "path", "*.json");
					var optimizedJsonFiles = directoryList(variables.optimizedTestData.coverageDir, false, "path", "*.json");
					
					// Process all original JSON files and build script-name mapping
					var originalScriptMapping = {};
					variables.originalParsedData = {};
					for (var jsonFile in originalJsonFiles) {
						var jsonData = deserializeJSON(fileRead(jsonFile), false);
						expect(jsonData).toBeStruct();
						
						var scriptName = jsonData.metadata["script-name"];
						var queryString = structKeyExists(jsonData.metadata, "query-string") ? jsonData.metadata["query-string"] : "";
						var scriptKey = scriptName & (len(queryString) > 0 ? "?" & queryString : "");
						var fileName = listLast(replace(jsonFile, ".json", ".exl"), "/\");
						
						if (!structKeyExists(originalScriptMapping, scriptKey)) {
							originalScriptMapping[scriptKey] = [];
						}
						arrayAppend(originalScriptMapping[scriptKey], fileName);
						variables.originalParsedData[fileName] = jsonData;
					}
					
					// Process all optimized JSON files and build script-name mapping  
					var optimizedScriptMapping = {};
					variables.optimizedParsedData = {};
					for (var jsonFile in optimizedJsonFiles) {
						var jsonData = deserializeJSON(fileRead(jsonFile), false);
						expect(jsonData).toBeStruct();
						
						var scriptName = jsonData.metadata["script-name"];
						var queryString = structKeyExists(jsonData.metadata, "query-string") ? jsonData.metadata["query-string"] : "";
						var scriptKey = scriptName & (len(queryString) > 0 ? "?" & queryString : "");
						var fileName = listLast(replace(jsonFile, ".json", ".exl"), "/\");
						
						if (!structKeyExists(optimizedScriptMapping, scriptKey)) {
							optimizedScriptMapping[scriptKey] = [];
						}
						arrayAppend(optimizedScriptMapping[scriptKey], fileName);
						variables.optimizedParsedData[fileName] = jsonData;
					}
					
					// Write parsed-index.json files
					fileWrite(variables.originalTestData.coverageDir & "/parsed-index.json", 
						serializeJSON(var=originalScriptMapping, compact=false));
					fileWrite(variables.optimizedTestData.coverageDir & "/parsed-index.json", 
						serializeJSON(var=optimizedScriptMapping, compact=false));
					
					variables.originalScriptMapping = originalScriptMapping;
					variables.optimizedScriptMapping = optimizedScriptMapping;
					
					systemOutput("Original scripts mapped: " & structCount(originalScriptMapping), true);
					systemOutput("Optimized scripts mapped: " & structCount(optimizedScriptMapping), true);
				});
			});

			describe("Output Comparison", function() {
				
				it("should validate all matching scripts between parsers", function() {
					var matchingScripts = [];
					var originalScripts = structKeyArray(variables.originalScriptMapping);
					var optimizedScripts = structKeyArray(variables.optimizedScriptMapping);
					
					// Find scripts that exist in both mappings
					for (var scriptKey in originalScripts) {
						if (structKeyExists(variables.optimizedScriptMapping, scriptKey)) {
							arrayAppend(matchingScripts, scriptKey);
						}
					}
					
					expect(arrayLen(matchingScripts)).toBeGT(0, "No matching scripts found between original and optimized parsers");
					systemOutput("Found " & arrayLen(matchingScripts) & " matching scripts to compare", true);
					
					var totalComparisons = 0;
					
					// Compare each matching script
					for (var scriptKey in matchingScripts) {
						var originalFiles = variables.originalScriptMapping[scriptKey];
						var optimizedFiles = variables.optimizedScriptMapping[scriptKey];
						
						// Compare first file from each script (should be same content)
						var originalFile = originalFiles[1];
						var optimizedFile = optimizedFiles[1];
						
						var originalData = variables.originalParsedData[originalFile];
						var optimizedData = variables.optimizedParsedData[optimizedFile];
						
						systemOutput("Comparing script: " & scriptKey & " (Original: " & originalFile & ", Optimized: " & optimizedFile & ")", true);
						
						// Run all comparison tests for this script pair
						try {
							compareHighLevelStructure(originalData, optimizedData);
						} catch (any e) {
							systemOutput("  ✗ High-level structure comparison failed for " & scriptName & ": " & e.message, true);
							rethrow;
						}
						
						try {
							compareMetadata(originalData.metadata, optimizedData.metadata);
						} catch (any e) {
							systemOutput("  ✗ Metadata comparison failed for " & scriptName & ": " & e.message, true);
							rethrow;
						}
						
						try {
							compareFileStructure(originalData.source.files, optimizedData.source.files);
						} catch (any e) {
							systemOutput("  ✗ File structure comparison failed for " & scriptName & ": " & e.message, true);
							systemOutput("    Original files count: " & structCount(originalData.source.files), true);
							systemOutput("    Optimized files count: " & structCount(optimizedData.source.files), true);
							rethrow;
						}
						
						try {
							compareCoverageStructure(originalData.coverage, optimizedData.coverage);
						} catch (any e) {
							systemOutput("  ✗ Coverage structure comparison failed for " & scriptName & ": " & e.message, true);
							rethrow;
						}
						
						try {
							compareParserPerformance(originalData, optimizedData);
						} catch (any e) {
							systemOutput("  ✗ Parser performance comparison failed for " & scriptName & ": " & e.message, true);
							rethrow;
						}
						
						totalComparisons++;
					}
					
					systemOutput("Successfully compared " & totalComparisons & " script pairs", true);
				});
			});
		});
	}

	// Helper functions for BDD tests
	
	private function compareHighLevelStructure(required struct originalData, required struct optimizedData) {
		systemOutput("Comparing high-level structure...", true);
		
		// Check main keys exist in both data structures
		var expectedKeys = ["metadata", "source", "coverage", "fileCoverage", "exeLog", "parserPerformance"];
		for (var key in expectedKeys) {
			expect(originalData).toHaveKey(key);
			expect(optimizedData).toHaveKey(key);
		}
		
		// Both should have files structure
		expect(originalData.source).toHaveKey("files");
		expect(optimizedData.source).toHaveKey("files");
		
		// File counts should match
		expect(structCount(originalData.source.files)).toBe(structCount(optimizedData.source.files));
		
		// Coverage array lengths should match
		expect(arrayLen(originalData.coverage)).toBe(arrayLen(optimizedData.coverage));
		expect(arrayLen(originalData.fileCoverage)).toBe(arrayLen(optimizedData.fileCoverage));
	}
	
	private function compareMetadata(required struct originalMeta, required struct optimizedMeta) {
		systemOutput("Comparing metadata (excluding time-sensitive fields)...", true);
		
		// Compare time-insensitive fields that should be identical
		var compareFields = ["script-name", "context-path", "server-name", "server-port", "protocol", "query-string", "path-info", "unit"];
		for (var field in compareFields) {
			if (structKeyExists(originalMeta, field) && structKeyExists(optimizedMeta, field)) {
				expect(originalMeta[field]).toBe(optimizedMeta[field]);
			}
		}
		
		// Verify time-sensitive fields exist (values will differ between runs)
		expect(originalMeta).toHaveKey("execution-time");
		expect(optimizedMeta).toHaveKey("execution-time");
	}
	
	private function compareFileStructure(required struct originalFiles, required struct optimizedFiles) {
		systemOutput("Comparing file structure...", true);
		
		// Compare each file's structure
		for (var fileIdx in originalFiles) {
			// Optimized parser should have same file indexes
			expect(optimizedFiles).toHaveKey(fileIdx);
			
			var origFile = originalFiles[fileIdx];
			var optFile = optimizedFiles[fileIdx];
			
			// File paths should be identical
			expect(origFile.path).toBe(optFile.path);
			
			// Line counts should match
			expect(origFile.linesFound).toBe(optFile.linesFound);
			expect(origFile.lineCount).toBe(optFile.lineCount);
			
			// Executable lines structure should be identical
			expect(structCount(origFile.executableLines)).toBe(structCount(optFile.executableLines));
			
			// Source code line arrays should match
			expect(arrayLen(origFile.lines)).toBe(arrayLen(optFile.lines));
		}
	}
	
	private function compareCoverageStructure(required struct originalCoverage, required struct optimizedCoverage) {
		systemOutput("Comparing coverage structure...", true);
		
		// Coverage should be struct with file indexes as keys
		expect(originalCoverage).toBeStruct();
		expect(optimizedCoverage).toBeStruct();
		
		// File count should match
		expect(structCount(originalCoverage)).toBe(structCount(optimizedCoverage));
		
		// Compare each file's coverage data
		for (var fileIdx in originalCoverage) {
			// Both parsers should have coverage for the same files
			expect(optimizedCoverage).toHaveKey(fileIdx);
			
			var origFileCoverage = originalCoverage[fileIdx];
			var optFileCoverage = optimizedCoverage[fileIdx];
			
			expect(origFileCoverage).toBeStruct();
			expect(optFileCoverage).toBeStruct();
			
			// Line count should match for each file
			expect(structCount(origFileCoverage)).toBe(structCount(optFileCoverage));
			
			// Sample a few lines to verify structure
			var lineNumbers = structKeyArray(origFileCoverage);
			var sampleSize = min(5, arrayLen(lineNumbers));
			
			for (var i = 1; i <= sampleSize; i++) {
				var lineNum = lineNumbers[i];
				// Both should have coverage data for the same lines
				expect(optFileCoverage).toHaveKey(lineNum);
				
				var origLineData = origFileCoverage[lineNum];
				var optLineData = optFileCoverage[lineNum];
				
				// Both should be arrays with 2 elements: [hitCount, executionTime]
				expect(origLineData).toBeArray();
				expect(optLineData).toBeArray();
				expect(arrayLen(origLineData)).toBe(2);
				expect(arrayLen(optLineData)).toBe(2);
				
				// Hit counts should match (Lucee will handle string/number conversion)
				expect(origLineData[1]).toBe(optLineData[1]);
				
				// Execution times should both be numeric (allow flexible comparison)
				expect(isNumeric(origLineData[2])).toBeTrue();
				expect(isNumeric(optLineData[2])).toBeTrue();
			}
		}
	}

	private function compareParserPerformance(required struct originalCoverage, required struct optimizedCoverage) {
		systemOutput("Comparing parser performance metrics...", true);
		
		// Both should have parserPerformance structure
		expect(originalCoverage).toHaveKey("parserPerformance");
		expect(optimizedCoverage).toHaveKey("parserPerformance");
		
		var origPerf = originalCoverage.parserPerformance;
		var optPerf = optimizedCoverage.parserPerformance;
		
		// Validate original parser performance structure
		expect(origPerf).toBeStruct();
		expect(origPerf).toHaveKey("parserType");
		expect(origPerf.parserType).toBe("original");
		expect(origPerf).toHaveKey("processingTime");
		expect(origPerf).toHaveKey("timePerLine");
		expect(origPerf).toHaveKey("totalLines");
		expect(origPerf).toHaveKey("optimizationsApplied");
		expect(origPerf.optimizationsApplied).toBeArray();
		expect(arrayLen(origPerf.optimizationsApplied)).toBe(0); // Original has no optimizations
		
		// Validate optimized parser performance structure
		expect(optPerf).toBeStruct();
		expect(optPerf).toHaveKey("parserType");
		expect(optPerf.parserType).toBe("optimized");
		expect(optPerf).toHaveKey("processingTime");
		expect(optPerf).toHaveKey("timePerLine");
		expect(optPerf).toHaveKey("totalLines");
		expect(optPerf).toHaveKey("optimizationsApplied");
		expect(optPerf.optimizationsApplied).toBeArray();
		expect(arrayLen(optPerf.optimizationsApplied)).toBeGT(0); // Optimized has optimizations
		expect(optPerf.optimizationsApplied[1]).toBe("pre-aggregation");
		
		// Validate pre-aggregation metrics
		expect(optPerf).toHaveKey("preAggregation");
		expect(optPerf.preAggregation).toBeStruct();
		expect(optPerf.preAggregation).toHaveKey("originalEntries");
		expect(optPerf.preAggregation).toHaveKey("aggregatedEntries");
		expect(optPerf.preAggregation).toHaveKey("duplicatesFound");
		expect(optPerf.preAggregation).toHaveKey("reductionPercent");
		expect(optPerf.preAggregation).toHaveKey("aggregationTime");
		
		// Both should process the same number of total lines
		expect(origPerf.totalLines).toBe(optPerf.totalLines);
		
		// Log performance comparison for visibility
		systemOutput("Performance comparison:", true);
		systemOutput("  Original: " & origPerf.processingTime & "ms (" & origPerf.timePerLine & "ms per line)", true);
		systemOutput("  Optimized: " & optPerf.processingTime & "ms (" & optPerf.timePerLine & "ms per line)", true);
		if (structKeyExists(optPerf, "preAggregation")) {
			systemOutput("  Pre-aggregation: " & optPerf.preAggregation.originalEntries & " -> " & optPerf.preAggregation.aggregatedEntries & " entries (" & optPerf.preAggregation.reductionPercent & "% reduction)", true);
		}
	}



}