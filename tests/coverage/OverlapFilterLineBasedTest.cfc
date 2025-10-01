component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
	}

	function run() {
		describe("OverlapFilter - Line-Based Tests", function() {
			it("should exclude large blocks that encompass smaller, more specific blocks", function() {
				var develop = excludeLargeBlocks(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=true));
				var stable = excludeLargeBlocks(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=false));
				compareResults(develop, stable, "exclude-large-blocks");
				testExcludeLargeBlocks(develop, "develop");
				testExcludeLargeBlocks(stable, "stable");
			});

			it("should not exclude when no whole-file block exists", function() {
				var develop = noWholeFileBlock(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=true));
				var stable = noWholeFileBlock(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=false));
				compareResults(develop, stable, "no-whole-file-block");
				testNoWholeFileBlock(develop, "develop");
				testNoWholeFileBlock(stable, "stable");
			});

			it("should handle single block", function() {
				var develop = singleBlock(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=true));
				var stable = singleBlock(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=false));
				compareResults(develop, stable, "single-block");
				testSingleBlock(develop, "develop");
				testSingleBlock(stable, "stable");
			});

			it("should not exclude all blocks (at least one block is always kept)", function() {
				var develop = allBlocksOverlap(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=true));
				var stable = allBlocksOverlap(variables.factory.getComponent(name="OverlapFilterLine", overrideUseDevelop=false));
				compareResults(develop, stable, "all-blocks-overlap");
				testAllBlocksOverlap(develop, "develop");
				testAllBlocksOverlap(stable, "stable");
			});
		});
	}

	// Test: Large block encompassing smaller blocks
	private struct function excludeLargeBlocks(any processor) {
		// Simulate blocks: [fileIdx, startLine, endLine, execTime]
		var blocks = [
			[1, 1, 10, 100],   // Large block (whole file)
			[1, 2, 3, 50],     // Small block inside
			[1, 5, 5, 20]      // Another small block inside
		];
		var lineMapping = [1, 11]; // Dummy mapping (not used for line-based)
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		// All lines 1-10 are executable for this test
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testExcludeLargeBlocks(result, label) {
		// Should only have the smaller, more specific blocks
		assertCoveredLines(result, 1, ["2", "3", "5"]);
	}

	// Test: No whole-file block
	private struct function noWholeFileBlock(any processor) {
		var blocks = [
			[1, 2, 3, 50],
			[1, 5, 5, 20]
		];
		var lineMapping = [1, 11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testNoWholeFileBlock(result, label) {
		assertCoveredLines(result, 1, ["2", "3", "5"]);
	}

	// Test: Single block
	private struct function singleBlock(any processor) {
		var blocks = [[1, 1, 10, 100]];
		var lineMapping = [1, 11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testSingleBlock(result, label) {
		assertCoveredLines(result, 1, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]);
	}

	// Test: All blocks overlap
	private struct function allBlocksOverlap(any processor) {
		// All blocks overlap, but at least one should be kept
		var blocks = [
			[1, 1, 10, 100],   // Large block (whole file)
			[1, 1, 10, 90],    // Identical block, lower execTime
			[1, 1, 10, 80]     // Identical block, even lower execTime
		];
		var lineMapping = [1, 11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testAllBlocksOverlap(result, label) {
		// At least one block should be kept (all lines covered)
		assertCoveredLines(result, 1, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]);
	}

	// Helper: Compare two result structs for equality
	private void function compareResults(any develop, any stable, string label) {
		var keys = structKeyArray(develop);
		for (var key in keys) {
			expect(stable).toHaveKey(key, "Key missing in stable: #key# for test: #label#");
			expect(develop[key]).toBe(stable[key], "Mismatch for key #key# in test: #label#");
		}
	}

	// Helper: Assert that the result[fileIdx] contains exactly the expected lines
	private void function assertCoveredLines(struct result, numeric fileIdx, array expectedLines) {
		expect(result).toHaveKey(fileIdx, "FileIdx #fileIdx# not found in result");
		var coveredLines = structKeyArray(result[fileIdx]);
		expect(coveredLines).toHaveLength(arrayLen(expectedLines),
			"Expected #arrayLen(expectedLines)# lines but got #arrayLen(coveredLines)#. Lines: #arrayToList(coveredLines)#");
		for (var line in expectedLines) {
			expect(coveredLines).toInclude(line, "Line #line# not found in covered lines: #arrayToList(coveredLines)#");
		}
	}
}