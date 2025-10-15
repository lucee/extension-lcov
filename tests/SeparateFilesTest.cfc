
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger(level=variables.logLevel);
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
		var outputDir = variables.testDataGenerator.getOutputDir( "false" );
		var options = {
			separateFiles: false,
			logLevel: variables.logLevel
		};

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
		expect(nonIndexFiles).NotToBeEmpty("no Html files produced in " & outputDir);
	}

	private function testSeparateFilesTrue() {
		var outputDir = variables.testDataGenerator.getOutputDir( "true" );
		var options = {
			separateFiles: true,
			logLevel: variables.logLevel
		};

		var result = lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = outputDir,
			options = options
		);

		expect(fileExists(outputDir & "index.html")).toBeTrue("Should have index.html");

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

		var nonIndexFiles = arrayFilter(htmlFiles, function(file) {
			return file != "index.html";
		});

		//systemOutput("separateFiles: true - Generated " & arrayLen(nonIndexFiles) & " HTML files", true);
		expect(arrayLen(nonIndexFiles)).toBeGT(0, "Should have generated HTML report files in directory: " & outputDir & " (found files: " & arrayToList(htmlFiles) & ")");

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
		var combinedDir = variables.testDataGenerator.getOutputDir( "by-request-comparison" );
		var separateDir = variables.testDataGenerator.getOutputDir( "by-source-file-comparison" );

		lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = combinedDir,
			options = {
				separateFiles: false,
				logLevel: variables.logLevel
			}
		);

		lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = separateDir,
			options = {
				separateFiles: true,
				logLevel: variables.logLevel
			}
		);

		var combinedFiles = directoryList(combinedDir, false, "name", "*.html");
		var separateFiles = directoryList(separateDir, false, "name", "*.html");

		//systemOutput("separateFiles: false generated " & arrayLen(combinedFiles) & " files", true);
		//systemOutput("separateFiles: true generated " & arrayLen(separateFiles) & " files", true);

		// Currently both approaches should generate the same files because separateFiles isn't implemented
		// Once fixed, separateFiles: true should create source-file-based HTML files
		expect(arrayLen(separateFiles)).toBeGTE(arrayLen(combinedFiles), "Should generate at least as many files (separateFiles:false=" & arrayLen(combinedFiles) & " files in " & combinedDir & ", separateFiles:true=" & arrayLen(separateFiles) & " files in " & separateDir & ")");
	}

	private function testIndexJsonContent() {
		var outputDir = variables.testDataGenerator.getOutputDir( "json-validation" );
		var options = {
			separateFiles: true,
			logLevel: variables.logLevel
		};

		lcovGenerateHtml(
			executionLogDir = variables.testData.coverageDir,
			outputDir = outputDir,
			options = options
		);

		var indexJsonPath = outputDir & "index.json";
		expect(fileExists(indexJsonPath)).toBeTrue("Should have index.json file at: " & indexJsonPath & " (output dir contents: " & arrayToList(directoryList(outputDir, false, "name")) & ")");

		var indexJsonContent = fileRead(indexJsonPath);
		var indexData = deserializeJSON(indexJsonContent);

		//systemOutput("index.json structure: " & (isArray(indexData) ? "Array of " & arrayLen(indexData) & " entries" : "Object with keys: " & structKeyList(indexData)), true);

		expect(isArray(indexData)).toBeTrue("index.json should be an array of report entries");
		expect(arrayLen(indexData)).toBeGT(0, "Should have at least one report entry");

		var firstReport = indexData[1];
		var expectedFields = ["scriptName", "htmlFile", "totalLinesFound", "totalLinesHit"];

		for (var field in expectedFields) {
			expect(firstReport).toHaveKey( field );
		}

		expect(firstReport).toHaveKey("totalLinesFound", "Should have totalLinesFound");
		expect(firstReport).toHaveKey("totalLinesHit", "Should have totalLinesHit");

		var hasNonZeroCoverage = false;
		for (var report in indexData) {
			expect(report).toHaveKey("totalLinesFound");
			expect(report.totalLinesFound).toBeTypeOf("numeric");
			expect(report).toHaveKey("totalLinesHit");
			expect(report.totalLinesHit).toBeTypeOf("numeric");
			if (report.totalLinesFound > 0 && report.totalLinesHit > 0) {
				hasNonZeroCoverage = true;
				var coveragePercent = report.totalLinesFound > 0 ? (report.totalLinesHit / report.totalLinesFound) * 100 : 0;
				variables.logger.debug("Found report with coverage: " & report.scriptName & " - " &
					report.totalLinesHit & "/" & report.totalLinesFound &
					" (" & numberFormat(coveragePercent, "0.0") & "%)");
				break;
			}
		}
		expect(hasNonZeroCoverage).toBeTrue("At least one report in " & outputDir & " should have non-zero coverage data: " & serializeJSON(indexData));

		var jsonFiles = directoryList(outputDir, false, "name", "file-*.json");
		expect(arrayLen(jsonFiles)).toBeGT(0, "Should have individual file JSON files in [" & outputDir & "]");

		for (var jsonFile in jsonFiles) {
			var jsonPath = outputDir & jsonFile;
			if (!fileExists(jsonPath)) continue;

			var jsonContent = fileRead(jsonPath);
			var jsonData = deserializeJSON(jsonContent);

			expect(jsonData).toHaveKey("files", "Per-file JSON should have files structure: " & jsonFile);
			expect(structCount(jsonData.files)).toBe(1, "Per-file JSON should contain exactly ONE file entry, not all files from execution: " & jsonFile & " (found " & structCount(jsonData.files) & " files)");

			if (structKeyExists(jsonData, "coverage")) {
				expect(structCount(jsonData.coverage)).toBeLTE(1, "Per-file JSON should contain coverage for at most ONE file: " & jsonFile & " (found " & structCount(jsonData.coverage) & " coverage entries)");
			}
		}
	}
}