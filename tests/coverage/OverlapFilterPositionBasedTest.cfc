component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level="none" );
	}

	function run() {
		describe("OverlapFilter - Position-Based Tests", function() {
			it("should work with aggregated format and preserve execution counts", function() {
				testAggregatedFormat();
			});

			it("should exclude large blocks that encompass smaller, more specific blocks", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = excludeLargeBlocks( processor );
				// removed duplicate stable call
				
				testExcludeLargeBlocks( result );
				
			});

			it("should handle real-world exception.cfm blocks", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = exceptionCfmRealWorldBlocks( processor );
				// removed duplicate stable call
				
			});

			it("should handle loops.cfm pattern with overlapping for-loop block", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = loopsCfmPattern( processor );
				// removed duplicate stable call
				
				testLoopsCfmPattern( result );
				
			});

			it("should handle multi-line blocks without double counting", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = multiLineBlocks( processor );
				// removed duplicate stable call
				
				testMultiLineBlocks( result );
				
			});

			it("should handle adjacent non-overlapping blocks", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = adjacentBlocks( processor );
				// removed duplicate stable call
				
				testAdjacentBlocks( result );
				
			});

			it("should handle deeply nested blocks", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = nestedBlocks( processor );
				// removed duplicate stable call
				
				testNestedBlocks( result );
				
			});

			it("should handle dense code with multiple blocks per line", function() {
				var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger ); var result = denseCodeBlocks( processor );
				// removed duplicate stable call
				
				testDenseCodeBlocks( result );
				
			});
		});
	}

	// Test: Aggregated format with execution counts preservation (Phase 2: NO DATA LOSS!)
	private void function testAggregatedFormat() {
		var processor = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger );

		// Simulate aggregated data format: key -> [fileIdx, startPos, endPos, count, totalTime]
		var aggregated = {
			"1#chr(9)#1#chr(9)#10000": [1, 1, 10000, 5, 500],        // Large block executed 5 times, 500ms total
			"1#chr(9)#1001#chr(9)#2000": [1, 1001, 2000, 10, 200],  // Small block executed 10 times, 200ms
			"1#chr(9)#5001#chr(9)#6000": [1, 5001, 6000, 3, 60]     // Another small block, 3 times, 60ms
		};

		var files = { "1": { "path": "test.cfm", "executableLines": {} } };
		var lineMappingsCache = {};

		// Mark overlapping blocks (Phase 2: keep all blocks!)
		var result = processor.filter(aggregated, files, lineMappingsCache);

		// Phase 2: ALL blocks should be present (no data loss!)
		expect(structCount(result)).toBe(3, "Should have ALL 3 blocks (Phase 2: no filtering, just marking)");

		// Verify all blocks are preserved with their counts and times
		var keyLarge = "1#chr(9)#1#chr(9)#10000";
		var key1 = "1#chr(9)#1001#chr(9)#2000";
		var key2 = "1#chr(9)#5001#chr(9)#6000";

		expect(result).toHaveKey(keyLarge, "Should have large block (marked as overlapping)");
		expect(result).toHaveKey(key1, "Should have first small block");
		expect(result).toHaveKey(key2, "Should have second small block");

		// Verify execution counts and times are preserved
		if (structKeyExists(result, keyLarge)) {
			var blockLarge = result[keyLarge];
			expect(arrayLen(blockLarge)).toBe(6, "Block should have 6 elements [fileIdx, start, end, count, time, isOverlapping]");
			expect(blockLarge[4]).toBe(5, "Large block should preserve count of 5");
			expect(blockLarge[5]).toBe(500, "Large block should preserve total time of 500ms");
			expect(blockLarge[6]).toBe(true, "Large block should be marked as overlapping");
		}

		if (structKeyExists(result, key1)) {
			var block1 = result[key1];
			expect(arrayLen(block1)).toBe(6, "Block should have 6 elements");
			expect(block1[4]).toBe(10, "First block should preserve count of 10");
			expect(block1[5]).toBe(200, "First block should preserve total time of 200ms");
			expect(block1[6]).toBe(false, "First block should NOT be marked as overlapping");
		}

		if (structKeyExists(result, key2)) {
			var block2 = result[key2];
			expect(arrayLen(block2)).toBe(6, "Block should have 6 elements");
			expect(block2[4]).toBe(3, "Second block should preserve count of 3");
			expect(block2[5]).toBe(60, "Second block should preserve total time of 60ms");
			expect(block2[6]).toBe(false, "Second block should NOT be marked as overlapping");
		}

		// Calculate total execution counts and times - NO DATA LOSS!
		var totalCount = 0;
		var totalTime = 0;
		for (var key in result) {
			totalCount += result[key][4];
			totalTime += result[key][5];
		}

		expect(totalCount).toBe(18, "Total execution count should be 18 (5+10+3, NO DATA LOSS!)");
		expect(totalTime).toBe(760, "Total execution time should be 760ms (500+200+60, NO DATA LOSS!)");
	}

	// Test: Basic large block exclusion with character positions
	private struct function excludeLargeBlocks(any processor) {
		// Simulate blocks: [fileIdx, startChar, endChar, execTime]
		// For this test, 1-1000 = line 1, 1001-2000 = line 2, etc.
		var blocks = [
			[1, 1, 10000, 100],    // Large block (whole file)
			[1, 1001, 2000, 50],   // Small block inside (line 2)
			[1, 5001, 6000, 20]    // Another small block inside (line 6)
		];
		// Build a fake line mapping: line 1 starts at 1, line 2 at 1001, ...
		var lineMapping = [];
		for (var i = 1; i <= 10; i++) lineMapping[i] = (i - 1) * 1000 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testExcludeLargeBlocks(result, label) {
		// Phase 2: Should have ALL blocks, with the large one marked as overlapping
		var filteredBlocks = result[1];
		expect(arrayLen(filteredBlocks)).toBe(3, "Should have ALL 3 blocks (Phase 2: no data loss)");

		// Check that we have all blocks including the large one
		var hasLargeBlock = false;
		var hasFirstBlock = false;
		var hasSecondBlock = false;
		var largeBlockIsOverlapping = false;

		for (var block in filteredBlocks) {
			if (block[2] == 1 && block[3] == 10000) {
				hasLargeBlock = true;
				largeBlockIsOverlapping = (arrayLen(block) >= 5 && block[5]);
			}
			if (block[2] == 1001 && block[3] == 2000) hasFirstBlock = true;
			if (block[2] == 5001 && block[3] == 6000) hasSecondBlock = true;
		}
		expect(hasLargeBlock).toBeTrue("Should have large block [1-10000] (marked as overlapping)");
		expect(largeBlockIsOverlapping).toBeTrue("Large block should be marked as overlapping");
		expect(hasFirstBlock).toBeTrue("Should have block [1001-2000]");
		expect(hasSecondBlock).toBeTrue("Should have block [5001-6000]");
	}

	// Test: Real-world exception.cfm blocks
	private struct function exceptionCfmRealWorldBlocks(any processor) {
		// Real-world char-based blocks from exception.cfm .exl file
		var blocks = [
			[1, 54, 85, 4],
			[1, 91, 164, 111],
			[1, 225, 249, 1],
			[1, 254, 305, 40],
			[1, 470, 491, 0],
			[1, 318, 505, 24],
			[1, 505, 529, 0],
			[1, 705, 735, 0],
			[1, 220, 768, 78],
			[1, 791, 888, 8],
			[1, 888, 915, 0],
			[1, 781, 1055, 10],
			[1, 772, 1211, 11],
			[1, 1211, 1243, 0],
			[1, 0, 1257, 210]
		];
		// Build a fake line mapping: line 1 starts at 1, line 2 at 100, ... (simulate 20 lines)
		var lineMapping = [];
		for (var i = 1; i <= 20; i++) lineMapping[i] = (i - 1) * 100 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 20; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "exception.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "exception.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	// Test: loops.cfm pattern from our debugging
	private struct function loopsCfmPattern(any processor) {
		// Actual pattern we found in loops.cfm
		// [72-145] is the for loop block that overlaps with [97-107] and [112-140]
		var blocks = [
			[1, 37, 46, 344],    // Line 3: total = 0
			[1, 72, 145, 565],   // Lines 6-9: for loop structure (should be excluded!)
			[1, 97, 107, 48],    // Line 7: total += i (inside for loop)
			[1, 112, 140, 162],  // Line 8: echo (inside for loop)
			[1, 167, 178, 7],    // Line 12: counter = 0
			[1, 189, 259, 31],   // Lines 13-16: while loop structure
			[1, 207, 240, 7],    // Line 14: echo (inside while)
			[1, 252, 254, 4]     // Line 15: counter++
		];
		// Simulate line mapping where each line is roughly 50 chars
		var lineMapping = [];
		for (var i = 1; i <= 30; i++) lineMapping[i] = (i - 1) * 50 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 30; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "loops.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "loops.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testLoopsCfmPattern(result, label) {
		// Phase 2: The large for-loop block [72-145] should be KEPT but marked as overlapping
		var filteredBlocks = result[1];
		var hasLargeBlock = false;
		var largeBlockIsOverlapping = false;

		for (var block in filteredBlocks) {
			if (block[2] == 72 && block[3] == 145) {
				hasLargeBlock = true;
				largeBlockIsOverlapping = (arrayLen(block) >= 5 && block[5]);
				break;
			}
		}
		expect(hasLargeBlock).toBeTrue("Large block [72-145] should be present (Phase 2: no data loss)");
		expect(largeBlockIsOverlapping).toBeTrue("Large block [72-145] should be marked as overlapping");

		// Should have ALL blocks
		expect(arrayLen(filteredBlocks)).toBe(8, "Should have all 8 blocks (Phase 2: no data loss)");
	}

	// Test: Multi-line blocks
	private struct function multiLineBlocks(any processor) {
		// Test blocks that legitimately span multiple lines
		var blocks = [
			[1, 100, 250, 50],   // Spans lines 3-5
			[1, 300, 350, 30],   // Single line 7
			[1, 400, 550, 60]    // Spans lines 9-11
		];
		// Line mapping: each line is 50 chars
		var lineMapping = [];
		for (var i = 1; i <= 20; i++) lineMapping[i] = (i - 1) * 50 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 20; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testMultiLineBlocks(result, label) {
		// All three blocks should remain (no overlap)
		var filteredBlocks = result[1];
		expect(arrayLen(filteredBlocks)).toBe(3, "Should have all 3 blocks (no overlap)");
	}

	// Test: Adjacent non-overlapping blocks
	private struct function adjacentBlocks(any processor) {
		var blocks = [
			[1, 50, 99, 10],     // End of line 1
			[1, 100, 149, 20],   // Start of line 3
			[1, 150, 199, 30],   // Line 4
			[1, 200, 249, 40]    // Line 5
		];
		var lineMapping = [];
		for (var i = 1; i <= 10; i++) lineMapping[i] = (i - 1) * 50 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testAdjacentBlocks(result, label) {
		// All four blocks should remain (adjacent but not overlapping)
		var filteredBlocks = result[1];
		expect(arrayLen(filteredBlocks)).toBe(4, "Should have all 4 adjacent blocks");
	}

	// Test: Nested blocks at different levels
	private struct function nestedBlocks(any processor) {
		var blocks = [
			[1, 100, 500, 100],  // Large outer block (lines 3-10)
			[1, 150, 450, 80],   // Medium nested block (lines 4-9)
			[1, 200, 250, 30],   // Small inner block (line 5)
			[1, 300, 350, 40]    // Another small inner block (line 7)
		];
		var lineMapping = [];
		for (var i = 1; i <= 15; i++) lineMapping[i] = (i - 1) * 50 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 15; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "test.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "test.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testNestedBlocks(result, label) {
		// Phase 2: Should keep ALL blocks, with overlapping ones marked
		var filteredBlocks = result[1];
		expect(arrayLen(filteredBlocks)).toBe(4, "Should have all 4 blocks (Phase 2: no data loss)");

		var hasSmallBlock1 = false;
		var hasSmallBlock2 = false;
		var hasLargeBlocks = 0;
		var largeBlocksMarkedAsOverlapping = 0;

		for (var block in filteredBlocks) {
			if (block[2] == 200 && block[3] == 250) hasSmallBlock1 = true;
			if (block[2] == 300 && block[3] == 350) hasSmallBlock2 = true;
			// Large and medium blocks should be marked as overlapping
			if ((block[2] == 100 && block[3] == 500) || (block[2] == 150 && block[3] == 450)) {
				hasLargeBlocks++;
				if (arrayLen(block) >= 5 && block[5]) largeBlocksMarkedAsOverlapping++;
			}
		}
		expect(hasSmallBlock1).toBeTrue("Should have block [200-250]");
		expect(hasSmallBlock2).toBeTrue("Should have block [300-350]");
		expect(hasLargeBlocks).toBe(2, "Should have both large blocks");
		expect(largeBlocksMarkedAsOverlapping).toBe(2, "Large blocks should be marked as overlapping");
	}

	// Test: Dense code with multiple blocks on same line
	private struct function denseCodeBlocks(any processor) {
		// Simulating dense.cfm with multiple blocks on single lines
		// Line 2: function test() { var a = 1; var b = 2; if (a > 0) { b++; } else { b--; } return a + b; }
		// Multiple overlapping blocks on positions 50-150
		var blocks = [
			[1, 20, 120, 100],   // Whole function block
			[1, 38, 48, 10],     // var a = 1
			[1, 50, 60, 10],     // var b = 2
			[1, 62, 85, 30],     // if statement
			[1, 72, 78, 15],     // b++ block
			[1, 86, 92, 0],      // else block (not executed)
			[1, 95, 115, 20],    // return statement
			// Line 3: for loop with multiple statements
			[1, 125, 180, 200],  // Whole for loop
			[1, 150, 160, 50],   // total += i
			[1, 162, 172, 50],   // echo(i)
			// Same line, different code blocks
			[1, 185, 210, 80],   // while loop
			[1, 195, 200, 40],   // x++
			[1, 202, 209, 40]    // process(x)
		];
		// Simulate dense line mapping (each line ~100 chars)
		var lineMapping = [];
		for (var i = 1; i <= 10; i++) lineMapping[i] = (i - 1) * 100 + 1;
		var fileIdx = 1;
		var blocksByFile = { "#fileIdx#": blocks };
		var execLines = {};
		for (var l = 1; l <= 10; l++) execLines[l] = true;
		var files = { "#fileIdx#": { "path": "dense.cfm", "executableLines": execLines } };
		var lineMappingsCache = { "dense.cfm": lineMapping };
		return processor.filter(blocksByFile, files, lineMappingsCache);
	}

	private function testDenseCodeBlocks(result, label) {
		// Phase 2: Should keep ALL blocks, with large ones marked as overlapping
		var filteredBlocks = result[1];

		// Should HAVE the large function block [20-120] but marked as overlapping
		var hasLargeFunctionBlock = false;
		var largeFunctionBlockIsOverlapping = false;
		for (var block in filteredBlocks) {
			if (block[2] == 20 && block[3] == 120) {
				hasLargeFunctionBlock = true;
				largeFunctionBlockIsOverlapping = (arrayLen(block) >= 5 && block[5]);
				break;
			}
		}
		expect(hasLargeFunctionBlock).toBeTrue("Large function block [20-120] should be present (Phase 2)");
		expect(largeFunctionBlockIsOverlapping).toBeTrue("Large function block should be marked as overlapping");

		// Should HAVE the whole for loop [125-180] but marked as overlapping
		var hasLargeForBlock = false;
		var largeForBlockIsOverlapping = false;
		for (var block in filteredBlocks) {
			if (block[2] == 125 && block[3] == 180) {
				hasLargeForBlock = true;
				largeForBlockIsOverlapping = (arrayLen(block) >= 5 && block[5]);
				break;
			}
		}
		expect(hasLargeForBlock).toBeTrue("Large for loop block [125-180] should be present (Phase 2)");
		expect(largeForBlockIsOverlapping).toBeTrue("Large for loop block should be marked as overlapping");

		// Should have ALL blocks (no data loss!)
		expect(arrayLen(filteredBlocks)).toBe(13, "Should have all 13 blocks (Phase 2: no data loss)");
	}
}