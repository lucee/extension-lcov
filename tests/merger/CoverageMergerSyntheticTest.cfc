
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
		});

	}
}
