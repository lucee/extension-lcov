component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.testDataGenerator = new "../GenerateTestData"( testName="RealWorldCallDetection" );
	}

	function run() {
		describe("Real-world call detection", function() {

			it("should detect all function calls in real-world-calls.cfm", function() {
				// Generate execution logs
				var testData = variables.testDataGenerator.generateExlFilesForArtifacts(
					adminPassword: request.SERVERADMINPASSWORD,
					fileFilter: "real-world-calls.cfm",
					iterations: 1
				);

				// Parse with call tree analysis
				var outputDir = variables.testDataGenerator.getOutputDir( "json" );
				lcovGenerateJson(
					executionLogDir: testData.coverageDir,
					outputDir: outputDir,
					options: { separateFiles: true, logLevel: "trace" }
				);

				// Read the JSON file
				var jsonFiles = directoryList( outputDir, false, "array", "file-*real-world-calls.cfm.json" );
				expect( arrayLen( jsonFiles ) ).toBe( 1, "Should find real-world-calls JSON file" );

				var jsonData = deserializeJSON( fileRead( jsonFiles[ 1 ] ) );
				var coverage = jsonData.coverage[ "0" ]; // First file

				// Lines that MUST be marked as child time
				var expectedChildTimeLines = [
					5,   // new SimpleComponent()
					8,   // new lucee.extension.lcov.Logger()
					11,  // new MathUtils()
					14,  // new CoverageComponentFactory()
					15,  // factory.getComponent()
					18   // factory.getComponent()
				];

				var failedLines = [];
				for ( var lineNum in expectedChildTimeLines ) {
					if ( !structKeyExists( coverage, lineNum ) ) {
						arrayAppend( failedLines, lineNum & " (no coverage)" );
						continue;
					}

					var lineData = coverage[ lineNum ];

					// NEW FORMAT: [hitCount, ownTime, childTime]
					// Third element is childTime (numeric) - time spent in function calls
					var childTime = lineData[ 3 ];
					if ( childTime == 0 ) {
						arrayAppend( failedLines, lineNum & " (not marked as child)" );
					}
				}

				if ( arrayLen( failedLines ) > 0 ) {
					fail( "Lines not correctly marked as child time: " & arrayToList( failedLines, ", " ) );
				}

				expect( arrayLen( failedLines ) ).toBe( 0, "All function call lines should be marked as child time" );
			});

		});
	}

}
