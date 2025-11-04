component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.testDataGenerator = new GenerateTestData(testName="OverlapDataLossTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: variables.adminPassword,
			fileFilter: "overlap-data-loss/test-nested-execution.cfm"
		);
	}

	function testOverlapFilterDataLoss() {
		// Parse the execution log to get raw blocks BEFORE filtering
		var options = {
			logLevel: "INFO",
			separateFiles: true,
			allowList: [],
			blocklist: []
		};

		var parser = new lucee.extension.lcov.ExecutionLogParser(options=options);
		var exlFiles = directoryList(variables.testData.coverageDir, false, "array", "*.exl");

		expect(exlFiles).toHaveLength(1, "Should have generated one .exl file");

		var parseResult = parser.parseExlFile(
			exlPath=exlFiles[1],
			allowList=[],
			blocklist=[],
			writeJsonCache=false,
			includeCallTree=false,
			includeSourceCode=false
		);

		// Get files from result object
		var files = parseResult.getFiles();
		var validFileIds = {};
		cfloop( collection=files, key="local.fileIdx" ) {
			validFileIds[fileIdx] = true;
		}

		// Get the raw aggregated blocks (BEFORE overlap filtering)
		var logger = new lucee.extension.lcov.Logger(level="INFO");
		var aggregator = new lucee.extension.lcov.coverage.CoverageAggregator(logger=logger);
		var aggregationResult = aggregator.aggregate(exlFiles[1], validFileIds);

		var beforeFilterCount = structCount(aggregationResult.aggregated);
		var beforeFilterTime = 0;
		var beforeFilterHits = 0;

		// Calculate total time and hits BEFORE filtering
		cfloop( collection=aggregationResult.aggregated, key="local.key" ) {
			var block = aggregationResult.aggregated[key];
			beforeFilterTime += block[5]; // totalTime
			beforeFilterHits += block[4]; // count
		}

		systemOutput("=== BEFORE OVERLAP FILTERING ===", true);
		systemOutput("Total blocks: " & beforeFilterCount, true);
		systemOutput("Total execution time: " & numberFormat(beforeFilterTime / 1000000) & "ms", true);
		systemOutput("Total hit counts: " & numberFormat(beforeFilterHits), true);

		// Now apply overlap filtering
		var overlapFilter = new lucee.extension.lcov.coverage.OverlapFilterPosition(options=options);
		var filtered = overlapFilter.filter(
			aggregatedOrBlocksByFile=aggregationResult.aggregated,
			files=files,
			lineMappingsCache={}
		);

		var afterFilterCount = structCount(filtered);
		var afterFilterTime = 0;
		var afterFilterHits = 0;

		// Calculate total time and hits AFTER filtering
		cfloop( collection=filtered, key="local.key" ) {
			var block = filtered[key];
			afterFilterTime += block[5]; // totalTime
			afterFilterHits += block[4]; // count
		}

		systemOutput("", true);
		systemOutput("=== AFTER OVERLAP FILTERING ===", true);
		systemOutput("Total blocks: " & afterFilterCount, true);
		systemOutput("Total execution time: " & numberFormat(afterFilterTime / 1000000) & "ms", true);
		systemOutput("Total hit counts: " & numberFormat(afterFilterHits), true);

		systemOutput("", true);
		systemOutput("=== DATA LOSS ===", true);
		var blocksRemoved = beforeFilterCount - afterFilterCount;
		var timeLost = beforeFilterTime - afterFilterTime;
		var hitsLost = beforeFilterHits - afterFilterHits;
		var percentBlocksLost = (blocksRemoved / beforeFilterCount) * 100;
		var percentTimeLost = (timeLost / beforeFilterTime) * 100;
		var percentHitsLost = (hitsLost / beforeFilterHits) * 100;

		systemOutput("Blocks removed: " & blocksRemoved & " (" & numberFormat(percentBlocksLost, "0.00") & "%)", true);
		systemOutput("Time lost: " & numberFormat(timeLost / 1000000) & "ms (" & numberFormat(percentTimeLost, "0.00") & "%)", true);
		systemOutput("Hits lost: " & numberFormat(hitsLost) & " (" & numberFormat(percentHitsLost, "0.00") & "%)", true);

		// Find specific examples of nested blocks that are MARKED as overlapping (Phase 2)
		systemOutput("", true);
		systemOutput("=== OVERLAPPING BLOCKS ANALYSIS (Phase 2: NO DATA LOSS!) ===", true);
		var overlappingBlocks = [];
		cfloop( collection=filtered, key="local.key" ) {
			var block = filtered[key];
			// Check if block is marked as overlapping (6th element = true)
			if (arrayLen(block) >= 6 && block[6]) {
				arrayAppend(overlappingBlocks, {
					key: key,
					fileIdx: block[1],
					startPos: block[2],
					endPos: block[3],
					span: block[3] - block[2],
					count: block[4],
					totalTime: block[5],
					isOverlapping: block[6]
				});
			}
		}

		// Sort by totalTime descending to see biggest overlaps
		arraySort(overlappingBlocks, function(a, b) {
			return b.totalTime - a.totalTime;
		});

		systemOutput("Top 10 overlapping blocks by execution time:", true);
		if (arrayLen(overlappingBlocks) > 0) {
			var topOverlapping = arraySlice(overlappingBlocks, 1, min(10, arrayLen(overlappingBlocks)));
			cfloop( array=topOverlapping, index="local.i", item="local.ob" ) {
				var filePath = files[toString(ob.fileIdx)].path ?: "unknown";
				systemOutput("  #i#. File: " & filePath, true);
				systemOutput("     Position: " & ob.startPos & "-" & ob.endPos & " (span: " & ob.span & ")", true);
				systemOutput("     Hits: " & ob.count & ", Time: " & numberFormat(ob.totalTime / 1000000) & "ms [MARKED AS OVERLAPPING]", true);
			}
		} else {
			systemOutput("  No overlapping blocks found", true);
		}

		// Assertions (Phase 2: NO DATA LOSS!)
		expect(blocksRemoved).toBe(0, "Phase 2: Should NOT remove any blocks (no data loss!)");
		expect(timeLost).toBe(0, "Phase 2: Should NOT lose any execution time data");
		expect(hitsLost).toBe(0, "Phase 2: Should NOT lose any hit count data");

		// Document the findings
		systemOutput("", true);
		systemOutput("=== CONCLUSION (Phase 2) ===", true);
		systemOutput("Phase 2 marks overlapping blocks instead of removing them.", true);
		systemOutput("Blocks removed: " & blocksRemoved & " (0% data loss!)", true);
		systemOutput("Time preserved: 100% - NO execution time data lost", true);
		systemOutput("Hits preserved: 100% - NO hit count data lost", true);
		systemOutput("Overlapping blocks marked: " & arrayLen(overlappingBlocks), true);
		systemOutput("This demonstrates that Phase 2 successfully preserves ALL data while", true);
		systemOutput("still marking overlaps for future processing decisions.", true);
	}

}
