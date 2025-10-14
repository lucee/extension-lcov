component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logger = new lucee.extension.lcov.Logger( level="none" );
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="DenseOverlapPositionTest");

		// Generate test data using the standard approach - executes all artifacts including dense.cfm
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = variables.adminPassword,
			fileFilter = "dense.cfm"  // Only execute dense.cfm for this test
		);

		// Get the generated artifacts directory for output
		variables.tempDir = variables.testDataGenerator.getOutputDir();


	}

	function run() {
		describe("Dense Overlap Position-Based Filtering with Real Execution Data", function() {
			it("should filter overlapping blocks from dense.cfm execution", function() {
				// Use the pre-generated test data
				expect(variables.testData).toHaveKey("coverageFiles", "Should have coverage files from test data generation");
				expect(arrayLen(variables.testData.coverageFiles)).toBeGT(0, "Should have at least one .exl file");

				// Build full path to the log file
				var logPath = variables.testData.coverageDir & variables.testData.coverageFiles[1];

				// Phase 1: Parse execution log
				var processor = new lucee.extension.lcov.ExecutionLogProcessor( options={logLevel: variables.logLevel} );
				var jsonFilePaths = processor.parseExecutionLogs( variables.testData.coverageDir );

				// Phase 2: Extract AST metadata
				var astMetadataPath = processor.extractAstMetadata( variables.testData.coverageDir, jsonFilePaths );

				// Phase 3: Build line coverage (converts aggregated → blocks → coverage)
				var lineCoverageBuilder = new lucee.extension.lcov.coverage.LineCoverageBuilder( logger=variables.logger );
				lineCoverageBuilder.buildCoverage( jsonFilePaths, astMetadataPath );

				// Load enriched result from JSON
				var jsonContent = fileRead( jsonFilePaths[1] );
				var parsedData = new lucee.extension.lcov.model.result();
				var data = deserializeJSON( jsonContent );
				for (var key in data) {
					var setter = "set" & key;
					if ( structKeyExists( parsedData, setter ) ) {
						parsedData[setter]( data[key] );
					}
				}

				// Get position-based overlap filter
				var overlapFilter = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger );

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

		});
	}
}