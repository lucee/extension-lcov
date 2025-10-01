component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovStartLoggingTest");
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		// Clean up any logging that might be enabled from previous runs
		try {
			lcovStopLogging(adminPassword=variables.adminPassword);
		} catch (any e) {
			// Ignore cleanup errors
		}
	}

	

	/**
	 * @displayName "Given I call lcovStartLogging with just admin password, When the function executes, Then it should return a log directory path"
	 */
	function testStartLoggingWithMinimalParameters() {
		// Given
		var adminPassword = variables.adminPassword;
		
		// When
		var logDirectory = lcovStartLogging(adminPassword=adminPassword);
		
		// Then
		expect(logDirectory).toBeString();
		expect(logDirectory).notToBeEmpty();
		expect(directoryExists(logDirectory)).toBeTrue("Log directory should exist");
		
		// Cleanup
		lcovStopLogging(adminPassword=adminPassword);
	}

	/**
	 * @displayName "Given I call lcovStartLogging with custom directory, When the function executes, Then it should use the specified directory"
	 */
	function testStartLoggingWithCustomDirectory() {
		// Given
		var adminPassword = variables.adminPassword;
		var customDir = variables.tempDir & "/custom-logs";
		directoryCreate(customDir);
		
		// When
		var logDirectory = lcovStartLogging(
			adminPassword=adminPassword,
			executionLogDir=customDir
		);
		
		// Then
		expect(logDirectory).toBe(customDir);
		expect(directoryExists(customDir)).toBeTrue("Custom directory should exist");
		
		// Cleanup
		lcovStopLogging(adminPassword=adminPassword);
	}

	/**
	 * @displayName "Given I call lcovStartLogging with options, When the function executes, Then it should configure logging with specified options"
	 */
	function testStartLoggingWithOptions() {
		// Given
		var adminPassword = variables.adminPassword;
		var options = {
			unit: "milli",
			minTime: 1000,
			className: "lucee.runtime.engine.ResourceExecutionLog"
		};
		
		// When
		var logDirectory = lcovStartLogging(
			adminPassword=adminPassword,
			executionLogDir="",
			options=options
		);
		
		// Then
		expect(logDirectory).toBeString();
		expect(logDirectory).notToBeEmpty();
		expect(directoryExists(logDirectory)).toBeTrue();
		
		// Cleanup
		lcovStopLogging(adminPassword=adminPassword);
	}

	/**
	 * @displayName "Given I call lcovStartLogging with invalid admin password, When the function executes, Then it should throw an exception"
	 */
	function testStartLoggingWithInvalidPassword() {
		// Given
		var invalidPassword = "invalid-password-123";
		
		// When/Then
		expect(function() {
			lcovStartLogging(adminPassword=invalidPassword);
		}).toThrow();
	}

	/**
	 * @displayName "Given I call lcovStartLogging with empty executionLogDir, When the function executes, Then it should auto-generate a directory"
	 */
	function testStartLoggingWithEmptyDirectory() {
		// Given
		var adminPassword = variables.adminPassword;
		
		// When
		var logDirectory = lcovStartLogging(
			adminPassword=adminPassword,
			executionLogDir=""
		);
		
		// Then
		expect(logDirectory).toBeString();
		expect(logDirectory).notToBeEmpty();
		expect(directoryExists(logDirectory)).toBeTrue();
		expect(logDirectory).toInclude("execution-log", "Should use default execution-log directory");
		
		// Cleanup
		lcovStopLogging(adminPassword=adminPassword);
	}
}