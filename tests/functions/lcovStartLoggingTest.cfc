component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";

		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovStartLoggingTest");
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		try {
			lcovStopLogging(adminPassword=variables.adminPassword);
		} catch (any e) {
			// Ignore cleanup errors
		}
	}

	function run() {

		describe("lcovStartLogging with minimal parameters", function() {
			it("should return a log directory path", function() {
				var adminPassword = variables.adminPassword;

				var logDirectory = lcovStartLogging(adminPassword=adminPassword);

				expect(logDirectory).toBeString();
				expect(logDirectory).notToBeEmpty();
				expect(directoryExists(logDirectory)).toBeTrue("Log directory should exist");

				lcovStopLogging(adminPassword=adminPassword);
			});
		});

		describe("lcovStartLogging with custom directory", function() {
			it("should use the specified directory", function() {
				var adminPassword = variables.adminPassword;
				var customDir = variables.tempDir & "/custom-logs";
				directoryCreate(customDir);

				var logDirectory = lcovStartLogging(
					adminPassword=adminPassword,
					executionLogDir=customDir
				);

				expect(logDirectory).toBe(customDir);
				expect(directoryExists(customDir)).toBeTrue("Custom directory should exist");

				lcovStopLogging(adminPassword=adminPassword);
			});
		});

		describe("lcovStartLogging with options", function() {
			it("should configure logging with specified options", function() {
				var adminPassword = variables.adminPassword;
				var options = {
					unit: "milli",
					minTime: 1000,
					className: "lucee.runtime.engine.ResourceExecutionLog"
				};

				var logDirectory = lcovStartLogging(
					adminPassword=adminPassword,
					executionLogDir="",
					options=options
				);

				expect(logDirectory).toBeString();
				expect(logDirectory).notToBeEmpty();
				expect(directoryExists(logDirectory)).toBeTrue();

				lcovStopLogging(adminPassword=adminPassword);
			});
		});

		describe("lcovStartLogging with invalid admin password", function() {
			it("should throw an exception", function() {
				var invalidPassword = "invalid-password-123";

				expect(function() {
					lcovStartLogging(adminPassword=invalidPassword);
				}).toThrow();
			});
		});

		describe("lcovStartLogging with empty executionLogDir", function() {
			it("should auto-generate a directory", function() {
				var adminPassword = variables.adminPassword;

				var logDirectory = lcovStartLogging(
					adminPassword=adminPassword,
					executionLogDir=""
				);

				expect(logDirectory).toBeString();
				expect(logDirectory).notToBeEmpty();
				expect(directoryExists(logDirectory)).toBeTrue();
				expect(logDirectory).toInclude("execution-log", "Should use default execution-log directory");

				lcovStopLogging(adminPassword=adminPassword);
			});
		});
	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

}
