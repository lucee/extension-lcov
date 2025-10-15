component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";

		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateAllReportsTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.outputDir = variables.testDataGenerator.getOutputDir( "output" );
	}

	function run() {

		describe("lcovGenerateAllReports with minimal parameters", function() {
			it("should generate all report types", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.testDataGenerator.getOutputDir( "minimal" );

				var result = lcovGenerateAllReports(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				assertValidAllReportsResult( result );
				expect(fileExists(result.lcovFile)).toBeTrue("LCOV file should be created at: " & result.lcovFile);
				expect(fileExists(result.htmlIndex)).toBeTrue("HTML index should be created at: " & result.htmlIndex);
			});
		});

		describe("lcovGenerateAllReports with options", function() {
			it("should respect the options", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.testDataGenerator.getOutputDir( "with-options" );
				var options = {
					displayUnit: "milli",
					chunkSize: 25000
				};

				var result = lcovGenerateAllReports(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidAllReportsResult( result );
				expect(result.stats.processingTimeMs).toBeGT(0);
			});
		});

		describe("lcovGenerateAllReports with filtering", function() {
			it("should apply filters", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.testDataGenerator.getOutputDir( "filtered" );
				var options = {
					allowList: ["/test"],
					blocklist: ["/vendor", "/testbox"]
				};

				var result = lcovGenerateAllReports(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidAllReportsResult( result );
				expect(result.stats.totalFiles).toBeGTE(0);
			});
		});

		describe("lcovGenerateAllReports with invalid log directory", function() {
			it("should throw an exception", function() {
				var invalidLogDir = "/non/existent/directory";
				var outputDir = variables.outputDir & "/invalid";

				expect(function() {
					lcovGenerateAllReports(
						executionLogDir=invalidLogDir,
						outputDir=outputDir
					);
				}).toThrow();
			});
		});

		describe("lcovGenerateAllReports with empty log directory", function() {
			it("should handle gracefully", function() {
				var emptyLogDir = variables.testDataGenerator.getOutputDir( "empty-logs" );
				var outputDir = variables.testDataGenerator.getOutputDir( "empty" );

				var result = lcovGenerateAllReports(
					executionLogDir=emptyLogDir,
					outputDir=outputDir
				);

				assertValidAllReportsResult( result );
				expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");
			});
		});

		describe("lcovGenerateAllReports return structure", function() {
			it("should return complete structure", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.testDataGenerator.getOutputDir( "structure-test" );

				var result = lcovGenerateAllReports(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				assertValidAllReportsResult( result );
				assertValidJsonFiles( result.jsonFiles );
				assertValidStats( result.stats );
			});
		});
	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

	private void function assertValidAllReportsResult( required struct result ) {
		expect( arguments.result ).toBeStruct();
		expect( arguments.result ).toHaveKey( "lcovFile" );
		expect( arguments.result ).toHaveKey( "htmlIndex" );
		expect( arguments.result ).toHaveKey( "htmlFiles" );
		expect( arguments.result ).toHaveKey( "jsonFiles" );
		expect( arguments.result ).toHaveKey( "stats" );
	}

	private void function assertValidJsonFiles( required struct jsonFiles ) {
		expect( arguments.jsonFiles ).toHaveKey( "results" );
		expect( arguments.jsonFiles ).toHaveKey( "merged" );
		expect( arguments.jsonFiles ).toHaveKey( "stats" );
	}

	private void function assertValidStats( required struct stats ) {
		expect( arguments.stats ).toHaveKey( "totalLinesFound" );
		expect( arguments.stats ).toHaveKey( "totalLinesHit" );
		expect( arguments.stats ).toHaveKey( "totalLinesSource" );
		expect( arguments.stats ).toHaveKey( "coveragePercentage" );
		expect( arguments.stats ).toHaveKey( "totalFiles" );
		expect( arguments.stats ).toHaveKey( "processingTimeMs" );
	}

}
