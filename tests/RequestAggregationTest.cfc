/*
	This test checks that request aggregation works correctly
	It does this by generating coverage for:
	- 1x request of a file that includes another file once
	- 2x requests of the same file
	- 1x request of a file that includes another file 5 times

	So the same exe logs, 2x and 5x, which get combined into per file json reports.

	It then checks that 
		- the execution counts in the resulting JSON files match
		- the isChild boolean flag, 3 element in the coverage is the same

	For both the json output per file, used to render HTML and and the JSON merged.json file
*/
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );

		// Generate test data for basic tests
		variables.testDataGenerator1 = new GenerateTestData( testName="RequestAggregationTest-1x" );
		variables.testData1 = variables.testDataGenerator1.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic.cfm",
			iterations = 1
		);

		variables.testDataGenerator2 = new GenerateTestData( testName="RequestAggregationTest-2x" );
		variables.testData2 = variables.testDataGenerator2.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic.cfm",
			iterations = 2
		);

		variables.testDataGenerator5 = new GenerateTestData( testName="RequestAggregationTest-5x" );
		variables.testData5 = variables.testDataGenerator5.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic-5x.cfm",
			iterations = 1
		);

		// Generate test data for kitchen-sink tests
		variables.testDataGenerator1KS = new GenerateTestData( testName="RequestAggregationTest-KS-1x" );
		variables.testData1KS = variables.testDataGenerator1KS.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "kitchen-sink-example.cfm",
			iterations = 1
		);

		variables.testDataGenerator2KS = new GenerateTestData( testName="RequestAggregationTest-KS-2x" );
		variables.testData2KS = variables.testDataGenerator2KS.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "kitchen-sink-example.cfm",
			iterations = 2
		);

		variables.testDataGenerator5KS = new GenerateTestData( testName="RequestAggregationTest-KS-5x" );
		variables.testData5KS = variables.testDataGenerator5KS.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/kitchen-sink-5x.cfm",
			iterations = 1
		);
	}

	function run() {
		describe( "Request Aggregation - basic", function() {

			it( "should have 2x the exec counts when run 2 times vs 1 time (multiple requests)", function() {
				testExecutionCountMultiplier(
					testDataGenerator1 = variables.testDataGenerator1,
					testData1 = variables.testData1,
					testDataGenerator2 = variables.testDataGenerator2,
					testData2 = variables.testData2
				);
			});

			it( "should have 5x the exec counts when included 5 times in single request", function() {
				testSingleRequestMultipleIncludes(
					testDataGenerator1 = variables.testDataGenerator1,
					testData1 = variables.testData1,
					testDataGenerator5 = variables.testDataGenerator5,
					testData5 = variables.testData5,
					filePattern = "file-*basic.cfm.json"
				);
			});
		});

		describe( "Request Aggregation - kitchen-sink", function() {


			it( "should have 2x the exec counts when run 2 times vs 1 time (multiple requests)", function() {
				testExecutionCountMultiplier(
					testDataGenerator1 = variables.testDataGenerator1KS,
					testData1 = variables.testData1KS,
					testDataGenerator2 = variables.testDataGenerator2KS,
					testData2 = variables.testData2KS
				);
			});

			it( "should have 5x the exec counts when included 5 times in single request", function() {
				testSingleRequestMultipleIncludes(
					testDataGenerator1 = variables.testDataGenerator1KS,
					testData1 = variables.testData1KS,
					testDataGenerator5 = variables.testDataGenerator5KS,
					testData5 = variables.testData5KS,
					filePattern = "file-*kitchen-sink-example.cfm.json"
				);
			});

		});
	}

	private function testExecutionCountMultiplier(
		required any testDataGenerator1,
		required struct testData1,
		required any testDataGenerator2,
		required struct testData2
	) {
		// Given: Generate JSON for both sets
		var outputDir1 = arguments.testDataGenerator1.getOutputDir( "json-1x" );
		var outputDir2 = arguments.testDataGenerator2.getOutputDir( "json-2x" );

		// When: Generate JSON reports with separateFiles: true
		lcovGenerateJson(
			executionLogDir = arguments.testData1.coverageDir,
			outputDir = outputDir1,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		lcovGenerateJson(
			executionLogDir = arguments.testData2.coverageDir,
			outputDir = outputDir2,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		// Then: Compare ALL per-file JSONs
		validateAllFiles( outputDir1, outputDir2, 2 );

		// Also validate merged.json
		validateMergedJson( outputDir1, outputDir2, 2 );
	}

	private function testSingleRequestMultipleIncludes(
		required any testDataGenerator1,
		required struct testData1,
		required any testDataGenerator5,
		required struct testData5,
		required string filePattern
	) {
		// Given: Generate JSON for both sets
		var outputDir1 = arguments.testDataGenerator1.getOutputDir( "json-1x-single" );
		var outputDir5 = arguments.testDataGenerator5.getOutputDir( "json-5x-single" );

		// When: Generate JSON reports with separateFiles: true
		lcovGenerateJson(
			executionLogDir = arguments.testData1.coverageDir,
			outputDir = outputDir1,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		lcovGenerateJson(
			executionLogDir = arguments.testData5.coverageDir,
			outputDir = outputDir5,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		// Then: Find JSON file in both sets and validate
		var jsonFiles1 = directoryList( outputDir1, false, "array", arguments.filePattern );
		var jsonFiles5 = directoryList( outputDir5, false, "array", arguments.filePattern );

		expect( arrayLen( jsonFiles1 ) ).toBe( 1, "Should have exactly one JSON from 1x run" );
		expect( arrayLen( jsonFiles5 ) ).toBe( 1, "Should have exactly one JSON from 5x run" );

		var fileName = listLast( arguments.filePattern, "*" );
		validateFileJson( jsonFiles1[ 1 ], jsonFiles5[ 1 ], 5, fileName & " (5x includes)" );

		// Also validate merged.json
		validateMergedJson( outputDir1, outputDir5, 5 );
	}

	private function validateAllFiles( required string outputDir1, required string outputDir2, required numeric expectedRatio ) {
		var jsonFiles1 = directoryList( arguments.outputDir1, false, "array", "file-*.json" );
		var jsonFiles2 = directoryList( arguments.outputDir2, false, "array", "file-*.json" );

		expect( arrayLen( jsonFiles1 ) ).toBeGT( 0, "Should have JSON files from 1x run" );
		expect( arrayLen( jsonFiles2 ) ).toBeGT( 0, "Should have JSON files from #arguments.expectedRatio#x run" );
		expect( arrayLen( jsonFiles1 ) ).toBe( arrayLen( jsonFiles2 ), "Should have same number of files in both runs" );

		var totalLinesChecked = 0;
		var filesChecked = 0;

		for ( var jsonFile1 in jsonFiles1 ) {
			var fileName = getFileFromPath( jsonFile1 );
			var jsonFile2 = arguments.outputDir2 & "/" & fileName;

			expect( fileExists( jsonFile2 ) ).toBeTrue( "#arguments.expectedRatio#x run should have matching file: #fileName#" );

			totalLinesChecked += validateFileJson( jsonFile1, jsonFile2, arguments.expectedRatio, fileName );
			filesChecked++;
		}

		variables.logger.info( "Validated #totalLinesChecked# lines across #filesChecked# files" );
		expect( totalLinesChecked ).toBeGT( 0, "Should have validated at least one line" );
	}

	private numeric function validateFileJson( required string jsonFile1, required string jsonFile2, required numeric expectedRatio, required string label ) {
		var json1 = deserializeJSON( fileRead( arguments.jsonFile1 ) );
		var json2 = deserializeJSON( fileRead( arguments.jsonFile2 ) );

		expect( structCount( json1.FILES ) ).toBe( structCount( json2.FILES ), "#arguments.label#: Should have same number of files" );

		var linesChecked = 0;

		// Validate all files in both JSONs match
		for ( var fileKey in json1.FILES ) {
			expect( structKeyExists( json2.FILES, fileKey ) ).toBeTrue( "#arguments.label#: File key #fileKey# should exist in both JSONs" );

			var file1 = json1.FILES[ fileKey ];
			var file2 = json2.FILES[ fileKey ];

			expect( file1.path ).toBe( file2.path, "#arguments.label#: Both JSON files should have same path for key #fileKey#" );

			var coverage1 = json1.coverage[ fileKey ];
			var coverage2 = json2.coverage[ fileKey ];

			for ( var lineNum in coverage1 ) {
				var hitCount1 = coverage1[ lineNum ][ 1 ];
				var hitCount2 = coverage2[ lineNum ][ 1 ];
				var isChild1 = coverage1[ lineNum ][ 3 ];
				var isChild2 = coverage2[ lineNum ][ 3 ];

				// Validate isChild flag matches
				expect( isChild1 ).toBe( isChild2, "#arguments.label# Line #lineNum#: isChild flag should match (1x=#isChild1#, 2x=#isChild2#)" );

				if ( hitCount1 > 0 ) {
					var hitRatio = hitCount2 / hitCount1;
					expect( hitRatio ).toBe( arguments.expectedRatio, "#arguments.label# Line #lineNum#: Expected #arguments.expectedRatio#x hit count ratio but got #hitRatio# (1x=#hitCount1#, #arguments.expectedRatio#x=#hitCount2#)" );
					linesChecked++;
				}
			}
		}

		return linesChecked;
	}

	private function validateMergedJson( required string outputDir1, required string outputDir2, required numeric expectedRatio ) {
		var merged1 = deserializeJSON( fileRead( arguments.outputDir1 & "/merged.json" ) );
		var merged2 = deserializeJSON( fileRead( arguments.outputDir2 & "/merged.json" ) );
		var mergedLinesChecked = 0;

		var coverage1 = merged1.mergedCoverage.coverage;
		var coverage2 = merged2.mergedCoverage.coverage;

		for ( var filePath in coverage1 ) {
			expect( structKeyExists( coverage2, filePath ) ).toBeTrue( "merged.json should have same file: #filePath#" );

			var lines1 = coverage1[ filePath ];
			var lines2 = coverage2[ filePath ];

			for ( var lineNum in lines1 ) {
				var hitCount1 = lines1[ lineNum ][ 1 ];
				var hitCount2 = lines2[ lineNum ][ 1 ];
				var isChild1 = lines1[ lineNum ][ 3 ];
				var isChild2 = lines2[ lineNum ][ 3 ];

				// Validate isChild flag matches
				expect( isChild1 ).toBe( isChild2, "merged.json #filePath# line #lineNum#: isChild flag should match (1x=#isChild1#, 2x=#isChild2#)" );

				if ( hitCount1 > 0 ) {
					var mergedHitRatio = hitCount2 / hitCount1;
					expect( mergedHitRatio ).toBe( arguments.expectedRatio, "merged.json #filePath# line #lineNum#: Expected #arguments.expectedRatio#x hit count but got #mergedHitRatio# (1x=#hitCount1#, #arguments.expectedRatio#x=#hitCount2#)" );
					mergedLinesChecked++;
				}
			}
		}

		variables.logger.info( "Validated #mergedLinesChecked# lines in merged.json" );
		expect( mergedLinesChecked ).toBeGT( 0, "Should have validated merged.json lines" );
	}
}
