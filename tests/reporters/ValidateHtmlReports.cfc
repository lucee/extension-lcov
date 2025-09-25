component {

	/**
	 * Validates HTML output has correct execution time units and values match JSON data
	 */
	public void function validateHtmlExecutionTimeUnits(required string outputDir, required string testUnit, required string expectedDisplayUnit, boolean debug = false) {
		// Test index page execution time units
		var indexPath = arguments.outputDir & "index.html";
		expect(fileExists(indexPath)).toBeTrue("Index HTML file should exist");
		if (arguments.debug) {
			systemOutput("Validating HTML execution time units in: " & indexPath, true);
		}

		var indexContent = fileRead(indexPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(indexContent);

		// Should have root html element
		var htmlNodes = htmlParser.select(doc, "html");
		expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element in [" & indexPath & "]");

		// Should have execution time column header with correct unit
		var executionTimeHeaders = htmlParser.select(doc, "[data-execution-time-header]");
		expect(arrayLen(executionTimeHeaders)).toBeGTE(1, "Should have [data-execution-time-header] element in [" & indexPath & "]");

		var headerText = trim(htmlParser.getText(executionTimeHeaders[1]));
		// Header should show correct display unit
		expect(headerText).toInclude(arguments.expectedDisplayUnit);

		// Should have execution time data cells with numeric values
		var executionTimeCells = htmlParser.select(doc, "[data-execution-time-cell]");
		expect(arrayLen(executionTimeCells)).toBeGTE(1, "Should have [data-execution-time-cell] element in [" & indexPath & "]");

		// Verify execution time values are reasonable for the display unit
		for (var cell in executionTimeCells) {
			var cellText = trim(htmlParser.getText(cell));
			if (cellText != "" && isNumeric(cellText)) {
				var timeValue = val(cellText);
				validateExecutionTimeRange(timeValue, arguments.expectedDisplayUnit, cellText);
			}
		}

		// Also verify index.html execution times against JSON
		validateIndexTimesAgainstJson(arguments.outputDir, arguments.expectedDisplayUnit);

		// Test individual report execution time units and verify against JSON data
		var reportFiles = directoryList(arguments.outputDir, false, "path", "request-*.html");
		if (arrayLen(reportFiles) > 0) {
			var reportPath = reportFiles[1]; // Test first report
			var reportContent = fileRead(reportPath);

			// Use JSoup HTML parser
			var htmlParser = new testAdditional.HtmlParser();
			var document = htmlParser.parseHtml(reportContent);

			// Should have total execution time span with correct display unit
			var totalTimeElements = htmlParser.select(document, ".stats .total-execution-time");
			expect(arrayLen(totalTimeElements)).toBeGTE(1, "Should have .total-execution-time element in [" & reportPath & "]");

			var totalTimeText = htmlParser.getText(totalTimeElements[1]);
			expect(totalTimeText).toInclude(arguments.expectedDisplayUnit);

			// Should have line-level execution time column with correct unit
			var lineTimeHeaders = htmlParser.select(document, "[data-execution-time-header]");
			expect(arrayLen(lineTimeHeaders)).toBeGTE(1, "Should have [data-execution-time-header] element in [" & reportPath & "]");

			var lineHeaderText = htmlParser.getText(lineTimeHeaders[1]);
			expect(lineHeaderText).toInclude(arguments.expectedDisplayUnit);

			// Verify HTML execution times against JSON data
			validateHtmlTimesAgainstJson(reportPath, arguments.expectedDisplayUnit);
		}
	}

	/**
	 * Validates that HTML execution time values match the JSON data after proper unit conversion
	 */
	public void function validateHtmlTimesAgainstJson(required string reportPath, required string expectedDisplayUnit) {
		// Find corresponding JSON file
		var jsonPath = replace(arguments.reportPath, ".html", ".json");
		expect(fileExists(jsonPath)).toBeTrue("Corresponding JSON file should exist");

		// Read and parse JSON data
		var jsonContent = fileRead(jsonPath);
		var jsonData = deserializeJSON(jsonContent);

		// Get source unit from metadata
		var sourceUnit = jsonData.metadata.unit;
		expect(sourceUnit).notToBeEmpty("JSON should have unit metadata in " & jsonPath	);

		// Get HTML content and parse
		var reportContent = fileRead(arguments.reportPath);
		var htmlParser = new testAdditional.HtmlParser();
		var document = htmlParser.parseHtml(reportContent);

		// Get line rows ONLY from file index 0 section to avoid mixing data from multiple files
		var fileSection = htmlParser.select(document, "[data-file-section][data-file-index='0']");
		expect(arrayLen(fileSection)).toBe(1, "Should have exactly one file section for index 0 in [" & reportPath & "]");

		var lineRows = htmlParser.select(fileSection[1], "[data-line-row][data-line-number]");
		expect(arrayLen(lineRows)).toBeGT(0, "Should have line rows in file section 0 of [" & reportPath & "]");

		var htmlUtils = new lucee.extension.lcov.reporter.HtmlUtils();
		var coverageData = jsonData.coverage["0"]; // First file coverage data
		var verifiedCount = 0;

		for (var row in lineRows) {
			var lineNumber = htmlParser.getAttr(row, "data-line-number");
			var timeCell = htmlParser.select(row, "[data-execution-time-cell]");

			if (arrayLen(timeCell) > 0) {
				var htmlTimeText = trim(htmlParser.getText(timeCell[1]));

				// Check if this line has execution data in JSON
				if (structKeyExists(coverageData, lineNumber) && arrayLen(coverageData[lineNumber]) >= 2) {
					var jsonTimeNanos = coverageData[lineNumber][2]; // Time in source unit from JSON

					// Use the EXACT same logic as HtmlFileSection.cfc
					var convertedTime = htmlUtils.convertTime(jsonTimeNanos, sourceUnit, arguments.expectedDisplayUnit);
					var expectedTimeFormatted;
					if (arguments.expectedDisplayUnit == "s") {
						expectedTimeFormatted = numberFormat(convertedTime, "0.0000");
					} else {
						// For ns, μs, ms - no decimal places
						expectedTimeFormatted = numberFormat(convertedTime, "0");
					}

					// Compare HTML value with expected formatted value
					if (htmlTimeText != "") {
						expect(htmlTimeText).toBe(expectedTimeFormatted,
							"ROW MISMATCH - HTML file: " & arguments.reportPath
							& " | JSON file: " & jsonPath
							& " | Line " & lineNumber
							& " | HTML time: '" & htmlTimeText & "' " & arguments.expectedDisplayUnit
							& " | Expected: '" & expectedTimeFormatted & "' " & arguments.expectedDisplayUnit
							& " | Source: " & jsonTimeNanos & " " & sourceUnit
							& " | Converted: " & convertedTime
							& " | Row index in lineRows: " & arrayFind(lineRows, row));
						verifiedCount++;
					} else if (convertedTime == 0) {
						// HTML should show empty for zero times
						expect(htmlTimeText == "").toBeTrue(
							"Line " & lineNumber & " should show empty for zero execution time in [" & reportPath & "]");
						verifiedCount++;
					}
				}
			}
		}

		// Ensure we verified at least some lines with execution time data
		expect(verifiedCount).toBeGT(0, "Should have verified at least one line with execution time data in [" & reportPath & "]");
	}

	/**
	 * Validates that index.html execution time values match the JSON data after proper unit conversion
	 */
	public void function validateIndexTimesAgainstJson(required string outputDir, required string expectedDisplayUnit) {
		// Read index.json
		var indexJsonPath = arguments.outputDir & "index.json";
		expect(fileExists(indexJsonPath)).toBeTrue("Index JSON file should exist");

		var jsonContent = fileRead(indexJsonPath);
		var indexData = deserializeJSON(jsonContent);

		// Read index.html
		var indexHtmlPath = arguments.outputDir & "index.html";
		var htmlContent = fileRead(indexHtmlPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(htmlContent);

		// Get all report rows with execution time data
		var reportRows = htmlParser.select(doc, "[data-file-row]");
		expect(arrayLen(reportRows)).toBeGT(0, "Should have report rows in [" & indexHtmlPath & "]");

		var htmlUtils = new lucee.extension.lcov.reporter.HtmlUtils();
		var verifiedIndexCount = 0;

		for (var row in reportRows) {
			var scriptName = htmlParser.getAttr(row, "data-script-name");
			var htmlFile = htmlParser.getAttr(row, "data-html-file");
			var timeCell = htmlParser.select(row, "[data-execution-time-cell]");

			if (arrayLen(timeCell) > 0) {
				var htmlTimeText = trim(htmlParser.getText(timeCell[1]));

				// Find matching report in index data by HTML file name (more precise than script name)
				for (var report in indexData) {
					if (structKeyExists(report, "htmlFile") && report.htmlFile == htmlFile) {
						if (structKeyExists(report, "executionTime") && isNumeric(report.executionTime)) {
							// Use the EXACT same logic as HtmlIndex.cfc for formatting times
							var sourceUnit = structKeyExists(report, "unit") ? report["unit"] : "μs";
							var executionTimeMicros = htmlUtils.convertTime(report.executionTime, sourceUnit, "μs");
							// Use same precision as HtmlIndex.cfc: 4 decimals for seconds, 2 for others
							var precision = (arguments.expectedDisplayUnit == "s") ? 4 : 2;
							var timeDisplay = htmlUtils.formatTime(executionTimeMicros, arguments.expectedDisplayUnit, precision);
							// Extract just the numeric part (remove unit suffix) like HtmlIndex.cfc does
							var expectedTimeFormatted = reReplace(timeDisplay, "\s+[a-zA-Zμ]+$", "");

							if (htmlTimeText != "") {
								expect(htmlTimeText).toBe(expectedTimeFormatted,
									"INDEX ROW MISMATCH - Script: " & scriptName
									& " | HTML file: " & htmlFile
									& " | HTML time: '" & htmlTimeText & "' " & arguments.expectedDisplayUnit
									& " | Expected: '" & expectedTimeFormatted & "' " & arguments.expectedDisplayUnit
									& " | Source: " & report.executionTime & " μs"
									& " | Source unit: " & sourceUnit
									& " | Converted to μs: " & executionTimeMicros
									& " | Row data: " & serializeJSON(report));
								verifiedIndexCount++;
							}
						}
						break;
					}
				}
			}
		}

		// Ensure we verified at least some index rows with execution time data
		expect(verifiedIndexCount).toBeGT(0, "Should have verified at least one index row with execution time data in [" & indexHtmlPath & "]");

		// Validate index.html summary total execution time against JSON data
		var summaryTotalElements = htmlParser.select(doc, ".total-execution-time");
		expect(arrayLen(summaryTotalElements)).toBeGTE(1, "Should have summary total execution time element in [" & indexHtmlPath & "]");

		var summaryTotalText = trim(htmlParser.getText(summaryTotalElements[1]));

		// Calculate expected total from JSON data using same logic as HtmlIndex.cfc
		var totalExecutionTimeMicroseconds = 0;
		for (var report in indexData) {
			if (structKeyExists(report, "executionTime") && isNumeric(report.executionTime)) {
				// Convert from source unit to microseconds before summing (same as HtmlIndex.cfc)
				var sourceUnit = structKeyExists(report, "unit") ? report["unit"] : "μs";
				var executionTimeMicros = htmlUtils.convertTime(report.executionTime, sourceUnit, "μs");
				totalExecutionTimeMicroseconds += executionTimeMicros;
			}
		}

		// Format using same logic as HtmlIndex.cfc
		var expectedTotalDisplay = htmlUtils.formatTime(totalExecutionTimeMicroseconds, arguments.expectedDisplayUnit, 2);

		if (summaryTotalText != "") {
			expect(summaryTotalText).toBe(expectedTotalDisplay,
				"INDEX SUMMARY MISMATCH - Output dir: " & arguments.outputDir
				& " | HTML total: '" & summaryTotalText & "'"
				& " | Expected: '" & expectedTotalDisplay & "'"
				& " | Calculated from: " & totalExecutionTimeMicroseconds & " μs"
				& " | Display unit: " & arguments.expectedDisplayUnit
				& " | Index data count: " & arrayLen(indexData)
				& " | Index data: " & serializeJSON(indexData));
		}
	}

	/**
	 * Validates execution time values are in reasonable range for the display unit
	 */
	public void function validateExecutionTimeRange(required numeric timeValue, required string displayUnit, required string originalText) {
		switch (arguments.displayUnit) {
			case "s":
				// Seconds: should be reasonable for test script execution (0.001 to 300 seconds)
				expect(arguments.timeValue).toBeGTE(0);
				expect(arguments.timeValue).toBeLT(300);
				break;
			case "ms":
				// Milliseconds: should be reasonable (1 to 300000 ms)
				expect(arguments.timeValue).toBeGTE(0);
				expect(arguments.timeValue).toBeLT(300000);
				break;
			case "μs":
				// Microseconds: should be reasonable (1 to 300000000 μs)
				expect(arguments.timeValue).toBeGTE(0);
				expect(arguments.timeValue).toBeLT(300000000);
				break;
			default:
				throw "Unsupported display unit: " & arguments.displayUnit;
		}
	}
}