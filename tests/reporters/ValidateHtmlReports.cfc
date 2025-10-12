component {

	/**
	 * Single entry point for validating HTML reports against JSON source data
	 * Used as a mixin, all methods should be public
	 *
	 * @outputDir Directory containing HTML and JSON report files
	 * @sourceUnit The source unit from execution logs (nano, micro, milli, second)
	 * @expectedDisplayUnit The expected time display unit (ms, μs, s, ns, auto)
	 * @debug Whether to output debug information
	 */
	public void function validateHtmlReports(required string outputDir, required string sourceUnit, required string expectedDisplayUnit, boolean debug = false) {
		// Validate index page
		var indexHtmlPath = arguments.outputDir & "index.html";
		var indexJsonPath = arguments.outputDir & "index.json";
		validateIndexPage(indexHtmlPath, indexJsonPath, arguments.expectedDisplayUnit, arguments.debug);

		// Validate detail pages
		validateDetailPages(arguments.outputDir, arguments.expectedDisplayUnit, arguments.debug);
	}

	/**
	 * Validates index.html against index.json
	 * Loops through each row once and validates all cells against JSON data
	 */
	public void function validateIndexPage(required string indexHtmlPath, required string indexJsonPath, required string expectedDisplayUnit, boolean debug = false) {
		expect(fileExists(arguments.indexHtmlPath)).toBeTrue("Index HTML file should exist [#arguments.indexHtmlPath#]");
		expect(fileExists(arguments.indexJsonPath)).toBeTrue("Index JSON file should exist [#arguments.indexJsonPath#]");

		// Parse HTML and JSON once
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(fileRead(arguments.indexHtmlPath));
		var indexData = deserializeJSON(fileRead(arguments.indexJsonPath));

		// Validate structure
		var htmlNodes = htmlParser.select(doc, "html");
		expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element in [#arguments.indexHtmlPath#]");

		// Validate headers
		validateIndexHeaders(doc, htmlParser, arguments.expectedDisplayUnit, arguments.indexHtmlPath);

		// Get all file rows
		var rows = htmlParser.select(doc, "tr[data-file-row]");
		expect(arrayLen(rows)).toBeGT(0, "Should have file rows in [#arguments.indexHtmlPath#]");

		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.expectedDisplayUnit);
		var hasNonZeroChildTime = false;
		var hasNonZeroOwnTime = false;

		// Loop through each row and validate against JSON
		for (var row in rows) {
			var htmlFile = htmlParser.getAttr(row, "data-html-file");
			var scriptName = htmlParser.getAttr(row, "data-script-name");

			// Find matching report in JSON
			var jsonReport = findJsonReportByHtmlFile(indexData, htmlFile);
			if (isNull(jsonReport)) {
				fail("No matching JSON entry found for HTML file: #htmlFile#");
			}

			// Get cells from this row
			var execTimeCells = htmlParser.select(row, "[data-execution-time-cell]");
			expect(arrayLen(execTimeCells)).toBe(1, "Each row should have one execution-time cell");

			var childTimeCells = htmlParser.select(row, "td.child-time");
			expect(arrayLen(childTimeCells)).toBe(1, "Each row should have one child-time cell");

			var ownTimeCells = htmlParser.select(row, "td.own-time");
			expect(arrayLen(ownTimeCells)).toBe(1, "Each row should have one own-time cell");

			// Validate execution time cell
			var execCell = execTimeCells[1];
			var execHtmlText = trim(htmlParser.getText(execCell));
			var execDataValue = htmlParser.getAttr(execCell, "data-value");

			// Get source unit from JSON report
			var sourceUnit = jsonReport.unit;

			// Use stats.totalExecutionTime (calculated as ownTime + childTime from coverage data)
			if (structKeyExists(jsonReport, "stats") && structKeyExists(jsonReport.stats, "totalExecutionTime")) {
				var executionTimeMicros = timeFormatter.convertTime(jsonReport.stats.totalExecutionTime, sourceUnit, "μs");
				var expectedTimeFormatted = timeFormatter.format(executionTimeMicros);

				if (execHtmlText != "") {
					expect(execHtmlText).toBe(expectedTimeFormatted,
						"Execution time mismatch for #scriptName# - HTML: '#execHtmlText#', Expected: '#expectedTimeFormatted#'");
				}

				// Validate data-value attribute
				expect(execDataValue).toBe(toString(executionTimeMicros),
					"Execution time data-value mismatch for #scriptName#");

				// CRITICAL: totalExecutionTime should never exceed request execution-time (metadata)
				if (structKeyExists(jsonReport, "metadata") && structKeyExists(jsonReport.metadata, "execution-time") && isNumeric(jsonReport.metadata["execution-time"])) {
					var requestExecutionTimeMicros = timeFormatter.convertTime(jsonReport.metadata["execution-time"], sourceUnit, "μs");
					expect(executionTimeMicros).toBeLTE(requestExecutionTimeMicros,
						"Total Execution Time (#executionTimeMicros# μs = #numberFormat(executionTimeMicros/1000, '0.000')# ms) should not exceed Request Execution Time from metadata (#requestExecutionTimeMicros# μs = #numberFormat(requestExecutionTimeMicros/1000, '0.000')# ms) for #scriptName#");
				}
			}

			// Validate child time cell
			var childCell = childTimeCells[1];
			var childHtmlText = trim(htmlParser.getText(childCell));
			var childSortValue = htmlParser.getAttr(childCell, "data-sort-value");

			if (structKeyExists(jsonReport, "totalChildTime") && isNumeric(jsonReport.totalChildTime)) {
				var childTimeSourceUnit = jsonReport.totalChildTime;
				// Convert from source unit to microseconds for comparison (same as production code)
				var childTimeMicros = timeFormatter.convertTime(childTimeSourceUnit, sourceUnit, "μs");
				// Format using same logic as production (format expects microseconds)
				var expectedChildFormatted = timeFormatter.format(childTimeMicros);

				if (childHtmlText != "" && childSortValue != "0") {
					hasNonZeroChildTime = true;
					expect(childHtmlText).toBe(expectedChildFormatted,
						"Child time mismatch for #scriptName# - HTML: '#childHtmlText#', Expected: '#expectedChildFormatted#'");
				}

				// Validate data-sort-value (should be in microseconds)
				expect(childSortValue).toBe(toString(childTimeMicros),
					"Child time data-sort-value mismatch for #scriptName#");
			}

			// Validate own time cell (Own = Exec - Child)
			var ownCell = ownTimeCells[1];
			var ownHtmlText = trim(htmlParser.getText(ownCell));
			var ownSortValue = htmlParser.getAttr(ownCell, "data-sort-value");

			if (isNumeric(execDataValue) && isNumeric(childSortValue)) {
				var execTime = parseNumber(execDataValue);
				var childTime = parseNumber(childSortValue);

				// CRITICAL: childTime should NEVER exceed totalExecutionTime
				// If it does, the math breaks: Own = Total - Child would be negative
				expect(childTime).toBeLTE(execTime,
					"Child time (#childTime# μs) should not exceed total execution time (#execTime# μs) for #scriptName#. This breaks the calculation: Own = Total - Child!");

				// Calculate expected own time
				var expectedOwnTime = max(execTime - childTime, 0);

				// Validate own time data attribute (with tolerance for floating point precision)
				var actualOwnTime = parseNumber(ownSortValue);
				var tolerance = 0.01; // Allow 0.01 microsecond difference for floating point precision
				expect(abs(actualOwnTime - expectedOwnTime)).toBeLTE(tolerance,
					"Own time should be (Exec - Child) = (#execTime# - #childTime#) = #expectedOwnTime# for #scriptName#, but got #ownSortValue# (diff: #abs(actualOwnTime - expectedOwnTime)#)");

				if (ownHtmlText != "" && ownSortValue != "0") {
					hasNonZeroOwnTime = true;
					// Use timeFormatter.format() same as production code
					var expectedOwnFormatted = timeFormatter.format(expectedOwnTime);
					expect(ownHtmlText).toBe(expectedOwnFormatted,
						"Own time display mismatch for #scriptName# - HTML: '#ownHtmlText#', Expected: '#expectedOwnFormatted#'");
				}
			}
		}

		// Validate total execution time in summary matches sum of all reports
		var summaryElements = htmlParser.select(doc, ".summary .total-execution-time");
		expect(arrayLen(summaryElements)).toBe(1, "Should have one .total-execution-time in summary");
		var summaryTimeText = trim(htmlParser.getText(summaryElements[1]));

		// Calculate expected total from JSON
		var expectedTotalMicros = 0;
		for (var entry in indexData) {
			if (structKeyExists(entry, "totalExecutionTime") && isNumeric(entry.totalExecutionTime)) {
				var sourceUnit = entry.unit;
				var timeMicros = timeFormatter.convertTime(entry.totalExecutionTime, sourceUnit, "μs");
				expectedTotalMicros += timeMicros;
			}
		}
		var expectedTotalFormatted = timeFormatter.formatTime(expectedTotalMicros, arguments.expectedDisplayUnit, true);
		expect(summaryTimeText).toBe(expectedTotalFormatted,
			"Summary total execution time mismatch - HTML: '#summaryTimeText#', Expected: '#expectedTotalFormatted#' (sum of all reports)");

		// Ensure we found some non-zero values
		if (arguments.debug) {
			systemOutput("Index has non-zero child time: #hasNonZeroChildTime#", true);
			systemOutput("Index has non-zero own time: #hasNonZeroOwnTime#", true);
		}

		// IMPORTANT: Validate that if detail pages have childTime, the index aggregates it correctly
		// This catches bugs where CoverageStats doesn't aggregate childTime properly
		for (var row in rows) {
			var htmlFile = htmlParser.getAttr(row, "data-html-file");
			var jsonReport = findJsonReportByHtmlFile(indexData, htmlFile);
			if (!isNull(jsonReport) && structKeyExists(jsonReport, "totalChildTime")) {
				var indexChildTime = jsonReport.totalChildTime;

				// Load the detail page JSON to check if it has any childTime
				var detailJsonPath = getDirectoryFromPath(arguments.indexHtmlPath) & replace(htmlFile, ".html", ".json");
				if (fileExists(detailJsonPath)) {
					var detailData = deserializeJSON(fileRead(detailJsonPath));
					var detailHasChildTime = false;
					var detailChildTimeSum = 0;

					// Check all coverage data for childTime values
					if (structKeyExists(detailData, "coverage")) {
						for (var fileIdx in detailData.coverage) {
							var fileCoverage = detailData.coverage[fileIdx];
							for (var lineNum in fileCoverage) {
								var lineData = fileCoverage[lineNum];
								var childTime = lineData[3];
								if (childTime > 0) {
									detailHasChildTime = true;
									detailChildTimeSum += childTime;
								}
							}
						}
					}

					// If detail has childTime, index MUST have totalChildTime > 0
					if (detailHasChildTime && indexChildTime == 0) {
						fail("Detail page #htmlFile# has childTime values (sum=#detailChildTimeSum#) but index shows totalChildTime=0. CoverageStats is not aggregating childTime correctly!");
					}
				}
			}
		}
	}

	/**
	 * Validates all detail report pages against their corresponding JSON files
	 */
	public void function validateDetailPages(required string outputDir, required string expectedDisplayUnit, boolean debug = false) {
		var reportFiles = directoryList(arguments.outputDir, false, "path", "request-*.html");
		expect(arrayLen(reportFiles)).toBeGT(0, "Should have report files in [#arguments.outputDir#]");

		for (var reportHtmlPath in reportFiles) {
			var reportJsonPath = replace(reportHtmlPath, ".html", ".json");
			expect(fileExists(reportJsonPath)).toBeTrue("Corresponding JSON file should exist for [#reportHtmlPath#]");

			validateDetailPage(reportHtmlPath, reportJsonPath, arguments.expectedDisplayUnit, arguments.debug);
		}
	}

	/**
	 * Validates a single detail report page against its JSON file
	 * Loops through each row once and validates cells against JSON coverage data
	 */
	public void function validateDetailPage(required string reportHtmlPath, required string reportJsonPath, required string expectedDisplayUnit, boolean debug = false) {
		// Parse HTML and JSON once
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(fileRead(arguments.reportHtmlPath));
		var jsonData = deserializeJSON(fileRead(arguments.reportJsonPath));

		var sourceUnit = jsonData.metadata.unit;
		expect(sourceUnit).notToBeEmpty("JSON should have unit metadata in [#arguments.reportJsonPath#]");

		// Validate headers
		validateDetailHeaders(doc, htmlParser, arguments.expectedDisplayUnit, arguments.reportHtmlPath);

		// Get file sections (reports can contain multiple files)
		var fileSections = htmlParser.select(doc, "[data-file-section][data-file-index]");
		expect(arrayLen(fileSections)).toBeGT(0, "Should have file sections in [#arguments.reportHtmlPath#]");

		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.expectedDisplayUnit);

		// Process each file section
		for (var fileSection in fileSections) {
			var fileIndex = htmlParser.getAttr(fileSection, "data-file-index");
			var coverageData = jsonData.coverage[fileIndex];

			// Get all line rows in this file section
			var lineRows = htmlParser.select(fileSection, "[data-line-row][data-line-number]");

			for (var row in lineRows) {
				var lineNumber = htmlParser.getAttr(row, "data-line-number");

				// Validate CSS class based on coverage data
				var rowClass = htmlParser.getAttr(row, "class");
				if (structKeyExists(coverageData, lineNumber) && arrayLen(coverageData[lineNumber]) > 0) {
					var hitCount = coverageData[lineNumber][1];
					var ownTime = coverageData[lineNumber][2];
					var childTime = coverageData[lineNumber][3];

					if (hitCount > 0) {
						// Check for exact "executed" class (not "not-executed")
						expect(rowClass).toBe("executed",
							"Line #lineNumber# with hitCount=#hitCount# should have class 'executed' but got '#rowClass#' in [#arguments.reportHtmlPath#]");

						// NOTE: We don't validate time > 0 because lines can execute too fast to measure (execTime=0)
						// This is especially common with simple assignments, returns, or very fast operations
					} else {
						// Check for exact "not-executed" class
						expect(rowClass).toBe("not-executed",
							"Line #lineNumber# with hitCount=0 should have class 'not-executed' but got '#rowClass#' in [#arguments.reportHtmlPath#]");

						// Not executed lines should have 0 time
						expect(ownTime).toBe(0,
							"Line #lineNumber# with hitCount=0 should have ownTime=0 but got #ownTime# in [#arguments.reportHtmlPath#]");
						expect(childTime).toBe(0,
							"Line #lineNumber# with hitCount=0 should have childTime=0 but got #childTime# in [#arguments.reportHtmlPath#]");
					}
				} else {
					// Check for exact "non-executable" class
					expect(rowClass).toBe("non-executable",
						"Line #lineNumber# not in coverage should have class 'non-executable' but got '#rowClass#' in [#arguments.reportHtmlPath#]");
				}

				// Get execution time cell and child time cell
				var execTimeCells = htmlParser.select(row, "[data-execution-time-cell]");
				var childTimeCells = htmlParser.select(row, "td.child-time");

				// Both should exist (mutually exclusive)
				expect(arrayLen(execTimeCells)).toBe(1, "Each row should have one execution-time cell in line #lineNumber#");
				expect(arrayLen(childTimeCells)).toBe(1, "Each row should have one child-time cell in line #lineNumber#");

				var execHtmlText = trim(htmlParser.getText(execTimeCells[1]));
				var childHtmlText = trim(htmlParser.getText(childTimeCells[1]));

				// Find matching line in JSON coverage data
				// NEW FORMAT: [hitCount, ownTime, childTime] - both ownTime and childTime can be present
				if (structKeyExists(coverageData, lineNumber) && arrayLen(coverageData[lineNumber]) >= 2) {
					var ownTimeNanos = coverageData[lineNumber][2]; // Own time in source unit
					var childTimeNanos = arrayLen(coverageData[lineNumber]) >= 3 ? coverageData[lineNumber][3] : 0; // Child time in source unit

					// Convert to display unit using same logic as production code
					var ownTimeMicros = timeFormatter.convertTime(ownTimeNanos, sourceUnit, "μs");
					var childTimeMicros = timeFormatter.convertTime(childTimeNanos, sourceUnit, "μs");

					// Validate total time (ownTime + childTime)
					var totalTimeMicros = ownTimeMicros + childTimeMicros;
					if (totalTimeMicros > 0) {
						var expectedTotalFormatted = timeFormatter.format(totalTimeMicros);
						expect(execHtmlText).toBe(expectedTotalFormatted,
							"Total time mismatch at line #lineNumber# - HTML: '#execHtmlText#', Expected: '#expectedTotalFormatted#' [#arguments.reportHtmlPath#]");
					} else {
						// No time at all, execution time cell should be empty
						expect(execHtmlText).toBe("",
							"Line #lineNumber# with totalTime=0 should have empty execution time cell [#arguments.reportHtmlPath#]");
					}

					// Validate child time if present
					if (childTimeMicros > 0) {
						var expectedChildFormatted = timeFormatter.format(childTimeMicros);
						expect(childHtmlText).toBe(expectedChildFormatted,
							"Child time mismatch at line #lineNumber# - HTML: '#childHtmlText#', Expected: '#expectedChildFormatted#' [#arguments.reportHtmlPath#]");
					} else {
						// No child time, child time cell should be empty
						expect(childHtmlText).toBe("",
							"Line #lineNumber# with childTime=0 should have empty child time cell [#arguments.reportHtmlPath#]");
					}
				}
			}
		}
	}

	/**
	 * Validates index.html headers
	 */
	public void function validateIndexHeaders(required any doc, required any htmlParser, required string expectedDisplayUnit, required string indexPath) {
		// Execution time header
		var executionTimeHeaders = htmlParser.select(arguments.doc, "[data-execution-time-header]");
		expect(arrayLen(executionTimeHeaders)).toBeGTE(1, "Should have [data-execution-time-header] in [#arguments.indexPath#]");

		var headerText = trim(htmlParser.getText(executionTimeHeaders[1]));
		if (arguments.expectedDisplayUnit == "auto") {
			expect(headerText).toBe("Execution Time", "Auto mode header should not include unit in [#arguments.indexPath#]");
		} else {
			// Normalize unit name to symbol (e.g., "milli" -> "ms") for validation
			var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter();
			var expectedSymbol = timeFormatter.getUnitInfo(arguments.expectedDisplayUnit).symbol;
			expect(headerText).toInclude(expectedSymbol, "Header should include unit symbol '#expectedSymbol#' in [#arguments.indexPath#]");
		}

		// Child time and own time headers should exist
		var allHeaders = htmlParser.select(arguments.doc, "th");
		var headerTexts = [];
		for (var th in allHeaders) {
			arrayAppend(headerTexts, trim(htmlParser.getText(th)));
		}

		var hasChildTimeHeader = false;
		var hasOwnTimeHeader = false;
		for (var text in headerTexts) {
			if (findNoCase("Child Time", text)) hasChildTimeHeader = true;
			if (findNoCase("Own Time", text)) hasOwnTimeHeader = true;
		}

		expect(hasChildTimeHeader).toBeTrue("Should have Child Time header in [#arguments.indexPath#]");
		expect(hasOwnTimeHeader).toBeTrue("Should have Own Time header in [#arguments.indexPath#]");
	}

	/**
	 * Validates detail report headers
	 */
	public void function validateDetailHeaders(required any doc, required any htmlParser, required string expectedDisplayUnit, required string reportPath) {
		// Execution time header
		var executionTimeHeaders = htmlParser.select(arguments.doc, "[data-execution-time-header]");
		expect(arrayLen(executionTimeHeaders)).toBeGTE(1, "Should have [data-execution-time-header] in [#arguments.reportPath#]");

		var headerText = trim(htmlParser.getText(executionTimeHeaders[1]));
		if (arguments.expectedDisplayUnit != "auto") {
			// Normalize unit name to symbol (e.g., "milli" -> "ms") for validation
			var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter();
			var expectedSymbol = timeFormatter.getUnitInfo(arguments.expectedDisplayUnit).symbol;
			expect(headerText).toInclude(expectedSymbol, "Header should include unit symbol '#expectedSymbol#' in [#arguments.reportPath#]");
		}

		// Total execution time in stats
		var totalTimeElements = htmlParser.select(arguments.doc, ".stats .total-execution-time");
		expect(arrayLen(totalTimeElements)).toBeGTE(1, "Should have .total-execution-time in [#arguments.reportPath#]");
	}

	/**
	 * Finds a report entry in index JSON data by HTML file name
	 */
	public any function findJsonReportByHtmlFile(required array indexData, required string htmlFile) {
		for (var report in arguments.indexData) {
			if (structKeyExists(report, "htmlFile") && report.htmlFile == arguments.htmlFile) {
				return report;
			}
		}
		return javaCast("null", "");
	}

}