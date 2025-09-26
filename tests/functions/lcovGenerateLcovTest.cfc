component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		
		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateLcovTest");
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
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with outputFile, When the function executes, Then it should create LCOV file and return string content"
	 */
	function testGenerateLcovWithOutputFile() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputFile = variables.outputDir & "/test.lcov";
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			outputFile=outputFile
		);
		
		// Then
		expect(result).toBeString();
		expect(fileExists(outputFile)).toBeTrue("LCOV file should be created");
		
		// Verify LCOV content format
		var fileContent = fileRead(outputFile);
		expect(fileContent).toInclude("SF:", "Should contain source file records");
		expect(fileContent).toInclude("DA:", "Should contain data array records");
		expect(fileContent).toInclude("end_of_record", "Should contain end of record markers");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov without outputFile, When the function executes, Then it should return LCOV content as string"
	 */
	function testGenerateLcovWithoutOutputFile() {
		// Given
		var executionLogDir = variables.testLogDir;
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir
		);
		
		// Then
		expect(result).toBeString();
		expect(result).notToBeEmpty();
		expect(result).toInclude("SF:", "Should contain source file records");
		expect(result).toInclude("DA:", "Should contain data array records");
		expect(result).toInclude("LF:", "Should contain lines found records");
		expect(result).toInclude("LH:", "Should contain lines hit records");
		expect(result).toInclude("end_of_record", "Should contain end of record markers");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with empty outputFile, When the function executes, Then it should return LCOV content as string"
	 */
	function testGenerateLcovWithEmptyOutputFile() {
		// Given
		var executionLogDir = variables.testLogDir;
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			outputFile=""
		);
		
		// Then
		expect(result).toBeString();
		expect(result).notToBeEmpty();
		expect(result).toInclude("SF:", "Should contain LCOV format content");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with options, When the function executes, Then it should respect the options"
	 */
	function testGenerateLcovWithOptions() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputFile = variables.outputDir & "/test-with-options.lcov";
		var options = {
			allowList: ["/test"],
			blocklist: ["/vendor"]
		};
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			outputFile=outputFile,
			options=options
		);
		
		// Then
		expect(result).toBeString();
		expect(fileExists(outputFile)).toBeTrue();
		
		// Should have processed files since allowList includes test artifacts
		var content = fileRead(outputFile);
		expect(content).toInclude("SF:", "Should contain source file entries for allowed files");
	}

	/**
	 * @displayName "Given I call lcovGenerateLcov with non-existent log directory, When the function executes, Then it should throw an exception"
	 */
	function testGenerateLcovWithInvalidLogDir() {
		// Given
		var invalidLogDir = "/non/existent/directory";
		var outputFile = variables.outputDir & "/invalid.lcov";
		
		// When/Then
		expect(function() {
			lcovGenerateLcov(
				executionLogDir=invalidLogDir,
				outputFile=outputFile
			);
		}).toThrow();
	}

	/**
	 * @displayName "Given I have empty execution log directory and call lcovGenerateLcov, When the function executes, Then it should return empty LCOV content"
	 */
	function testGenerateLcovWithEmptyLogDir() {
		// Given
		var emptyLogDir = variables.tempDir & "/empty-logs";
		directoryCreate(emptyLogDir);
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=emptyLogDir
		);
		
		// Then
		expect(result).toBeString();
		// Should be empty or minimal content for empty directory
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with blocklist, When the function executes, Then it should exclude blocked files"
	 */
	function testGenerateLcovWithBlocklist() {
		// Given
		var executionLogDir = variables.testLogDir;
		var options = {
			blocklist: ["artifacts"]  // Block all artifact files (same pattern as the summary test)
		};
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			options=options
		);
		
		// Then
		expect(result).toBeString();
		// Should have minimal content due to blocklist excluding artifacts
		expect(result.length()).toBeLT(100, result);
	}

	/**
	 * @displayName "Given I have multiple execution log files and call lcovGenerateLcov, When the function executes, Then it should merge coverage data"
	 */
	function testGenerateLcovWithMultipleFiles() {
		// Given - GenerateTestData already creates multiple coverage files
		var executionLogDir = variables.testLogDir;
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir
		);
		
		// Then
		expect(result).toBeString();
		// Should contain multiple SF: entries for different source files
		var sfCount = len(result) - len(replace(result, "SF:", "", "all"));
		expect(sfCount).toBeGT(0, "Should include multiple source files");
		expect(result).toInclude("end_of_record", "Should have proper LCOV format");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with useRelativePath false, When the function executes, Then it should use absolute paths in SF records"
	 */
	function testGenerateLcovWithAbsolutePaths() {
		// Given
		var executionLogDir = variables.testLogDir;
		var options = {
			useRelativePath: false  // Explicitly set to false (default behavior)
		};
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			options=options
		);
		
		// Then
		expect(result).toBeString();
		expect(result).notToBeEmpty();
		
		// Should contain absolute paths in SF records (paths starting with drive letter or forward slash)
		var lines = listToArray(result, chr(10));
		var sfLines = [];
		for (var line in lines) {
			if (left(line, 3) == "SF:") {
				arrayAppend(sfLines, line);
			}
		}
		
	expect(arrayLen(sfLines)).toBeGT(0, "Should have at least one SF record");
		
		// Check that at least one SF line contains the known test artifact paths
		var hasExpectedAbsolutePath = false;
		for (var sfLine in sfLines) {
			var path = mid(sfLine, 4); // Remove "SF:" prefix
			// Check if path contains our test artifacts directory
			if (find("extension-lcov\tests\artifacts", path) > 0 || find("extension-lcov/tests/artifacts", path) > 0) {
				hasExpectedAbsolutePath = true;
				break;
			}
		}
		expect(hasExpectedAbsolutePath).toBeTrue("Should contain absolute paths when useRelativePath=false");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with useRelativePath true, When the function executes, Then it should use relative paths in SF records"
	 */
	function testGenerateLcovWithRelativePaths() {
		// Given
		var executionLogDir = variables.testLogDir;
		var options = {
			useRelativePath: true
		};
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			options=options
		);
		
		// Then
		expect(result).toBeString();
		expect(result).notToBeEmpty();
		
		// Should contain relative paths in SF records (no drive letters, no leading slash)
		var lines = listToArray(result, chr(10));
		var sfLines = [];
		for (var line in lines) {
			if (left(line, 3) == "SF:") {
				arrayAppend(sfLines, line);
			}
		}
		
		expect(arrayLen(sfLines)).toBeGT(0, "Should have at least one SF record");
		
		// Check that all SF lines contain relative paths (should not contain the full directory structure)
		var allRelativePaths = true;
		for (var sfLine in sfLines) {
			var path = mid(sfLine, 4); // Remove "SF:" prefix
			// Check that path is relative (should not contain the full extension-lcov directory path)
			if (find("extension-lcov\tests\artifacts", path) > 0 || find("extension-lcov/tests/artifacts", path) > 0) {
				allRelativePaths = false;
				break;
			}
		}
		expect(allRelativePaths).toBeTrue("Should contain only relative paths when useRelativePath=true");
	}


	/**
	 * @displayName "Given I have execution logs and call lcovGenerateLcov with verbose option, When the function executes, Then it should produce verbose logging output"
	 * it should only parse a single file, as we don't want too much verbose logging
	 * create it's own directory /data set for output
	 */
	function testGenerateLcovWithVerbose() {
		systemOutput("", true);
		systemOutput("Testing LCOV generation with verbose logging", true);
		
		// Given - Create isolated test data for verbose test
		// Use separate GenerateTestData instance for isolated verbose test
		var verboseTestDataGenerator = new "../GenerateTestData"(testName="lcovGenerateLcovTest-verbose");
		var verboseTestData = verboseTestDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword,
			fileFilter="conditional.cfm"  // Only process one file to limit verbose output
		);
		
		var executionLogDir = verboseTestData.coverageDir;
		var outputFile = verboseTestDataGenerator.getGeneratedArtifactsDir() & "/test-verbose.lcov";
		var options = {
			verbose: true
		};
		
		// When
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			outputFile=outputFile,
			options=options
		);
		
		// Then
		expect(result).toBeString();
		expect(fileExists(outputFile)).toBeTrue("LCOV file should be created");
		
		// Verify LCOV content format (verbose should not change the content format)
		var fileContent = fileRead(outputFile);
		expect(fileContent).toInclude("SF:", "Should contain source file records");
		expect(fileContent).toInclude("DA:", "Should contain data array records");
		expect(fileContent).toInclude("LF:", "Should contain lines found records");
		expect(fileContent).toInclude("LH:", "Should contain lines hit records");
		expect(fileContent).toInclude("end_of_record", "Should contain end of record markers");
	}

	/**
	 * @displayName "Test lcovGenerateLcov with multiple files (regression test for mergeResultsByFile bug)"
	 * This test specifically targets the data contract between CoverageMerger.mergeResultsByFile and LcovWriter
	 */
	function testLcovGenerateWithMultipleFilesRegression() {
		// Use GenerateTestData to create multiple .exl files with different artifacts
		var multiFileGenerator = new "../GenerateTestData"(testName="lcovGenerateLcovTest-multiFile");
		var multiFileData = multiFileGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);

		var executionLogDir = multiFileData.coverageDir;
		var outputFile = multiFileGenerator.getGeneratedArtifactsDir() & "/multi-file-regression.lcov";

		// This should trigger the mergeResultsByFile -> LcovWriter integration path
		var result = lcovGenerateLcov(
			executionLogDir=executionLogDir,
			outputFile=outputFile
		);
		// Verify the LCOV was generated successfully (no exceptions thrown)
		expect(result).toBeString();
		expect(fileExists(outputFile)).toBeTrue("LCOV file should be created");

		var fileContent = fileRead(outputFile);

		// Verify LCOV format for multiple files
		expect(fileContent).toInclude("SF:", "Should contain source file records");
		expect(fileContent).toInclude("DA:", "Should contain data array records");
		expect(fileContent).toInclude("end_of_record", "Should contain end of record markers");

		// Count SF records to verify multiple files were processed
		var sfCount = len(fileContent) - len(replace(fileContent, "SF:", "", "all"));
		expect(sfCount).toBeGTE(9, "Should process multiple source files (3 chars removed per SF record)");

		// Verify that each SF record has a corresponding end_of_record
		var endRecordCount = len(fileContent) - len(replace(fileContent, "end_of_record", "", "all"));
		expect(endRecordCount).toBeGTE(39, "Should have end_of_record for each file (13 chars removed per end_of_record)");

	}
}