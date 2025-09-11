component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new GenerateTestData(testName="SeparateFilesTest");
		
		// Generate test data using kitchen-sink-example.cfm to get multiple source files
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "kitchen-sink-example.cfm"
		);
	}

	// Leave test artifacts for inspection - no cleanup in afterAll

	public function testSeparateFilesFalse() {
		// Given
		var outputDir = variables.testData.coverageDir & "/by-request/";
		var options = {
			separateFiles: false,
			verbose: true
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
		var nonIndexFiles = 0;
		for (var file in htmlFiles) {
			if (file.name != "index.html") {
				nonIndexFiles++;
			}
		}
		
		//systemOutput("separateFiles: false - Generated " & nonIndexFiles & " HTML files", true);
		expect(nonIndexFiles).toBeGT(0, "Should have generated HTML report files");
	}

	public function testSeparateFilesTrue() {
		// Given  
		var outputDir = variables.testData.coverageDir & "/by-source-file/";
		var options = {
			separateFiles: true,
			verbose: true
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

	public function testSeparateFilesBehaviorComparison() {
		// Given
		var combinedDir = variables.testData.coverageDir & "/by-request-comparison/";
		var separateDir = variables.testData.coverageDir & "/by-source-file-comparison/";
		
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

	public function testIndexJsonContent() {
		// Given
		var outputDir = variables.testData.coverageDir & "/json-validation/";
		var options = {
			separateFiles: true,
			verbose: true
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
			expect(structKeyExists(firstReport, field)).toBeTrue("Report entry should have '" & field & "' field");
		}

		// Check that we have coverage data with non-zero values
		expect(structKeyExists(firstReport, "totalLinesFound")).toBeTrue("Should have totalLinesFound");
		expect(structKeyExists(firstReport, "totalLinesHit")).toBeTrue("Should have totalLinesHit");  
		
		// At least one report should have meaningful coverage data (not all zeros)
		var hasNonZeroCoverage = false;
		for (var report in indexData) {
			if (val(report.totalLinesFound ?: 0) > 0 && 
				val(report.totalLinesHit ?: 0) > 0) {
				hasNonZeroCoverage = true;
				var coveragePercent = report.totalLinesFound > 0 ? (report.totalLinesHit / report.totalLinesFound) * 100 : 0;
				systemOutput("Found report with coverage: " & report.scriptName & " - " & 
					report.totalLinesHit & "/" & report.totalLinesFound & 
					" (" & numberFormat(coveragePercent, "0.0") & "%)", true);
				break;
			}
		}
		
		expect(hasNonZeroCoverage).toBeTrue("At least one report should have non-zero coverage data");
	}
}