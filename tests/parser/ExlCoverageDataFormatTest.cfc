component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.parser = new lucee.extension.lcov.ExecutionLogParser();
	variables.testDataGenerator = new "../GenerateTestData"(testName="ExlCoverageDataFormatTest");
		
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
	}
	
	function testCoverageDataIsAlwaysLineBased() skip=true {
		systemOutput("Testing assumption: .exl coverage data (startpos, endpos) is always line-based", true);
		
		expect(directoryExists(variables.testData.coverageDir)).toBeTrue("Coverage directory should exist");

		var files = directoryList(variables.testData.coverageDir, false, "path", "*.exl");
		expect(arrayLen(files)).toBeGT(0, "Should find some .exl files");
		
		var totalCoverageLines = 0;
		var lineBasedCount = 0;
		var characterBasedCount = 0;
		var inconsistentRanges = [];
		
		for (var file in files) {
			systemOutput("Analyzing file: " & listLast(file, "\/"), true);
			
			var result = variables.parser.parseExlFile(file);
			
			// Skip files with no coverage data
			var fileCoverage = result.getFileCoverage();
			if (arrayLen(fileCoverage) == 0) {
				systemOutput("  Skipping file with no coverage data", true);
				continue;
			}
			
			// Analyze each coverage line in the file
			for (var coverageLine in fileCoverage) {
				totalCoverageLines++;
				
				// Parse tab-separated values: fileIdx, startPos, endPos, execTime
				var parts = listToArray(coverageLine, chr(9), false, false);
				
				if (arrayLen(parts) != 4) {
					continue; // Skip malformed lines
				}
				
				var fileIdx = parts[1];
				expect(parts[2]).toBeNumeric("Start position should be numeric");
				expect(parts[3]).toBeNumeric("End position should be numeric");
				expect(parts[4]).toBeNumeric("Execution time should be numeric");
				var startPos = parts[2];
				var endPos = parts[3];
				var execTime = parts[4];
				
				// Skip if file not in parsed results (blocked/not allowed)
				if (!structKeyExists(result.source.files, fileIdx)) {
					continue;
				}
				
				var filePath = result.source.files[fileIdx].path;
				
				// Get line numbers for start and end positions
				var startLine = variables.parser.getLineFromCharacterPosition(startPos, filePath);
				var endLine = variables.parser.getLineFromCharacterPosition(endPos, filePath);
				
				// Check if this range spans exactly one line (line-based)
				if (startLine == endLine && startLine > 0) {
					lineBasedCount++;
				} else if (startLine > 0 && endLine > 0 && endLine > startLine) {
					characterBasedCount++;
					
					// Record details of multi-line ranges for analysis
					if (arrayLen(inconsistentRanges) < 10) { // Limit to first 10 for output
						arrayAppend(inconsistentRanges, {
							"file": listLast(filePath, "\/"),
							"startPos": startPos,
							"endPos": endPos,
							"startLine": startLine,
							"endLine": endLine,
							"lineSpan": endLine - startLine + 1,
							"execTime": execTime
						});
					}
				}
			}
		}
		
		systemOutput("", true);
		systemOutput("=== COVERAGE DATA ANALYSIS RESULTS ===", true);
		systemOutput("Total coverage entries analyzed: " & totalCoverageLines, true);
		systemOutput("Single-line ranges (line-based): " & lineBasedCount & " (" & numberFormat(lineBasedCount/totalCoverageLines*100, "0.00") & "%)", true);
		systemOutput("Multi-line ranges (character-based): " & characterBasedCount & " (" & numberFormat(characterBasedCount/totalCoverageLines*100, "0.00") & "%)", true);
		
		if (arrayLen(inconsistentRanges) > 0) {
			systemOutput("", true);
			systemOutput("Sample multi-line ranges:", true);
			for (var range in inconsistentRanges) {
				systemOutput("  " & range.file & ": pos " & range.startPos & "-" & range.endPos & 
					" (lines " & range.startLine & "-" & range.endLine & ", " & range.lineSpan & " lines, " & range.execTime & "ms)", true);
			}
		}
		
		systemOutput("", true);
		
		// Test the assumption: coverage data should be predominantly line-based
		var lineBasedPercentage = lineBasedCount / totalCoverageLines * 100;
		
		// Allow for some character-based ranges but expect majority to be line-based
		expect(lineBasedPercentage).toBeGTE(80, 
			"Coverage data should be at least 80% line-based. Found " & numberFormat(lineBasedPercentage, "0.00") & "% line-based ranges");
		
		// Report findings
		if (lineBasedPercentage > 95) {
			systemOutput("✓ CONCLUSION: Coverage data is predominantly line-based (" & numberFormat(lineBasedPercentage, "0.00") & "%)", true);
		} else if (lineBasedPercentage > 80) {
			systemOutput("⚠ CONCLUSION: Coverage data is mostly line-based (" & numberFormat(lineBasedPercentage, "0.00") & "%) but has significant character-based ranges", true);
		} else {
			systemOutput("✗ CONCLUSION: Coverage data is NOT predominantly line-based (" & numberFormat(lineBasedPercentage, "0.00") & "%)", true);
		}
		
		systemOutput("========================================", true);
	}
	
	function testCoverageLineStructure() {
		// Testing coverage line structure and data types
		
		var files = directoryList(variables.testData.coverageDir, false, "path", "*.exl");
		expect(arrayLen(files)).toBeGT(0, "Should find some .exl files");
		
		var sampleFile = files[1];
		var result = variables.parser.parseExlFile(sampleFile);
		
		var fileCoverage = result.getFileCoverage();
		if (arrayLen(fileCoverage) > 0) {
			var firstLine = fileCoverage[1];
			var parts = listToArray(firstLine, chr(9), false, false);
			
			expect(parts).toHaveLength(4, "Coverage line should have exactly 4 tab-separated parts");
			
			// Test that parts are in expected format
			expect(parts[1]).toBeNumeric("File index should be numeric");
			expect(parts[2]).toBeNumeric("Start position should be numeric");
			expect(parts[3]).toBeNumeric("End position should be numeric");
			expect(parts[4]).toBeNumeric("Execution time should be numeric");
			
			// Test position ordering
			expect(parts[3]).toBeNumeric("End position should be numeric");
			expect(parts[2]).toBeNumeric("Start position should be numeric");
			expect(parts[3]).toBeGTE(parts[2], "End position should be >= start position");
			
			// Sample coverage line structure verified
		}
	}
}