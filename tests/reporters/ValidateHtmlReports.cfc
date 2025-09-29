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

		// Parse HTML only once
		var indexContent = fileRead(indexPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(indexContent);

		// Use the same displayUnit for validation as was used for HTML generation

		// Should have root html element
		var htmlNodes = htmlParser.select(doc, "html");
		expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element in [" & indexPath & "]");

		// Should have execution time column header with correct unit
		var executionTimeHeaders = htmlParser.select(doc, "[data-execution-time-header]");
		expect(arrayLen(executionTimeHeaders)).toBeGTE(1, "Should have [data-execution-time-header] element in [" & indexPath & "]");

		var headerText = trim(htmlParser.getText(executionTimeHeaders[1]));
		// Header should show correct display unit - but in auto mode, no unit should be shown
		if (arguments.expectedDisplayUnit == "auto") {
			expect(headerText).toBe("Execution Time", "Auto mode header should not include any unit in [" & indexPath & "]");
		} else {
			expect(headerText).toInclude(arguments.expectedDisplayUnit, "Header should include unit in [" & indexPath & "]");
		}

		// Should have execution time data cells with numeric values
		var executionTimeCells = htmlParser.select(doc, "[data-execution-time-cell]");
		expect(arrayLen(executionTimeCells)).toBeGTE(1, "Should have [data-execution-time-cell] element in [" & indexPath & "]");

		// Verify execution time values are reasonable for the display unit
		for (var cell in executionTimeCells) {
			var cellText = trim(htmlParser.getText(cell));
			if (cellText != "") {
				validateExecutionTimeFormatting(cellText, arguments.expectedDisplayUnit);
				if (isNumeric(cellText)) {
					var timeValue = parseNumber(cellText);
					validateExecutionTimeRange(timeValue, arguments.expectedDisplayUnit, cellText);
				}
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
			if (arguments.expectedDisplayUnit != "auto") {
				expect(totalTimeText).toInclude(arguments.expectedDisplayUnit);
			}

			// Should have line-level execution time column with correct unit
			var lineTimeHeaders = htmlParser.select(document, "[data-execution-time-header]");
			expect(arrayLen(lineTimeHeaders)).toBeGTE(1, "Should have [data-execution-time-header] element in [" & reportPath & "]");

			var lineHeaderText = htmlParser.getText(lineTimeHeaders[1]);
			if (arguments.expectedDisplayUnit != "auto") {
				expect(lineHeaderText).toInclude(arguments.expectedDisplayUnit);
			}

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

		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.expectedDisplayUnit);
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
					var timeMicros = timeFormatter.convertTime(jsonTimeNanos, sourceUnit, "μs");
					var expectedTimeFormatted = timeFormatter.format(timeMicros);

					// Compare HTML value with expected formatted value
					if (htmlTimeText != "") {
						expect(htmlTimeText).toBe(expectedTimeFormatted,
							"ROW MISMATCH - HTML file: " & arguments.reportPath
							& " | JSON file: " & jsonPath
							& " | Line " & lineNumber & chr(10)
							& " | HTML time: '" & htmlTimeText & "' " & arguments.expectedDisplayUnit
							& " | Expected: '" & expectedTimeFormatted & "' " & arguments.expectedDisplayUnit & chr(10)
							& " | Source: " & jsonTimeNanos & " " & sourceUnit
							& " | Converted to μs: " & timeMicros
							& " | Row index in lineRows: " & arrayFind(lineRows, row));
						verifiedCount++;
					} else if (timeMicros == 0) {
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

		// Also validate that line times sum to file total
		validateExecutionTimeTotals(arguments.reportPath);
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

		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.expectedDisplayUnit);
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
							var executionTimeMicros = timeFormatter.convertTime(report.executionTime, sourceUnit, "μs");
							// Use format method with the configured displayUnit
							var expectedTimeFormatted = timeFormatter.format(executionTimeMicros);

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
				var executionTimeMicros = timeFormatter.convertTime(report.executionTime, sourceUnit, "μs");
				totalExecutionTimeMicroseconds += executionTimeMicros;
			}
		}

		// Format using same logic as HtmlIndex.cfc
		// For auto mode, use independent auto-selection for the total time (not just pass "auto")
		var totalTimeUnit = (arguments.expectedDisplayUnit == "auto") ? "auto" : arguments.expectedDisplayUnit;
		var totalTimeFormatter = new lucee.extension.lcov.reporter.TimeFormatter();
		var expectedTotalDisplay = totalTimeFormatter.formatTime(totalExecutionTimeMicroseconds, totalTimeUnit, true);

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

	/**
	 * Validates execution time formatting includes commas for values >= 1000
	 */
	public void function validateExecutionTimeFormatting(required string cellText, required string displayUnit) {
		// Extract numeric part (remove commas and units if present)
		var numericPart = reReplace(arguments.cellText, "\s+[a-zA-Zμ]+$", "");
		var cleanValue = reReplace(numericPart, ",", "", "all");

		// Must be numeric after cleaning
		expect(isNumeric(cleanValue)).toBeTrue("Execution time cell value should be numeric: '" & arguments.cellText & "'");

		var numericValue = parseNumber(cleanValue);

		// Values >= 1000 should have comma separators (only if they would naturally have them)
		if (numericValue >= 1000) {
			expect(arguments.cellText).toInclude(",", "Values >= 1000 should include comma separators: '" & arguments.cellText & "' (value: " & numericValue & ")");
		} else {
			// Values < 1000 should NOT have commas
			expect(arguments.cellText).notToInclude(",", "Values < 1000 should not include comma separators: '" & arguments.cellText & "' (value: " & numericValue & ")");
		}

		// In auto mode, execution time cells should include units
		// In explicit mode, execution time cells should NOT include units (units are in headers)
		if (arguments.displayUnit == "auto") {
			// Auto mode: cells should have units
			var hasUnit = find("μs", arguments.cellText) || find("ms", arguments.cellText) || find(" s", arguments.cellText) || find("ns", arguments.cellText);
			expect(hasUnit).toBeTrue("Auto mode execution time cells should include units: '" & arguments.cellText & "'");
		} else {
			// Explicit mode: cells should NOT have units
			var hasUnit = find("μs", arguments.cellText) || find("ms", arguments.cellText) || find(" s", arguments.cellText) || find("ns", arguments.cellText);
			expect(hasUnit).toBeFalse("Explicit mode execution time cells should NOT include units: '" & arguments.cellText & "' (displayUnit: " & arguments.displayUnit & ")");
		}
	}

	/**
	 * Validates that individual line execution times sum to the file total
	 */
	public void function validateExecutionTimeTotals(required string reportPath) {
		// Find corresponding JSON file
		var jsonPath = replace(arguments.reportPath, ".html", ".json");
		expect(fileExists(jsonPath)).toBeTrue("Corresponding JSON file should exist");

		// Read and parse JSON data
		var jsonContent = fileRead(jsonPath);
		var jsonData = deserializeJSON(jsonContent);

		// Get coverage data for first file
		var coverageData = jsonData.coverage["0"];

		// Sum up all line execution times
		var lineTimeTotal = 0;
		var lineCount = 0;

		for (var lineNum in coverageData) {
			var lineData = coverageData[lineNum];
			if (arrayLen(lineData) >= 2) {
				lineTimeTotal += lineData[2]; // execution time is second element
				lineCount++;
			}
		}

		// Get file total from metadata - look for it in various locations
		var fileTotal = 0;
		if (structKeyExists(jsonData, "executionTime")) {
			fileTotal = jsonData.executionTime;
		} else if (structKeyExists(jsonData, "metadata") && structKeyExists(jsonData.metadata, "executionTime")) {
			fileTotal = jsonData.metadata.executionTime;
		} else if (structKeyExists(jsonData, "files") && structKeyExists(jsonData.files, "0") && structKeyExists(jsonData.files["0"], "executionTime")) {
			// files is a struct with string keys "0", "1", etc.
			fileTotal = jsonData.files["0"].executionTime;
		} else {
			// Skip validation if we can't find the file total
			return;
		}

		// Compare totals
		if (fileTotal > 0 && lineTimeTotal > 0) {
			var difference = abs(fileTotal - lineTimeTotal);
			var percentDiff = (difference / fileTotal) * 100;

			expect(lineTimeTotal).toBe(fileTotal,
				"Line execution times should sum to file total in [" & jsonPath & "]" & chr(10)
				& "Sum of line times: " & lineTimeTotal & chr(10)
				& "File total: " & fileTotal & chr(10)
				& "Difference: " & difference & " (" & numberFormat(percentDiff, '0.00') & "%)" & chr(10)
				& "Lines with data: " & lineCount
			);
		}
	}

	/**
	 * Detects the actual display unit chosen by auto-selection from HTML content
	 * @doc The parsed HTML document
	 * @htmlParser The HTML parser instance
	 * @return String the detected unit symbol (μs, ms, s, etc.)
	 */
	public string function detectActualDisplayUnit(required any doc, required any htmlParser) {
		// First try header - this shows the unit for individual file execution times
		var executionTimeHeaders = arguments.htmlParser.select(arguments.doc, "[data-execution-time-header]");
		if (arrayLen(executionTimeHeaders) > 0) {
			var headerText = trim(arguments.htmlParser.getText(executionTimeHeaders[1]));
			// Extract unit from header like "Execution Time (μs)" or "Execution Time (ms)"
			var unitMatch = reFind("\(([^)]+)\)", headerText, 1, true);
			if (unitMatch.pos[1] > 0) {
				return mid(headerText, unitMatch.pos[2], unitMatch.len[2]);
			}
		}

		// Fallback: check ALL execution time cells to find the most common unit
		var executionTimeCells = arguments.htmlParser.select(arguments.doc, "[data-execution-time-cell]");
		var unitCounts = {};

		for (var cell in executionTimeCells) {
			var cellText = trim(arguments.htmlParser.getText(cell));
			if (cellText != "") {
				var detectedUnit = "";
				if (find("μs", cellText)) detectedUnit = "μs";
				else if (find("ms", cellText)) detectedUnit = "ms";
				else if (find("ns", cellText)) detectedUnit = "ns";
				else if (find(" s", cellText)) detectedUnit = "s";

				if (detectedUnit != "") {
					unitCounts[detectedUnit] = (structKeyExists(unitCounts, detectedUnit) ? unitCounts[detectedUnit] : 0) + 1;
				}
			}
		}

		// Return the most common unit
		var maxCount = 0;
		var mostCommonUnit = "";
		for (var unit in unitCounts) {
			if (unitCounts[unit] > maxCount) {
				maxCount = unitCounts[unit];
				mostCommonUnit = unit;
			}
		}

		if (mostCommonUnit != "") {
			return mostCommonUnit;
		}

		throw("Could not detect display unit from parsed HTML document");
	}

	/**
	 * Validates that child time values are correctly displayed in HTML reports
	 * @outputDir The directory containing generated HTML files
	 * @debug Whether to output debug information
	 */
	public void function validateChildTimeDisplay(required string outputDir, boolean debug = false) {
		// 1. Validate index.html child time column
		validateIndexChildTime(arguments.outputDir, arguments.debug);

		// 2. Validate individual report file child time columns
		validateReportChildTime(arguments.outputDir, arguments.debug);

		// 3. Validate child time consistency between JSON and HTML
		validateChildTimeDataConsistency(arguments.outputDir, arguments.debug);

		// 4. Validate that child time and execution time are mutually exclusive
		validateChildTimeExclusivity(arguments.outputDir);
	}

	/**
	 * Validates child time column in index.html
	 */
	private void function validateIndexChildTime(required string outputDir, boolean debug = false) {
		var indexPath = arguments.outputDir & "index.html";
		expect(fileExists(indexPath)).toBeTrue("Index HTML file should exist");

		var indexContent = fileRead(indexPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(indexContent);

		// Check for child time column header
		var childTimeHeaders = htmlParser.select(doc, "th:contains('Child Time')");
		expect(arrayLen(childTimeHeaders)).toBeGTE(1, "Should have Child Time column header in index.html");

		// Check for own time column header (new addition)
		var ownTimeHeaders = htmlParser.select(doc, "th:contains('Own Time')");
		expect(arrayLen(ownTimeHeaders)).toBeGTE(1, "Should have Own Time column header in index.html");

		// Check for child time data cells
		var childTimeCells = htmlParser.select(doc, "td.child-time");
		expect(arrayLen(childTimeCells)).toBeGT(0, "Should have child time cells in index.html");

		// Check for own time data cells
		var ownTimeCells = htmlParser.select(doc, "td.own-time");
		expect(arrayLen(ownTimeCells)).toBeGT(0, "Should have own time cells in index.html");

		// Validate that child time values are numeric and formatted correctly
		var hasNonZeroChildTime = false;
		var hasNonZeroOwnTime = false;

		for (var i = 1; i <= arrayLen(childTimeCells); i++) {
			var childCell = childTimeCells[i];
			var childText = trim(htmlParser.getText(childCell));
			var childSortValue = htmlParser.getAttr(childCell, "data-sort-value");

			// Get corresponding own time and execution time cells
			var ownCell = (i <= arrayLen(ownTimeCells)) ? ownTimeCells[i] : "";
			var ownText = (ownCell != "") ? trim(htmlParser.getText(ownCell)) : "";
			var ownSortValue = (ownCell != "") ? htmlParser.getAttr(ownCell, "data-sort-value") : "0";

			// Get execution time from same row
			var row = htmlParser.select(doc, "tr[data-file-row]:nth-of-type(" & i & ")");
			var execCell = arrayLen(row) > 0 ? htmlParser.select(row[1], "[data-execution-time-cell]") : [];
			var execSortValue = arrayLen(execCell) > 0 ? htmlParser.getAttr(execCell[1], "data-value") : "0";

			if (childText != "" && childSortValue != "0") {
				hasNonZeroChildTime = true;

				// Child time should be formatted with commas for values >= 1000
				var numericValue = parseNumber(childSortValue);
				if (numericValue >= 1000) {
					expect(childText).toInclude(",", "Child time >= 1000 should have comma separators: " & childText);
				}

				// Verify sort value matches displayed value (without commas)
				var cleanDisplayValue = reReplace(childText, "[^0-9]", "", "all");
				expect(cleanDisplayValue).toBe(childSortValue, "Child time display should match sort value");
			}

			if (ownText != "" && ownSortValue != "0") {
				hasNonZeroOwnTime = true;
			}

			// Validate Own Time = Execution Time - Child Time
			if (isNumeric(execSortValue) && isNumeric(childSortValue) && isNumeric(ownSortValue)) {
				var expectedOwnTime = parseNumber(execSortValue) - parseNumber(childSortValue);
				if (expectedOwnTime < 0) expectedOwnTime = 0;

				expect(parseNumber(ownSortValue)).toBe(expectedOwnTime,
					"Own time should equal execution time minus child time. " &
					"Exec: " & execSortValue & ", Child: " & childSortValue &
					", Own: " & ownSortValue & ", Expected Own: " & expectedOwnTime);
			}
		}

		// For tests with function calls, we should have non-zero child time
		if (arguments.debug) {
			systemOutput("Index has non-zero child time: " & hasNonZeroChildTime, true);
			systemOutput("Index has non-zero own time: " & hasNonZeroOwnTime, true);
		}
	}

	/**
	 * Validates child time columns in individual report files
	 */
	private void function validateReportChildTime(required string outputDir, boolean debug = false) {
		var reportFiles = directoryList(arguments.outputDir, false, "path", "*.html");

		for (var reportPath in reportFiles) {
			if (findNoCase("index.html", reportPath)) continue;

			var reportContent = fileRead(reportPath);
			var htmlParser = new testAdditional.HtmlParser();
			var doc = htmlParser.parseHtml(reportContent);

			// Check for child time column header
			var childTimeHeaders = htmlParser.select(doc, "th:contains('Child Time')");
			expect(arrayLen(childTimeHeaders)).toBeGTE(1,
				"Should have Child Time column header in report: " & getFileFromPath(reportPath));

			// Get line rows with time data
			var lineRows = htmlParser.select(doc, "[data-line-row]");
			var childTimeCount = 0;
			var executionOnlyCount = 0;

			for (var row in lineRows) {
				var childTimeCell = htmlParser.select(row, "td.child-time");
				var execTimeCell = htmlParser.select(row, "td.execution-time");

				if (arrayLen(childTimeCell) > 0 && arrayLen(execTimeCell) > 0) {
					var childText = trim(htmlParser.getText(childTimeCell[1]));
					var execText = trim(htmlParser.getText(execTimeCell[1]));

					if (childText != "") {
						childTimeCount++;
						// If there's child time, execution time cell should be empty
						expect(execText).toBe("",
							"Line with child time should have empty execution time in " &
							getFileFromPath(reportPath) & " at line " &
							htmlParser.getAttr(row, "data-line-number"));
					} else if (execText != "") {
						executionOnlyCount++;
						// If there's execution time, child time should be empty
						expect(childText).toBe("",
							"Line with execution time should have empty child time in " &
							getFileFromPath(reportPath) & " at line " &
							htmlParser.getAttr(row, "data-line-number"));
					}
				}
			}

			if (arguments.debug) {
				systemOutput("Report " & getFileFromPath(reportPath) &
					" - Lines with child time: " & childTimeCount &
					", Lines with execution time only: " & executionOnlyCount, true);
			}
		}
	}

	/**
	 * Validates that child time data in HTML matches JSON data
	 */
	private void function validateChildTimeDataConsistency(required string outputDir, boolean debug = false) {
		// Check index.json for child time totals
		var indexJsonPath = arguments.outputDir & "index.json";
		if (fileExists(indexJsonPath)) {
			var indexData = deserializeJSON(fileRead(indexJsonPath));

			// Read index.html
			var indexHtmlPath = arguments.outputDir & "index.html";
			var htmlContent = fileRead(indexHtmlPath);
			var htmlParser = new testAdditional.HtmlParser();
			var doc = htmlParser.parseHtml(htmlContent);

			var reportRows = htmlParser.select(doc, "[data-file-row]");

			for (var row in reportRows) {
				var htmlFile = htmlParser.getAttr(row, "data-html-file");
				var childTimeCell = htmlParser.select(row, "td.child-time");

				if (arrayLen(childTimeCell) > 0) {
					var sortValue = htmlParser.getAttr(childTimeCell[1], "data-sort-value");
					var htmlChildTime = isNumeric(sortValue) ? parseNumber(sortValue) : 0;

					// Find matching report in JSON
					for (var report in indexData) {
						if (structKeyExists(report, "htmlFile") && report.htmlFile == htmlFile) {
							if (structKeyExists(report, "totalChildTime")) {
								expect(htmlChildTime).toBe(report.totalChildTime,
									"Child time mismatch for " & htmlFile &
									" - HTML: " & htmlChildTime & ", JSON: " & report.totalChildTime);
							}
							break;
						}
					}
				}
			}
		}

		// Check individual report JSON files
		var jsonFiles = directoryList(arguments.outputDir, false, "path", "*.json");

		for (var jsonPath in jsonFiles) {
			if (findNoCase("index.json", jsonPath)) continue;

			var jsonData = deserializeJSON(fileRead(jsonPath));
			var htmlPath = replace(jsonPath, ".json", ".html");

			if (fileExists(htmlPath) && structKeyExists(jsonData, "coverage")) {
				var totalChildTimeFromLines = 0;
				var totalExecutionTime = 0;

				// Sum up child time from coverage data
				for (var fileIdx in jsonData.coverage) {
					var fileCoverage = jsonData.coverage[fileIdx];
					for (var lineNum in fileCoverage) {
						var lineData = fileCoverage[lineNum];
						if (arrayLen(lineData) >= 2) {
							totalExecutionTime += lineData[2];
							// Check if line has child time flag (3rd element)
							if (arrayLen(lineData) >= 3 && lineData[3] == true) {
								totalChildTimeFromLines += lineData[2]; // Add execution time as child time
							}
						}
					}
				}

				// Validate child time against HTML
				var reportContent = fileRead(htmlPath);
				var htmlParser = new testAdditional.HtmlParser();
				var reportDoc = htmlParser.parseHtml(reportContent);

				// Check individual line child times
				for (var fileIdx in jsonData.coverage) {
					var fileSection = htmlParser.select(reportDoc, "[data-file-section][data-file-index='" & fileIdx & "']");
					if (arrayLen(fileSection) == 0) continue;

					var fileCoverage = jsonData.coverage[fileIdx];
					for (var lineNum in fileCoverage) {
						var lineData = fileCoverage[lineNum];
						if (arrayLen(lineData) >= 3) {
							var isChildTime = lineData[3];
							var lineRow = htmlParser.select(fileSection[1], "[data-line-row][data-line-number='" & lineNum & "']");

							if (arrayLen(lineRow) > 0) {
								var childCell = htmlParser.select(lineRow[1], "td.child-time");
								var execCell = htmlParser.select(lineRow[1], "td.execution-time");

								if (arrayLen(childCell) > 0 && arrayLen(execCell) > 0) {
									var childText = trim(htmlParser.getText(childCell[1]));
									var execText = trim(htmlParser.getText(execCell[1]));

									if (isChildTime == true) {
										// Should have child time, not execution time
										expect(childText != "").toBeTrue(
											"Line " & lineNum & " marked as child time in JSON should show child time in HTML");
										expect(execText == "").toBeTrue(
											"Line " & lineNum & " marked as child time should not show execution time");
									} else {
										// Should have execution time, not child time
										expect(execText != "" || lineData[2] == 0).toBeTrue(
											"Line " & lineNum & " not marked as child time should show execution time (unless zero)");
										expect(childText == "").toBeTrue(
											"Line " & lineNum & " not marked as child time should not show child time");
									}
								}
							}
						}
					}
				}

				if (arguments.debug) {
					systemOutput("File " & getFileFromPath(jsonPath) &
						" - Total execution time: " & totalExecutionTime &
						", Total child time: " & totalChildTimeFromLines, true);
				}
			}
		}
	}

	/**
	 * Validates that child time and execution time are mutually exclusive per line
	 */
	public void function validateChildTimeExclusivity(required string outputDir) {
		var reportFiles = directoryList(arguments.outputDir, false, "path", "*.html");

		for (var reportPath in reportFiles) {
			if (findNoCase("index.html", reportPath)) continue;

			var reportContent = fileRead(reportPath);
			var htmlParser = new testAdditional.HtmlParser();
			var doc = htmlParser.parseHtml(reportContent);

			var lineRows = htmlParser.select(doc, "[data-line-row]");

			for (var row in lineRows) {
				var execTimeCell = htmlParser.select(row, "td.execution-time");
				var childTimeCell = htmlParser.select(row, "td.child-time");

				if (arrayLen(execTimeCell) > 0 && arrayLen(childTimeCell) > 0) {
					var execText = trim(htmlParser.getText(execTimeCell[1]));
					var childText = trim(htmlParser.getText(childTimeCell[1]));
					var lineNum = htmlParser.getAttr(row, "data-line-number");

					// A line should have EITHER execution time OR child time, not both
					if (execText != "" && childText != "") {
						fail("Line " & lineNum & " should not have both execution and child time in " &
							 getFileFromPath(reportPath) &
							 " - Exec: " & execText & ", Child: " & childText);
					}
				}
			}
		}
	}

}