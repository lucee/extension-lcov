component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateHtmlTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		variables.outputDir = variables.tempDir & "/output";
		directoryCreate(variables.outputDir);
	}

	function run() {
		describe("lcovGenerateHtml with minimal parameters", function() {
			it("should generate HTML reports when given execution logs", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-minimal";
				directoryCreate(outputDir);

				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				assertValidHtmlResult( result );
				expect(fileExists(result.htmlIndex)).toBeTrue("HTML index should be created");
				expect(result.htmlIndex).toInclude("index.html", "Should be index.html file");
				assertValidStats( result.stats );
			});
		});
	
		describe("lcovGenerateHtml with display options", function() {
			it("should respect display options when generating HTML reports", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-display";
				directoryCreate(outputDir);
				var options = {
					displayUnit: "milli"
				};

				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidHtmlResult( result );
				expect(fileExists(result.htmlIndex)).toBeTrue();

				var indexContent = fileRead(result.htmlIndex);
				expect(indexContent).toInclude("html", "Should be valid HTML");
			});
		});

		describe("lcovGenerateHtml with filtering options", function() {
			it("should apply allow and block list filters", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-filtered";
				directoryCreate(outputDir);
				var options = {
					allowList: ["/test"],
					blocklist: ["/vendor", "/testbox"]
				};

				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidHtmlResult( result );
				expect(result.stats.totalFiles).toBeGTE(0);
			});
		});

		describe("lcovGenerateHtml with invalid log directory", function() {
			it("should throw an exception when log directory does not exist", function() {
				var invalidLogDir = "/non/existent/directory";
				var outputDir = variables.outputDir & "/html-invalid";

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
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-content";
				directoryCreate(outputDir);

				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				expect(fileExists(result.htmlIndex)).toBeTrue();

				var doc = parseHtmlFile( result.htmlIndex );
				var htmlParser = new testAdditional.HtmlParser();

				var htmlNodes = htmlParser.select(doc, "html");
				expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element");

				var summaryNodes = htmlParser.select(doc, "[data-coverage-summary]");
				expect(arrayLen(summaryNodes)).toBeGTE(1, "Should have a coverage summary section");


				var foundPercent = false;
				for (var node in summaryNodes) {
					var nodeText = htmlParser.getText(node);
					if (find("%", nodeText)) foundPercent = true;
				}
				expect(foundPercent).toBeTrue("Should show percentage coverage in summary");

				var validator = new testAdditional.reporters.ValidateHtmlReports();
				// Add validator methods as mixins so expect() works
				var validatorMeta = getMetaData(validator);
				for (var method in validatorMeta.functions) {
					variables[method.name] = validator[method.name];
				}
				validateHtmlReports(
					outputDir=outputDir & "/",
					sourceUnit="micro",
					expectedDisplayUnit="ms"
				);
			});
		});

		describe("lcovGenerateHtml with empty log directory", function() {
			it("should handle empty log directory gracefully", function() {
				var emptyLogDir = variables.tempDir & "/empty-logs";
				directoryCreate(emptyLogDir);
				var outputDir = variables.outputDir & "/html-empty";
				directoryCreate(outputDir);

				var result = lcovGenerateHtml(
					executionLogDir=emptyLogDir,
					outputDir=outputDir
				);

				assertValidHtmlResult( result );
				expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");
			});
		});

		describe("lcovGenerateHtml with blocklist", function() {
			it("should exclude blocked files from processing", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-blocked";
				directoryCreate(outputDir);
				var options = {
					blocklist: ["artifacts/conditional"]
				};

				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidHtmlResult( result );
				expect(result.stats.totalFiles).toBeGT(0, "Should report at least some files");

				var htmlParser = new testAdditional.HtmlParser();
				var htmlFiles = directoryList(outputDir, false, "name", "*.html");
				for (var htmlFile in htmlFiles) {
					if (htmlFile == "index.html") continue;
					var doc = parseHtmlFile( outputDir & "/" & htmlFile );
					var filePathNodes = htmlParser.select(doc, "[data-file-path]");
					for (var node in filePathNodes) {
						var filePath = node.getAttribute("data-file-path");
						var normalizedPath = normalizePath( filePath );
						if (findNoCase(options.blocklist[1], normalizedPath) > 0) {
							fail("Found blocklisted file in HTML report: " & filePath);
						}
					}
				}
			});
		});

		describe("lcovGenerateHtml with multiple files", function() {
			it("should process all available files", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/html-multiple";
				directoryCreate(outputDir);

				var result = lcovGenerateHtml(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				assertValidHtmlResult( result );
				expect(result.stats.totalFiles).toBeGTE(1, "Should process multiple files");
				expect(fileExists(result.htmlIndex)).toBeTrue();

				var files = directoryList(outputDir, false, "query", "*.html");
				expect(files.recordCount).toBeGTE(1, "Should create individual HTML files");
			});
		});
	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

	private void function assertValidHtmlResult( required struct result ) {
		expect( arguments.result ).toBeStruct();
		expect( arguments.result ).toHaveKey( "htmlIndex" );
		expect( arguments.result ).toHaveKey( "stats" );
	}

	private void function assertValidStats( required struct stats ) {
		expect( arguments.stats ).toHaveKey( "totalLinesFound" );
		expect( arguments.stats ).toHaveKey( "totalLinesHit" );
		expect( arguments.stats ).toHaveKey( "totalLinesSource" );
		expect( arguments.stats ).toHaveKey( "coveragePercentage" );
		expect( arguments.stats ).toHaveKey( "totalFiles" );
		expect( arguments.stats ).toHaveKey( "processingTimeMs" );
	}

	private any function parseHtmlFile( required string filePath ) {
		var htmlContent = fileRead( arguments.filePath );
		var htmlParser = new testAdditional.HtmlParser();
		return htmlParser.parseHtml( htmlContent );
	}

}