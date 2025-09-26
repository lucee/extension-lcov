component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="HtmlReporterValidationTest");
		variables.tempDir = variables.testDataGenerator.getGeneratedArtifactsDir();

		variables.debug = true;
		variables.validator = new ValidateHtmlReports();
		// add validator methods as mixins
		var validatorMeta = getMetaData(variables.validator);
		for (var method in validatorMeta.functions) {
			variables[method.name] = validator[method.name];
		}

		// Clean up any logging that might be enabled from previous runs
		try {
			lcovStopLogging(adminPassword=variables.adminPassword);
		} catch (any e) {
			// Ignore cleanup errors
		}
	}

	function afterAll(){
		// Leave test artifacts for inspection - no cleanup
		try {
			lcovStopLogging(adminPassword=variables.adminPassword);
		} catch (any e) {
			// Ignore cleanup errors
		}
	}

	function run() {
		describe("HTML Reporter Unit Display Validation", function() {

			it("displays units correctly when unit=nano and displayUnit=ms", function() {
				testHtmlUnitDisplay(unit="nano", minTime=10, testName="unit-nano-display-ms", displayUnit="ms");
			});

			it("displays units correctly when unit=micro and displayUnit=μs", function() {
				testHtmlUnitDisplay(unit="micro", minTime=10, testName="unit-micro-display-us", displayUnit="μs");
			});

			it("displays units correctly when unit=milli and displayUnit=ms", function() {
				testHtmlUnitDisplay(unit="milli", minTime=10, testName="unit-milli-display-ms", displayUnit="ms");
			});

			it("displays units correctly when unit=micro and displayUnit=s", function() {
				testHtmlUnitDisplay(unit="micro", minTime=10, testName="unit-micro-display-s", displayUnit="s");
			});

			it("auto-selects appropriate units when displayUnit=auto", function() {
				testHtmlUnitDisplay(unit="micro", minTime=10, testName="unit-micro-display-auto", displayUnit="auto");
			});

		});

		describe("HTML Reporter Edge Cases", function() {

			it("validates static example 1, known to cause problems", function() {
				testMisParse(1);
			});

			it("validates static example 2, Expected [9] Actual [74]", function() {
				testMisParse(2);
			});

			it("validates static example 3, Expected [0] Actual [25]", function() {
				testMisParse(3);
			});
		});

	}

	/**
	 * Test HTML unit display for different unit/displayUnit combinations
	 */
	private function testHtmlUnitDisplay(required string unit, required numeric minTime, required string testName, required string displayUnit) {
		var testDataGenerator = new "../GenerateTestData"(testName="HtmlReporterValidationTest-" & arguments.testName);
		var logDir = testDataGenerator.getCoverageDir();

		var executionLogOptions = {
			unit: arguments.unit
		};
		if (arguments.minTime > 0) {
			executionLogOptions["min-time"] = arguments.minTime;
		}

		testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword,
			executionLogOptions=executionLogOptions
		);

		var outputDir = testDataGenerator.getGeneratedArtifactsDir() & "reports/";
		directoryCreate(outputDir);

		lcovGenerateHtml(
			executionLogDir = logDir,
			outputDir = outputDir,
			options = { displayUnit = arguments.displayUnit, verbose=false }
		);

		// For auto unit selection, determine expected display unit based on typical execution times
		var expectedDisplayUnit = arguments.displayUnit;
		if (arguments.displayUnit == "auto") {
			// With micro source unit and typical test execution times, auto should select μs for most values
			// But we need to validate that auto selection is actually working, not just assume μs
			expectedDisplayUnit = "auto"; // Let the validation handle auto mode properly
		}

		// mixin from ValidateHtmlReports()
		validateHtmlExecutionTimeUnits(outputDir, arguments.unit, expectedDisplayUnit);
	}

	private function testMisParse(required numeric exampleNumber, string unit="") {
		var overrideLogDir = expandPath(getDirectoryFromPath(getCurrentTemplatePath()) & "../artifacts/misParse/" & exampleNumber & "/");
		var oldJsonFiles = directoryList(path=overrideLogDir, filter="*.json");
		if (arrayLen( oldJsonFiles )) {
			for (var file in oldJsonFiles) {
				fileDelete( file );
			}
		}
		var srcExlFiles = directoryList(path=overrideLogDir, filter="*.exl");
		if (variables.debug) {
			systemOutput("testMisParse: testing " & srcExlFiles.toJson(), true);
		}
		var testName="misParse-#exampleNumber#";
		var testDataGenerator = new "../GenerateTestData"(testName="HtmlReporterValidationTest-" & testName );
		var outputDir = testDataGenerator.getGeneratedArtifactsDir() & "reports/";
		directoryCreate(outputDir);

		var displayUnit = "μs"; // Default to microseconds
		if (arguments.unit == "second") {
			displayUnit = "s";
		} else if (arguments.unit == "milli") {
			displayUnit = "ms";
		} else if (arguments.unit == "nano") {
			displayUnit = "ms"; // Display nanoseconds as milliseconds
		}

		lcovGenerateHtml(
			executionLogDir = overrideLogDir,
			outputDir = outputDir,
			options = { displayUnit = displayUnit, verbose=true }
		);
		// mixin from ValidateHtmlReports()
		validateHtmlExecutionTimeUnits(outputDir, arguments.unit, displayUnit);
	}
}