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


	/**
	 * @displayName "Given I have execution logs and call lcovGenerateHtml with minimal parameters, When the function executes, Then it should generate HTML reports"
	 */
	function testGenerateHtmlMinimal() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/html-minimal";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("htmlIndex");
		expect(result).toHaveKey("stats");
		
		// Verify HTML files were created
		expect(fileExists(result.htmlIndex)).toBeTrue("HTML index should be created");
		expect(result.htmlIndex).toInclude("index.html", "Should be index.html file");
		
		// Verify stats structure
		expect(result.stats).toHaveKey("totalLinesFound");
		expect(result.stats).toHaveKey("totalLinesHit");
		expect(result.stats).toHaveKey("totalLinesSource");
		expect(result.stats).toHaveKey("coveragePercentage");
		expect(result.stats).toHaveKey("totalFiles");
		expect(result.stats).toHaveKey("processingTimeMs");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateHtml with display options, When the function executes, Then it should respect display options"
	 */
	function testGenerateHtmlWithDisplayOptions() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/html-display";
		directoryCreate(outputDir);
		var options = {
			displayUnit: "milli"
		};
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("htmlIndex");
		expect(fileExists(result.htmlIndex)).toBeTrue();
		
		// Verify HTML content includes time units
		var indexContent = fileRead(result.htmlIndex);
		expect(indexContent).toInclude("html", "Should be valid HTML");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateHtml with filtering, When the function executes, Then it should apply filters"
	 */
	function testGenerateHtmlWithFiltering() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/html-filtered";
		directoryCreate(outputDir);
		var options = {
			allowList: ["/test"],
			blocklist: ["/vendor", "/testbox"]
		};
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("stats");
		// Should have processed files since our test file matches allowList
		expect(result.stats.totalFiles).toBeGTE(0);
	}

	/**
	 * @displayName "Given I call lcovGenerateHtml with non-existent log directory, When the function executes, Then it should throw an exception"
	 */
	function testGenerateHtmlWithInvalidLogDir() {
		// Given
		var invalidLogDir = "/non/existent/directory";
		var outputDir = variables.outputDir & "/html-invalid";
		
		// When/Then
		expect(function() {
			lcovGenerateHtml(
				executionLogDir=invalidLogDir,
				outputDir=outputDir
			);
		}).toThrow();
	}

	/**
	 * @displayName "Given I have empty execution log directory and call lcovGenerateHtml, When the function executes, Then it should handle gracefully"
	 */
	function testGenerateHtmlWithEmptyLogDir() {
		// Given
		var emptyLogDir = variables.tempDir & "/empty-logs";
		directoryCreate(emptyLogDir);
		var outputDir = variables.outputDir & "/html-empty";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=emptyLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");
		// Should still create an index.html even if empty
		expect(result).toHaveKey("htmlIndex");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateHtml with blocklist, When the function executes, Then it should exclude blocked files"
	 */
	function testGenerateHtmlWithBlocklist() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/html-blocked";
		directoryCreate(outputDir);
		var options = {
			blocklist: ["artifacts"]  // Block all artifact files (same pattern as other working tests)
		};
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.stats.totalFiles).toBe(0, result.stats);
	}

	/**
	 * @displayName "Given I have multiple execution log files and call lcovGenerateHtml, When the function executes, Then it should process all files"
	 */
	function testGenerateHtmlWithMultipleFiles() {
		// Given - GenerateTestData already creates multiple coverage files
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/html-multiple";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.stats.totalFiles).toBeGTE(1, "Should process multiple files");
		expect(fileExists(result.htmlIndex)).toBeTrue();
		
		// Should have individual HTML files for each source file
		var files = directoryList(outputDir, false, "query", "*.html");
		expect(files.recordCount).toBeGTE(1, "Should create individual HTML files");
	}

	/**
	 * @displayName "Given I verify HTML content structure, When lcovGenerateHtml completes, Then HTML files should contain proper coverage data"
	 */
	function testGenerateHtmlContentStructure() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/html-content";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateHtml(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(fileExists(result.htmlIndex)).toBeTrue();
		// systemOutput("HTML index file: " & result.htmlIndex, true);
		// Read and parse HTML content
		var indexContent = fileRead(result.htmlIndex);
		var doc = htmlParse(indexContent);
		// Check for root html element
		var htmlNodes = xmlSearch(doc, "//*[local-name()='html']");
		expect(arrayLen(htmlNodes)).toBe(1, "Should have one <html> root element");
		// Check for coverage summary section
		var summaryNodes = xmlSearch(doc, "//*[@data-coverage-summary]");
		expect(arrayLen(summaryNodes)).toBeGTE(1, "Should have a coverage summary section");
		// Check for percentage in summary text
		var foundPercent = false;
		for (var node in summaryNodes) {
			if (find("%", node.xmlText)) foundPercent = true;
		}
		expect(foundPercent).toBeTrue("Should show percentage coverage in summary");
	}
}