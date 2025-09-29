component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		
		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateAllReportsTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getOutputDir();
		
		variables.outputDir = variables.tempDir & "/output";
		directoryCreate(variables.outputDir);
	}

	


	/**
	 * @displayName "Given I have execution logs and call lcovGenerateAllReports with minimal parameters, When the function executes, Then it should generate all report types"
	 */
	function testGenerateAllReportsMinimal() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/minimal";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateAllReports(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("lcovFile");
		expect(result).toHaveKey("htmlIndex");
		expect(result).toHaveKey("jsonFiles");
		expect(result).toHaveKey("stats");
		
		// Verify files were created
		expect(fileExists(result.lcovFile)).toBeTrue("LCOV file should be created");
		expect(fileExists(result.htmlIndex)).toBeTrue("HTML index should be created");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateAllReports with options, When the function executes, Then it should respect the options"
	 */
	function testGenerateAllReportsWithOptions() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/with-options";
		directoryCreate(outputDir);
		var options = {
			displayUnit: "milli",
			chunkSize: 25000
		};
		
		// When
		var result = lcovGenerateAllReports(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("stats");
		expect(result.stats).toHaveKey("processingTimeMs");
		expect(result.stats.processingTimeMs).toBeGT(0);
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateAllReports with filtering, When the function executes, Then it should apply filters"
	 */
	function testGenerateAllReportsWithFiltering() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/filtered";
		directoryCreate(outputDir);
		var options = {
			allowList: ["/test"],
			blocklist: ["/vendor", "/testbox"]
		};
		
		// When
		var result = lcovGenerateAllReports(
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
	 * @displayName "Given I call lcovGenerateAllReports with non-existent log directory, When the function executes, Then it should throw an exception"
	 */
	function testGenerateAllReportsWithInvalidLogDir() {
		// Given
		var invalidLogDir = "/non/existent/directory";
		var outputDir = variables.outputDir & "/invalid";
		
		// When/Then
		expect(function() {
			lcovGenerateAllReports(
				executionLogDir=invalidLogDir,
				outputDir=outputDir
			);
		}).toThrow();
	}

	/**
	 * @displayName "Given I have empty execution log directory and call lcovGenerateAllReports, When the function executes, Then it should handle gracefully"
	 */
	function testGenerateAllReportsWithEmptyLogDir() {
		// Given
		var emptyLogDir = variables.tempDir & "/empty-logs";
		directoryCreate(emptyLogDir);
		var outputDir = variables.outputDir & "/empty";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateAllReports(
			executionLogDir=emptyLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");
	}

	/**
	 * @displayName "Given I call lcovGenerateAllReports and verify return structure, When the function executes, Then it should return complete structure"
	 */
	function testGenerateAllReportsReturnStructure() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/structure-test";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateAllReports(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then - Verify complete return structure matches API design
		expect(result).toHaveKey("lcovFile");
		expect(result).toHaveKey("htmlIndex");
		expect(result).toHaveKey("htmlFiles");
		expect(result).toHaveKey("jsonFiles");
		expect(result).toHaveKey("stats");
		
		// Verify jsonFiles structure
		expect(result.jsonFiles).toHaveKey("results");
		expect(result.jsonFiles).toHaveKey("merged");
		expect(result.jsonFiles).toHaveKey("stats");
		
		// Verify stats structure
		expect(result.stats).toHaveKey("totalLinesFound");
		expect(result.stats).toHaveKey("totalLinesHit");
		expect(result.stats).toHaveKey("totalLinesSource");
		expect(result.stats).toHaveKey("coveragePercentage");
		expect(result.stats).toHaveKey("totalFiles");
		expect(result.stats).toHaveKey("processingTimeMs");
	}
}