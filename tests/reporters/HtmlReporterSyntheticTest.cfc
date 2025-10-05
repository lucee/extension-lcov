
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger(level=variables.logLevel);
		variables.testDataHelper = new "../GenerateTestData"("synthetic-html");
	}

	/**
	 * Test the HTML reporter with synthetic coverage data (no file I/O)
	 */
	function testHtmlReporterWithSyntheticData() {
		var HtmlReporter = new lucee.extension.lcov.reporter.HtmlReporter( logger=variables.logger );
		var outDir = variables.testDataHelper.getOutputDir();
		HtmlReporter.setOutputDir( outDir );
		// Synthetic result object: 2 files, one fully covered, one partially covered
		// Use a CFC instance to match the model API and allow member access
		var syntheticResult = new lucee.extension.lcov.model.result();
		
		syntheticResult.setExeLog(outDir & "/synthetic.exl");
		syntheticResult.setStats({
			totalLinesFound: 10,
			totalLinesHit: 7,
			totalLinesSource: 10,
			coveragePercentage: 70,
			totalFiles: 2,
			linesFound: 10,
			linesHit: 7,
			totalExecutions: 17,
			totalExecutionTime: 123,
			totalChildTime: 0
		});
		// Add per-file stats to match model expectations
		// Use numeric file indices for all per-file data
		var filePaths = [outDir & "/FullyCovered.cfm", outDir & "/PartiallyCovered.cfm"];
		// fileIndex 0 = FullyCovered.cfm, fileIndex 1 = PartiallyCovered.cfm
		syntheticResult.setStatsProperty("files", {
			0: { linesFound: 5, linesHit: 5, totalExecutions: 10, totalExecutionTime: 60 },
			1: { linesFound: 5, linesHit: 2, totalExecutions: 7, totalExecutionTime: 63 }
		});
		syntheticResult.setFiles({
			0: {
				path: filePaths[1], // 0-based: filePaths[1] is FullyCovered.cfm
				linesFound: 5,
				linesHit: 5,
				linesSource: 5,
				coveragePercentage: 100,
				totalExecutions: 10,
				totalExecutionTime: 60,
				lines: ["line1", "line2", "line3", "line4", "line5"],
				executableLines: {}
			},
			1: {
				path: filePaths[2], // 0-based: filePaths[2] is PartiallyCovered.cfm
				linesFound: 5,
				linesHit: 2,
				linesSource: 5,
				coveragePercentage: 40,
				totalExecutions: 7,
				totalExecutionTime: 63,
				lines: ["line1", "line2", "line3", "line4", "line5"],
				executableLines: {}
			}
		});
		
		syntheticResult.setCoverage({
			total: 70,
			0: { linesFound: 5, linesHit: 5, coveragePercentage: 100 },
			1: { linesFound: 5, linesHit: 2, coveragePercentage: 40 }
		});
		syntheticResult.setMetadata({ "script-name": "synthetic.cfm", "execution-time": 123, "unit": "ms" });

		// Set outputFilename for the synthetic result (required by HtmlReporter)
		syntheticResult.setOutputFilename("synthetic-html-test");
		// Generate HTML report and get the file path
		// HtmlReporter uses its instance displayUnit now
		var htmlPath = HtmlReporter.generateHtmlReport(syntheticResult);
		variables.logger.debug("Generated HTML path: " & htmlPath);

		// Read the generated HTML file
		var html = fileRead(htmlPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(html);
		// Write the HTML content to a file for inspection
		var htmlOutPath = outDir & "/synthetic-html-content.html";
		fileWrite(htmlOutPath, html);
		variables.logger.debug("Wrote HTML content to: " & htmlOutPath);

		// Assert: file sections exist for all files using JSoup selectors
		var files = syntheticResult.getFiles();

		var fileSections = htmlParser.select(doc, "[data-file-section]");
		expect(arrayLen(fileSections)).toBe(structCount(files));
		// Assert the data-file-section attribute exists (boolean attribute with no value)
		fileSections.each(function(n){ expect(htmlParser.hasAttr(n, "data-file-section")).toBeTrue(); });
		var filenames = fileSections.map(function(n){ return htmlParser.getAttr(n, "data-filename"); });
		for (var idx in files) {
			expect(filenames).toInclude(files[idx].path);
		}

			// Assert: line rows exist and have correct attributes using JSoup selectors
		var lineRows = htmlParser.select(doc, "tr[data-line-row]");
		var totalLines = 0;
		for (var idx in files) {
			totalLines += files[idx].linesSource;
		}
		expect(arrayLen(lineRows)).toBe(totalLines);
		// Check exact number of line rows for each file using syntheticResult
		for (var idx in files) {
			var filePath = files[idx].path;
			var fileRows = htmlParser.select(doc, "div[data-filename='" & filePath & "'] tr[data-line-row]");
			expect(arrayLen(fileRows)).toBe(files[idx].linesSource);
		}

		// Assert: summary section exists and contains correct percentage using JSoup selectors
		var summary = htmlParser.select(doc, "[data-coverage-summary]");
		expect(arrayLen(summary)).toBe(1);
		var expectedPct = syntheticResult.getStats().coveragePercentage & ".0%";
		expect(htmlParser.getText(summary[1])).toInclude(expectedPct);

		// Assert: no duplicate table rows in reports table (for index pages)
		var reportRows = htmlParser.select(doc, "table.reports-table tbody tr[data-file-row]");
		if (arrayLen(reportRows) > 1) {
			var uniqueRows = {};
			var duplicateFound = false;
			var duplicateDetails = [];

			for (var row in reportRows) {
				var scriptNameCell = htmlParser.select(row, "td.script-name");
				var coverageCell = htmlParser.select(row, "td.coverage");
				var percentageCell = htmlParser.select(row, "td.percentage");
				var executionTimeCell = htmlParser.select(row, "td.execution-time");

				if (arrayLen(scriptNameCell) > 0 && arrayLen(coverageCell) > 0 && arrayLen(percentageCell) > 0 && arrayLen(executionTimeCell) > 0) {
					var rowSignature = htmlParser.getText(scriptNameCell[1]) & "|" &
									 htmlParser.getText(coverageCell[1]) & "|" &
									 htmlParser.getText(percentageCell[1]) & "|" &
									 htmlParser.getText(executionTimeCell[1]);

					if (structKeyExists(uniqueRows, rowSignature)) {
						duplicateFound = true;
						arrayAppend(duplicateDetails, "Duplicate row: " & rowSignature);
					} else {
						uniqueRows[rowSignature] = true;
					}
				}
			}

			expect(duplicateFound).toBeFalse("Found duplicate table rows in reports table: " & arrayToList(duplicateDetails, "; "));
		}
	}

	/**
	 * Test the HTML index generation with multiple results to catch duplicate row bugs
	 */
	function testHtmlIndexWithMultipleResults() {
		var HtmlIndex = new lucee.extension.lcov.reporter.HtmlIndex();
		var outDir = variables.testDataHelper.getOutputDir();

		// Create synthetic results array with 3 different files
		var results = [];

		// Result 1
		var result1 = new lucee.extension.lcov.model.result();
		result1.setOutputFilename("file1-result");
		result1.setStats({
			totalLinesFound: 10,
			totalLinesHit: 8,
			coveragePercentage: 80,
			totalExecutionTime: 1000,
			totalChildTime: 0
		});
		result1.setMetadata({ "script-name": "file1.cfm", "execution-time": 1000 });
		arrayAppend(results, result1);

		// Result 2
		var result2 = new lucee.extension.lcov.model.result();
		result2.setOutputFilename("file2-result");
		result2.setStats({
			totalLinesFound: 20,
			totalLinesHit: 5,
			coveragePercentage: 25,
			totalExecutionTime: 2000,
			totalChildTime: 0
		});
		result2.setMetadata({ "script-name": "file2.cfm", "execution-time": 2000 });
		arrayAppend(results, result2);

		// Result 3
		var result3 = new lucee.extension.lcov.model.result();
		result3.setOutputFilename("file3-result");
		result3.setStats({
			totalLinesFound: 15,
			totalLinesHit: 12,
			coveragePercentage: 80,
			totalExecutionTime: 1500,
			totalChildTime: 0
		});
		result3.setMetadata({ "script-name": "file3.cfm", "execution-time": 1500 });
		arrayAppend(results, result3);

		// Generate index HTML content
		var htmlEncoder = new lucee.extension.lcov.reporter.HtmlEncoder();
		var resultsData = [];

		// Transform result models to the expected struct format that HtmlIndex expects
		for (var result in results) {
			var resultData = {
				scriptName: result.getMetadata()["script-name"],
				htmlFile: result.getOutputFilename() & ".html",
				totalLinesHit: result.getStats().totalLinesHit,
				totalLinesFound: result.getStats().totalLinesFound,
				executionTime: result.getStats().totalExecutionTime,
				totalChildTime: result.getStats().totalChildTime
			};
			arrayAppend(resultsData, resultData);
		}

		var indexHtml = HtmlIndex.generateIndexHtmlContent(resultsData, htmlEncoder, "μs");
		var indexPath = outDir & "/index.html";
		fileWrite(indexPath, indexHtml);

		// Read and parse the generated HTML
		var html = fileRead(indexPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(html);

		// Write HTML content for inspection
		var htmlOutPath = outDir & "/index-content.html";
		fileWrite(htmlOutPath, html);
		variables.logger.debug("Wrote index HTML content to: " & htmlOutPath);

		// Check for duplicate rows in the reports table
		var reportRows = htmlParser.select(doc, "table.reports-table tbody tr[data-file-row]");
		expect(arrayLen(reportRows)).toBe(3, "Should have exactly 3 report rows");

		var uniqueRows = {};
		var duplicateFound = false;
		var duplicateDetails = [];
		var rowSignatures = [];

		for (var row in reportRows) {
			var scriptNameCell = htmlParser.select(row, "td.script-name");
			var coverageCell = htmlParser.select(row, "td.coverage");
			var percentageCell = htmlParser.select(row, "td.percentage");
			var executionTimeCell = htmlParser.select(row, "td.execution-time");

			if (arrayLen(scriptNameCell) > 0 && arrayLen(coverageCell) > 0 && arrayLen(percentageCell) > 0 && arrayLen(executionTimeCell) > 0) {
				var rowSignature = htmlParser.getText(scriptNameCell[1]) & "|" &
								 htmlParser.getText(coverageCell[1]) & "|" &
								 htmlParser.getText(percentageCell[1]) & "|" &
								 htmlParser.getText(executionTimeCell[1]);

				arrayAppend(rowSignatures, rowSignature);

				if (structKeyExists(uniqueRows, rowSignature)) {
					duplicateFound = true;
					arrayAppend(duplicateDetails, "Duplicate row: " & rowSignature);
				} else {
					uniqueRows[rowSignature] = true;
				}
			}
		}

		// Log all row signatures for debugging
		variables.logger.debug("Row signatures found: " & serializeJSON(rowSignatures));

		expect(duplicateFound).toBeFalse("Found duplicate table rows in index page: " & arrayToList(duplicateDetails, "; "));

		// Verify that each file appears exactly once with correct data
		// Note: displayUnit="μs" is explicit (not "auto"), so execution time cells should not include units
		expect(arrayLen(rowSignatures)).toBe(3, "Should have 3 unique rows");
		expect(rowSignatures).toInclude("file1.cfm|8 / 10|80.0|1,000", "Should include file1.cfm row");
		expect(rowSignatures).toInclude("file2.cfm|5 / 20|25.0|2,000", "Should include file2.cfm row");
		expect(rowSignatures).toInclude("file3.cfm|12 / 15|80.0|1,500", "Should include file3.cfm row");
	}

}