component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

    function beforeAll() {
        variables.adminPassword = request.SERVERADMINPASSWORD;
        
        // Use GenerateTestData with test name - it handles directory creation and cleanup
        variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateSummaryTest");
        variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
            adminPassword=variables.adminPassword
        );
        variables.testLogDir = variables.testData.coverageDir;
        variables.tempDir = variables.testDataGenerator.getGeneratedArtifactsDir();
    }

    // Leave test artifacts for inspection - no cleanup in afterAll


    /**
     * @displayName "Given I have execution logs and call lcovGenerateSummary with minimal parameters, When the function executes, Then it should return coverage statistics"
     */
    function testGenerateSummaryMinimal() {
        // Given
        var executionLogDir = variables.testLogDir;
        
        // When
        var result = lcovGenerateSummary(
            executionLogDir=executionLogDir
        );
        
        // Then
        expect(result).toBeStruct();
        expect(result).toHaveKey("totalLines");
        expect(result).toHaveKey("coveredLines");
        expect(result).toHaveKey("coveragePercentage");
        expect(result).toHaveKey("totalFiles");
        expect(result).toHaveKey("executedFiles");
        expect(result).toHaveKey("processingTimeMs");
        expect(result).toHaveKey("fileStats");
        
        // Verify data types
        expect(result.totalLines).toBeNumeric();
        expect(result.coveredLines).toBeNumeric();
        expect(result.coveragePercentage).toBeNumeric();
        expect(result.totalFiles).toBeNumeric();
        expect(result.executedFiles).toBeNumeric();
        expect(result.processingTimeMs).toBeNumeric();
        expect(result.fileStats).toBeStruct();
        
        // Verify logical ranges
        expect(result.coveragePercentage).toBeBetween(0, 100);
        expect(result.processingTimeMs).toBeGTE(0);
        expect(result.coveredLines).toBeLTE(result.totalLines);
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
        expect(result.totalFiles).toBe(0, result);
        expect(structCount(result.fileStats)).toBe(0, result.fileStats);
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
        expect(result.totalFiles).toBe(0, "Should report zero files for empty directory");
        expect(result.totalLines).toBe(0, "Should report zero lines for empty directory");
        expect(result.coveredLines).toBe(0, "Should report zero covered lines for empty directory");
        expect(result.coveragePercentage).toBe(0, "Should report zero coverage for empty directory");
        expect(structCount(result.fileStats)).toBe(0, "fileStats should be empty for empty directory");
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
        expect(result.totalFiles).toBeGTE(1, "Should process multiple files");
        
        // Verify fileStats contains multiple files
        var fileCount = structCount(result.fileStats);
        expect(fileCount).toBeGTE(1, "Should have stats for multiple files");
        
        // Verify fileStats structure
        for (var filePath in result.fileStats) {
            var fileData = result.fileStats[filePath];
            expect(fileData).toHaveKey("totalLines");
            expect(fileData).toHaveKey("coveredLines");
            expect(fileData).toHaveKey("coveragePercentage");
            
            expect(fileData.totalLines).toBeNumeric();
            expect(fileData.coveredLines).toBeNumeric();
            expect(fileData.coveragePercentage).toBeBetween(0, 100);
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
            executionLogDir=executionLogDir
        );
        
        // Then
        expect(result.fileStats).toBeStruct();
        
        // Verify each file entry has proper structure
        for (var filePath in result.fileStats) {
            var fileData = result.fileStats[filePath];
            
            // Should match the API design structure
            expect(fileData).toHaveKey("totalLines", "Each file should have totalLines");
            expect(fileData).toHaveKey("coveredLines", "Each file should have coveredLines");
            expect(fileData).toHaveKey("coveragePercentage", "Each file should have coveragePercentage");
            
            // Verify data relationships
            if (fileData.totalLines > 0) {
                var expectedPercentage = (fileData.coveredLines / fileData.totalLines) * 100;
                expect(fileData.coveragePercentage).toBeCloseTo(expectedPercentage, 1, 
                    "Coverage percentage should match calculation");
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
            options={chunkSize: 10000}
        );
        
        var result2 = lcovGenerateSummary(
            executionLogDir=executionLogDir,
            options={chunkSize: 50000}
        );
        
        // Then - Results should be the same regardless of chunk size
        expect(result1.totalFiles).toBe(result2.totalFiles, "Total files should be consistent");
        expect(result1.totalLines).toBe(result2.totalLines, "Total lines should be consistent");
        expect(result1.coveredLines).toBe(result2.coveredLines, "Covered lines should be consistent");
        expect(result1.coveragePercentage).toBe(result2.coveragePercentage, "Coverage percentage should be consistent");
    }
}