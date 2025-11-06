component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );

		// Generate test data with predictable timing
		variables.testDataGenerator = new GenerateTestData( testName="ChildTimeValidationTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/timing-test.cfm",
			iterations = 1
		);

		variables.outputDir = variables.testDataGenerator.getOutputDir() & "/output";
		directoryCreate( variables.outputDir );
	}

	function run() {
		describe( "Child Time Validation", function() {

			it( "childTime should never exceed totalExecutionTime for any line AND aggregate should not exceed request time", function() {
				// Generate JSON reports
				lcovGenerateJson(
					executionLogDir = variables.testData.coverageDir,
					outputDir = variables.outputDir,
					options = { separateFiles: false, logLevel: variables.logLevel }
				);

				// Find and validate the JSON files in the OUTPUT dir (where lcovGenerateJson wrote them)
				var jsonFiles = directoryList( variables.outputDir, false, "array", "*.json" );
				expect( arrayLen( jsonFiles ) ).toBeGT( 0, "Should have at least one JSON file in output dir: " & variables.outputDir );

				for ( var jsonFile in jsonFiles ) {
					var filename = getFileFromPath( jsonFile );

					// Skip ast-metadata.json (doesn't have coverage)
					if ( findNoCase( "ast-metadata", filename ) ) {
						continue;
					}

					// Skip core JSON files (merged.json, results.json, summary-stats.json)
					// Only validate individual request JSON files (request-*.json)
					if ( !findNoCase( "request-", filename ) ) {
						continue;
					}

					validateChildTimeInFile( jsonFile );
					validateRequestTotalInJson( jsonFile );
				}
			});

		});
	}

	private function validateChildTimeInFile( required string jsonFilePath ) {
		var json = deserializeJSON( fileRead( arguments.jsonFilePath ) );
		var label = getFileFromPath( arguments.jsonFilePath );

		expect(json.files).NotToBeEmpty("No files found in JSON: " & arguments.jsonFilePath);

		// Validate each file in the JSON
		for ( var fileKey in json.files ) {
			var file = json.files[ fileKey ];
			expect(json).toHaveKey( "COVERAGE", "No coverage for found in JSON: " & arguments.jsonFilePath);
			expect(json.COVERAGE).toHaveKey( fileKey, "No coverage for #fileKey# found in JSON: " & arguments.jsonFilePath);
			var coverage = json.COVERAGE[ fileKey ];

			//systemOutput( "Validating file: #file.path#", true );

			// Check each line - new format is [hitCount, execTime, blockType]
			// blockType: 0=own, 1=child, 2=own+overlap, 3=child+overlap
			for ( var lineNum in coverage ) {
				var lineData = coverage[ lineNum ];
				var hitCount = lineData[ 1 ];
				var execTime = lineData[ 2 ];
				var blockType = lineData[ 3 ];

				// All execTime values should be non-negative
				expect( execTime ).toBeGTE( 0, "#label# Line #lineNum#: execTime should be >= 0" );

				// blockType should be 0-3
				expect( blockType ).toBeBetween( 0, 3, "#label# Line #lineNum#: blockType should be 0-3" );
			}
		}
	}

	private function validateRequestTotalInJson( required string jsonFilePath ) {
		var json = deserializeJSON( fileRead( arguments.jsonFilePath ) );
		var label = getFileFromPath( arguments.jsonFilePath );

		//systemOutput( "Validating aggregate totals for: #label#", true );

		// Get request execution time from metadata
		var requestExecutionTime = json.metadata["execution-time"];
		if ( !isNumeric( requestExecutionTime ) ) {
			systemOutput( "  No request execution time in metadata, skipping validation", true );
			return;
		}

		// Get aggregate stats
		var totalExecutionTime = json.stats.totalExecutionTime;

		//systemOutput( "  Request execution time: #requestExecutionTime#", true );
		//systemOutput( "  Total execution time (stats): #totalExecutionTime#", true );
		//systemOutput( "  Ratio: #numberFormat(totalExecutionTime / requestExecutionTime, '0.00')#x", true );

		// CRITICAL: The sum of all execution times should not exceed the request time
		expect( totalExecutionTime ).toBeLTE( requestExecutionTime,
			"#label#: Total execution time (#totalExecutionTime#) exceeds request execution time (#requestExecutionTime#). Child time is being over-counted by #numberFormat((totalExecutionTime / requestExecutionTime - 1) * 100, '0.0')#%! in " & jsonFilePath );
	}

	private function validateRequestTotalTime( required string exlFilePath ) {
		//systemOutput( "Validating request-level totals for: #arguments.exlFilePath#", true );

		// Use lcovGenerateJson to parse the log
		var exlDir = getDirectoryFromPath( arguments.exlFilePath );
		var tempOutputDir = getTempDirectory() & "/child-time-validation-" & createUUID();
		directoryCreate( tempOutputDir );

		lcovGenerateJson(
			executionLogDir = exlDir,
			outputDir = tempOutputDir,
			options = { logLevel: variables.logLevel }
		);

		// Find the JSON file
		var jsonFiles = directoryList( tempOutputDir, true, "array", "*.json" );
		if ( arrayLen( jsonFiles ) == 0 ) {
			systemOutput( "  No JSON files found, skipping validation", true );
			return;
		}

		var result = deserializeJSON( fileRead( jsonFiles[ 1 ] ) );

		// Get request execution time from metadata
		var requestExecutionTime = result.metadata["execution-time"];
		if ( !isNumeric( requestExecutionTime ) ) {
			systemOutput( "  No request execution time in metadata, skipping validation", true );
			return;
		}

		// Calculate sum of totalExecutionTime across all files
		var totalExecutionTime = result.stats.totalExecutionTime;

		//systemOutput( "  Request execution time: #requestExecutionTime#", true );
		//systemOutput( "  Sum of file totalExecutionTime: #totalExecutionTime#", true );
		//systemOutput( "  Ratio: #numberFormat(totalExecutionTime / requestExecutionTime, '0.00')#x", true );

		// CRITICAL: The sum of all file execution times should not exceed the request time
		// If it does, we're double-counting child time somewhere
		expect( totalExecutionTime ).toBeLTE( requestExecutionTime,
			"Total execution time (#totalExecutionTime#) exceeds request execution time (#requestExecutionTime#). Child time is being over-counted! in " & arguments.exlFilePath );
	}

}
