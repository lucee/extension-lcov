component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll(){
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level="none" );
		variables.utils = new lucee.extension.lcov.CoverageMergerUtils();
	};

	function run() {
		// NOTE: filterValidResults test was removed - that function is now a private helper in CoverageMergerTest

		describe("builds file index mappings from valid results", function() {
			it("builds file index mappings from valid results", function() {
				var result = new lucee.extension.lcov.model.result();
				result.setCoverage({ 0: { 1: [0,0,0] } });
				result.setFiles({ 0: { path: "/foo.cfm" } });

				// Add an invalid result (missing files struct)
				var invalidResult = new lucee.extension.lcov.model.result();
				invalidResult.setCoverage({ 0: { 1: [0,0,0] } });
				// Do NOT set files on invalidResult

				var validResults = {
					"/foo.exl": result,
					"/invalid.exl": invalidResult
				};
				var mappings = utils.buildFileIndexMappings(validResults);
				expect(mappings.filePathToIndex["/foo.cfm"]).toBe(0);
				expect(mappings.indexToFilePath[0]).toBe("/foo.cfm");
				// The invalid result should be ignored (no mapping for it)
				expect(structKeyExists(mappings.filePathToIndex, "")).toBeFalse();
			});
		});

		describe("initializes merged results for all canonical indices", function() {
			it("initializes merged results for all canonical indices", function() {
				var result = new lucee.extension.lcov.model.result();
				result.setCoverage({ 0: { 1: [0,0,0] } });
				// Add required fields: linesSource and linesFound
				result.setFiles({ 0: { path: "/foo.cfm", linesSource: 1, linesFound: 1 } });
				result.getMetadata = function() { return { unit: "μs" }; };
				var validResults = { "/foo.exl": result };
				var mappings = { filePathToIndex: { "/foo.cfm": 0 }, indexToFilePath: { 0: "/foo.cfm" } };
				var merged = utils.initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
				expect(structKeyExists(merged, 0)).toBeTrue();
			});
		});

		describe("throws if fileIndex has empty path in buildFileIndexMappings", function() {
			it("throws if fileIndex has empty path in buildFileIndexMappings", function() {
				var result = new lucee.extension.lcov.model.result();
				result.setCoverage({ 0: { 1: [0,0,0] } });
				result.setFiles({ 0: { path: "" } });
				var validResults = { "/foo.exl": result };
				expect(function() {
					utils.buildFileIndexMappings(validResults);
				}).toThrow();
			});
		});

		describe("initializeSourceFileEntry", function() {
			it("initializes a source file entry with required fields", function() {
				var sourceFilePath = "/bar.cfm";
				var sourceResult = new lucee.extension.lcov.model.result();
				sourceResult.setFiles({ 0: { path: sourceFilePath, linesSource: 7, linesFound: 3 } });
				sourceResult.setCoverage({ 0: { 1: [1,1,1], 2: [0,0,0], 3: [1,1,1] } });
				var fileIndex = 0;
				var mergedResult = utils.initializeSourceFileEntry(sourceFilePath, sourceResult, fileIndex);
				expect(mergedResult).notToBeNull();
				expect(mergedResult.getFileItem(0, "path")).toBe(sourceFilePath);
				expect(mergedResult.getFileItem(0)).toHaveKey("linesSource");
				expect(mergedResult.getFileItem(0)).toHaveKey("linesFound");
				expect(mergedResult.getFileItem(0, "linesSource")).toBe(7);
				expect(mergedResult.getFileItem(0, "linesFound")).toBe(3);
			});
		});

			// Zero/empty coverage cases
		describe("Zero/empty coverage cases", function() {
			it("should handle file with zero executable lines (linesFound=0)", function() {
				var filePath = "zero-exec.cfm";
				var result = new lucee.extension.lcov.model.result();
				result.setFiles({ 0: { path: filePath, linesSource: 10, linesFound: 0, linesHit: 0 } });
				var entry = utils.initializeSourceFileEntry(filePath, result, 0);
				expect(entry.getFileItem(0, "linesFound")).toBe(0);
				expect(entry.getFileItem(0, "linesHit")).toBe(0);
				expect(entry.getFileItem(0, "linesSource")).toBe(10);
			});

			it("should handle file with zero source lines (linesSource=0)", function() {
				var filePath = "zero-source.cfm";
				var result = new lucee.extension.lcov.model.result();
				result.setFiles({ 0: { path: filePath, linesSource: 0, linesFound: 0, linesHit: 0 } });
				var entry = utils.initializeSourceFileEntry(filePath, result, 0);
				expect(entry.getFileItem(0, "linesSource")).toBe(0);
				expect(entry.getFileItem(0, "linesFound")).toBe(0);
				expect(entry.getFileItem(0, "linesHit")).toBe(0);
			});

			it("should handle completely empty result struct", function() {
				expect(function() {
					var filePath = "empty.cfm";
					var result = new lucee.extension.lcov.model.result();
					utils.initializeSourceFileEntry(filePath, result, 0);
				}).toThrow();
			});
		});

		// Boundary conditions
		describe("Boundary conditions", function() {
			it("should handle file with only one line, covered", function() {
				var filePath = "one-line-covered.cfm";
				var result = new lucee.extension.lcov.model.result();
				result.setFiles({ 0: { path: filePath, linesSource: 1, linesFound: 1, linesHit: 1 } });
				var entry = utils.initializeSourceFileEntry(filePath, result, 0);
				expect(entry.getFileItem(0, "linesSource")).toBe(1);
				expect(entry.getFileItem(0, "linesFound")).toBe(1);
				expect(entry.getFileItem(0, "linesHit")).toBe(1);
			});

			it("should handle file with only one line, not covered", function() {
				var filePath = "one-line-not-covered.cfm";
				var result = new lucee.extension.lcov.model.result();
				result.setFiles({ 0: { path: filePath, linesSource: 1, linesFound: 1, linesHit: 0 } });
				var entry = utils.initializeSourceFileEntry(filePath, result, 0);
				expect(entry.getFileItem(0, "linesSource")).toBe(1);
				expect(entry.getFileItem(0, "linesFound")).toBe(1);
				expect(entry.getFileItem(0, "linesHit")).toBe(0);
			});

			it("should handle file with all lines covered", function() {
				var filePath = "all-covered.cfm";
				var result = new lucee.extension.lcov.model.result();
				result.setFiles({ 0: { path: filePath, linesSource: 5, linesFound: 5, linesHit: 5 } });
				var entry = utils.initializeSourceFileEntry(filePath, result, 0);
				expect(entry.getFileItem(0, "linesSource")).toBe(5);
				expect(entry.getFileItem(0, "linesFound")).toBe(5);
				expect(entry.getFileItem(0, "linesHit")).toBe(5);
			});

			it("should handle file with no lines covered", function() {
				var filePath = "none-covered.cfm";
				var result = new lucee.extension.lcov.model.result();
				result.setFiles({ 0: { path: filePath, linesSource: 5, linesFound: 5, linesHit: 0 } });
				var entry = utils.initializeSourceFileEntry(filePath, result, 0);
				expect(entry.getFileItem(0, "linesSource")).toBe(5);
				expect(entry.getFileItem(0, "linesFound")).toBe(5);
				expect(entry.getFileItem(0, "linesHit")).toBe(0);
			});
		});
	}
}
