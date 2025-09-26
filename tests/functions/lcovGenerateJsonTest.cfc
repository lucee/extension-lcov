component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		
		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateJsonTest");
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
	 * @displayName "Given I have execution logs and call lcovGenerateJson with minimal parameters, When the function executes, Then it should generate JSON reports"
	 */
	function testGenerateJsonMinimal() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-minimal";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("jsonFiles");
		expect(result).toHaveKey("stats");
		
		// Verify jsonFiles structure
		expect(result.jsonFiles).toHaveKey("results");
		expect(result.jsonFiles).toHaveKey("merged");
		expect(result.jsonFiles).toHaveKey("stats");
		
		// Verify JSON files were created
		expect(fileExists(result.jsonFiles.results)).toBeTrue("Results JSON should be created");
		expect(fileExists(result.jsonFiles.merged)).toBeTrue("Merged JSON should be created");
		expect(fileExists(result.jsonFiles.stats)).toBeTrue("Stats JSON should be created");
		
		// Verify stats structure
		expect(result.stats).toHaveKey("totalLinesSource");
		expect(result.stats).toHaveKey("totalLinesHit");
		expect(result.stats).toHaveKey("totalLinesFound");
		expect(result.stats).toHaveKey("coveragePercentage");
		expect(result.stats).toHaveKey("totalFiles");
		expect(result.stats).toHaveKey("processingTimeMs");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateJson with formatting options, When the function executes, Then it should respect formatting options"
	 */
	function testGenerateJsonWithFormattingOptions() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-formatted";
		directoryCreate(outputDir);
		var options = {
			compact: false,
			includeStats: true
		};
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("jsonFiles");
		
		// Verify JSON files exist
		expect(fileExists(result.jsonFiles.results)).toBeTrue();
		
		// Verify JSON is not compact (should have formatting)
		var jsonContent = fileRead(result.jsonFiles.results);
		expect(jsonContent).toInclude(chr(10), "Non-compact JSON should have line breaks");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateJson with separateFiles option, When the function executes, Then it should create individual JSON files"
	 */
	function testGenerateJsonWithSeparateFiles() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-separate";
		directoryCreate(outputDir);
		var options = {
			separateFiles: true
		};
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("jsonFiles");
		
		// Should have created individual JSON files per source file
		var jsonFiles = directoryList(outputDir, false, "query", "*.json");
		expect(jsonFiles.recordCount).toBeGTE(1, "Should create individual JSON files when separateFiles=true");

		// Validate that each per-file JSON contains only data for that specific file
		for (var row = 1; row <= jsonFiles.recordCount; row++) {
			var jsonFile = jsonFiles.name[row];
			var jsonPath = outputDir & "/" & jsonFile;

			if (!fileExists(jsonPath)) continue;

			// Skip merged.json and other system files - only validate per-file JSONs (file-*.json)
			if (!reFind("^file-[A-Z0-9]+-", jsonFile)) continue;

			var jsonContent = fileRead(jsonPath);
			var jsonData = deserializeJSON(jsonContent);

			// Each per-file JSON should have exactly ONE file in the files structure
			expect(jsonData).toHaveKey("files", "Per-file JSON should have files structure: " & jsonFile);
			expect(structCount(jsonData.files)).toBe(1, "Per-file JSON should contain exactly ONE file entry, not all files from execution: " & jsonFile);

			// Should have exactly ONE entry in coverage structure (for the single file)
			if (structKeyExists(jsonData, "coverage")) {
				expect(structCount(jsonData.coverage)).toBeLTE(1, "Per-file JSON should contain coverage for at most ONE file: " & jsonFile);
			}

			// Verify the file path matches what we expect from the filename
			var fileEntry = jsonData.files[structKeyArray(jsonData.files)[1]];
			expect(fileEntry).toHaveKey("path", "File entry should have path property: " & jsonFile);

			// Extract expected filename from the JSON filename (file-HASH-filename.extension.json -> filename.(cfm|cfc))
			var expectedFilePattern = reReplace(jsonFile, "^file-[A-Z0-9]+-(.+)\.(cfm|cfc)\.json$", "\1");
			expectedFilePattern = expectedFilePattern & "\.(cfm|cfc)";
			expect(fileEntry.path).toMatch(".*" & expectedFilePattern & "$", "File path should match the JSON filename pattern: " & jsonFile);
		}
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateJson with compact option, When the function executes, Then it should create compact JSON"
	 */
	function testGenerateJsonWithCompactOption() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-compact";
		directoryCreate(outputDir);
		var options = {
			compact: true,
			includeStats: false
		};
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=executionLogDir,
			outputDir=outputDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(fileExists(result.jsonFiles.results)).toBeTrue();
		
		// Verify JSON is compact (minimal whitespace)
		var jsonContent = fileRead(result.jsonFiles.results);
		var lineBreaks = arrayLen(listToArray(jsonContent, chr(10)));
		expect(lineBreaks).toBeLTE(5, "Compact JSON should have minimal line breaks");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateJson with filtering, When the function executes, Then it should apply filters"
	 */
	function testGenerateJsonWithFiltering() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-filtered";
		directoryCreate(outputDir);
		var options = {
			allowList: ["/test"],
			blocklist: ["/vendor", "/testbox"]
		};
		
		// When
		var result = lcovGenerateJson(
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
	 * @displayName "Given I call lcovGenerateJson with non-existent log directory, When the function executes, Then it should throw an exception"
	 */
	function testGenerateJsonWithInvalidLogDir() {
		// Given
		var invalidLogDir = "/non/existent/directory";
		var outputDir = variables.outputDir & "/json-invalid";
		
		// When/Then
		expect(function() {
			lcovGenerateJson(
				executionLogDir=invalidLogDir,
				outputDir=outputDir
			);
		}).toThrow();
	}

	/**
	 * @displayName "Given I have empty execution log directory and call lcovGenerateJson, When the function executes, Then it should handle gracefully"
	 */
	function testGenerateJsonWithEmptyLogDir() {
		// Given
		var emptyLogDir = variables.tempDir & "/empty-logs";
		directoryCreate(emptyLogDir);
		var outputDir = variables.outputDir & "/json-empty";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=emptyLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");
		// Should still create JSON files even if empty
		expect(result).toHaveKey("jsonFiles");
	}

	/**
	 * @displayName "Given I verify JSON content structure, When lcovGenerateJson completes, Then JSON files should contain valid coverage data"
	 */
	function testGenerateJsonContentStructure() {
		// Given
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-content";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);
		
		// Then
		expect(fileExists(result.jsonFiles.results)).toBeTrue();
		
		// Verify JSON is valid and contains expected structure
		var jsonContent = fileRead(result.jsonFiles.results);
		var parsedJson = deserializeJson(jsonContent);
		
		expect(parsedJson).toBeStruct("JSON should be valid and parseable");
		// Should contain coverage data structure
		expect(isStruct(parsedJson)).toBeTrue("Parsed JSON should be a struct");
	}

	/**
	 * @displayName "Given I have multiple execution log files and call lcovGenerateJson, When the function executes, Then it should merge coverage data"
	 */
	function testGenerateJsonWithMultipleFiles() {
		// Given - GenerateTestData already creates multiple coverage files
		var executionLogDir = variables.testLogDir;
		var outputDir = variables.outputDir & "/json-multiple";
		directoryCreate(outputDir);
		
		// When
		var result = lcovGenerateJson(
			executionLogDir=executionLogDir,
			outputDir=outputDir
		);

		// Then
		expect(result).toBeStruct();
		expect(result.stats.totalFiles).toBeGTE(1, "Should process multiple files");
		
		// Verify merged JSON contains data from multiple files
		expect(fileExists(result.jsonFiles.merged)).toBeTrue();
		var mergedContent = fileRead(result.jsonFiles.merged);
		var mergedData = deserializeJson(mergedContent);
		expect(isStruct(mergedData)).toBeTrue("Merged JSON should be valid");
	}
}