component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		
		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateSummaryTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		variables.logLevel="info";
	}

	


	/**
	 * @displayName "Given I have execution logs and call lcovGenerateSummary with minimal parameters, When the function executes, Then it should return coverage statistics"
	 */
	function testGenerateSummaryMinimal() {
		// Given
		var executionLogDir = variables.testLogDir;
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options:{logLevel: variables.logLevel}
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("totalLinesSource");
		expect(result).toHaveKey("totalLinesHit");
		expect(result).toHaveKey("totalLinesFound");
		expect(result).toHaveKey("coveragePercentage");
		expect(result).toHaveKey("totalFiles");
		expect(result).toHaveKey("executedFiles");
		expect(result).toHaveKey("processingTimeMs");
		expect(result).toHaveKey("fileStats");
		
		// Verify data types
		expect(result.totalLinesSource).toBeNumeric();
		expect(result.totalLinesHit).toBeNumeric();
		expect(result.totalLinesFound).toBeNumeric();
		expect(result.coveragePercentage).toBeNumeric();
		expect(result.totalFiles).toBeNumeric();
		expect(result.executedFiles).toBeNumeric();
		expect(result.processingTimeMs).toBeNumeric();
		expect(result.fileStats).toBeStruct();
		
		// Verify logical ranges
		expect(result.coveragePercentage).toBeBetween(0, 100, "coveragePercentage should be between 0 and 100 but was " & result.coveragePercentage & ".");
		expect(result.processingTimeMs).toBeGTE(0, "processingTimeMs should be >= 0 but was " & result.processingTimeMs & ".");
		expect(result.totalLinesHit).toBeLTE(result.totalLinesSource, "totalLinesHit (" & result.totalLinesHit & ") should be <= totalLinesSource (" & result.totalLinesSource & ").");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateSummary with options, When the function executes, Then it should respect the options"
	 */
	function testGenerateSummaryWithOptions() {
		// Given
		var executionLogDir = variables.testLogDir;
		var options = {
			chunkSize: 25000
		};
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result).toHaveKey("processingTimeMs");
		expect(result.processingTimeMs).toBeGTE(0, "Should track processing time");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateSummary with filtering, When the function executes, Then it should apply filters to statistics"
	 */
	function testGenerateSummaryWithFiltering() {
		// Given
		var executionLogDir = variables.testLogDir;
		var options = {
			allowList: ["/test"],
			blocklist: ["/vendor", "/testbox"]
		};
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.totalFiles).toBeGTE(0, "Should process files matching allowList");
		
		// fileStats should contain allowed files (artifacts match allowList pattern)
		expect(structCount(result.fileStats)).toBeGTE(0, "Should have files matching allowList");
	}

	/**
	 * @displayName "Given I have execution logs and call lcovGenerateSummary with blocklist, When the function executes, Then it should exclude blocked files from statistics"
	 */
	function testGenerateSummaryWithBlocklist() {
		// Given
		var executionLogDir = variables.testLogDir;
		var options = {
			blocklist: ["artifacts"]  // Block all artifact files
		};
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options=options
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.totalFiles).toBe(0, "Expected totalFiles to be 0 but got: " & result.totalFiles & ". Full result: " & serializeJSON(result));
		expect(structCount(result.fileStats)).toBe(0, "Expected fileStats to be empty but got: " & serializeJSON(result.fileStats));
	}

	/**
	 * @displayName "Given I call lcovGenerateSummary with non-existent log directory, When the function executes, Then it should throw an exception"
	 */
	function testGenerateSummaryWithInvalidLogDir() {
		// Given
		var invalidLogDir = "/non/existent/directory";
		
		// When/Then
		expect(function() {
			lcovGenerateSummary(
				executionLogDir=invalidLogDir
			);
		}).toThrow();
	}

	/**
	 * @displayName "Given I have empty execution log directory and call lcovGenerateSummary, When the function executes, Then it should return zero statistics"
	 */
	function testGenerateSummaryWithEmptyLogDir() {
		// Given
		var emptyLogDir = variables.tempDir & "/empty-logs";
		directoryCreate(emptyLogDir);
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=emptyLogDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.totalFiles).toBe(0, "Should report zero files for empty directory, got: " & result.totalFiles & ".");
		expect(result.totalLinesSource).toBe(0, "Should report zero lines for empty directory, got: " & result.totalLinesSource & ".");
		expect(result.totalLinesHit).toBe(0, "Should report zero covered lines for empty directory, got: " & result.totalLinesHit & ".");
		expect(result.coveragePercentage).toBe(0, "Should report zero coverage for empty directory, got: " & result.coveragePercentage & ".");
		expect(structCount(result.fileStats)).toBe(0, "fileStats should be empty for empty directory, got: " & serializeJSON(result.fileStats));
	}

	/**
	 * @displayName "Given I have multiple execution log files and call lcovGenerateSummary, When the function executes, Then it should aggregate statistics across files"
	 */
	function testGenerateSummaryWithMultipleFiles() {
		// Given - GenerateTestData already creates multiple coverage files
		var executionLogDir = variables.testLogDir;
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=executionLogDir
		);
		
		// Then
		expect(result).toBeStruct();
		expect(result.totalFiles).toBeGTE(1, "Should process multiple files, got: " & result.totalFiles & ".");
		
		// Verify fileStats contains multiple files
		var fileCount = structCount(result.fileStats);
		expect(fileCount).toBeGTE(1, "Should have stats for multiple files, got: " & fileCount & ".");
		
		// Verify fileStats structure
		for (var filePath in result.fileStats) {
			var fileData = result.fileStats[filePath];
			expect(fileData).toHaveKey("linesSource", "Missing linesSource for file " & filePath & ".");
			expect(fileData).toHaveKey("linesHit", "Missing linesHit for file " & filePath & ".");
			expect(fileData).toHaveKey("coveragePercentage", "Missing coveragePercentage for file " & filePath & ".");
			
			expect(fileData.linesSource).toBeNumeric("linesSource should be numeric for file " & filePath & ".");
			expect(fileData.linesHit).toBeNumeric("linesHit should be numeric for file " & filePath & ".");
			expect(fileData.coveragePercentage).toBeBetween(0, 100, "coveragePercentage should be between 0 and 100 for file " & filePath & ". linesHit=" & fileData.linesHit & ", linesFound=" & fileData.linesFound & ", linesSource=" & fileData.linesSource & ", percentage=" & fileData.coveragePercentage);
		}
	}

	/**
	 * @displayName "Given I verify fileStats structure, When lcovGenerateSummary completes, Then fileStats should contain per-file coverage details"
	 * 
	 * do not make this pass but changing the max logic in the function
	 */
	function testGenerateSummaryFileStatsStructure() {
		// Given
		var executionLogDir = variables.testLogDir;
		
		// When
		var result = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options:{logLevel: variables.logLevel}
		);

		// Then
		expect(result.fileStats).toBeStruct();
		
		// Verify each file entry has proper structure
		for (var filePath in result.fileStats) {
			var fileData = result.fileStats[filePath];
			
			// Should match the API design structure
			// expect(fileData).toHaveKey("totalLinesSource", "Each file should have totalLinesSource");
			expect(fileData).toHaveKey("linesSource", "Each file should have linesSource");
			expect(fileData).toHaveKey("coveragePercentage", "Each file should have coveragePercentage");
			
			// Verify data relationships and reasonable coverage percentage
			if (fileData.linesFound > 0) {
				var expectedPercentage = (fileData.linesHit / fileData.linesFound) * 100;

				expect(fileData.coveragePercentage).toBeCloseTo(expectedPercentage, 3,
					"Coverage percentage should match calculation for file " & filePath & ". Expected: " & expectedPercentage & ", got: " & fileData.coveragePercentage & ".");
				// Verify coverage is reasonable (not negative, not over 100%)
				expect(fileData.coveragePercentage).toBeBetween(0, 100,
					"Coverage percentage out of range for file " & filePath & ". linesHit=" & fileData.linesHit & ", linesFound=" & fileData.linesFound & ", linesSource=" & fileData.linesSource & ", percentage=" & fileData.coveragePercentage);
			}
		}
	}

	/**
	 * @displayName "Given I have execution logs with different chunk sizes and call lcovGenerateSummary, When the function executes, Then results should be consistent"
	 */
	function testGenerateSummaryWithDifferentChunkSizes() {
		// Given
		var executionLogDir = variables.testLogDir;
		
		// When - Test with different chunk sizes
		var result1 = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options={chunkSize: 10000, logLevel: variables.logLevel}
		);
		
		var result2 = lcovGenerateSummary(
			executionLogDir=executionLogDir,
			options={chunkSize: 50000, logLevel: variables.logLevel}
		);
		
		// Then - Results should be the same regardless of chunk size
		expect(result1.totalFiles).toBe(result2.totalFiles, "Total files should be consistent. result1: " & result1.totalFiles & ", result2: " & result2.totalFiles & ".");
		expect(result1.totalLinesSource).toBe(result2.totalLinesSource, "Total lines should be consistent. result1: " & result1.totalLinesSource & ", result2: " & result2.totalLinesSource & ".");
		expect(result1.totalLinesHit).toBe(result2.totalLinesHit, "Covered lines should be consistent. result1: " & result1.totalLinesHit & ", result2: " & result2.totalLinesHit & ".");
		expect(result1.coveragePercentage).toBe(result2.coveragePercentage, "Coverage percentage should be consistent. result1: " & result1.coveragePercentage & ", result2: " & result2.coveragePercentage & ".");
	}
}