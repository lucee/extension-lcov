component extends="testbox.system.BaseSpec" {
	
	function beforeAll() {
		variables.adminPassword = server.system.environment.LUCEE_ADMIN_PASSWORD ?: "admin";
		
		// Create test generator instance with test name - handles directory creation and cleanup
	variables.testGenerator = new "../GenerateTestData"(testName="AstComparisonTest");
		variables.testOutputDir = variables.testGenerator.getGeneratedArtifactsDir();
	}
	
	function run() {
		describe("AST Implementation Comparison", function() {
			
			it("should generate EXL file for functions.cfm only", function() {
				// Generate EXL file for just functions.cfm
				var result = variables.testGenerator.generateExlFilesForArtifacts(
					adminPassword = variables.adminPassword,
					fileFilter = "functions.cfm"
				);
				
				expect(result.fileCount).toBeGT(0);
				expect(result.coverageFiles).toHaveLength(1);
				expect(result.coverageFiles[1]).toInclude(".exl");
			});
			
			it("should compare AST vs simple line counting approaches", function() {
				// Get the generated EXL file
				var coverageDir = variables.testGenerator.getCoverageDir();
				var exlFiles = directoryList(coverageDir, false, "path", "*.exl");
				expect(exlFiles).toHaveLength(1);
				
				var exlPath = exlFiles[1];
				
				// Create parser instance
				var parser = new lucee.extension.lcov.ExecutionLogParser();
				
				// Parse with AST approach (default)
				var astResult = parser.parseExlFile(
					exlPath = exlPath,
					useAstForLinesFound = true
				);
				
				// Parse with simple line counting approach
				var simpleResult = parser.parseExlFile(
					exlPath = exlPath,
					useAstForLinesFound = false
				);
				
				// Both should have parsed the same file
				expect(structCount(astResult.source.files)).toBe(structCount(simpleResult.source.files));
				
				// Get the functions.cfm file data
				var astFileData = {};
				var simpleFileData = {};
				
				for (var fileIdx in astResult.source.files) {
					var file = astResult.source.files[fileIdx];
					if (find("functions.cfm", file.path)) {
						astFileData = file;
						break;
					}
				}
				
				for (var fileIdx in simpleResult.source.files) {
					var file = simpleResult.source.files[fileIdx];
					if (find("functions.cfm", file.path)) {
						simpleFileData = file;
						break;
					}
				}
				
				// Compare results
				systemOutput("", true);
				systemOutput("=== AST Implementation Comparison ===", true);
				systemOutput("File: functions.cfm", true);
				systemOutput("", true);
				
				systemOutput("AST Approach:", true);
				systemOutput("  - linesFound: #astFileData.linesFound#", true);
				systemOutput("  - lineCount: #astFileData.lineCount#", true);
				
				systemOutput("", true);
				systemOutput("Simple Line Counting Approach:", true);
				systemOutput("  - linesFound: #simpleFileData.linesFound#", true);
				systemOutput("  - lineCount: #simpleFileData.lineCount#", true);
				
				systemOutput("", true);
				systemOutput("Difference: #abs(astFileData.linesFound - simpleFileData.linesFound)# lines", true);
				
				// Both approaches should return the same lineCount (total lines in file)
				expect(astFileData.lineCount).toBe(simpleFileData.lineCount);
				
				// Document the differences
				if (astFileData.linesFound != simpleFileData.linesFound) {
					systemOutput("", true);
					systemOutput("Note: The approaches differ in counting executable lines:", true);
					systemOutput("- AST approach attempts to traverse the AST structure", true);
					systemOutput("- Simple approach counts non-empty, non-comment lines", true);
				}
				
				// Store results for analysis
				variables.comparisonResults = {
					ast: astFileData,
					simple: simpleFileData,
					difference: abs(astFileData.linesFound - simpleFileData.linesFound)
				};
			});
			
			it("should analyze coverage accuracy with both approaches", function() {
				// Skip if no comparison results
				if (!structKeyExists(variables, "comparisonResults")) {
					skip("No comparison results available");
					return;
				}
				
				var coverageDir = variables.testGenerator.getCoverageDir();
				var exlFiles = directoryList(coverageDir, false, "path", "*.exl");
				var exlPath = exlFiles[1];
				
				// Parse to get coverage data
				var parser = new lucee.extension.lcov.ExecutionLogParser();
				var coverageData = parser.parseExlFile(exlPath = exlPath);
				
				// Count actual covered lines
				var coveredLines = {};
				for (var fileIdx in coverageData.coverage) {
					if (find("functions.cfm", coverageData.source.files[fileIdx].path)) {
						for (var line in coverageData.coverage[fileIdx]) {
							coveredLines[line] = true;
						}
					}
				}
				
				var actualCoveredCount = structCount(coveredLines);
				
				systemOutput("", true);
				systemOutput("=== Coverage Accuracy Analysis ===", true);
				systemOutput("Actual lines covered: #actualCoveredCount#", true);
				systemOutput("", true);
				
				// Calculate coverage percentages
				var astCoverage = (actualCoveredCount / variables.comparisonResults.ast.linesFound) * 100;
				var simpleCoverage = (actualCoveredCount / variables.comparisonResults.simple.linesFound) * 100;
				
				systemOutput("Coverage with AST approach: #numberFormat(astCoverage, '99.9')#%", true);
				systemOutput("Coverage with Simple approach: #numberFormat(simpleCoverage, '99.9')#%", true);
				systemOutput("", true);
				
				// The coverage percentage should be reasonable (not over 100%)
				expect(astCoverage).toBeLTE(100);
				expect(simpleCoverage).toBeLTE(100);
				
				// Document which approach is more accurate
				if (abs(astCoverage - 50) < abs(simpleCoverage - 50)) {
					systemOutput("AST approach appears more accurate for this test case", true);
				} else if (abs(simpleCoverage - 50) < abs(astCoverage - 50)) {
					systemOutput("Simple line counting appears more accurate for this test case", true);
				} else {
					systemOutput("Both approaches produce similar accuracy", true);
				}
			});
			
			it("should verify both approaches handle edge cases", function() {
				var parser = new lucee.extension.lcov.ExecutionLogParser();
				
				// Test with empty lines and comments
				var testSourceLines = [
					"",  // empty line
					"// This is a comment",
					"/* Multi-line",
					"   comment */",
					"var x = 1;",  // executable
					"",
					"function test() {",  // potentially executable
					"    return true;",  // executable
					"}"
				];
				
				// Test simple line counting
				var simpleResult = parser.getAst().countExecutableLinesSimple(testSourceLines);
				var simpleCount = simpleResult.count;
				
				systemOutput("", true);
				systemOutput("=== Edge Case Testing ===", true);
				systemOutput("Test source has #arrayLen(testSourceLines)# total lines", true);
				systemOutput("Simple counting found #simpleCount# executable lines", true);
				
				// Should count lines 5, 7, 8 as executable (3 lines)
				expect(simpleCount).toBeGTE(2);  // At minimum lines 5 and 8
				expect(simpleCount).toBeLTE(4);  // At most lines 5, 7, 8, 9
			});
		});
	}
}