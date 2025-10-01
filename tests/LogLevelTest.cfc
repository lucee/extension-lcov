component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" skip="true" {

	function beforeAll() {
		variables.testData = new GenerateTestData(testName = "LogLevelTest");
		variables.testData.generateExlFilesForArtifacts(adminPassword=request.SERVERADMINPASSWORD, fileFilter="loops.cfm");
		variables.exlDir = variables.testData.getSourceArtifactsDir();
	}

	function run() {
		describe("Logger log levels", function() {

			it("should log nothing at level none", function() {
				systemOutput("", true);
				systemOutput("=== Testing logLevel: none ===", true);

				var result = lcovGenerateHtml(
					executionLogDir = variables.exlDir,
					outputDir = variables.testData.getOutputDir("none"),
					options = {
						logLevel: "none",
						separateFiles: false
					}
				);

				expect(result).toHaveKey("stats");
				systemOutput("Completed: none", true);
			});

			it("should log INFO, DEBUG, and TRACE at level info", function() {
				systemOutput("", true);
				systemOutput("=== Testing logLevel: info ===", true);

				var result = lcovGenerateHtml(
					executionLogDir = variables.exlDir,
					outputDir = variables.testData.getOutputDir("info"),
					options = {
						logLevel: "info",
						separateFiles: false
					}
				);

				expect(result).toHaveKey("stats");
				systemOutput("Completed: info", true);
			});

			it("should log DEBUG and TRACE at level debug", function() {
				systemOutput("", true);
				systemOutput("=== Testing logLevel: debug ===", true);

				var result = lcovGenerateHtml(
					executionLogDir = variables.exlDir,
					outputDir = variables.testData.getOutputDir("debug"),
					options = {
						logLevel: "debug",
						separateFiles: false
					}
				);

				expect(result).toHaveKey("stats");
				systemOutput("Completed: debug", true);
			});

			it("should log TRACE at level trace", function() {
				systemOutput("", true);
				systemOutput("=== Testing logLevel: trace ===", true);

				var result = lcovGenerateHtml(
					executionLogDir = variables.exlDir,
					outputDir = variables.testData.getOutputDir("trace"),
					options = {
						logLevel: "trace",
						separateFiles: false
					}
				);

				expect(result).toHaveKey("stats");
				systemOutput("Completed: trace", true);
			});

		});

		describe("Logger direct testing", function() {

			it("should log at level none", function() {
				systemOutput("", true);
				systemOutput("=== Direct Logger test: none ===", true);
				var logger = new lucee.extension.lcov.Logger(level="none");
				logger.info("INFO message");
				logger.debug("DEBUG message");
				logger.trace("TRACE message");
				systemOutput("Completed direct test: none", true);
			});

			it("should log at level info", function() {
				systemOutput("", true);
				systemOutput("=== Direct Logger test: info ===", true);
				var logger = new lucee.extension.lcov.Logger(level="info");
				logger.info("INFO message");
				logger.debug("DEBUG message");
				logger.trace("TRACE message");
				systemOutput("Completed direct test: info", true);
			});

			it("should log at level debug", function() {
				systemOutput("", true);
				systemOutput("=== Direct Logger test: debug ===", true);
				var logger = new lucee.extension.lcov.Logger(level="debug");
				logger.info("INFO message");
				logger.debug("DEBUG message");
				logger.trace("TRACE message");
				systemOutput("Completed direct test: debug", true);
			});

			it("should log at level trace", function() {
				systemOutput("", true);
				systemOutput("=== Direct Logger test: trace ===", true);
				var logger = new lucee.extension.lcov.Logger(level="trace");
				logger.info("INFO message");
				logger.debug("DEBUG message");
				logger.trace("TRACE message");
				systemOutput("Completed direct test: trace", true);
			});

		});
	}
}
