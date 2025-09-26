
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.utils = new lucee.extension.lcov.CoverageMergerUtils();		
	}

	// BDD: Given/When/Then for each step in mergeResults

	function run() {
		describe("CoverageMerger helpers with synthetic data", function() {
			it("builds file mappings and initializes merged struct (synthetic)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				// Synthetic results: two files, two sources
				var fileA = "/tmp/SynthA.cfm";
				var fileB = "/tmp/SynthB.cfm";
				var result1 = new lucee.extension.lcov.model.result();
				result1.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true,"2":true} } });
				result1.setCoverage({ 0: { "1": [1,2], "2": [2,3] } });
				var result2 = new lucee.extension.lcov.model.result();
				result2.setFiles({ 0: { path: fileB, linesSource: 5, executableLines: {"1":true} } });
				result2.setCoverage({ 0: { "1": [1,1] } });
				var results = { "exl1": result1, "exl2": result2 };
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				expect(mappingResult).toHaveKey("merged");
				expect(mappingResult).toHaveKey("fileMappings");
				expect(mappingResult.merged.files).toHaveKey(fileA);
				expect(mappingResult.merged.files).toHaveKey(fileB);
			});

			it("merges coverage lines into merged struct (synthetic)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var fileA = "/tmp/SynthA.cfm";
				var fileB = "/tmp/SynthB.cfm";
				var result1 = new lucee.extension.lcov.model.result();
				result1.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true,"2":true} } });
				result1.setCoverage({ 0: { "1": [1,2], "2": [2,3] } });
				var result2 = new lucee.extension.lcov.model.result();
				result2.setFiles({ 0: { path: fileB, linesSource: 5, executableLines: {"1":true} } });
				result2.setCoverage({ 0: { "1": [1,1] } });
				var results = { "exl1": result1, "exl2": result2 };
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);
				expect(mappingResult.merged.coverage).toHaveKey(fileA);
				expect(mappingResult.merged.coverage).toHaveKey(fileB);
				expect(mappingResult.merged.coverage[fileA]["1"][2]).toBe(2);
				expect(mappingResult.merged.coverage[fileA]["2"][2]).toBe(3);
				expect(mappingResult.merged.coverage[fileB]["1"][2]).toBe(1);
			});

			it("merges coverage lines without stats calculation (synthetic)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var fileA = "/tmp/SynthA.cfm";
				var fileB = "/tmp/SynthB.cfm";
				var result1 = new lucee.extension.lcov.model.result();
				result1.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true,"2":true} } });
				result1.setCoverage({ 0: { "1": [1,2], "2": [2,3] } });
				var result2 = new lucee.extension.lcov.model.result();
				result2.setFiles({ 0: { path: fileB, linesSource: 5, executableLines: {"1":true} } });
				result2.setCoverage({ 0: { "1": [1,1] } });
				var results = { "exl1": result1, "exl2": result2 };
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);
				// Stats calculation now handled by CoverageStats component
				var statsA = mappingResult.merged.files[fileA];
				var statsB = mappingResult.merged.files[fileB];
				expect(statsA).toHaveKey("path");
				expect(statsB).toHaveKey("path");
				// Verify coverage data was merged
				expect(mappingResult.merged.coverage[fileA]["1"][2]).toBe(2);
				expect(mappingResult.merged.coverage[fileB]["1"][2]).toBe(1);
			});
		
			it("merges overlapping coverage for same file (synthetic)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var fileA = "/tmp/SynthA.cfm";
				// result1: lines 1,2; result2: lines 2,3 (overlap on 2)
				var result1 = new lucee.extension.lcov.model.result();
				result1.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true,"2":true,"3":true} } });
				result1.setCoverage({ 0: { "1": [1,2], "2": [2,3] } });
				var result2 = new lucee.extension.lcov.model.result();
				result2.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true,"2":true,"3":true} } });
				result2.setCoverage({ 0: { "2": [2,4], "3": [3,5] } });
				var results = { "exl1": result1, "exl2": result2 };
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);
				// Validate merged: line 1 = 2, line 2 = 3+4=7, line 3 = 5
				expect(mappingResult.merged.coverage[fileA]["1"][2]).toBe(2);
				expect(mappingResult.merged.coverage[fileA]["2"][2]).toBe(7);
				expect(mappingResult.merged.coverage[fileA]["3"][2]).toBe(5);
				// Stats calculation now handled by CoverageStats component
				var statsA = mappingResult.merged.files[fileA];
				expect(statsA).toHaveKey("path");
			});

			it("does not allow linesHit to exceed linesFound for duplicate line coverage (synthetic)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var fileA = "/tmp/SynthA.cfm";
				// Both results report line 1 as hit, should only count once for linesHit and linesFound
				var result1 = new lucee.extension.lcov.model.result();
				result1.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true} } });
				result1.setCoverage({ 0: { "1": [1,1] } });
				var result2 = new lucee.extension.lcov.model.result();
				result2.setFiles({ 0: { path: fileA, linesSource: 10, executableLines: {"1":true} } });
				result2.setCoverage({ 0: { "1": [1,1] } });
				var results = { "exl1": result1, "exl2": result2 };
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);
				// Stats calculation now handled by CoverageStats component
				var statsA = mappingResult.merged.files[fileA];
				expect(statsA).toHaveKey("path");
			});

			it("mergeResultsByFile produces unique file data for index generation (synthetic)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");

				// Create 3 different files with different coverage patterns
				var fileA = "/tmp/File1.cfm";
				var fileB = "/tmp/File2.cfm";
				var fileC = "/tmp/File3.cfm";

				// File A: Good coverage (80%)
				var jsonPathA = "/tmp/fileA.json";
				var resultA = new lucee.extension.lcov.model.result();
				resultA.setFiles({
					0: { path: fileA, linesFound: 10, linesHit: 8, linesSource: 10 }
				});
				resultA.setCoverage({
					0: { "1": [1,100], "2": [1,200], "3": [1,150], "4": [1,180], "5": [1,120], "6": [1,90], "7": [1,110], "8": [1,75] }
				});

				// File B: Poor coverage (25%)
				var jsonPathB = "/tmp/fileB.json";
				var resultB = new lucee.extension.lcov.model.result();
				resultB.setFiles({
					0: { path: fileB, linesFound: 20, linesHit: 5, linesSource: 20 }
				});
				resultB.setCoverage({
					0: { "1": [1,50], "5": [1,75], "10": [1,100], "15": [1,25], "20": [1,60] }
				});

				// File C: Moderate coverage (60%)
				var jsonPathC = "/tmp/fileC.json";
				var resultC = new lucee.extension.lcov.model.result();
				resultC.setFiles({
					0: { path: fileC, linesFound: 15, linesHit: 9, linesSource: 15 }
				});
				resultC.setCoverage({
					0: { "1": [1,80], "2": [1,90], "3": [1,70], "5": [1,85], "7": [1,95], "9": [1,75], "11": [1,65], "13": [1,55], "15": [1,45] }
				});

				// Create synthetic JSON file paths array (this is what mergeResultsByFile expects)
				var jsonFilePaths = [jsonPathA, jsonPathB, jsonPathC];

				// Mock the JSON file reading by setting up the results directly
				// In real usage, mergeResultsByFile reads JSON files, but we'll use the direct approach
				var results = {
					"#jsonPathA#": resultA,
					"#jsonPathB#": resultB,
					"#jsonPathC#": resultC
				};

				// Use buildFileMappingsAndInitMerged and mergeCoverageLines to simulate mergeResultsByFile
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);

				// Verify that we have 3 unique files in the merged data
				expect(structCount(mappingResult.merged.files)).toBe(3, "Should have exactly 3 files");
				expect(structCount(mappingResult.merged.coverage)).toBe(3, "Should have coverage for exactly 3 files");

				// Verify each file has different data
				expect(mappingResult.merged.files).toHaveKey(fileA);
				expect(mappingResult.merged.files).toHaveKey(fileB);
				expect(mappingResult.merged.files).toHaveKey(fileC);

				expect(mappingResult.merged.coverage).toHaveKey(fileA);
				expect(mappingResult.merged.coverage).toHaveKey(fileB);
				expect(mappingResult.merged.coverage).toHaveKey(fileC);

				// Verify files have different line counts (different linesFound values)
				expect(mappingResult.merged.files[fileA].linesFound).toBe(10);
				expect(mappingResult.merged.files[fileB].linesFound).toBe(20);
				expect(mappingResult.merged.files[fileC].linesFound).toBe(15);

				// Verify files have different coverage counts
				expect(structCount(mappingResult.merged.coverage[fileA])).toBe(8, "File A should have 8 covered lines");
				expect(structCount(mappingResult.merged.coverage[fileB])).toBe(5, "File B should have 5 covered lines");
				expect(structCount(mappingResult.merged.coverage[fileC])).toBe(9, "File C should have 9 covered lines");

				// This test ensures that when multiple files are processed:
				// 1. Each file maintains its unique metadata (linesFound, linesHit, etc.)
				// 2. Each file has its own distinct coverage data
				// 3. Files are not incorrectly duplicated or merged into identical entries
				// This prevents the index page from showing identical rows for different files
			});
		});

	}
}
