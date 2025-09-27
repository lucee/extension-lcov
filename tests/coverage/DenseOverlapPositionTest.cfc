component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.adminPassword = request.SERVERADMINPASSWORD;

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="DenseOverlapPositionTest");

		// Generate test data using the standard approach - executes all artifacts including dense.cfm
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = variables.adminPassword,
			fileFilter = "dense.cfm"  // Only execute dense.cfm for this test
		);

		// Get the generated artifacts directory for output
		variables.tempDir = variables.testDataGenerator.getGeneratedArtifactsDir();

		// Leave test artifacts for inspection - no cleanup in afterAll
	}

	function run() {
		describe("Dense Overlap Position-Based Filtering with Real Execution Data", function() {
			it("should filter overlapping blocks from dense.cfm execution", function() {
				// Use the pre-generated test data
				expect(variables.testData).toHaveKey("coverageFiles", "Should have coverage files from test data generation");
				expect(arrayLen(variables.testData.coverageFiles)).toBeGT(0, "Should have at least one .exl file");

				// Build full path to the log file
				var logPath = variables.testData.coverageDir & variables.testData.coverageFiles[1];

				// Parse the execution log
				var parser = variables.factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false);
				var parsedData = parser.parseExlFile(logPath);

				// Get position-based overlap filter
				var overlapFilter = variables.factory.getComponent(name="OverlapFilterPosition", overrideUseDevelop=false);

				// Extract blocks for dense.cfm
				var denseFileIdx = "";
				var files = parsedData.getFiles();
				for (var fileIdx in files) {
					var fileData = parsedData.getFileItem(fileIdx);
					if (fileData.path contains "dense.cfm") {
						denseFileIdx = fileIdx;
						break;
					}
				}

				expect(denseFileIdx).notToBe("", "Should find dense.cfm in parsed files");

				// Get blocks by file from the coverage data
				var blocksByFile = {};
				var coverage = parsedData.getCoverageItem(denseFileIdx);

				// Build blocks array from coverage data
				var blocks = [];
				for (var line in coverage) {
					var lineData = coverage[line];
					// Create a position-based block (approximating positions)
					var startPos = (line - 1) * 100; // Rough estimate
					var endPos = line * 100;
					blocks.append([denseFileIdx, startPos, endPos, lineData[1], lineData[2]]);
				}

				expect(arrayLen(blocks)).toBeGT(0, "Should have blocks for dense.cfm");

				blocksByFile[denseFileIdx] = blocks;
				var originalCount = arrayLen(blocks);

				// Apply overlap filtering
				var files = { "#denseFileIdx#": parsedData.getFileItem(denseFileIdx) };
				var lineMappingsCache = {};

				var filteredResult = overlapFilter.filter(blocksByFile, files, lineMappingsCache);
				var filteredBlocks = filteredResult[denseFileIdx];

				expect(arrayLen(filteredBlocks)).toBeLTE(originalCount, "Filtered blocks should not exceed original count");
				expect(arrayLen(filteredBlocks)).toBeGT(0, "Should have at least some blocks after filtering");

				// Check that no blocks overlap after filtering
				var hasOverlaps = false;
				var overlapDetails = [];
				for (var i = 1; i <= arrayLen(filteredBlocks); i++) {
					for (var j = i + 1; j <= arrayLen(filteredBlocks); j++) {
						var block1 = filteredBlocks[i];
						var block2 = filteredBlocks[j];

						// Check if blocks overlap (one contains the other)
						if (block1[2] <= block2[2] && block1[3] >= block2[3]) {
							hasOverlaps = true;
							overlapDetails.append("Block [#block1[2]#-#block1[3]#] contains [#block2[2]#-#block2[3]#]");
						} else if (block2[2] <= block1[2] && block2[3] >= block1[3]) {
							hasOverlaps = true;
							overlapDetails.append("Block [#block2[2]#-#block2[3]#] contains [#block1[2]#-#block1[3]#]");
						}
					}
				}

				expect(hasOverlaps).toBeFalse("No blocks should overlap after filtering. Found: #arrayToList(overlapDetails, '; ')#");

				// Log summary for inspection
				var summary = {
					originalBlocks: originalCount,
					filteredBlocks: arrayLen(filteredBlocks),
					reductionPercent: round((originalCount - arrayLen(filteredBlocks)) / originalCount * 100)
				};

				// Write summary to artifacts directory
				fileWrite(
					variables.tempDir & "/dense-overlap-summary.json",
					serializeJSON(summary)
				);

				// Don't cleanup - we're using shared test data
			});

			it("should handle dense code with develop version consistently", function() {
				// Use the same pre-generated test data
				var logPath = variables.testData.coverageDir & variables.testData.coverageFiles[1];

				// Parse once
				var parser = variables.factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false);
				var parsedData = parser.parseExlFile(logPath);

				// Get both versions of the filter
				var stableFilter = variables.factory.getComponent(name="OverlapFilterPosition", overrideUseDevelop=false);
				var developFilter = variables.factory.getComponent(name="OverlapFilterPosition", overrideUseDevelop=true);

				// Extract dense.cfm data
				var denseFileIdx = "";
				var files = parsedData.getFiles();
				for (var fileIdx in files) {
					var fileData = parsedData.getFileItem(fileIdx);
					if (fileData.path contains "dense.cfm") {
						denseFileIdx = fileIdx;
						break;
					}
				}

				// Build blocks from coverage data
				var blocks = [];
				var coverage = parsedData.getCoverageItem(denseFileIdx);
				for (var line in coverage) {
					var lineData = coverage[line];
					var startPos = (line - 1) * 100;
					var endPos = line * 100;
					blocks.append([denseFileIdx, startPos, endPos, lineData[1], lineData[2]]);
				}

				var blocksByFile = { "#denseFileIdx#": blocks };
				var files = { "#denseFileIdx#": parsedData.getFileItem(denseFileIdx) };
				var lineMappingsCache = {};

				// Filter with both versions
				var stableResult = stableFilter.filter(blocksByFile, files, lineMappingsCache);
				var developResult = developFilter.filter(blocksByFile, files, lineMappingsCache);

				// Compare results
				expect(structCount(developResult)).toBe(structCount(stableResult), "Should have same number of files");
				expect(arrayLen(developResult[denseFileIdx])).toBe(arrayLen(stableResult[denseFileIdx]),
					"Should have same number of filtered blocks");

				// Don't cleanup - we're using shared test data
			});
		});
	}
}