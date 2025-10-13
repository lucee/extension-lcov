component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;

		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateSummaryTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		variables.logLevel="info";
	}

	function run() {

		describe("lcovGenerateSummary with minimal parameters", function() {
			it("should return coverage statistics", function() {
				var executionLogDir = variables.testLogDir;

				var result = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options:{logLevel: variables.logLevel}
				);

				assertValidSummaryResult( result );
				assertValidDataTypes( result );
				assertValidRanges( result );
			});
		});

		describe("lcovGenerateSummary with options", function() {
			it("should respect the options", function() {
				var executionLogDir = variables.testLogDir;
				var options = {
					chunkSize: 25000
				};

				var result = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options=options
				);

				assertValidSummaryResult( result );
				expect(result.processingTimeMs).toBeGTE(0, "Should track processing time");
			});
		});

		describe("lcovGenerateSummary with filtering", function() {
			it("should apply filters to statistics", function() {
				var executionLogDir = variables.testLogDir;
				var options = {
					allowList: ["/test"],
					blocklist: ["/vendor", "/testbox"]
				};

				var result = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options=options
				);

				assertValidSummaryResult( result );
				expect(result.totalFiles).toBeGTE(0, "Should process files matching allowList");
				expect(structCount(result.fileStats)).toBeGTE(0, "Should have files matching allowList");
			});
		});

		describe("lcovGenerateSummary with blocklist", function() {
			it("should exclude blocked files from statistics", function() {
				var executionLogDir = variables.testLogDir;
				var options = {
					blocklist: ["artifacts/conditional"]
				};

				var result = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options=options
				);

				assertValidSummaryResult( result );
				expect(result.totalFiles).toBeGT(0, "Should report at least some files");
			});
		});

		describe("lcovGenerateSummary with invalid log directory", function() {
			it("should throw an exception", function() {
				var invalidLogDir = "/non/existent/directory";

				expect(function() {
					lcovGenerateSummary(
						executionLogDir=invalidLogDir
					);
				}).toThrow();
			});
		});

		describe("lcovGenerateSummary with empty log directory", function() {
			it("should return zero statistics", function() {
				var emptyLogDir = variables.tempDir & "/empty-logs";
				directoryCreate(emptyLogDir);

				var result = lcovGenerateSummary(
					executionLogDir=emptyLogDir
				);

				assertValidSummaryResult( result );
				expect(result.totalFiles).toBe(0, "Should report zero files for empty directory, got: " & result.totalFiles & ".");
				expect(result.totalLinesSource).toBe(0, "Should report zero lines for empty directory, got: " & result.totalLinesSource & ".");
				expect(result.totalLinesHit).toBe(0, "Should report zero covered lines for empty directory, got: " & result.totalLinesHit & ".");
				expect(result.coveragePercentage).toBe(0, "Should report zero coverage for empty directory, got: " & result.coveragePercentage & ".");
				expect(structCount(result.fileStats)).toBe(0, "fileStats should be empty for empty directory, got: " & serializeJSON(result.fileStats));
			});
		});

		describe("lcovGenerateSummary with multiple files", function() {
			it("should aggregate statistics across files", function() {
				var executionLogDir = variables.testLogDir;

				var result = lcovGenerateSummary(
					executionLogDir=executionLogDir
				);

				assertValidSummaryResult( result );
				expect(result.totalFiles).toBeGTE(1, "Should process multiple files, got: " & result.totalFiles & ".");

				var fileCount = structCount(result.fileStats);
				expect(fileCount).toBeGTE(1, "Should have stats for multiple files, got: " & fileCount & ".");

				assertValidFileStats( result.fileStats );
			});
		});

		describe("lcovGenerateSummary fileStats structure", function() {
			it("should contain per-file coverage details", function() {
				var executionLogDir = variables.testLogDir;

				var result = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options:{logLevel: variables.logLevel}
				);

				expect(result.fileStats).toBeStruct();

				for (var filePath in result.fileStats) {
					var fileData = result.fileStats[filePath];

					expect(fileData).toHaveKey("linesSource", "Each file should have linesSource");
					expect(fileData).toHaveKey("coveragePercentage", "Each file should have coveragePercentage");

					if (fileData.linesFound > 0) {
						var expectedPercentage = (fileData.linesHit / fileData.linesFound) * 100;

						expect(fileData.coveragePercentage).toBeCloseTo(expectedPercentage, 3,
							"Coverage percentage should match calculation for file " & filePath & ". Expected: " & expectedPercentage & ", got: " & fileData.coveragePercentage & ".");
						expect(fileData.coveragePercentage).toBeBetween(0, 100,
							"Coverage percentage out of range for file " & filePath & ". linesHit=" & fileData.linesHit & ", linesFound=" & fileData.linesFound & ", linesSource=" & fileData.linesSource & ", percentage=" & fileData.coveragePercentage);
					}
				}
			});
		});

		describe("lcovGenerateSummary with different chunk sizes", function() {
			it("should produce consistent results", function() {
				var executionLogDir = variables.testLogDir;

				var result1 = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options={chunkSize: 10000, logLevel: variables.logLevel}
				);

				var result2 = lcovGenerateSummary(
					executionLogDir=executionLogDir,
					options={chunkSize: 50000, logLevel: variables.logLevel}
				);

				expect(result1.totalFiles).toBe(result2.totalFiles, "Total files should be consistent. result1: " & result1.totalFiles & ", result2: " & result2.totalFiles & ".");
				expect(result1.totalLinesSource).toBe(result2.totalLinesSource, "Total lines should be consistent. result1: " & result1.totalLinesSource & ", result2: " & result2.totalLinesSource & ".");
				expect(result1.totalLinesHit).toBe(result2.totalLinesHit, "Covered lines should be consistent. result1: " & result1.totalLinesHit & ", result2: " & result2.totalLinesHit & ".");
				expect(result1.coveragePercentage).toBe(result2.coveragePercentage, "Coverage percentage should be consistent. result1: " & result1.coveragePercentage & ", result2: " & result2.coveragePercentage & ".");
			});
		});
	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

	private void function assertValidSummaryResult( required struct result ) {
		expect( arguments.result ).toBeStruct();
		expect( arguments.result ).toHaveKey( "totalLinesSource" );
		expect( arguments.result ).toHaveKey( "totalLinesHit" );
		expect( arguments.result ).toHaveKey( "totalLinesFound" );
		expect( arguments.result ).toHaveKey( "coveragePercentage" );
		expect( arguments.result ).toHaveKey( "totalFiles" );
		expect( arguments.result ).toHaveKey( "executedFiles" );
		expect( arguments.result ).toHaveKey( "processingTimeMs" );
		expect( arguments.result ).toHaveKey( "fileStats" );
	}

	private void function assertValidDataTypes( required struct result ) {
		expect( arguments.result.totalLinesSource ).toBeNumeric();
		expect( arguments.result.totalLinesHit ).toBeNumeric();
		expect( arguments.result.totalLinesFound ).toBeNumeric();
		expect( arguments.result.coveragePercentage ).toBeNumeric();
		expect( arguments.result.totalFiles ).toBeNumeric();
		expect( arguments.result.executedFiles ).toBeNumeric();
		expect( arguments.result.processingTimeMs ).toBeNumeric();
		expect( arguments.result.fileStats ).toBeStruct();
	}

	private void function assertValidRanges( required struct result ) {
		expect( arguments.result.coveragePercentage ).toBeBetween( 0, 100, "coveragePercentage should be between 0 and 100 but was " & arguments.result.coveragePercentage & "." );
		expect( arguments.result.processingTimeMs ).toBeGTE( 0, "processingTimeMs should be >= 0 but was " & arguments.result.processingTimeMs & "." );
		expect( arguments.result.totalLinesHit ).toBeLTE( arguments.result.totalLinesSource, "totalLinesHit (" & arguments.result.totalLinesHit & ") should be <= totalLinesSource (" & arguments.result.totalLinesSource & ")." );
	}

	private void function assertValidFileStats( required struct fileStats ) {
		for ( var filePath in arguments.fileStats ) {
			var fileData = arguments.fileStats[ filePath ];
			expect( fileData ).toHaveKey( "linesSource", "Missing linesSource for file " & filePath & "." );
			expect( fileData ).toHaveKey( "linesHit", "Missing linesHit for file " & filePath & "." );
			expect( fileData ).toHaveKey( "coveragePercentage", "Missing coveragePercentage for file " & filePath & "." );

			expect( fileData.linesSource ).toBeNumeric( "linesSource should be numeric for file " & filePath & "." );
			expect( fileData.linesHit ).toBeNumeric( "linesHit should be numeric for file " & filePath & "." );
			expect( fileData.coveragePercentage ).toBeBetween( 0, 100, "coveragePercentage should be between 0 and 100 for file " & filePath & ". linesHit=" & fileData.linesHit & ", linesFound=" & fileData.linesFound & ", linesSource=" & fileData.linesSource & ", percentage=" & fileData.coveragePercentage );
		}
	}

}
