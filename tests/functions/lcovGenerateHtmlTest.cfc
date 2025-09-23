component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		
		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateHtmlTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getGeneratedArtifactsDir();
		
		variables.outputDir = variables.tempDir & "/output";
		directoryCreate(variables.outputDir);
	}

	// Leave test artifacts for inspection - no cleanup in afterAll


	function run() {
		describe("lcovGenerateHtml with minimal parameters", function() {
			it("should generate HTML reports when given execution logs", function() {
				// Given - execution log data exists
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-minimal";
				directoryCreate(outputDir);

				// When - I generate HTML reports with minimal parameters
				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				// Then - it should return a result with required structure
				expect(result).toBeStruct();
				expect(result).toHaveKey("htmlIndex");
				expect(result).toHaveKey("stats");

				// And - HTML files should be created
				expect(fileExists(result.htmlIndex)).toBeTrue("HTML index should be created");
				expect(result.htmlIndex).toInclude("index.html", "Should be index.html file");

				// And - stats should have expected structure
				expect(result.stats).toHaveKey("totalLinesFound");
				expect(result.stats).toHaveKey("totalLinesHit");
				expect(result.stats).toHaveKey("totalLinesSource");
				expect(result.stats).toHaveKey("coveragePercentage");
				expect(result.stats).toHaveKey("totalFiles");
				expect(result.stats).toHaveKey("processingTimeMs");
			});
		});
	
		describe("lcovGenerateHtml with display options", function() {
			it("should respect display options when generating HTML reports", function() {
				// Given - execution logs and display options
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-display";
				directoryCreate(outputDir);
				var options = {
					displayUnit: "milli"
				};

				// When - I generate HTML with display options
				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				// Then - it should return a valid result
				expect(result).toBeStruct();
				expect(result).toHaveKey("htmlIndex");
				expect(fileExists(result.htmlIndex)).toBeTrue();

				// And - HTML content should be valid
				var indexContent = fileRead(result.htmlIndex);
				expect(indexContent).toInclude("html", "Should be valid HTML");
			});
		});

		describe("lcovGenerateHtml with filtering options", function() {
			it("should apply allow and block list filters", function() {
				// Given - execution logs and filtering options
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-filtered";
				directoryCreate(outputDir);
				var options = {
					allowList: ["/test"],
					blocklist: ["/vendor", "/testbox"]
				};

				// When - I generate HTML with filters
				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				// Then - it should return filtered results
				expect(result).toBeStruct();
				expect(result).toHaveKey("stats");

				// And - should have processed files matching allowList
				expect(result.stats.totalFiles).toBeGTE(0);
			});
		});

		describe("lcovGenerateHtml with invalid log directory", function() {
			it("should throw an exception when log directory does not exist", function() {
				// Given - a non-existent log directory
				var invalidLogDir = "/non/existent/directory";
				var outputDir = variables.outputDir & "/html-invalid";

				// When/Then - I generate HTML with invalid directory, it should throw
				expect(function() {
					lcovGenerateHtml(
						executionLogDir=invalidLogDir,
						outputDir=outputDir
					);
				}).toThrow();
			});
		});

		describe("lcovGenerateHtml content structure validation", function() {
			it("should generate HTML with proper coverage data structure", function() {
				// Given - execution log data
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-content";
				directoryCreate(outputDir);

				// When - I generate HTML reports
				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				// Then - HTML index should exist
				expect(fileExists(result.htmlIndex)).toBeTrue();

				// And - HTML should have proper structure
				var indexContent = fileRead(result.htmlIndex);
				var doc = htmlParse(indexContent);

				// And - should have root html element
				var htmlNodes = xmlSearch(doc, "//*[local-name()='html']");
				expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element");

				// And - should have coverage summary section
				var summaryNodes = xmlSearch(doc, "//*[@data-coverage-summary]");
				expect(arrayLen(summaryNodes)).toBeGTE(1, "Should have a coverage summary section");

				// And - should show percentage coverage
				var foundPercent = false;
				for (var node in summaryNodes) {
					if (find("%", node.xmlText)) foundPercent = true;
				}
				expect(foundPercent).toBeTrue("Should show percentage coverage in summary");
			});
		});

		describe("lcovGenerateHtml with empty log directory", function() {
			it("should handle empty log directory gracefully", function() {
				// Given - an empty execution log directory
				var emptyLogDir = variables.tempDir & "/empty-logs";
				directoryCreate(emptyLogDir);
				var outputDir = variables.outputDir & "/html-empty";
				directoryCreate(outputDir);

				// When - I generate HTML from empty directory
				var result = lcovGenerateHtml(
					executionLogDir=emptyLogDir,
					outputDir=outputDir
				);

				// Then - it should return a valid result
				expect(result).toBeStruct();
				expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");

				// And - should still create an index.html
				expect(result).toHaveKey("htmlIndex");
			});
		});

		describe("lcovGenerateHtml with blocklist", function() {
			it("should exclude blocked files from processing", function() {
				// Given - execution logs and blocklist options
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-blocked";
				directoryCreate(outputDir);
				var options = {
					blocklist: ["artifacts"]
				};

				// When - I generate HTML with blocklist
				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				// Then - it should exclude blocked files
				expect(result).toBeStruct();
				expect(result.stats.totalFiles).toBe(0, result.stats);
			});
		});

		describe("lcovGenerateHtml with multiple files", function() {
			it("should process all available files", function() {
				// Given - multiple execution log files exist
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-multiple";
				directoryCreate(outputDir);

				// When - I generate HTML from multiple files
				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				// Then - it should process multiple files
				expect(result).toBeStruct();
				expect(result.stats.totalFiles).toBeGTE(1, "Should process multiple files");
				expect(fileExists(result.htmlIndex)).toBeTrue();

				// And - should create individual HTML files
				var files = directoryList(outputDir, false, "query", "*.html");
				expect(files.recordCount).toBeGTE(1, "Should create individual HTML files");
			});
		});
	}
}