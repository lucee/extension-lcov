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

				// Generate HTML report for visual inspection
				var htmlOutputDir = variables.testDataGenerator.getOutputDir() & "/html";
				directoryCreate( htmlOutputDir );
				lcovGenerateHtml(
					executionLogDir = variables.testData.coverageDir,
					outputDir = htmlOutputDir,
					options = { logLevel: variables.logLevel, displayUnit: "auto" }
				);
				systemOutput( "HTML report: file:///" & replace( htmlOutputDir, "\", "/", "all" ) & "/index.html", true );

				// Find and validate the request JSON file in the coverage dir
				var jsonFiles = directoryList( variables.testData.coverageDir, false, "array", "*.json" );
				expect( arrayLen( jsonFiles ) ).toBeGT( 0, "Should have at least one JSON file in coverage dir" );

				for ( var jsonFile in jsonFiles ) {
					validateChildTimeInFile( jsonFile );
					validateRequestTotalInJson( jsonFile );
				}
			});

		});
	}

	private function validateChildTimeInFile( required string jsonFilePath ) {
		var json = deserializeJSON( fileRead( arguments.jsonFilePath ) );
		var label = getFileFromPath( arguments.jsonFilePath );

		// Validate each file in the JSON
		for ( var fileKey in json.FILES ) {
			var file = json.FILES[ fileKey ];
			var coverage = json.coverage[ fileKey ];

			systemOutput( "Validating file: #file.path#", true );

			// Check each line
			for ( var lineNum in coverage ) {
				var lineData = coverage[ lineNum ];
				var hitCount = lineData[ 1 ];
				var ownTime = lineData[ 2 ];
				var childTime = lineData[ 3 ];
				var totalTime = ownTime + childTime;

				// CRITICAL: childTime should NEVER exceed totalTime
				// If it does, it means child time is being counted multiple times
				if ( childTime > 0 ) {
					expect( childTime ).toBeLTE( totalTime,
						"#label# Line #lineNum#: childTime (#childTime#) exceeds totalTime (#totalTime#). ownTime=#ownTime#. This suggests double-counting!" );

					systemOutput( "  Line #lineNum#: hitCount=#hitCount#, ownTime=#ownTime#, childTime=#childTime#, total=#totalTime#", true );
				}
			}
		}
	}

	private function validateRequestTotalInJson( required string jsonFilePath ) {
		var json = deserializeJSON( fileRead( arguments.jsonFilePath ) );
		var label = getFileFromPath( arguments.jsonFilePath );

		systemOutput( "Validating aggregate totals for: #label#", true );

		// Get request execution time from metadata
		var requestExecutionTime = json.metadata["execution-time"];
		if ( !isNumeric( requestExecutionTime ) ) {
			systemOutput( "  No request execution time in metadata, skipping validation", true );
			return;
		}

		// Get aggregate stats
		var totalExecutionTime = json.stats.totalExecutionTime;

		systemOutput( "  Request execution time: #requestExecutionTime#", true );
		systemOutput( "  Total execution time (stats): #totalExecutionTime#", true );
		systemOutput( "  Ratio: #numberFormat(totalExecutionTime / requestExecutionTime, '0.00')#x", true );

		// CRITICAL: The sum of all execution times should not exceed the request time
		expect( totalExecutionTime ).toBeLTE( requestExecutionTime,
			"#label#: Total execution time (#totalExecutionTime#) exceeds request execution time (#requestExecutionTime#). Child time is being over-counted by #numberFormat((totalExecutionTime / requestExecutionTime - 1) * 100, '0.0')#%!" );
	}

	private function validateRequestTotalTime( required string exlFilePath ) {
		systemOutput( "Validating request-level totals for: #arguments.exlFilePath#", true );

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

		systemOutput( "  Request execution time: #requestExecutionTime#", true );
		systemOutput( "  Sum of file totalExecutionTime: #totalExecutionTime#", true );
		systemOutput( "  Ratio: #numberFormat(totalExecutionTime / requestExecutionTime, '0.00')#x", true );

		// CRITICAL: The sum of all file execution times should not exceed the request time
		// If it does, we're double-counting child time somewhere
		expect( totalExecutionTime ).toBeLTE( requestExecutionTime,
			"Total execution time (#totalExecutionTime#) exceeds request execution time (#requestExecutionTime#). Child time is being over-counted!" );
	}

}
