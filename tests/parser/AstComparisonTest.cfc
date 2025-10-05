component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger(level=variables.logLevel);

		// Create test generator instance with test name - handles directory creation and cleanup
		variables.testGenerator = new "../GenerateTestData"(testName="AstComparisonTest");
		variables.testOutputDir = variables.testGenerator.getOutputDir();
	}

	function run() {
		describe("AST vs Simple Executable Line Counting Comparison", function() {

			it("should generate EXL file for kitchen-sink-example.cfm only", function() {
				// Generate EXL file for just kitchen-sink-example.cfm
				var result = variables.testGenerator.generateExlFilesForArtifacts(
					adminPassword = variables.adminPassword,
					fileFilter = "kitchen-sink-example.cfm"
				);

				expect(result.fileCount).toBeGT(0);
				expect(result.coverageFiles).toHaveLength(1);
				expect(result.coverageFiles[1]).toInclude(".exl");
			});

			it("should compare AST vs Simple method on kitchen-sink-example.cfm", function() {
				// Get the generated EXL file
				var coverageDir = variables.testGenerator.getExecutionLogDir();
				var exlFiles = directoryList(coverageDir, false, "path", "*.exl");
				expect(exlFiles).toHaveLength(1);

				var exlPath = exlFiles[1];

				// Create parser and ExecutableLineCounter instances
				var parser = new lucee.extension.lcov.ExecutionLogParser( options={logLevel: variables.logLevel} );
				var ast = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );

				// Parse to get file path and source
				var result = parser.parseExlFile(exlPath = exlPath);

				// Get the functions.cfm file data
				var fileData = {};
				var filePath = "";
				var files = result.getFiles();

				for (var fileIdx in files) {
					var file = files[fileIdx];
					if (find("kitchen-sink-example.cfm", file.path)) {
						fileData = file;
						filePath = file.path;
						break;
					}
				}

				expect(structCount(fileData)).toBeGT(0, "Should find kitchen-sink-example.cfm in parsed results");

				// Read source file and get AST
				var sourceContent = fileRead(filePath);
				var sourceLines = listToArray(sourceContent, chr(10), true, false);
				var parsedAst = astFromString(sourceContent);

				// Add sourceLines to AST if not present
				if (!structKeyExists(parsedAst, "sourceLines")) {
					parsedAst.sourceLines = sourceLines;
				}

				// TEMP write the ast to a debug file
				var astDebugPath = filePath & ".ast.json";
				variables.logger.debug("Generated AST for " & filePath & " saved as " & astDebugPath);
				fileWrite( astDebugPath, serializeJSON(var=parsedAst, compact=false) );

				// Count executable lines using both methods
				var simpleResult = ast.countExecutableLinesSimple(sourceLines);
				var astResult = ast.countExecutableLinesFromAst(parsedAst);

				// Output comparison
				variables.logger.debug("");
				variables.logger.debug("=== Executable Line Counting Comparison ===");
				variables.logger.debug("File: kitchen-sink-example.cfm");
				variables.logger.debug("  - Simple method: #simpleResult.count# lines");
				variables.logger.debug("  - AST method:    #astResult.count# lines");
				variables.logger.debug("  - Difference:    #(simpleResult.count - astResult.count)# lines");
				variables.logger.debug("");

				// Show which lines differ
				var simpleLines = simpleResult.executableLines;
				var astLines = astResult.executableLines;
				var onlyInSimple = [];
				var onlyInAst = [];

				for (var line in simpleLines) {
					if (!structKeyExists(astLines, line)) {
						arrayAppend(onlyInSimple, line);
					}
				}

				for (var line in astLines) {
					if (!structKeyExists(simpleLines, line)) {
						arrayAppend(onlyInAst, line);
					}
				}

				// Show all lines found by each method
				var simpleLinesList = structKeyArray(simpleLines);
				arraySort(simpleLinesList, "numeric");
				variables.logger.trace("Simple method lines: #arrayToList(simpleLinesList)#");

				var astLinesList = structKeyArray(astLines);
				arraySort(astLinesList, "numeric");
				variables.logger.trace("AST method lines: #arrayToList(astLinesList)#");

				if (arrayLen(onlyInSimple) > 0) {
					arraySort(onlyInSimple, "numeric");
					variables.logger.trace("Lines only in SIMPLE method: #arrayToList(onlyInSimple)#");
				}

				if (arrayLen(onlyInAst) > 0) {
					arraySort(onlyInAst, "numeric");
					variables.logger.trace("Lines only in AST method: #arrayToList(onlyInAst)#");
				}
				variables.logger.trace("");

				// Get actual coverage data from the parsed result for THIS file only
				var coverage = result.getCoverage();
				var actualCoveredLines = {};
				for (var fileIdx in coverage) {
					if (files[fileIdx].path == filePath) {
						for (var line in coverage[fileIdx]) {
							actualCoveredLines[line] = true;
						}
						break;
					}
				}

				// Show which AST lines have actual coverage
				var astLinesWithCoverage = [];
				var astLinesWithoutCoverage = [];
				for (var line in astLines) {
					if (structKeyExists(actualCoveredLines, line)) {
						arrayAppend(astLinesWithCoverage, line);
					} else {
						arrayAppend(astLinesWithoutCoverage, line);
					}
				}

				arraySort(astLinesWithCoverage, "numeric");
				arraySort(astLinesWithoutCoverage, "numeric");

				variables.logger.trace("AST lines WITH coverage: #arrayToList(astLinesWithCoverage)#");
				variables.logger.trace("AST lines WITHOUT coverage (over-counted): #arrayToList(astLinesWithoutCoverage)#");

				// Show which covered lines AST missed
				var coveredLinesMissedByAst = [];
				for (var line in actualCoveredLines) {
					if (!structKeyExists(astLines, line)) {
						arrayAppend(coveredLinesMissedByAst, line);
					}
				}
				arraySort(coveredLinesMissedByAst, "numeric");
				if (arrayLen(coveredLinesMissedByAst) > 0) {
					variables.logger.trace("Covered lines MISSED by AST (under-counted): #arrayToList(coveredLinesMissedByAst)#");
				}
				variables.logger.trace("");

				// Extract bytecode LineNumberTable (ground truth)
				var bytecodeAnalyzer = new lucee.extension.lcov.ast.BytecodeAnalyzer( logger=variables.logger );
				var bytecodeLines = bytecodeAnalyzer.extractLineNumberTable(filePath);
				variables.logger.debug("Bytecode extraction returned #structCount(bytecodeLines)# lines");
				if (structCount(bytecodeLines) > 0) {
					var bytecodeLinesList = structKeyArray(bytecodeLines);
					arraySort(bytecodeLinesList, "numeric");
					variables.logger.debug("=== Bytecode LineNumberTable (Ground Truth) ===");
					variables.logger.trace("Bytecode tracks #arrayLen(bytecodeLinesList)# lines: #arrayToList(bytecodeLinesList)#");

					// Compare AST vs Bytecode
					var astOnlyLines = [];
					var bytecodeOnlyLines = [];
					for (var line in astLines) {
						if (!structKeyExists(bytecodeLines, line)) {
							arrayAppend(astOnlyLines, line);
						}
					}
					for (var line in bytecodeLines) {
						if (!structKeyExists(astLines, line)) {
							arrayAppend(bytecodeOnlyLines, line);
						}
					}

					arraySort(astOnlyLines, "numeric");
					arraySort(bytecodeOnlyLines, "numeric");

					if (arrayLen(astOnlyLines) > 0) {
						variables.logger.trace("AST over-counted (not in bytecode): #arrayToList(astOnlyLines)#");
					}
					if (arrayLen(bytecodeOnlyLines) > 0) {
						variables.logger.trace("AST under-counted (in bytecode, not in AST): #arrayToList(bytecodeOnlyLines)#");
					}

					var accuracy = (astResult.count - arrayLen(astOnlyLines) - arrayLen(bytecodeOnlyLines)) / arrayLen(bytecodeLinesList) * 100;
					variables.logger.debug("AST accuracy: #numberFormat(accuracy, '99.9')#% (perfect = 100%)");
					variables.logger.trace("");
				}
				variables.logger.trace("");

				// Store results for next test
				variables.comparisonResults = {
					file: fileData,
					simpleCount: simpleResult.count,
					astCount: astResult.count,
					filePath: filePath
				};
			});

			it("should analyze coverage accuracy", function() {
				// Throw if no test results
				if (!structKeyExists(variables, "comparisonResults")) {
					throw(message="No comparison results available from previous test");
				}

				var coverageDir = variables.testGenerator.getExecutionLogDir();
				var exlFiles = directoryList(coverageDir, false, "path", "*.exl");
				var exlPath = exlFiles[1];

				// Parse to get coverage data
				var parser = new lucee.extension.lcov.ExecutionLogParser(options={logLevel: variables.logLevel});
				var coverageData = parser.parseExlFile(exlPath = exlPath);

				// Count actual covered lines
				var coveredLines = {};
				var coverage = coverageData.getCoverage();
				var files = coverageData.getFiles();

				for (var fileIdx in coverage) {
					if (find("functions-example.cfm", files[fileIdx].path)) {
						for (var line in coverage[fileIdx]) {
							coveredLines[line] = true;
						}
					}
				}

				var actualCoveredCount = structCount(coveredLines);

				variables.logger.trace("");
				variables.logger.debug("=== Coverage Accuracy Analysis ===");
				variables.logger.debug("Actual lines covered: #actualCoveredCount#");
				variables.logger.debug("Executable lines found (simple): #variables.comparisonResults.simpleCount#");
				variables.logger.debug("Executable lines found (AST): #variables.comparisonResults.astCount#");
				variables.logger.trace("");

				// Calculate coverage percentage using AST count
				var coveragePercent = (actualCoveredCount / variables.comparisonResults.astCount) * 100;

				variables.logger.debug("Coverage percentage: #numberFormat(coveragePercent, '99.9')#%");
				variables.logger.trace("");

				// The coverage percentage should be reasonable (not over 100%)
				expect(coveragePercent).toBeLTE(100, "Coverage should not exceed 100%");
				expect(coveragePercent).toBeGTE(0, "Coverage should be positive");
			});

			it("should handle edge cases correctly", function() {
				var ast = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );

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

				// Test simple line counting (deprecated but kept for reference)
				var simpleResult = ast.countExecutableLinesSimple(testSourceLines);
				var simpleCount = simpleResult.count;

				variables.logger.trace("");
				variables.logger.debug("=== Edge Case Testing ===");
				variables.logger.debug("Test source has #arrayLen(testSourceLines)# total lines");
				variables.logger.debug("Line counting found #simpleCount# executable lines");

				// Should count non-empty, non-comment lines as executable
				expect(simpleCount).toBeGTE(2);  // At minimum some executable lines
				expect(simpleCount).toBeLTE(6);  // At most all non-empty lines
			});

			it("should compare all artifact files against bytecode", function() {
				// Get all .cfm files from artifacts (excluding error subdirectory)
				var artifactFiles = directoryList(
					path = expandPath("/testAdditional/artifacts"),
					recurse = false,
					listInfo = "path",
					filter = "*.cfm"
				);

				variables.logger.trace("");
				variables.logger.debug("=== Testing All Artifact Files ===");
				variables.logger.debug("Found #arrayLen(artifactFiles)# artifact files to test");

				var ast = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );
				var bytecodeAnalyzer = new lucee.extension.lcov.ast.BytecodeAnalyzer( logger=variables.logger );
				var totalFiles = 0;
				var perfectMatches = 0;
				var totalAccuracy = 0;
				var results = [];

				for (var filePath in artifactFiles) {
					var fileName = getFileFromPath(filePath);

					// Skip files that won't have bytecode or are problematic
					if (findNoCase("error", fileName) || findNoCase("syntax", fileName)) {
						continue;
					}

					totalFiles++;

					// Read source
					var sourceContent = fileRead(filePath);
					// Split on newlines properly (handle both Unix \n and Windows \r\n)
					var sourceLines = sourceContent.split("\r?\n");

					// Get simple count
					var simpleResult = ast.countExecutableLinesSimple(sourceLines);

					// Try to get bytecode
					var bytecodeLines = bytecodeAnalyzer.extractLineNumberTable(filePath);
					var bytecodeCount = structCount(bytecodeLines);

					if (bytecodeCount > 0) {
						var accuracy = (simpleResult.count / bytecodeCount) * 100;
						totalAccuracy += accuracy;

						if (simpleResult.count == bytecodeCount) {
							perfectMatches++;
						}

						arrayAppend(results, {
							file: fileName,
							simple: simpleResult.count,
							bytecode: bytecodeCount,
							accuracy: accuracy
						});
					}
				}

				// Output summary
				variables.logger.trace("");
				variables.logger.debug("=== Summary Across All Files ===");
				variables.logger.debug("Total files tested: #totalFiles#");

				if (arrayLen(results) > 0) {
					variables.logger.debug("Files with bytecode: #arrayLen(results)#");
					variables.logger.debug("Perfect matches: #perfectMatches# (#numberFormat((perfectMatches/arrayLen(results))*100, '99.9')#%)");
					variables.logger.debug("Average accuracy: #numberFormat(totalAccuracy/arrayLen(results), '99.9')#%");
					variables.logger.trace("");

					// Show individual results
					for (var result in results) {
						var status = result.simple == result.bytecode ? "✓" : "✗";
						variables.logger.trace("#status# #result.file#: Simple=#result.simple#, Bytecode=#result.bytecode#, Accuracy=#numberFormat(result.accuracy, '99.9')#%");
					}
				} else {
					variables.logger.debug("No bytecode found for any files (files may not have been executed yet)");
				}

				// Test should pass as long as we ran some comparisons
				expect(totalFiles).toBeGT(0);
			});
		});
	}
}