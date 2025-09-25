component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.parser = variables.factory.getComponent(name="ExecutionLogParser");

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="MinTimeTest");
		variables.tempDir = variables.testDataGenerator.getGeneratedArtifactsDir();

		// Clean up any logging that might be enabled from previous runs
		try {
			lcovStopLogging(adminPassword=variables.adminPassword);
		} catch (any e) {
			// Ignore cleanup errors
		}
	}

	// Leave test artifacts for inspection - no cleanup in afterAll


	function run() {
		xdescribe("Minimum execution time metadata parsing", function() {

			it("parses min-time-nano metadata when unit=nano and minTime=10", function() {
				testMinTimeMetadata(unit="nano", minTime=10, testName="min-time-nano", expectedUnitSymbol="ns", expectedNanoValue=10);
			});

			it("parses min-time-nano metadata when unit=micro and minTime=10", function() {
				testMinTimeMetadata(unit="micro", minTime=10, testName="min-time-nano", expectedUnitSymbol="μs", expectedNanoValue=10);
			});

			it("parses min-time-nano metadata when unit=milli and minTime=10", function() {
				testMinTimeMetadata(unit="milli", minTime=10, testName="min-time-nano", expectedUnitSymbol="ms", expectedNanoValue=10);
			});

			it("parses min-time-nano metadata when unit=second and minTime=10", function() {
				testMinTimeMetadata(unit="second", minTime=10, testName="min-time-nano", expectedUnitSymbol="ns", expectedNanoValue=10);
			});

			it("parses min-time metadata of 0 when minTime not specified", function() {
				testMinTimeMetadata(unit="micro", minTime=0, testName="min-time-nano", expectedUnitSymbol="μs", expectedNanoValue=0);
			});

			it("logs in nanoseconds and reports in milliseconds", function() {
				testMinTimeMetadata(unit="nano", minTime=10, testName="min-time-nano", expectedUnitSymbol="ns", expectedNanoValue=10);
			});

		});

		describe("Minimum execution time metadata parsing", function() {
			it("test static example, known to cause problems", function() {
				var overrideLogDir = expandPath(getDirectoryFromPath(getCurrentTemplatePath()) & "../artifacts/misParse/");
				testMinTimeMetadata(unit="micro", minTime=10, 
					testName="min-time-nano", expectedUnitSymbol="μs", expectedNanoValue=10, overrideLogDir=overrideLogDir);
			});
		});

	}

	/**
	 * Helper function to test minimum time metadata parsing
	 */
	private function testMinTimeMetadata(required string unit, 
			required numeric minTime, required string testName, 
			required string expectedUnitSymbol, 
			required numeric expectedNanoValue, string overrideLogDir="") {
		var testDataGenerator = new "../GenerateTestData"(testName="MinTimeTest-" 
			& arguments.testName );
		var logDir = testDataGenerator.getCoverageDir();

		var executionLogOptions = {
			unit: arguments.unit
		};
		if (arguments.minTime > 0) {
			executionLogOptions["min-time"] = arguments.minTime;
		}

		testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword,
			executionLogOptions=executionLogOptions
		);
		var exlFiles = directoryList(logDir, false, "path", "*.exl");
		expect(arrayLen(exlFiles)).toBeGT(0, "Should have generated at least one .exl file");

		var result = variables.parser.parseExlFile(exlFiles[1]);
		expect(result.getMetadata()).notToBeEmpty("Metadata should not be empty");

		var metadata = result.getMetadata();
		expect(metadata).toHaveKey("min-time-nano", "Metadata should have min-time-nano key");
		expect(metadata["min-time-nano"]).toBe(arguments.expectedNanoValue);
		expect(metadata).toHaveKey("unit");
		expect(metadata.unit).toBe(arguments.expectedUnitSymbol);

		var outputDir = testDataGenerator.getGeneratedArtifactsDir() & "reports/";
		directoryCreate(outputDir);

		// used for testing problematic examples
		if (arguments.overrideLogDir != "") {
			systemOutput("Overriding .exl logDir to: " & arguments.overrideLogDir, true);
			logDir = arguments.overrideLogDir;
		}

		var displayUnit = "μs"; // Default to microseconds
		if (arguments.unit == "second") {
			displayUnit = "s";
		} else if (arguments.unit == "milli") {
			displayUnit = "ms";
		} else if (arguments.unit == "nano") {
			displayUnit = "ms"; // Display nanoseconds as milliseconds
		}

		lcovGenerateHtml(
			executionLogDir = logDir,
			outputDir = outputDir,
			options = { displayUnit = displayUnit, verbose=false }
		);

		validateHtmlExecutionTimeUnits(outputDir, arguments.unit, displayUnit);
	}

	/**
	 * Validates HTML output has correct execution time units and values match JSON data
	 */
	private void function validateHtmlExecutionTimeUnits(required string outputDir, required string testUnit, required string expectedDisplayUnit) {
		// Test index page execution time units
		var indexPath = arguments.outputDir & "index.html";
		expect(fileExists(indexPath)).toBeTrue("Index HTML file should exist");

		var indexContent = fileRead(indexPath);
		var htmlParser = new testAdditional.HtmlParser();
		var doc = htmlParser.parseHtml(indexContent);

		// Should have root html element
		var htmlNodes = htmlParser.select(doc, "html");
		expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element");

		// Should have execution time column header with correct unit
		var executionTimeHeaders = htmlParser.select(doc, "[data-execution-time-header]");
		expect(arrayLen(executionTimeHeaders)).toBeGTE(1);

		var headerText = trim(htmlParser.getText(executionTimeHeaders[1]));
		// Header should show correct display unit
		expect(headerText).toInclude(arguments.expectedDisplayUnit);

		// Should have execution time data cells with numeric values
		var executionTimeCells = htmlParser.select(doc, "[data-execution-time-cell]");
		expect(arrayLen(executionTimeCells)).toBeGTE(1);

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
			expect(arrayLen(totalTimeElements)).toBeGTE(1);

			var totalTimeText = htmlParser.getText(totalTimeElements[1]);
			expect(totalTimeText).toInclude(arguments.expectedDisplayUnit);

			// Should have line-level execution time column with correct unit
			var lineTimeHeaders = htmlParser.select(document, "[data-execution-time-header]");
			expect(arrayLen(lineTimeHeaders)).toBeGTE(1);

			var lineHeaderText = htmlParser.getText(lineTimeHeaders[1]);
			expect(lineHeaderText).toInclude(arguments.expectedDisplayUnit);

			// Verify HTML execution times against JSON data
			validateHtmlTimesAgainstJson(reportPath, arguments.expectedDisplayUnit);
		}
	}

	/**
	 * Validates that HTML execution time values match the JSON data after proper unit conversion
	 */
	private void function validateHtmlTimesAgainstJson(required string reportPath, required string expectedDisplayUnit) {
		// Find corresponding JSON file
		var jsonPath = replace(arguments.reportPath, ".html", ".json");
		expect(fileExists(jsonPath)).toBeTrue("Corresponding JSON file should exist");

		// Read and parse JSON data
		var jsonContent = fileRead(jsonPath);
		var jsonData = deserializeJSON(jsonContent);

		// Get source unit from metadata
		var sourceUnit = jsonData.metadata.unit;
		expect(sourceUnit).notToBeEmpty("JSON should have unit metadata");

		// Get HTML content and parse
		var reportContent = fileRead(arguments.reportPath);
		var htmlParser = new testAdditional.HtmlParser();
		var document = htmlParser.parseHtml(reportContent);

		// Get all line rows with execution data
		var lineRows = htmlParser.select(document, "[data-line-row][data-line-number]");
		expect(arrayLen(lineRows)).toBeGT(0, "Should have line rows");

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
							"Line " & lineNumber & " should show empty for zero execution time");
						verifiedCount++;
					}
				}
			}
		}

		// Ensure we verified at least some lines with execution time data
		expect(verifiedCount).toBeGT(0, "Should have verified at least one line with execution time data");
	}

	/**
	 * Validates that index.html execution time values match the JSON data after proper unit conversion
	 */
	private void function validateIndexTimesAgainstJson(required string outputDir, required string expectedDisplayUnit) {
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
		expect(arrayLen(reportRows)).toBeGT(0, "Should have report rows in index");

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
		expect(verifiedIndexCount).toBeGT(0, "Should have verified at least one index row with execution time data");

		// Validate index.html summary total execution time against JSON data
		var summaryTotalElements = htmlParser.select(doc, ".total-execution-time");
		expect(arrayLen(summaryTotalElements)).toBeGTE(1, "Should have summary total execution time element");

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
	private void function validateExecutionTimeRange(required numeric timeValue, required string displayUnit, required string originalText) {
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