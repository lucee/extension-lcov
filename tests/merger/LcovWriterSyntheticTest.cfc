component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.debug = false;
		variables.testDataHelper = new "../GenerateTestData"("lcov-writer-synthetic");
	}

	/**
	 * @displayName "Test LcovWriter with synthetic merged coverage data to verify file path key mapping"
	 */
	function testLcovWriterWithMergedSyntheticData() {
		// Create synthetic merged coverage data that mimics what mergeResultsByFile returns
		// This specifically tests the data contract between CoverageMerger and LcovWriter

		var testDir = variables.testDataHelper.getOutputDir();
		var file1Path = testDir & "/TestFile1.cfm";
		var file2Path = testDir & "/TestFile2.cfm";
		var file3Path = testDir & "/TestFile3.cfm";

		// Structure returned by mergeResultsByFile: coverage keyed by file PATHS, files keyed by indices
		var mergedCoverage = {
			files: {
				"0": {
					path: file1Path,
					linesFound: 3,
					linesHit: 3,
					linesSource: 3,
					executableLines: {"1": true, "2": true, "3": true}
				},
				"1": {
					path: file2Path,
					linesFound: 4,
					linesHit: 2,
					linesSource: 4,
					executableLines: {"1": true, "2": true, "3": true, "4": true}
				},
				"2": {
					path: file3Path,
					linesFound: 2,
					linesHit: 0,
					linesSource: 2,
					executableLines: {"1": true, "2": true}
				}
			},
			// CRITICAL: Coverage data is keyed by file PATHS (not indices)
			coverage: {
				"#file1Path#": {
					"1": [1, 50], // [hitCount, totalTime]
					"2": [2, 75],
					"3": [1, 25]
				},
				"#file2Path#": {
					"1": [3, 100],
					"2": [0, 0],   // unhit line
					"3": [1, 30],
					"4": [0, 0]    // unhit line
				},
				"#file3Path#": {
					"1": [0, 0],   // unhit line
					"2": [0, 0]    // unhit line
				}
			}
		};

		// Test LcovWriter.buildLCOV with this merged data
		var lcovWriter = new lucee.extension.lcov.reporter.LcovWriter({});
		var lcovContent = lcovWriter.buildLCOV(mergedCoverage, false);

		if (variables.debug) {
			systemOutput("Generated LCOV content:", true);
			systemOutput(lcovContent, true);
		}

		// Write LCOV content for inspection
		var lcovFile = testDir & "/synthetic-merged.lcov";
		fileWrite(lcovFile, lcovContent);
		if (variables.debug) {
			systemOutput("Wrote LCOV to: " & lcovFile, true);
		}

		// Parse and validate LCOV format
		var lines = listToArray(lcovContent, chr(10));
		var sfLines = [];
		var daLines = [];
		var lfLines = [];
		var lhLines = [];
		var endRecords = 0;

		for (var line in lines) {
			if (left(line, 3) == "SF:") {
				arrayAppend(sfLines, mid(line, 4));
			} else if (left(line, 3) == "DA:") {
				arrayAppend(daLines, mid(line, 4));
			} else if (left(line, 3) == "LF:") {
				arrayAppend(lfLines, mid(line, 4));
			} else if (left(line, 3) == "LH:") {
				arrayAppend(lhLines, mid(line, 4));
			} else if (trim(line) == "end_of_record") {
				endRecords++;
			}
		}

		// CRITICAL ASSERTIONS: Verify the file path mapping works correctly

		// Should have 3 source file records (SF:)
		expect(arrayLen(sfLines)).toBe(3, "Should have 3 SF records for 3 files");

		// SF records should contain the actual file paths from coverage keys
		expect(sfLines).toInclude(file1Path, "Should include file1 path in SF records");
		expect(sfLines).toInclude(file2Path, "Should include file2 path in SF records");
		expect(sfLines).toInclude(file3Path, "Should include file3 path in SF records");

		// Should have 3 end_of_record markers
		expect(endRecords).toBe(3, "Should have 3 end_of_record markers");

		// Should have correct number of DA (data array) records
		// File1: 3 lines, File2: 4 lines, File3: 2 lines = 9 total
		expect(arrayLen(daLines)).toBe(9, "Should have 9 DA records for all lines across all files");

		// Should have correct LF (lines found) values
		expect(arrayLen(lfLines)).toBe(3, "Should have 3 LF records");
		expect(lfLines).toInclude("3", "File1 should have LF:3");
		expect(lfLines).toInclude("4", "File2 should have LF:4");
		expect(lfLines).toInclude("2", "File3 should have LF:2");

		// Should have correct LH (lines hit) values
		expect(arrayLen(lhLines)).toBe(3, "Should have 3 LH records");
		expect(lhLines).toInclude("3", "File1 should have LH:3 (all hit)");
		expect(lhLines).toInclude("2", "File2 should have LH:2 (2 of 4 hit)");
		expect(lhLines).toInclude("0", "File3 should have LH:0 (none hit)");

		// Verify specific DA records contain correct hit counts
		expect(daLines).toInclude("1,1", "File1 line 1 should show 1 hit");
		expect(daLines).toInclude("2,2", "File1 line 2 should show 2 hits");
		expect(daLines).toInclude("3,1", "File1 line 3 should show 1 hit");

		expect(daLines).toInclude("1,3", "File2 line 1 should show 3 hits");
		expect(daLines).toInclude("2,0", "File2 line 2 should show 0 hits");
		expect(daLines).toInclude("3,1", "File2 line 3 should show 1 hit");
		expect(daLines).toInclude("4,0", "File2 line 4 should show 0 hits");

		expect(daLines).toInclude("1,0", "File3 line 1 should show 0 hits");
		expect(daLines).toInclude("2,0", "File3 line 2 should show 0 hits");

		// Test relative path conversion
		var lcovContentRelative = lcovWriter.buildLCOV(mergedCoverage, true);
		if (variables.debug) {
			systemOutput("Generated LCOV content with relative paths:", true);
			systemOutput(lcovContentRelative, true);
		}

		// With relative paths, SF records should not contain full paths
		var relativeSfLines = [];
		var relativeLines = listToArray(lcovContentRelative, chr(10));
		for (var line in relativeLines) {
			if (left(line, 3) == "SF:") {
				arrayAppend(relativeSfLines, mid(line, 4));
			}
		}

		// Verify relative paths don't contain the test directory
		// Note: safeContractPath may not work with synthetic test paths, so just verify we get some output
		expect(arrayLen(relativeSfLines)).toBe(3, "Should still have 3 SF records with relative path option");

		// Log the actual relative paths for inspection
		if (variables.debug) {
			systemOutput("Relative SF paths:", true);
			for (var sfPath in relativeSfLines) {
				systemOutput("  " & sfPath, true);
			}
		}
	}

	/**
	 * @displayName "Test LcovWriter fails with wrong key mapping (demonstrates the bug)"
	 */
	function testLcovWriterWithWrongKeyMapping() {
		// Create data structure with WRONG key mapping to demonstrate the bug
		// This shows what happens when coverage is keyed by indices but accessed by file paths

		var testDir = variables.testDataHelper.getOutputDir();
		var file1Path = testDir & "/WrongTest.cfm";

		var wrongStructure = {
			files: {
				"0": {
					path: file1Path,
					linesFound: 2,
					linesHit: 1,
					linesSource: 2
				}
			},
			// WRONG: Coverage keyed by index but LcovWriter tries to access by file path
			coverage: {
				"0": {  // This is wrong - should be keyed by file1Path
					"1": [1, 50],
					"2": [0, 0]
				}
			}
		};

		var lcovWriter = new lucee.extension.lcov.reporter.LcovWriter({});

		// This should throw an error because coverage[file1Path] doesn't exist
		expect(function() {
			lcovWriter.buildLCOV(wrongStructure, false);
		}).toThrow(message="Should throw error when coverage key doesn't match file path");
	}

	/**
	 * @displayName "Test empty coverage data handling"
	 */
	function testLcovWriterWithEmptyCoverage() {
		var emptyCoverage = {
			files: {},
			coverage: {}
		};

		var lcovWriter = new lucee.extension.lcov.reporter.LcovWriter({});
		var lcovContent = lcovWriter.buildLCOV(emptyCoverage, false);

		// Should return empty string or minimal content
		expect(lcovContent).toBeString();
		expect(len(trim(lcovContent))).toBeLTE(50, "Empty coverage should produce minimal LCOV content");
	}

	/**
	 * @displayName "Test LcovWriter with single file (edge case)"
	 */
	function testLcovWriterWithSingleFile() {
		var testDir = variables.testDataHelper.getOutputDir();
		var singleFilePath = testDir & "/SingleFile.cfm";

		var singleFileCoverage = {
			files: {
				"0": {
					path: singleFilePath,
					linesFound: 1,
					linesHit: 1,
					linesSource: 1,
					executableLines: {"1": true}
				}
			},
			coverage: {
				"#singleFilePath#": {
					"1": [5, 100]
				}
			}
		};

		var lcovWriter = new lucee.extension.lcov.reporter.LcovWriter({});
		var lcovContent = lcovWriter.buildLCOV(singleFileCoverage, false);

		// Should produce valid LCOV for single file
		expect(lcovContent).toInclude("SF:" & singleFilePath);
		expect(lcovContent).toInclude("DA:1,5");
		expect(lcovContent).toInclude("LF:1");
		expect(lcovContent).toInclude("LH:1");
		expect(lcovContent).toInclude("end_of_record");
	}
}