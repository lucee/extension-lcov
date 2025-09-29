
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	function beforeAll() {
		variables.debug = false;
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new GenerateTestData(testName="SeparateFilesTest");
		
		// Generate test data using kitchen-sink-example.cfm to get multiple source files
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "loops.cfm"
		);
	}

	

	function run() {
		describe("mergeResults BDD steps", function() {
			it("test separateFiles: false", function() {
				testSeparateFilesFalse();
			});

			it("test separateFiles: true", function() {
				testSeparateFilesTrue();
			});

			it("test separateFiles behavior comparison", function() {
				testSeparateFilesBehaviorComparison();
			});

			it("test index.json content with separateFiles: true", function() {
				testIndexJsonContent();
			});
		})
	}

	public function testSeparateFilesFalse() {
		// Given
		var outputDir = variables.testData.coverageDir & "/false/";
		if (!directoryExists(outputDir)) {
			directoryCreate(outputDir, true);
		}
		var options = {
			separateFiles: false,
			verbose: false
		};

		// When
		var result = lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = outputDir,
			options = options
		);

		// With separateFiles: false, should create one index.html and individual files for each .exl execution
		expect(fileExists(outputDir & "index.html")).toBeTrue("Should have index.html");
		
		// Count HTML files (excluding index.html)
		var htmlFiles = directoryList(outputDir, false, "query", "*.html");
		var nonIndexFiles = [];
		for (var file in htmlFiles) {
			if (file.name != "index.html") {
				arrayAppend(nonIndexFiles, file.name);
			}
		}
		// dumb test!!
		expect(nonIndexFiles).NotToBeEmpty("no Html files produced in " & outputDir);
	}

	private function testSeparateFilesTrue() {
		// Given
		var outputDir = variables.testData.coverageDir & "/true/";
		if (!directoryExists(outputDir)) {
			directoryCreate(outputDir, true);
		}
		var options = {
			separateFiles: true,
			verbose: false
		};

		// When
		var result = lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = outputDir,
			options = options
		);

		// With separateFiles: true, should create individual files for each SOURCE file
		expect(fileExists(outputDir & "index.html")).toBeTrue("Should have index.html");

		// Look for files that should be created for each source file from kitchen-sink
		var expectedSourceFiles = [
			"kitchen-sink-example", 
			"coverage-simple-sequential", 
			"conditional", 
			"loops", 
			"functions-example",
			"simple_cfc",
			"exception"
		];

		var htmlFiles = directoryList(outputDir, false, "name", "*.html");
		//systemOutput("separateFiles: true - Generated files: " & arrayToList(htmlFiles), true);

		// Count non-index files
		var nonIndexFiles = arrayFilter(htmlFiles, function(file) {
			return file != "index.html";
		});

		//systemOutput("separateFiles: true - Generated " & arrayLen(nonIndexFiles) & " HTML files", true);
		expect(arrayLen(nonIndexFiles)).toBeGT(0, "Should have generated HTML report files");

		// TODO: Once separateFiles is properly implemented, verify we get source-file-based names
		// instead of execution-run-based names like "5-test_index_cfm.html"
		
		// For now, just document what we currently get vs what we should get
		var currentBehavior = arrayFilter(nonIndexFiles, function(file) {
			return reFind("^\d+-.*\.html$", file);
		});
		
		if (arrayLen(currentBehavior) > 0) {
			//systemOutput("CURRENT BEHAVIOR: Getting execution-run-based files: " & arrayToList(currentBehavior), true);
		}
	}

	private function testSeparateFilesBehaviorComparison() {
		// Given
		var combinedDir = variables.testData.coverageDir & "/by-request-comparison/";
		var separateDir = variables.testData.coverageDir & "/by-source-file-comparison/";

		if (!directoryExists(combinedDir)) {
			directoryCreate(combinedDir, true);
		}
		if (!directoryExists(separateDir)) {
			directoryCreate(separateDir, true);
		}

		// When - Generate with separateFiles: false
		lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = combinedDir,
			options = { separateFiles: false }
		);

		// When - Generate with separateFiles: true  
		lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = separateDir,
			options = { separateFiles: true }
		);

		// Count files in each approach
		var combinedFiles = directoryList(combinedDir, false, "name", "*.html");
		var separateFiles = directoryList(separateDir, false, "name", "*.html");

		//systemOutput("separateFiles: false generated " & arrayLen(combinedFiles) & " files", true);
		//systemOutput("separateFiles: true generated " & arrayLen(separateFiles) & " files", true);

		// Currently both approaches should generate the same files because separateFiles isn't implemented
		// Once fixed, separateFiles: true should create source-file-based HTML files
		expect(arrayLen(separateFiles)).toBeGTE(arrayLen(combinedFiles), "Should generate at least as many files");
	}

	private function testIndexJsonContent() {
		// Given
		var outputDir = variables.testData.coverageDir & "/json-validation/";
		if (!directoryExists(outputDir)) {
			directoryCreate(outputDir, true);
		}
		var options = {
			separateFiles: true,
			verbose: false
		};

		// When
		lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = outputDir,
			options = options
		);

		// Then - Check that index.json exists and has valid content
		var indexJsonPath = outputDir & "index.json";
		expect(fileExists(indexJsonPath)).toBeTrue("Should have index.json file");

		// Load and validate the JSON content
		var indexJsonContent = fileRead(indexJsonPath);
		var indexData = deserializeJSON(indexJsonContent);

		//systemOutput("index.json structure: " & (isArray(indexData) ? "Array of " & arrayLen(indexData) & " entries" : "Object with keys: " & structKeyList(indexData)), true);

		// Validate the structure - should be an array of report entries
		expect(isArray(indexData)).toBeTrue("index.json should be an array of report entries");
		expect(arrayLen(indexData)).toBeGT(0, "Should have at least one report entry");

		// Check that each report entry has the expected fields
		var firstReport = indexData[1];
		var expectedFields = ["scriptName", "htmlFile", "totalLinesFound", "totalLinesHit"];

		for (var field in expectedFields) {
			expect(firstReport).toHaveKey( field );
		}

		// Check that we have coverage data with non-zero values
		expect(firstReport).toHaveKey("totalLinesFound", "Should have totalLinesFound");
		expect(firstReport).toHaveKey("totalLinesHit", "Should have totalLinesHit");

		// At least one report should have meaningful coverage data (not all zeros)
		var hasNonZeroCoverage = false;
		for (var report in indexData) {
			expect(report).toHaveKey("totalLinesFound");
			expect(report.totalLinesFound).toBeTypeOf("numeric");
			expect(report).toHaveKey("totalLinesHit");
			expect(report.totalLinesHit).toBeTypeOf("numeric");
			if (report.totalLinesFound > 0 && report.totalLinesHit > 0) {
				hasNonZeroCoverage = true;
				var coveragePercent = report.totalLinesFound > 0 ? (report.totalLinesHit / report.totalLinesFound) * 100 : 0;
				if (variables.debug) {
					systemOutput("Found report with coverage: " & report.scriptName & " - " &
						report.totalLinesHit & "/" & report.totalLinesFound &
						" (" & numberFormat(coveragePercent, "0.0") & "%)", true);
				}
				break;
			}
		}
		   expect(hasNonZeroCoverage).toBeTrue("At least one report in " & outputDir & " should have non-zero coverage data: "
			   & serializeJSON(indexData));

		// Validate that each individual per-file JSON contains only data for that specific file
		var jsonFiles = directoryList(outputDir, false, "name", "file-*.json");
		expect(arrayLen(jsonFiles)).toBeGT(0, "Should have individual file JSON files");

		for (var jsonFile in jsonFiles) {
			var jsonPath = outputDir & jsonFile;
			if (!fileExists(jsonPath)) continue;

			var jsonContent = fileRead(jsonPath);
			var jsonData = deserializeJSON(jsonContent);

			// Each per-file JSON should have exactly ONE file in the files structure
			expect(jsonData).toHaveKey("files", "Per-file JSON should have files structure: " & jsonFile);
			expect(structCount(jsonData.files)).toBe(1, "Per-file JSON should contain exactly ONE file entry, not all files from execution: " & jsonFile & " (found " & structCount(jsonData.files) & " files)");

			// Should have exactly ONE entry in coverage structure (for the single file)
			if (structKeyExists(jsonData, "coverage")) {
				expect(structCount(jsonData.coverage)).toBeLTE(1, "Per-file JSON should contain coverage for at most ONE file: " & jsonFile & " (found " & structCount(jsonData.coverage) & " coverage entries)");
			}
		}
	}
}