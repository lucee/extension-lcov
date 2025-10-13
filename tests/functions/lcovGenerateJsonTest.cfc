component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";

		variables.testDataGenerator = new "../GenerateTestData"(testName="lcovGenerateJsonTest");
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword=variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		variables.outputDir = variables.tempDir & "/output";
		directoryCreate(variables.outputDir);
	}

	function run() {

		describe("lcovGenerateJson with minimal parameters", function() {
			it("should generate JSON reports", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-minimal";
				directoryCreate(outputDir);

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				assertValidJsonResult( result );
				assertValidJsonFiles( result.jsonFiles );
				assertValidStats( result.stats );
			});
		});

		describe("lcovGenerateJson with formatting options", function() {
			it("should respect formatting options", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-formatted";
				directoryCreate(outputDir);
				var options = {
					compact: false,
					includeStats: true
				};

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidJsonResult( result );
				expect(fileExists(result.jsonFiles.results)).toBeTrue();

				var jsonContent = fileRead(result.jsonFiles.results);
				expect(jsonContent).toInclude(chr(10), "Non-compact JSON should have line breaks");
			});
		});

		describe("lcovGenerateJson with separateFiles option", function() {
			it("should create individual JSON files", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-separate";
				directoryCreate(outputDir);
				var options = {
					separateFiles: true
				};

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidJsonResult( result );

				var jsonFiles = directoryList(outputDir, false, "query", "*.json");
				expect(jsonFiles.recordCount).toBeGTE(1, "Should create individual JSON files when separateFiles=true");

				for (var row = 1; row <= jsonFiles.recordCount; row++) {
					var jsonFile = jsonFiles.name[row];
					var jsonPath = outputDir & "/" & jsonFile;

					if (!fileExists(jsonPath)) continue;
					if (!reFind("^file-[A-Z0-9]+-", jsonFile)) continue;

					var jsonContent = fileRead(jsonPath);
					var jsonData = deserializeJSON(jsonContent);

					expect(jsonData).toHaveKey("files", "Per-file JSON should have files structure: " & jsonFile);
					expect(structCount(jsonData.files)).toBe(1, "Per-file JSON should contain exactly ONE file entry: " & jsonFile);

					if (structKeyExists(jsonData, "coverage")) {
						expect(structCount(jsonData.coverage)).toBeLTE(1, "Per-file JSON should contain coverage for at most ONE file: " & jsonFile);
					}

					var fileEntry = jsonData.files[structKeyArray(jsonData.files)[1]];
					expect(fileEntry).toHaveKey("path", "File entry should have path property: " & jsonFile);

					var expectedFilePattern = reReplace(jsonFile, "^file-[A-Z0-9]+-(.+)\.(cfm|cfc)\.json$", "\1");
					expectedFilePattern = expectedFilePattern & "\.(cfm|cfc)";
					expect(fileEntry.path).toMatch(".*" & expectedFilePattern & "$", "File path should match the JSON filename pattern: " & jsonFile);
				}
			});
		});

		describe("lcovGenerateJson with compact option", function() {
			it("should create compact JSON", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-compact";
				directoryCreate(outputDir);
				var options = {
					compact: true,
					includeStats: false
				};

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidJsonResult( result );
				expect(fileExists(result.jsonFiles.results)).toBeTrue();

				var jsonContent = fileRead(result.jsonFiles.results);
				var lineBreaks = arrayLen(listToArray(jsonContent, chr(10)));
				expect(lineBreaks).toBeLTE(5, "Compact JSON should have minimal line breaks");
			});
		});

		describe("lcovGenerateJson with filtering", function() {
			it("should apply filters", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-filtered";
				directoryCreate(outputDir);
				var options = {
					allowList: ["/test"],
					blocklist: ["/vendor", "/testbox"]
				};

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir,
					options=options
				);

				assertValidJsonResult( result );
				expect(result.stats.totalFiles).toBeGTE(0);
			});
		});

		describe("lcovGenerateJson with invalid log directory", function() {
			it("should throw an exception", function() {
				var invalidLogDir = "/non/existent/directory";
				var outputDir = variables.outputDir & "/json-invalid";

				expect(function() {
					lcovGenerateJson(
						executionLogDir=invalidLogDir,
						outputDir=outputDir
					);
				}).toThrow();
			});
		});

		describe("lcovGenerateJson with empty log directory", function() {
			it("should handle gracefully", function() {
				var emptyLogDir = variables.tempDir & "/empty-logs";
				directoryCreate(emptyLogDir);
				var outputDir = variables.outputDir & "/json-empty";
				directoryCreate(outputDir);

				var result = lcovGenerateJson(
					executionLogDir=emptyLogDir,
					outputDir=outputDir
				);

				assertValidJsonResult( result );
				expect(result.stats.totalFiles).toBe(0, "Should report zero files for empty directory");
			});
		});

		describe("lcovGenerateJson content structure", function() {
			it("should contain valid coverage data", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-content";
				directoryCreate(outputDir);

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				expect(fileExists(result.jsonFiles.results)).toBeTrue();

				var jsonContent = fileRead(result.jsonFiles.results);
				var parsedJson = deserializeJson(jsonContent);

				expect(parsedJson).toBeStruct("JSON should be valid and parseable");
				expect(isStruct(parsedJson)).toBeTrue("Parsed JSON should be a struct");
			});
		});

		describe("lcovGenerateJson with multiple files", function() {
			it("should merge coverage data", function() {
				var executionLogDir = variables.testLogDir;
				var outputDir = variables.outputDir & "/json-multiple";
				directoryCreate(outputDir);

				var result = lcovGenerateJson(
					executionLogDir=executionLogDir,
					outputDir=outputDir
				);

				assertValidJsonResult( result );
				expect(result.stats.totalFiles).toBeGTE(1, "Should process multiple files");

				expect(fileExists(result.jsonFiles.merged)).toBeTrue();
				var mergedContent = fileRead(result.jsonFiles.merged);
				var mergedData = deserializeJson(mergedContent);
				expect(isStruct(mergedData)).toBeTrue("Merged JSON should be valid");
			});
		});
	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

	private void function assertValidJsonResult( required struct result ) {
		expect( arguments.result ).toBeStruct();
		expect( arguments.result ).toHaveKey( "jsonFiles" );
		expect( arguments.result ).toHaveKey( "stats" );
	}

	private void function assertValidJsonFiles( required struct jsonFiles ) {
		expect( arguments.jsonFiles ).toHaveKey( "results" );
		expect( arguments.jsonFiles ).toHaveKey( "merged" );
		expect( arguments.jsonFiles ).toHaveKey( "stats" );
		expect( fileExists( arguments.jsonFiles.results ) ).toBeTrue( "Results JSON should be created" );
		expect( fileExists( arguments.jsonFiles.merged ) ).toBeTrue( "Merged JSON should be created" );
		expect( fileExists( arguments.jsonFiles.stats ) ).toBeTrue( "Stats JSON should be created" );
	}

	private void function assertValidStats( required struct stats ) {
		expect( arguments.stats ).toHaveKey( "totalLinesSource" );
		expect( arguments.stats ).toHaveKey( "totalLinesHit" );
		expect( arguments.stats ).toHaveKey( "totalLinesFound" );
		expect( arguments.stats ).toHaveKey( "coveragePercentage" );
		expect( arguments.stats ).toHaveKey( "totalFiles" );
		expect( arguments.stats ).toHaveKey( "processingTimeMs" );
	}

}
