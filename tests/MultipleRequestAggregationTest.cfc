component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "trace";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );

		// Generate three separate test data sets
		// Set 1: Run kitchen-sink 1 time
		variables.testDataGenerator1 = new GenerateTestData( testName="MultipleRequestAggregationTest-1x" );
		variables.testData1 = variables.testDataGenerator1.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic.cfm",
			iterations = 1
		);

		// Set 2: Run basic 2 times (multiple requests)
		variables.testDataGenerator2 = new GenerateTestData( testName="MultipleRequestAggregationTest-2x" );
		variables.testData2 = variables.testDataGenerator2.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic.cfm",
			iterations = 2
		);

		// Set 3: Run basic-5x once (includes loops.cfm 5 times within single request)
		variables.testDataGenerator5 = new GenerateTestData( testName="MultipleRequestAggregationTest-5x" );
		variables.testData5 = variables.testDataGenerator5.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic-5x.cfm",
			iterations = 1
		);
	}

	function run() {
		describe( "Multiple Request Aggregation", function() {

			it( "should have 2x the execution counts when run 2 times vs 1 time (multiple requests)", function() {
				testExecutionCountMultiplier();
			});

			it( "should have 5x the execution counts when included 5 times in single request", function() {
				testSingleRequestMultipleIncludes();
			});

		});
	}

	private function testExecutionCountMultiplier() {
		// Given: Generate JSON for both sets
		var outputDir1 = variables.testDataGenerator1.getOutputDir( "json-1x" );
		var outputDir2 = variables.testDataGenerator2.getOutputDir( "json-2x" );

		// When: Generate JSON reports with separateFiles: true
		lcovGenerateJson(
			executionLogDir = variables.testData1.coverageDir,
			outputDir = outputDir1,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		lcovGenerateJson(
			executionLogDir = variables.testData2.coverageDir,
			outputDir = outputDir2,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		// Then: Compare ALL per-file JSONs
		validateAllFiles( outputDir1, outputDir2, 2 );

		// Also validate merged.json
		validateMergedJson( outputDir1, outputDir2, 2 );
	}

	private function testSingleRequestMultipleIncludes() {
		// Given: Generate JSON for both sets
		var outputDir1 = variables.testDataGenerator1.getOutputDir( "json-1x-single" );
		var outputDir5 = variables.testDataGenerator5.getOutputDir( "json-5x-single" );

		// When: Generate JSON reports with separateFiles: true
		lcovGenerateJson(
			executionLogDir = variables.testData1.coverageDir,
			outputDir = outputDir1,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		lcovGenerateJson(
			executionLogDir = variables.testData5.coverageDir,
			outputDir = outputDir5,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);

		// Then: Find basic.cfm JSON file in both sets and validate
		var jsonFiles1 = directoryList( outputDir1, false, "array", "file-*basic.cfm.json" );
		var jsonFiles5 = directoryList( outputDir5, false, "array", "file-*basic.cfm.json" );

		expect( arrayLen( jsonFiles1 ) ).toBe( 1, "Should have exactly one basic JSON from 1x run" );
		expect( arrayLen( jsonFiles5 ) ).toBe( 1, "Should have exactly one basic JSON from 5x run" );

		validateFileJson( jsonFiles1[ 1 ], jsonFiles5[ 1 ], 5, "basic.cfm (5x includes)" );

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

		// Validate stats keys
		var allowedStatsKeys = [ "totalLinesFound", "totalLinesHit", "totalLinesSource", "totalExecutions", "totalExecutionTime", "totalChildTime" ];
		for ( var key in json1.stats ) {
			expect( arrayContains( allowedStatsKeys, key ) ).toBeTrue( "#arguments.label#: stats key '#key#' is not in allowed keys list" );
		}
		for ( var key in json2.stats ) {
			expect( arrayContains( allowedStatsKeys, key ) ).toBeTrue( "#arguments.label#: stats key '#key#' is not in allowed keys list" );
		}

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
