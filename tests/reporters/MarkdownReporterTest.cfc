component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.logLevel = "DEBUG";  // Use DEBUG for detailed cache validation logging
		variables.testDataGenerator = new "../GenerateTestData"( testName="MarkdownReporterTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: variables.adminPassword,
			fileFilter: "multiline-timing/test-multiline-calls.cfm"
		);
	}

	function testMarkdownReporterOptions() {
		// Generate various markdown reports with different option combinations

		var exlFiles = directoryList( variables.testData.coverageDir, false, "array", "*.exl" );
		expect( exlFiles ).toHaveLength( 1, "Should have generated one .exl file" );

		// Test 1: Line-based markdown (default, backward compatibility)
		systemOutput( "", true );
		systemOutput( "=== Test 1: Line-based markdown (backward compatible) ===", true );
		var lineMdDir = variables.testDataGenerator.getOutputDir( "01-line-based" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=lineMdDir,
			options={
				separateFiles: true,
				logLevel: "DEBUG",
				markdown: {
					blockBased: false
				}
			}
		);
		verifyMarkdownGenerated( lineMdDir );

		// Test 2: Block-based with default options
		systemOutput( "", true );
		systemOutput( "=== Test 2: Block-based with default options ===", true );
		var blockDefaultDir = variables.testDataGenerator.getOutputDir( "02-block-default" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=blockDefaultDir,
			options={
				separateFiles: true,
				logLevel: "DEBUG",
				markdown: {
					blockBased: true
				}
			}
		);
		verifyMarkdownGenerated( blockDefaultDir );

		// Test 3: Sorted by average time descending (find hotspots)
		systemOutput( "", true );
		systemOutput( "=== Test 3: Sorted by average time descending ===", true );
		var avgDescDir = variables.testDataGenerator.getOutputDir( "03-sort-avg-desc" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=avgDescDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "avg-desc"
				}
			}
		);
		verifyMarkdownGenerated( avgDescDir );

		// Test 4: Sorted by position (code order)
		systemOutput( "", true );
		systemOutput( "=== Test 4: Sorted by position ===", true );
		var positionDir = variables.testDataGenerator.getOutputDir( "04-sort-position" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=positionDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "position",
					contextLines: 3
				}
			}
		);
		verifyMarkdownGenerated( positionDir );

		// Test 5: Filtered by minimum total time
		systemOutput( "", true );
		systemOutput( "=== Test 5: Filtered by minimum total time ===", true );
		var minTimeDir = variables.testDataGenerator.getOutputDir( "05-filter-mintime" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=minTimeDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "time-desc",
					minTime: 5000  // 5ms minimum total time
				}
			}
		);
		verifyMarkdownGenerated( minTimeDir );

		// Test 6: Filtered by minimum average time
		systemOutput( "", true );
		systemOutput( "=== Test 6: Filtered by minimum average time ===", true );
		var minAvgDir = variables.testDataGenerator.getOutputDir( "06-filter-minavg" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=minAvgDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "avg-desc",
					minAvg: 1000  // 1ms minimum average time per hit
				}
			}
		);
		verifyMarkdownGenerated( minAvgDir );

		// Test 7: Filtered by minimum hit count
		systemOutput( "", true );
		systemOutput( "=== Test 7: Filtered by minimum hit count ===", true );
		var minHitDir = variables.testDataGenerator.getOutputDir( "07-filter-minhit" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=minHitDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "hitCount",
					minHitCount: 5  // Only blocks hit 5+ times
				}
			}
		);
		verifyMarkdownGenerated( minHitDir );

		// Test 8: Combined filters (aggressive filtering)
		systemOutput( "", true );
		systemOutput( "=== Test 8: Combined filters ===", true );
		var combinedDir = variables.testDataGenerator.getOutputDir( "08-combined-filters" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=combinedDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "avg-desc",
					contextLines: 5,
					minTime: 1000,    // 1ms total
					minAvg: 500,      // 0.5ms average
					minHitCount: 2    // Hit at least twice
				}
			}
		);
		verifyMarkdownGenerated( combinedDir );

		// Test 9: Sorted by hit count (most executed first)
		systemOutput( "", true );
		systemOutput( "=== Test 9: Sorted by hit count ===", true );
		var hitCountDir = variables.testDataGenerator.getOutputDir( "09-sort-hitcount" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=hitCountDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					blockBased: true,
					sortBy: "hitCount"
				}
			}
		);
		verifyMarkdownGenerated( hitCountDir );

		// Test 10: Markdown disabled
		systemOutput( "", true );
		systemOutput( "=== Test 10: Markdown disabled ===", true );
		var mdDisabledDir = variables.testDataGenerator.getOutputDir( "10-markdown-disabled" );
		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=mdDisabledDir,
			options={
				separateFiles: true,
				logLevel: variables.logLevel,
				markdown: {
					enabled: false
				}
			}
		);
		verifyHtmlGenerated( mdDisabledDir );
		verifyMarkdownNotGenerated( mdDisabledDir );

		systemOutput( "", true );
		systemOutput( "✓ All markdown reporter tests passed!", true );
		systemOutput( "View reports at: file:///#replace( variables.testDataGenerator.getOutputDir(), '\', '/', 'all' )#", true );
	}

	private void function verifyMarkdownGenerated( required string outputDir ) {
		var mdFiles = directoryList( arguments.outputDir, false, "array", "*.md" );
		expect( arrayLen( mdFiles ) ).toBeGT( 0, "Should have generated markdown files in #arguments.outputDir#" );
	}

	private void function verifyHtmlGenerated( required string outputDir ) {
		var htmlFiles = directoryList( arguments.outputDir, false, "array", "*.html" );
		expect( arrayLen( htmlFiles ) ).toBeGT( 0, "Should have generated HTML files in #arguments.outputDir#" );
	}

	private void function verifyMarkdownNotGenerated( required string outputDir ) {
		var mdFiles = directoryList( arguments.outputDir, false, "array", "*.md" );
		expect( mdFiles ).toHaveLength( 0, "Should NOT have generated markdown files when disabled" );
	}

}
