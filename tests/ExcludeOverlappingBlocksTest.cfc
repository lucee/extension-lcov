component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe("Exclude Overlapping Blocks (excludeOverlappingBlocks)", function() {
			it("should exclude large blocks that encompass smaller, more specific blocks (line-based)", function() {
				var develop = excludeLargeBlocksLineBased(new lucee.extension.lcov.develop.codeCoverageUtils());
				var stable = excludeLargeBlocksLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(develop, stable, "line-based");
				testExcludeLargeBlocksLineBased(develop, "develop");
				testExcludeLargeBlocksLineBased(stable, "stable");
			});

			it("should not exclude when no whole-file block exists (line-based)", function() {
				var develop = noWholeFileBlockLineBased(new lucee.extension.lcov.develop.codeCoverageUtils());
				var stable = noWholeFileBlockLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(develop, stable, "no-whole-file-block");
				testNoWholeFileBlockLineBased(develop, "develop");
				testNoWholeFileBlockLineBased(stable, "stable");
			});

			it("should handle single block (line-based)", function() {
				var develop = singleBlockLineBased(new lucee.extension.lcov.develop.codeCoverageUtils());
				var stable = singleBlockLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(develop, stable, "single-block");
				testSingleBlockLineBased(develop, "develop");
				testSingleBlockLineBased(stable, "stable");
			});

			it("should exclude large blocks that encompass smaller, more specific blocks (char-based)", function() {
				var develop = excludeLargeBlocksCharBased(new lucee.extension.lcov.develop.codeCoverageUtils());
				var stable = excludeLargeBlocksCharBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(develop, stable, "char-based");
				testExcludeLargeBlocksCharBased(develop, "develop");
				testExcludeLargeBlocksCharBased(stable, "stable");
			});
			it("should not exclude all blocks (at least one block is always kept)", function() {
				var develop = allBlocksOverlapLineBased(new lucee.extension.lcov.develop.codeCoverageUtils());
				var stable = allBlocksOverlapLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(develop, stable, "all-blocks-overlap");
				testAllBlocksOverlapLineBased(develop, "develop");
				testAllBlocksOverlapLineBased(stable, "stable");
			});

			it("should match stable and develop results for real-world exception.cfm blocks (char-based)",
					function() {
				var develop = exceptionCfmRealWorldBlocks(new lucee.extension.lcov.develop.codeCoverageUtils());
				var stable = exceptionCfmRealWorldBlocks(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(develop, stable, "exception-cfm-real-world");
				// Optionally, print stabler debugging:
				// systemOutput("develop: " & serializeJSON(develop, false));
				// systemOutput("stable: " & serializeJSON(stablel, false));
			});
		});
	}


	private struct function exceptionCfmRealWorldBlocks(any utils) {
		// Real-world char-based blocks from exception.cfm .exl file
		var blocks = [
			[1,54,85,4],
			[1,91,164,111],
			[1,225,249,1],
			[1,254,305,40],
			[1,470,491,0],
			[1,318,505,24],
			[1,505,529,0],
			[1,705,735,0],
			[1,220,768,78],
			[1,791,888,8],
			[1,888,915,0],
			[1,781,1055,10],
			[1,772,1211,11],
			[1,1211,1243,0],
			[1,0,1257,210]
		];
		// Build a fake line mapping: line 1 starts at 1, line 2 at 1001, ... (simulate 20 lines)
		var lineMapping = [];
		for (var i = 1; i <= 20; i++) lineMapping[i] = (i-1)*100+1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		// All lines 1-20 are executable for this test
		var execLines = {};
		for (var l = 1; l <= 20; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "exception.cfm", "executableLines": execLines } };
		var lineMappingsCache = { ("exception.cfm"): lineMapping };
		return utils.excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, false);
	}

	private struct function excludeLargeBlocksLineBased(any utils) {
		// Simulate blocks: [fileIdx, startLine, endLine, execTime]
		var blocks = [
			[1, 1, 10, 100],   // Large block (whole file)
			[1, 2, 3, 50],     // Small block inside
			[1, 5, 5, 20]      // Another small block inside
		];
		var lineMapping = [1,11]; // Dummy mapping (not used for line-based)
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#" : blocks };
		// All lines 1-10 are executable for this test
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return utils.excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testExcludeLargeBlocksLineBased(result, label){
		//systemOutput("[DEBUG] #label # result struct (testExcludeLargeBlocksLineBased): " & serializeJSON(var=result, compact=false));
		assertCoveredLines(result, 1, ["2", "3", "5"]);
	}

	private struct function noWholeFileBlockLineBased(any utils) {
		var blocks = [
			[1, 2, 3, 50],
			[1, 5, 5, 20]
		];
		var lineMapping = [1,11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		// All lines 1-10 are executable for this test
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { ("test.cfm"): lineMapping };
		return utils.excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testNoWholeFileBlockLineBased(result, label){
		//systemOutput("[DEBUG] #label# result struct (noWholeFileBlockLineBased): " 	& serializeJSON(var=result, compact=false));
		assertCoveredLines(result, 1, ["2", "3", "5"]);
	}

	private struct function singleBlockLineBased(any utils) {
		var blocks = [ [1, 1, 10, 100] ];
		var lineMapping = [1,11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		// All lines 1-10 are executable for this test
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { ("test.cfm"): lineMapping };
		return utils.excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testSingleBlockLineBased(result, label){
		//systemOutput("[DEBUG] #label # result struct (testSingleBlockLineBased): " & serializeJSON(var=result, compact=false));
		assertCoveredLines(result, 1, ["1","2","3","4","5","6","7","8","9","10"]);
	}

	private struct function excludeLargeBlocksCharBased(any utils) {
		// Simulate blocks: [fileIdx, startChar, endChar, execTime]
		// We'll use getLineFromCharacterPosition to map chars to lines
		// For this test, 1-1000 = line 1, 1001-2000 = line 2, etc.
		var blocks = [
			[1, 1, 10000, 100],    // Large block (whole file)
			[1, 1001, 2000, 50],   // Small block inside (line 2)
			[1, 5001, 6000, 20]    // Another small block inside (line 6)
		];
		// Build a fake line mapping: line 1 starts at 1, line 2 at 1001, ...
		var lineMapping = [];
		for (var i = 1; i <= 10; i++) lineMapping[i] = (i-1)*1000+1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		// All lines 1-10 are executable for this test
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { ("test.cfm"): lineMapping };
		return utils.excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, false);
	}


	private function testExcludeLargeBlocksCharBased(result, label){
		// systemOutput("[DEBUG] #label # result struct (testExcludeLargeBlocksCharBased): " & serializeJSON(var=result, compact=false));
		// Should only have coverage for the two small blocks (lines 2 and 6)
		assertCoveredLines(result, 1, ["2", "6"]);
	}

	private struct function allBlocksOverlapLineBased(any utils) {
		// All blocks overlap, but at least one should be kept
		var blocks = [
			[1, 1, 10, 100],   // Large block (whole file)
			[1, 1, 10, 90],    // Identical block, lower execTime
			[1, 1, 10, 80]     // Identical block, even lower execTime
		];
		var lineMapping = [1,11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { ("test.cfm"): lineMapping };
		return utils.excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testAllBlocksOverlapLineBased(result, label){
		// At least one block should be kept (all lines covered)
		assertCoveredLines(result, 1, ["1","2","3","4","5","6","7","8","9","10"]);
	}

	// Compare two result structs for equality and log differences
	private void function compareResults(any develop, any stable, string label) {
		// loop over keys and stable
		/*
		systemOutput("", true);
		systemOutput("[DEBUG] Comparing results for #label#", true);
		systemOutput("develop: " & serializeJSON(develop), true);
		systemOutput("stable:  " & serializeJSON(stableal), true);
		*/
		var keys = structKeyArray(develop);
		for (var key in keys) {
			expect(stable).toHaveKey(key);
			expect(develop[key]).toBe(stable[key]);
		}
	}

	// Assert that the result[fileIdx] contains exactly the expected lines
	private void function assertCoveredLines(struct result, numeric fileIdx, array expectedLines) {
		var coveredLines = structKeyArray(result[fileIdx]);
		expect(coveredLines).toHaveLength(arrayLen(expectedLines));
		for (var line in expectedLines) {
			expect(coveredLines).toInclude(line);
		}
	}
}