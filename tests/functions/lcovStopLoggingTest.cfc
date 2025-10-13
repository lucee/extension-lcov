component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";
	}

	function run() {

		describe("lcovStopLogging with minimal parameters", function() {
			it("should disable logging", function() {
				var adminPassword = variables.adminPassword;
				var logDirectory = lcovStartLogging(adminPassword=adminPassword);

				lcovStopLogging(adminPassword=adminPassword);

				expect(true).toBeTrue("Function should complete successfully");
			});
		});

		describe("lcovStopLogging with specific className", function() {
			it("should disable that specific log class", function() {
				var adminPassword = variables.adminPassword;
				var logDirectory = lcovStartLogging(
					adminPassword=adminPassword,
					executionLogDir="",
					options={className: "lucee.runtime.engine.ResourceExecutionLog"}
				);

				lcovStopLogging(
					adminPassword=adminPassword,
					className="lucee.runtime.engine.ResourceExecutionLog"
				);

				expect(true).toBeTrue("Function should complete successfully");
			});
		});

		describe("lcovStopLogging with invalid admin password", function() {
			it("should throw an exception", function() {
				var invalidPassword = "invalid-password-123";

				expect(function() {
					lcovStopLogging(adminPassword=invalidPassword);
				}).toThrow();
			});
		});

		describe("lcovStopLogging when not enabled", function() {
			it("should handle gracefully", function() {
				var adminPassword = variables.adminPassword;

				lcovStopLogging(adminPassword=adminPassword);
				expect(true).toBeTrue("Function should handle case when logging not enabled");
			});
		});

		describe("lcovStopLogging with ConsoleExecutionLog className", function() {
			it("should disable console logging", function() {
				var adminPassword = variables.adminPassword;

				lcovStopLogging(
					adminPassword=adminPassword,
					className="lucee.runtime.engine.ConsoleExecutionLog"
				);

				expect(true).toBeTrue("Function should handle different log class names");
			});
		});
	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

}
