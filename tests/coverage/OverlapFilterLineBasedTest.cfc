component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level="none" );
	}

	function run() {
		describe("OverlapFilter - Line-Based Tests", function() {
			it("should exclude large blocks that encompass smaller, more specific blocks", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterLine( logger=variables.logger );
				var result = excludeLargeBlocks( processor );
				testExcludeLargeBlocks( result );
			});

			it("should not exclude when no whole-file block exists", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterLine( logger=variables.logger );
				var result = noWholeFileBlock( processor );
				testNoWholeFileBlock( result );
			});

			it("should handle single block", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterLine( logger=variables.logger );
				var result = singleBlock( processor );
				testSingleBlock( result );
			});

			it("should not exclude all blocks (at least one block is always kept)", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterLine( logger=variables.logger );
				var result = allBlocksOverlap( processor );
				testAllBlocksOverlap( result );
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

	private function testExcludeLargeBlocks( result ) {
		// Should only have the smaller, more specific blocks
		assertCoveredLines( result, 1, ["2", "3", "5"] );
	}

	// Test: No whole-file block
	private struct function noWholeFileBlock( any processor ) {
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
		return processor.filter( blocksByFile, files, lineMappingsCache );
	}

	private function testNoWholeFileBlock( result ) {
		assertCoveredLines( result, 1, ["2", "3", "5"] );
	}

	// Test: Single block
	private struct function singleBlock( any processor ) {
		var blocks = [[1, 1, 10, 100]];
		var lineMapping = [1, 11];
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter( blocksByFile, files, lineMappingsCache );
	}

	private function testSingleBlock( result ) {
		assertCoveredLines( result, 1, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] );
	}

	// Test: All blocks overlap
	private struct function allBlocksOverlap( any processor ) {
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
		return processor.filter( blocksByFile, files, lineMappingsCache );
	}

	private function testAllBlocksOverlap( result ) {
		// At least one block should be kept (all lines covered)
		assertCoveredLines( result, 1, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] );
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