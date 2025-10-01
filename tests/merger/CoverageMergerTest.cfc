
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.utils = new lucee.extension.lcov.CoverageMergerUtils();
		variables.testDataGenerator = new "../GenerateTestData"(testName="SeparateFilesStepsTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "kitchen-sink-example.cfm"
		);

		// Parse all .exl files in COVERAGEDIR using ExecutionLogParser
		variables.parsedResults = {};
		var parser = variables.factory.getComponent(name="ExecutionLogParser");
		for (var exlFile in variables.testData.COVERAGEFILES) {
			var exlPath = variables.testData.COVERAGEDIR & exlFile;
			variables.parsedResults[exlPath] = parser.parseExlFile(exlPath);
		}
		variables.verbose = false;
	}

	// BDD: Given/When/Then for each step in mergeResults

	function run() {
		describe("mergeResults BDD steps", function() {

			it("filters valid results", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				// Use parsedResults as the input for all steps
				var results = duplicate(variables.parsedResults);
				// systemOutput("parsedResults struct: " & serializeJSON(allResults), true);
				var validResults = variables.utils.filterValidResults(results);
				expect(validResults).toBeStruct();
				expect(structCount(validResults)).toBeGT(0);
			});

			it("builds file index mappings", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var validResults = variables.utils.filterValidResults(results);
				var mappings = variables.utils.buildFileIndexMappings(validResults);
				expect(mappings).toHaveKey("filePathToIndex");
				expect(mappings).toHaveKey("indexToFilePath");
				expect(structCount(mappings.filePathToIndex)).toBeGT(0);
				expect(structCount(mappings.indexToFilePath)).toBeGT(0);
			});

			it("initializes merged results", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var validResults = variables.utils.filterValidResults(results);
				var mappings = variables.utils.buildFileIndexMappings(validResults);
				var mergedResults = variables.utils.initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
				expect(mergedResults).toBeStruct();
				expect(structCount(mergedResults)).toBeGT(0);
			});

			it("merges results and synchronizes stats", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var outputDir = getTempDirectory(true);
				var jsonFilePaths = writeResultsToJsonFiles(results, outputDir);
				var mergedResults = merger.mergeResults(jsonFilePaths, outputDir);
				expect(mergedResults).toBeStruct();
				expect(structCount(mergedResults)).toBeGT(0);
			});

			it("merges line coverage data correctly (unit, synthetic result)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				// Create a synthetic result object as in HtmlReporterSyntheticTest
				var targetResult = new lucee.extension.lcov.model.result();
				targetResult.setExeLog("/tmp/synthetic.exl");
				targetResult.setStats({
					totalLinesFound: 0,
					totalLinesHit: 0,
					totalLinesSource: 0,
					coveragePercentage: 0,
					totalFiles: 1,
					linesFound: 0,
					linesHit: 0,
					totalExecutions: 0,
					totalExecutionTime: 0
				});
				targetResult.setStatsProperty("files", { 0: { linesFound: 0, linesHit: 0, totalExecutions: 0, totalExecutionTime: 0 } });
				targetResult.setFiles({
					0: {
						path: "/tmp/Synthetic.cfm",
						linesFound: 0,
						linesHit: 0,
						linesSource: 0,
						coveragePercentage: 0,
						totalExecutions: 0,
						totalExecutionTime: 0,
						lines: [],
						executableLines: {}
					}
				});
				targetResult.setCoverage({});
				targetResult.setMetadata({ "script-name": "synthetic.cfm", "execution-time": 0, "unit": "ms" });
				targetResult.setOutputFilename("synthetic-mergeCoverageData-test");

				// Source coverage: line 10 hit 2 times, line 20 hit 3 times
				var sourceCoverage = {"10": [10, 2], "20": [20, 3]};
				// Merge into empty target
				var mergedLines = merger.mergeCoverageData(targetResult, sourceCoverage, "/tmp/Synthetic.cfm", 0);
				expect(mergedLines).toBe(2);
				var cov = targetResult.getCoverage();
				expect(cov["0"]).toHaveKey("10");
				expect(cov["0"]["10"][2]).toBe(2);
				expect(cov["0"]["20"][2]).toBe(3);

				// Merge again with new hits
				var sourceCoverage2 = {"10": [10, 5], "20": [20, 7]};
				var mergedLines2 = merger.mergeCoverageData(targetResult, sourceCoverage2, "/tmp/Synthetic.cfm", 0);
				expect(mergedLines2).toBe(2);
				cov = targetResult.getCoverage();
				expect(cov["0"]["10"][2]).toBe(7); // 2+5
				expect(cov["0"]["20"][2]).toBe(10); // 3+7
			});

			it("merges all coverage data from synthetic results (mergeAllCoverageDataFromResults)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				// Create two synthetic result objects, each with coverage for the same file but different lines
				var filePath = "/tmp/Synthetic.cfm";
				var exlPath1 = "/tmp/synthetic1.exl";
				var exlPath2 = "/tmp/synthetic2.exl";
				var result1 = new lucee.extension.lcov.model.result();
				result1.setExeLog(exlPath1);
				result1.setFiles({ 0: { path: filePath, linesFound: 0, linesHit: 0, linesSource: 0, coveragePercentage: 0, totalExecutions: 0, totalExecutionTime: 0, lines: [], executableLines: {} } });
				result1.setCoverage({ 0: { "10": [10, 2], "20": [20, 3] } });
				result1.setMetadata({ "script-name": "synthetic1.cfm", "execution-time": 0, "unit": "ms" });
				result1.setOutputFilename("synthetic1-mergeAll-test");

				var result2 = new lucee.extension.lcov.model.result();
				result2.setExeLog(exlPath2);
				result2.setFiles({ 0: { path: filePath, linesFound: 0, linesHit: 0, linesSource: 0, coveragePercentage: 0, totalExecutions: 0, totalExecutionTime: 0, lines: [], executableLines: {} } });
				result2.setCoverage({ 0: { "10": [10, 5], "30": [30, 4] } });
				result2.setMetadata({ "script-name": "synthetic2.cfm", "execution-time": 0, "unit": "ms" });
				result2.setOutputFilename("synthetic2-mergeAll-test");

				var validResults = { exlPath1: result1, exlPath2: result2 };
				var utils = variables.utils;
				var mappings = utils.buildFileIndexMappings(validResults);
				var mergedResults = utils.initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
				var sourceFileStats = merger.createSourceFileStats(mappings.indexToFilePath);
				var totalMergeOperations = 0;
				mergedResults = merger.mergeAllCoverageDataFromResults(validResults, mergedResults, mappings, sourceFileStats, totalMergeOperations);

				// Validate merged coverage: line 10 = 2+5=7, line 20 = 3, line 30 = 4
				var merged = mergedResults[0].getCoverage()["0"];
				expect(merged["10"][2]).toBe(7);
				expect(merged["20"][2]).toBe(3);
				expect(merged["30"][2]).toBe(4);
			});


			xit("remaps fileCoverage lines to canonical index (mergeFileCoverageArray, synthetic) - SKIPPED: fileCoverage removed", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				// Create synthetic source and target result objects
				var targetResult = new lucee.extension.lcov.model.result();
				targetResult.setFileCoverage([]);
				var sourceResult = new lucee.extension.lcov.model.result();
				// Simulate fileCoverage lines as arrays, then join with tab for correct .exl format: <fileIndex> <startLine> <endLine> <hitCount>
				var fileCoverageLines = [
					arrayToList(["1","10","10","2"], chr(9)),
					arrayToList(["1","20","20","3"], chr(9))
				];
				sourceResult.setFileCoverage(fileCoverageLines);
				// Call mergeFileCoverageArray, should remap fileIndex to 0 (column 1)
				merger.mergeFileCoverageArray(targetResult, sourceResult, "1", 0, "/tmp/Synthetic.cfm");
				var mergedLines = targetResult.getFileCoverage();
				expect(arrayLen(mergedLines)).toBe(2);
				// All fileIndex columns should be 0 (column 1)
				for (var i=1; i <= arrayLen(mergedLines); i++) {
					var parts = listToArray(mergedLines[i], chr(9), false, false);
					expect(parts[1]).toBe("0");
				}
				// Line numbers and hit counts preserved
				expect(listToArray(mergedLines[1], chr(9), false, false)[2]).toBe("10");
				expect(listToArray(mergedLines[1], chr(9), false, false)[4]).toBe("2");
				expect(listToArray(mergedLines[2], chr(9), false, false)[2]).toBe("20");
				expect(listToArray(mergedLines[2], chr(9), false, false)[4]).toBe("3");
			});

			it("calculates stats for merged results", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var validResults = variables.utils.filterValidResults(results);
				var mappings = variables.utils.buildFileIndexMappings(validResults);
				var mergedResults = variables.utils.initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
				   new lucee.extension.lcov.CoverageStats().calculateStatsForMergedResults(mergedResults);
				for (var idx in mergedResults) {
					var result = mergedResults[idx];
					// Stats are set on the result object
					var stats = result.getStats();
					expect(stats).toHaveKey("totalLinesFound");
					expect(stats).toHaveKey("totalLinesHit");
					expect(stats).toHaveKey("totalLinesSource");
					expect(stats.totalLinesFound).toBeGTE(0);
					expect(stats.totalLinesHit).toBeGTE(0);
					expect(stats.totalLinesSource).toBeGTE(0);
					expect(stats.totalLinesHit).toBeLTE(stats.totalLinesFound, "linesHit should never exceed linesFound");
				}
			});

			it("writes merged results to files with proper filtering", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var validResults = variables.utils.filterValidResults(results);
				var mappings = variables.utils.buildFileIndexMappings(validResults);
				var mergedResults = variables.utils.initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
				new lucee.extension.lcov.CoverageStats().calculateStatsForMergedResults(mergedResults);
				var outputDir = variables.testData.COVERAGEDIR & "/bdd/";
				var writtenFiles = new lucee.extension.lcov.CoverageMergerWriter().writeMergedResultsToFiles(mergedResults, outputDir, variables.verbose);
				expect(writtenFiles).toBeArray();
				expect(arrayLen(writtenFiles)).toBeGT(0);

				// Validate that each written file contains only data for that specific file
				for (var writtenFile in writtenFiles) {
					if (!fileExists(writtenFile)) continue;

					var jsonContent = fileRead(writtenFile);
					var jsonData = deserializeJSON(jsonContent);
					var fileName = getFileFromPath(writtenFile);

					// Each per-file JSON should have exactly ONE file in the files structure
					expect(jsonData).toHaveKey("files", "Per-file JSON should have files structure: " & fileName);
					expect(structCount(jsonData.files)).toBe(1, "Per-file JSON should contain exactly ONE file entry, not all files from execution: " & fileName & " (found " & structCount(jsonData.files) & " files)");

					// Should have exactly ONE entry in coverage structure (for the single file)
					if (structKeyExists(jsonData, "coverage")) {
						expect(structCount(jsonData.coverage)).toBeLTE(1, "Per-file JSON should contain coverage for at most ONE file: " & fileName & " (found " & structCount(jsonData.coverage) & " coverage entries)");
					}

					// The single file entry should have valid stats
					var fileEntry = jsonData.files[structKeyArray(jsonData.files)[1]];
					expect(fileEntry).toHaveKey("linesFound");
					expect(fileEntry).toHaveKey("linesHit");
					expect(fileEntry.linesFound).toBeGTE(0);
					expect(fileEntry.linesHit).toBeGTE(0);
					expect(fileEntry.linesHit).toBeLTE(fileEntry.linesFound, "linesHit should never exceed linesFound in per-file JSON: " & fileName);
				}
			});
		});

	   describe("CoverageMerger mergeResultsByFile refactor", function() {

			it("builds file mappings and initializes merged struct", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				expect(mappingResult).toHaveKey("merged");
				expect(mappingResult).toHaveKey("fileMappings");
				expect(mappingResult.merged).toHaveKey("files");
				expect(mappingResult.merged).toHaveKey("coverage");
				expect(mappingResult.fileMappings).toBeStruct();
			});

			it("merges coverage lines into merged struct", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);
				expect(structCount(mappingResult.merged.coverage)).toBeGT(0);
			});

			it("merges coverage lines without finalizing stats", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var mappingResult = merger.buildFileMappingsAndInitMerged(results);
				merger.mergeCoverageLines(mappingResult.merged, mappingResult.fileMappings, results);
				// Stats calculation now handled by CoverageStats component
				for (var filePath in mappingResult.merged.files) {
					var stats = mappingResult.merged.files[filePath];
					// File metadata should exist but stats calculation happens elsewhere
					expect(stats).toHaveKey("path");
				}
			});

			it("merges results by file (integration)", function() {
				var merger = variables.factory.getComponent(name="CoverageMerger");
				var results = duplicate(variables.parsedResults);
				var outputDir = getTempDirectory(true);
				var jsonFilePaths = writeResultsToJsonFiles(results, outputDir);
				var mergedResult = merger.mergeResultsByFile(jsonFilePaths);
				expect(mergedResult).toHaveKey("mergedCoverage");
				expect(mergedResult).toHaveKey("files");
				for (var filePath in mergedResult.files) {
					var fileData = mergedResult.files[filePath];
					expect(fileData).toHaveKey("path");
					expect(fileData).toHaveKey("linesFound");
					expect(fileData.linesFound).toBeGTE(0);
					// Stats are now calculated by CoverageStats component, not during merge
				}
			});

		});

	}

	private array function writeResultsToJsonFiles(required struct results, required string outputDir) {
		var jsonFilePaths = [];
		for (var exlPath in arguments.results) {
			var result = arguments.results[exlPath];
			var jsonFileName = result.getOutputFilename() & ".json";
			var jsonFilePath = arguments.outputDir & jsonFileName;
			fileWrite(jsonFilePath, result.toJson(false, true));
			arrayAppend(jsonFilePaths, jsonFilePath);
		}
		return jsonFilePaths;
	}
}
