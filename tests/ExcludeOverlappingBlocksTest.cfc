component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe("Exclude Overlapping Blocks (processBlocks)", function() {
			it("should exclude large blocks that encompass smaller, more specific blocks (line-based)", function() {
				var optimized = excludeLargeBlocksLineBased(new lucee.extension.lcov.codeCoverageUtilsOptimized());
				var original = excludeLargeBlocksLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(optimized, original, "line-based");
				testExcludeLargeBlocksLineBased(optimized, "optimized");
				testExcludeLargeBlocksLineBased(original, "original");
			});

			it("should not exclude when no whole-file block exists (line-based)", function() {
				var optimized = noWholeFileBlockLineBased(new lucee.extension.lcov.codeCoverageUtilsOptimized());
				var original = noWholeFileBlockLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(optimized, original, "no-whole-file-block");
				testNoWholeFileBlockLineBased(optimized, "optimized");
				testNoWholeFileBlockLineBased(original, "original");
			});

			it("should handle single block (line-based)", function() {
				var optimized = singleBlockLineBased(new lucee.extension.lcov.codeCoverageUtilsOptimized());
				var original = singleBlockLineBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(optimized, original, "single-block");
				testSingleBlockLineBased(optimized, "optimized");
				testSingleBlockLineBased(original, "original");
			});

			it("should exclude large blocks that encompass smaller, more specific blocks (char-based)", function() {
				var optimized = excludeLargeBlocksCharBased(new lucee.extension.lcov.codeCoverageUtilsOptimized());
				var original = excludeLargeBlocksCharBased(new lucee.extension.lcov.codeCoverageUtils());
				compareResults(optimized, original, "char-based");
				testExcludeLargeBlocksCharBased(optimized, "optimized");
				testExcludeLargeBlocksCharBased(original, "original");
			});
		});
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
		return utils.processBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testExcludeLargeBlocksLineBased(result, label){
		systemOutput("[DEBUG] #label # result struct (testExcludeLargeBlocksLineBased): " 
			& serializeJSON(var=result, compact=false));
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
		return utils.processBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testNoWholeFileBlockLineBased(result, label){
		systemOutput("[DEBUG] #label# result struct (noWholeFileBlockLineBased): " 
			& serializeJSON(var=result, compact=false));
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
		return utils.processBlocks(blocksByFile, files, lineMappingsCache, true);
	}

	private function testSingleBlockLineBased(result, label){
		systemOutput("[DEBUG] #label # result struct (testSingleBlockLineBased): " 
			& serializeJSON(var=result, compact=false));
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
		return utils.processBlocks(blocksByFile, files, lineMappingsCache, false);		
	}

	
	private function testExcludeLargeBlocksCharBased(result, label){
		systemOutput("[DEBUG] #label # result struct (testExcludeLargeBlocksCharBased): " 
			& serializeJSON(var=result, compact=false));
		// Should only have coverage for the two small blocks (lines 2 and 6)
		assertCoveredLines(result, 1, ["2", "6"]);
	}

	// Compare two result structs for equality and log differences
	private void function compareResults(any optimized, any original, string label) {
		// loop over keys and compare
		var keys = structKeyArray(optimized);
		for (var key in keys) {
			expect(original).toHaveKey(key);
			expect(optimized[key]).toBe(original[key]);
		}
	}

	// Assert that the result[fileIdx] contains exactly the expected lines
	private void function assertCoveredLines(struct result, numeric fileIdx, array expectedLines) {
		var coveredLines = structKeyArray(result[fileIdx]);
		expect(arrayLen(coveredLines)).toBe(arrayLen(expectedLines));
		for (var line in expectedLines) {
			expect(coveredLines).toInclude(line);
		}
	}
}