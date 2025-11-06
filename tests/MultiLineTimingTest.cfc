component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.testDataGenerator = new GenerateTestData( testName="MultiLineTimingTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: variables.adminPassword,
			fileFilter: "multiline-timing/test-multiline-calls.cfm"
		);
	}

	function testForLoopMarkedAsBlockType() {
		// Test that the for loop at line 41 is marked as "Block" type (not "Child" or "Own")
		// Block containers should show their execution time separately to avoid double-counting

		var exlFiles = directoryList( variables.testData.coverageDir, false, "array", "*.exl" );
		expect( exlFiles ).toHaveLength( 1, "Should have generated one .exl file" );

		// Generate HTML report with full pipeline (includes annotateCallTree)
		var outputDir = variables.testDataGenerator.getOutputDir( "reports" );

		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=outputDir,
			options={
				separateFiles: true,
				logLevel: "INFO"
			}
		);

		// Find the HTML file for test-multiline-calls.cfm
		var htmlFiles = directoryList( outputDir, false, "array", "*.html" );
		var testHtmlFile = "";
		for ( var htmlFile in htmlFiles ) {
			if ( find( "test-multiline-calls", htmlFile ) ) {
				testHtmlFile = htmlFile;
				break;
			}
		}

		expect( testHtmlFile ).notToBe( "", "Should find HTML file for test-multiline-calls.cfm" );

		// Parse HTML and check line 41 (for loop)
		var htmlContent = fileRead( testHtmlFile );
		var htmlParser = new HtmlParser();
		var doc = htmlParser.parseHtml( htmlContent );

		// Find line 41 - the for loop should be marked as "Block" type
		var line41Rows = htmlParser.select( doc, "tr[data-line-number='41']" );
		expect( line41Rows ).toHaveLength( 1, "Should find line 41 in HTML" );

		var line41 = line41Rows[1];

		// Find the type cell (should contain "Block")
		var typeCells = htmlParser.select( line41, "td.time-type" );
		expect( typeCells ).toHaveLength( 1, "Should have type cell for line 41" );

		var typeText = htmlParser.getText( typeCells[1] );

		systemOutput( "", true );
		systemOutput( "Line 41 (for loop) type: #typeText#", true );
		systemOutput( "HTML report: file:///#replace( testHtmlFile, '\', '/', 'all' )#", true );

		// Assert: The for loop should be marked as "Block" type
		expect( typeText ).toBe( "Block", "For loop at line 41 should be marked as Block type (not Child or Own)" );
	}

}
