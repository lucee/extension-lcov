component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.parser = variables.factory.getComponent(name="ExecutionLogParser");

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="MinTimeTest");
		variables.tempDir = variables.testDataGenerator.getGeneratedArtifactsDir();

		variables.debug = true;

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
		describe("Execution log metadata parsing", function() {

			it("parses min-time-nano metadata when unit=nano and minTime=10", function() {
				testParseMetadata(unit="nano", minTime=10, expectedUnitSymbol="ns", expectedNanoValue=10);
			});

			it("parses min-time-nano metadata when unit=micro and minTime=10", function() {
				testParseMetadata(unit="micro", minTime=10, expectedUnitSymbol="μs", expectedNanoValue=10);
			});

			it("parses min-time-nano metadata when unit=milli and minTime=10", function() {
				testParseMetadata(unit="milli", minTime=10, expectedUnitSymbol="ms", expectedNanoValue=10);
			});

			it("parses min-time metadata of 0 when minTime not specified", function() {
				testParseMetadata(unit="micro", minTime=0, expectedUnitSymbol="μs", expectedNanoValue=0);
			});

		});

		describe("Static execution log parsing", function() {

			it("parses static example 1 from misParse artifacts", function() {
				testParseStaticExlFile(1);
			});

			it("parses static example 2 from misParse artifacts", function() {
				testParseStaticExlFile(2);
			});

			it("parses static example 3 from misParse artifacts", function() {
				testParseStaticExlFile(3);
			});
		});

	}

	/**
	 * Test parser-only functionality - just parse metadata from generated .exl files
	 */
	private function testParseMetadata(required string unit, required numeric minTime, required string expectedUnitSymbol, required numeric expectedNanoValue) {
		var testDataGenerator = new "../GenerateTestData"(testName="MinTimeTest-parse-" & arguments.unit & "-" & arguments.minTime);
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

		var exlFiles = directoryList(logDir, false, "path", "*.exl");
		expect(arrayLen(exlFiles)).toBeGT(0, "Should have generated at least one .exl file");

		var result = variables.parser.parseExlFile(exlFiles[1]);
		expect(result.getMetadata()).notToBeEmpty("Metadata should not be empty");

		var metadata = result.getMetadata();
		expect(metadata).toHaveKey("min-time-nano", "Metadata should have min-time-nano key");
		expect(metadata["min-time-nano"]).toBe(arguments.expectedNanoValue);
		expect(metadata).toHaveKey("unit", "Metadata should have unit key");
		expect(metadata.unit).toBe(arguments.expectedUnitSymbol);
	}

	/**
	 * Test parser on static .exl files from misParse artifacts (edge cases)
	 */
	private function testParseStaticExlFile(required numeric exampleNumber) {
		var artifactDir = expandPath(getDirectoryFromPath(getCurrentTemplatePath()) & "../artifacts/misParse/" & arguments.exampleNumber & "/");
		var exlFiles = directoryList(path=artifactDir, filter="*.exl");
		expect(arrayLen(exlFiles)).toBeGT(0, "Should have .exl file in misParse/" & arguments.exampleNumber);
		if (variables.debug) {
			systemOutput("Parsing static .exl file: " & exlFiles[1], true);
		}
		var result = variables.parser.parseExlFile(exlFiles[1]);

		expect(result).notToBeNull("Parser should return a result object");
		expect(result.getMetadata()).notToBeEmpty("Metadata should not be empty");
		expect(result.getCoverage()).notToBeEmpty("Coverage data should not be empty");

		var metadata = result.getMetadata();
		expect(metadata).toHaveKey("unit", "Metadata should have unit key");
		expect(metadata).toHaveKey("execution-time", "Metadata should have execution-time key");

		// Validate the unit is one of the supported values
		var supportedUnits = ["ns", "μs", "ms"];
		expect(arrayContains(supportedUnits, metadata.unit)).toBeTrue("Unit should be one of: " & arrayToList(supportedUnits) & " but got: " & metadata.unit);
		if (variables.debug) {
			systemOutput("Parsed unit: " & metadata.unit, true);
			systemOutput("Parsed metadata: " & serializeJSON(metadata), true);
		}
		
	}
}
