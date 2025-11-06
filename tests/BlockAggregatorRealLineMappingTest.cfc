component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	variables.testGen = "";

	function beforeAll() {
		variables.testGen = new "GenerateTestData"( testName="BlockAggregatorRealLineMappingTest" );
	}

	function run() {
		describe( "BlockAggregator - integration with real lineMapping format", function() {

			it( "should aggregate blocks using real lineMapping from buildCharacterToLineMapping", function() {
				var result = new lucee.extension.lcov.model.result();
				var processor = new lucee.extension.lcov.coverage.CoverageBlockProcessor();

				// Use real file content to get real lineMapping
				var artifactPath = variables.testGen.getSourceArtifactsDir() & "/kitchen-sink-example.cfm";
				var content = fileRead( artifactPath );

				// Get REAL lineMapping (array of line start positions, not direct index lookup)
				var lineMapping = processor.buildCharacterToLineMapping( content );


				// Add some realistic blocks at known positions
				// From earlier debug, we know blocks exist like "431-444", "531-556", etc
				// Let's add blocks at positions we can verify

				// Block at position 100-150 (should map to some early line)
				result.addBlock( 0, 100, 150, { hitCount: 5, execTime: 100, blockType: 0 } );

				// Block at position 500-550 (should map to some middle line)
				result.addBlock( 0, 500, 550, { hitCount: 3, execTime: 200, blockType: 1 } );

				// Use BlockAggregator to aggregate blocks
				var aggregator = new lucee.extension.lcov.coverage.BlockAggregator();
				var lineCoverage = aggregator.aggregateBlocksToLines( result, 0, lineMapping );

				// Verify we got SOME line coverage (not empty)
				expect( structCount( lineCoverage ) ).toBeGT( 0, "Should have line coverage data" );

				// Verify each line has the correct format [hitCount, execTime, blockType]
				for ( var lineNum in lineCoverage ) {
					var lineData = lineCoverage[ lineNum ];
					expect( arrayLen( lineData ) ).toBe( 3, "Line #lineNum# should have 3 elements" );
					expect( lineData[ 1 ] ).toBeGTE( 0, "Line #lineNum# hitCount should be >= 0" );
					expect( lineData[ 2 ] ).toBeGTE( 0, "Line #lineNum# execTime should be >= 0" );
					expect( lineData[ 3 ] ).toBeBetween( 0, 3, "Line #lineNum# blockType should be 0-3" );
				}

				// Verify the blocks were actually mapped to lines (not all skipped)
				var totalHits = 0;
				for ( var lineNum in lineCoverage ) {
					totalHits += lineCoverage[ lineNum ][ 1 ];
				}
				expect( totalHits ).toBeGT( 0, "Should have some hit counts (blocks not all skipped)" );
			});

		});
	}
}
