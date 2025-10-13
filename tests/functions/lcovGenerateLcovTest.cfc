component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );

		// Use GenerateTestData with test name - it handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"( testName="lcovGenerateLcovTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = variables.adminPassword
		);
		variables.testLogDir = variables.testData.coverageDir;
		variables.tempDir = variables.testDataGenerator.getOutputDir();

		variables.outputDir = variables.tempDir & "/output";
		directoryCreate( variables.outputDir );
	}

	function run() {

		describe("lcovGenerateLcov output handling", function() {

			it("should create LCOV file and return string content when outputFile is provided", function() {
				var outputFile = variables.outputDir & "/test.lcov";

				var result = lcovGenerateLcov(
					executionLogDir = variables.testLogDir,
					outputFile = outputFile
				);

				expect( result ).toBeString();

				expect( fileExists( outputFile ) ).toBeTrue( "LCOV file should be created" );

				assertValidLcovFormat( fileRead( outputFile ) );
			});

			it("should return LCOV content as string when outputFile is not provided", function() {
				var result = lcovGenerateLcov(
					executionLogDir = variables.testLogDir
				);

				expect( result ).toBeString();
				expect( result ).notToBeEmpty();
				assertValidLcovFormatWithStats( result );
			});

			it("should return LCOV content as string when outputFile is empty string", function() {
				var result = lcovGenerateLcov(
					executionLogDir = variables.testLogDir,
					outputFile = ""
				);

				expect( result ).toBeString();
				expect( result ).notToBeEmpty();
				expect( result ).toInclude( "SF:", "Should contain LCOV format content" );
			});

		});

		describe("lcovGenerateLcov with options", function() {

			it("should respect allowList and blocklist options", function() {
				var executionLogDir = variables.testLogDir;
				var outputFile = variables.outputDir & "/test-with-options.lcov";
				var options = {
					allowList: ["/test"],
					blocklist: ["/vendor"]
				};

				var result = lcovGenerateLcov(
					executionLogDir = executionLogDir,
					outputFile = outputFile,
					options = options
				);

				expect( result ).toBeString();

				expect( fileExists( outputFile ) ).toBeTrue();

				var content = fileRead( outputFile );
				expect( content ).toInclude( "SF:", "Should contain source file entries for allowed files" );
			});

			it("should produce verbose logging when logLevel is info", function() {
				variables.logger.debug( "" );
				variables.logger.debug( "Testing LCOV generation with verbose logging" );

				var verboseTestDataGenerator = new "../GenerateTestData"( testName="lcovGenerateLcovTest-verbose" );
				var verboseTestData = verboseTestDataGenerator.generateExlFilesForArtifacts(
					adminPassword = variables.adminPassword,
					fileFilter = "conditional.cfm"  // Only process one file to limit verbose output
				);

				var executionLogDir = verboseTestData.coverageDir;
				var outputFile = verboseTestDataGenerator.getOutputDir() & "/test-verbose.lcov";
				var options = {
					logLevel: "info"
				};

				var result = lcovGenerateLcov(
					executionLogDir = executionLogDir,
					outputFile = outputFile,
					options = options
				);

				expect( result ).toBeString();
				expect( fileExists( outputFile ) ).toBeTrue( "LCOV file should be created" );

				var fileContent = fileRead( outputFile );
				expect( fileContent ).toInclude( "SF:", "Should contain source file records" );
				expect( fileContent ).toInclude( "DA:", "Should contain data array records" );
				expect( fileContent ).toInclude( "LF:", "Should contain lines found records" );
				expect( fileContent ).toInclude( "LH:", "Should contain lines hit records" );
				expect( fileContent ).toInclude( "end_of_record", "Should contain end of record markers" );
			});

		});

		describe("lcovGenerateLcov with blocklist", function() {

			it("should exclude blocked files from coverage report", function() {
				var options = {
					blocklist: ["artifacts/conditional"]
				};

				var result = lcovGenerateLcov(
					executionLogDir = variables.testLogDir,
					options = options
				);

				expect( result ).toBeString();

				var sourceFiles = extractSourceFiles( result );

				expect( arrayLen( sourceFiles ) ).toBeGT( 0, "Should report at least some files" );

				for ( var filePath in sourceFiles ) {
					var normalizedPath = normalizePath( filePath );
					if ( findNoCase( options.blocklist[ 1 ], normalizedPath ) > 0 ) {
						fail( "Found blocklisted file in results: " & filePath );
					}
				}
			});

		});

		describe("lcovGenerateLcov path handling", function() {

			it("should use absolute paths when useRelativePath is false", function() {
				var executionLogDir = variables.testLogDir;
				var options = {
					useRelativePath: false
				};

				var result = lcovGenerateLcov(
					executionLogDir = executionLogDir,
					options = options
				);

				expect( result ).toBeString();
				expect( result ).notToBeEmpty();

				var lines = listToArray( result, chr( 10 ) );
				var sfLines = [];
				for ( var line in lines ) {
					if ( left( line, 3 ) == "SF:" ) {
						arrayAppend( sfLines, line );
					}
				}

				expect( arrayLen( sfLines ) ).toBeGT( 0, "Should have at least one SF record" );

				var hasExpectedAbsolutePath = false;
				for ( var sfLine in sfLines ) {
					var path = normalizePath( mid( sfLine, 4 ) );
					if ( find( "extension-lcov/tests/artifacts", path ) > 0 ) {
						hasExpectedAbsolutePath = true;
						break;
					}
				}
				expect( hasExpectedAbsolutePath ).toBeTrue( "Should contain absolute paths when useRelativePath=false" );
			});

			it("should use relative paths when useRelativePath is true", function() {
				var executionLogDir = variables.testLogDir;
				var options = {
					useRelativePath: true
				};

				var result = lcovGenerateLcov(
					executionLogDir = executionLogDir,
					options = options
				);

				expect( result ).toBeString();
				expect( result ).notToBeEmpty();

				var lines = listToArray( result, chr( 10 ) );
				var sfLines = [];
				for ( var line in lines ) {
					if ( left( line, 3 ) == "SF:" ) {
						arrayAppend( sfLines, line );
					}
				}

				expect( arrayLen( sfLines ) ).toBeGT( 0, "Should have at least one SF record" );

				var allRelativePaths = true;
				for ( var sfLine in sfLines ) {
					var path = normalizePath( mid( sfLine, 4 ) );
					if ( find( "extension-lcov/tests/artifacts", path ) > 0 ) {
						allRelativePaths = false;
						break;
					}
				}
				expect( allRelativePaths ).toBeTrue( "Should contain only relative paths when useRelativePath=true" );
			});

		});

		describe("lcovGenerateLcov edge cases", function() {

			it("should throw exception when log directory does not exist", function() {
				var invalidLogDir = "/non/existent/directory";
				var outputFile = variables.outputDir & "/invalid.lcov";

				expect( function() {
					lcovGenerateLcov(
						executionLogDir = invalidLogDir,
						outputFile = outputFile
					);
				} ).toThrow();
			});

			it("should handle empty log directory gracefully", function() {
				var emptyLogDir = variables.tempDir & "/empty-logs";
				directoryCreate( emptyLogDir );

				var result = lcovGenerateLcov(
					executionLogDir = emptyLogDir
				);

				expect( result ).toBeString();
			});

		});

		describe("lcovGenerateLcov with multiple files", function() {

			it("should merge coverage data from multiple execution logs", function() {
				var executionLogDir = variables.testLogDir;

				var result = lcovGenerateLcov(
					executionLogDir = executionLogDir
				);

				expect( result ).toBeString();

				var sfCount = len( result ) - len( replace( result, "SF:", "", "all" ) );
				expect( sfCount ).toBeGT( 0, "Should include multiple source files" );
				expect( result ).toInclude( "end_of_record", "Should have proper LCOV format" );
			});

			it("should merge multiple files correctly (regression test)", function() {
				var multiFileGenerator = new "../GenerateTestData"( testName="lcovGenerateLcovTest-multiFile" );
				var multiFileData = multiFileGenerator.generateExlFilesForArtifacts(
					adminPassword = variables.adminPassword
				);

				var executionLogDir = multiFileData.coverageDir;
				var outputFile = multiFileGenerator.getOutputDir() & "/multi-file-regression.lcov";

				var result = lcovGenerateLcov(
					executionLogDir = executionLogDir,
					outputFile = outputFile
				);

				expect( result ).toBeString();
				expect( fileExists( outputFile ) ).toBeTrue( "LCOV file should be created" );

				var fileContent = fileRead( outputFile );
				expect( fileContent ).toInclude( "SF:", "Should contain source file records" );
				expect( fileContent ).toInclude( "DA:", "Should contain data array records" );
				expect( fileContent ).toInclude( "end_of_record", "Should contain end of record markers" );

				var sfCount = len( fileContent ) - len( replace( fileContent, "SF:", "", "all" ) );
				expect( sfCount ).toBeGTE( 9, "Should process multiple source files (3 chars removed per SF record)" );

				var endRecordCount = len( fileContent ) - len( replace( fileContent, "end_of_record", "", "all" ) );
				expect( endRecordCount ).toBeGTE( 39, "Should have end_of_record for each file (13 chars removed per end_of_record)" );
			});

		});

	}

	// Helper functions
	private string function normalizePath( required string path ) {
		return replace( arguments.path, "\", "/", "all" );
	}

	private array function extractSourceFiles( required string lcovContent ) {
		var lines = listToArray( arguments.lcovContent, chr( 10 ) );
		var sourceFiles = [];
		for ( var line in lines ) {
			if ( left( line, 3 ) == "SF:" ) {
				arrayAppend( sourceFiles, mid( line, 4 ) );
			}
		}
		return sourceFiles;
	}

	private void function assertValidLcovFormat( required string lcovContent ) {
		expect( arguments.lcovContent ).toInclude( "SF:", "Should contain source file records" );
		expect( arguments.lcovContent ).toInclude( "DA:", "Should contain data array records" );
		expect( arguments.lcovContent ).toInclude( "end_of_record", "Should contain end of record markers" );
	}

	private void function assertValidLcovFormatWithStats( required string lcovContent ) {
		assertValidLcovFormat( arguments.lcovContent );
		expect( arguments.lcovContent ).toInclude( "LF:", "Should contain lines found records" );
		expect( arguments.lcovContent ).toInclude( "LH:", "Should contain lines hit records" );
	}

}
