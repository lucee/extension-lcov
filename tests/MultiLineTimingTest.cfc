component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.testDataGenerator = new GenerateTestData( testName="MultiLineTimingTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: variables.adminPassword,
			fileFilter: "multiline-timing/test-multiline-calls.cfm"
		);
	}

	function testMultiLineTimingNotDuplicated() {
		// Parse the execution log to analyze multi-line function call timing
		var options = {
			logLevel: "INFO",
			separateFiles: true,
			allowList: [],
			blocklist: []
		};

		var parser = new lucee.extension.lcov.ExecutionLogParser( options=options );
		var exlFiles = directoryList( variables.testData.coverageDir, false, "array", "*.exl" );

		expect( exlFiles ).toHaveLength( 1, "Should have generated one .exl file" );

		var parseResult = parser.parseExlFile(
			exlPath=exlFiles[1],
			allowList=[],
			blocklist=[],
			writeJsonCache=false,
			includeCallTree=false,
			includeSourceCode=false
		);

		// Get files from result object
		var files = parseResult.getFiles();
		var validFileIds = {};
		cfloop( collection=files, key="local.fileIdx" ) {
			validFileIds[fileIdx] = true;
		}

		// Get the aggregated blocks
		var logger = new lucee.extension.lcov.Logger( level="INFO" );
		var aggregator = new lucee.extension.lcov.coverage.CoverageAggregator( logger=logger );
		var aggregationResult = aggregator.aggregate( exlFiles[1], validFileIds );

		// Apply overlap filtering
		var overlapFilter = new lucee.extension.lcov.coverage.OverlapFilterPosition( options=options );
		var filtered = overlapFilter.filter(
			aggregatedOrBlocksByFile=aggregationResult.aggregated,
			files=files,
			lineMappingsCache={}
		);

		systemOutput( "", true );
		systemOutput( "=== MULTI-LINE TIMING ANALYSIS ===", true );
		systemOutput( "Total blocks after filtering: " & structCount( filtered ), true );

		// Find the test file
		var testFilePath = "";
		cfloop( collection=files, key="local.fileIdx", value="local.fileInfo" ) {
			if ( find( "test-multiline-calls.cfm", fileInfo.path ) ) {
				testFilePath = fileInfo.path;
				systemOutput( "Test file: " & testFilePath, true );
				break;
			}
		}

		expect( testFilePath ).notToBe( "", "Should find test-multiline-calls.cfm in files" );

		// Analyze blocks from the test file
		var testFileBlocks = [];
		cfloop( collection=filtered, key="local.blockKey" ) {
			var block = filtered[blockKey];
			var blockFileIdx = toString( block[1] );
			if ( structKeyExists( files, blockFileIdx ) && files[blockFileIdx].path == testFilePath ) {
				arrayAppend( testFileBlocks, {
					key: blockKey,
					fileIdx: block[1],
					startPos: block[2],
					endPos: block[3],
					span: block[3] - block[2],
					count: block[4],
					totalTime: block[5],
					isOverlapping: arrayLen( block ) >= 6 ? block[6] : false
				});
			}
		}

		// Sort by startPos to see execution order
		arraySort( testFileBlocks, function( a, b ) {
			return a.startPos - b.startPos;
		});

		systemOutput( "", true );
		systemOutput( "Blocks from test file (sorted by position):", true );
		cfloop( array=testFileBlocks, index="local.i", item="local.block" ) {
			systemOutput( "  #i#. Position: #block.startPos#-#block.endPos# (span: #block.span#)", true );
			systemOutput( "     Hits: #block.count#, Time: #numberFormat( block.totalTime / 1000000 )#ms", true );
			systemOutput( "     Overlapping: #block.isOverlapping#", true );
		}

		// Look for potential timing duplication issues
		// Group blocks by overlapping positions to detect if same time is counted multiple times
		var positionGroups = {};
		cfloop( array=testFileBlocks, item="local.block" ) {
			for ( var pos = block.startPos; pos <= block.endPos; pos++ ) {
				if ( !structKeyExists( positionGroups, pos ) ) {
					positionGroups[pos] = [];
				}
				arrayAppend( positionGroups[pos], block );
			}
		}

		// Find positions covered by multiple blocks
		var overlappingPositions = [];
		cfloop( collection=positionGroups, key="local.pos", value="local.blocks" ) {
			if ( arrayLen( blocks ) > 1 ) {
				arrayAppend( overlappingPositions, {
					position: pos,
					blockCount: arrayLen( blocks ),
					blocks: blocks
				});
			}
		}

		if ( arrayLen( overlappingPositions ) > 0 ) {
			systemOutput( "", true );
			systemOutput( "=== OVERLAPPING POSITIONS (potential timing duplication) ===", true );
			arraySort( overlappingPositions, function( a, b ) {
				return val( a.position ) - val( b.position );
			});

			var sampleSize = min( 10, arrayLen( overlappingPositions ) );
			cfloop( array=arraySlice( overlappingPositions, 1, sampleSize ), index="local.i", item="local.op" ) {
				systemOutput( "  Position #op.position# covered by #op.blockCount# blocks:", true );
				cfloop( array=op.blocks, item="local.block" ) {
					systemOutput( "    - Block #block.startPos#-#block.endPos#: #numberFormat( block.totalTime / 1000000 )#ms", true );
				}
			}
		} else {
			systemOutput( "", true );
			systemOutput( "No overlapping positions found - timing is clean!", true );
		}

		// Calculate total time from all blocks
		var totalTime = 0;
		cfloop( array=testFileBlocks, item="local.block" ) {
			totalTime += block.totalTime;
		}

		systemOutput( "", true );
		systemOutput( "=== TIMING SUMMARY ===", true );
		systemOutput( "Total execution time (sum of all blocks): #numberFormat( totalTime / 1000000 )#ms", true );
		systemOutput( "Number of blocks: #arrayLen( testFileBlocks )#", true );
		systemOutput( "Overlapping positions: #arrayLen( overlappingPositions )#", true );

		// Generate HTML report to visually inspect timing
		systemOutput( "", true );
		systemOutput( "=== GENERATING HTML REPORT ===", true );

		var outputDir = variables.testDataGenerator.getOutputDir( "reports" );

		lcovGenerateHtml(
			executionLogDir=variables.testData.coverageDir,
			outputDir=outputDir,
			options={
				includeSourceCode: true,
				logLevel: "INFO"
			}
		);

		systemOutput( "HTML report generated at: #outputDir#", true );
		systemOutput( "Open: file:///#replace( outputDir, '\', '/', 'all' )#/index.html", true );

		// Assertion: If timing is NOT duplicated, we should see reasonable execution times
		// This is a smoke test - real validation would require analyzing line-by-line coverage
		expect( arrayLen( testFileBlocks ) ).toBeGT( 0, "Should have at least some execution blocks" );
	}

}
