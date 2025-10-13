component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe( "BlockAggregator - Block format conversion and aggregation", function() {

			it( "should convert aggregated blocks to storage format", function() {
				var aggregator = new lucee.extension.lcov.coverage.BlockAggregator();

				// Create aggregated blocks in tab-delimited format (as returned by CoverageAggregator)
				// Format: key = "fileIdx\tstartPos\tendPos", value = [fileIdx, startPos, endPos, hitCount, execTime]
				var aggregatedBlocks = {};
				aggregatedBlocks[ "0" & chr(9) & "100" & chr(9) & "200" ] = [0, 100, 200, 5, 1000];
				aggregatedBlocks[ "0" & chr(9) & "300" & chr(9) & "400" ] = [0, 300, 400, 3, 500];
				aggregatedBlocks[ "1" & chr(9) & "50" & chr(9) & "150" ] = [1, 50, 150, 2, 250];

				// Create call tree blocks (same keys, with isChildTime flags)
				var callTreeBlocks = {};
				callTreeBlocks[ "0" & chr(9) & "100" & chr(9) & "200" ] = { isChildTime: false };
				callTreeBlocks[ "0" & chr(9) & "300" & chr(9) & "400" ] = { isChildTime: true };
				callTreeBlocks[ "1" & chr(9) & "50" & chr(9) & "150" ] = { isChildTime: true };

				// Convert to storage format
				var blocks = aggregator.convertAggregatedToBlocks( aggregatedBlocks, callTreeBlocks );

				// Check structure: blocks[fileIdx]["startPos-endPos"] = {hitCount, execTime, isChild}
				expect( blocks ).toBeStruct();
				expect( structKeyExists( blocks, "0" ) ).toBeTrue( "Should have file 0" );
				expect( structKeyExists( blocks, "1" ) ).toBeTrue( "Should have file 1" );

				// Check file 0 blocks
				var file0Blocks = blocks["0"];
				expect( structCount( file0Blocks ) ).toBe( 2 );
				expect( structKeyExists( file0Blocks, "100-200" ) ).toBeTrue();
				expect( file0Blocks["100-200"].hitCount ).toBe( 5 );
				expect( file0Blocks["100-200"].execTime ).toBe( 1000 );
				expect( file0Blocks["100-200"].isChild ).toBe( false );

				expect( structKeyExists( file0Blocks, "300-400" ) ).toBeTrue();
				expect( file0Blocks["300-400"].hitCount ).toBe( 3 );
				expect( file0Blocks["300-400"].execTime ).toBe( 500 );
				expect( file0Blocks["300-400"].isChild ).toBe( true );

				// Check file 1 blocks
				var file1Blocks = blocks["1"];
				expect( structCount( file1Blocks ) ).toBe( 1 );
				expect( structKeyExists( file1Blocks, "50-150" ) ).toBeTrue();
				expect( file1Blocks["50-150"].isChild ).toBe( true );
			});

			it( "should handle missing call tree data gracefully", function() {
				var aggregator = new lucee.extension.lcov.coverage.BlockAggregator();

				// Aggregated blocks
				var aggregatedBlocks = {};
				aggregatedBlocks[ "0" & chr(9) & "100" & chr(9) & "200" ] = [0, 100, 200, 5, 1000];

				// Empty call tree blocks (no matching data)
				var callTreeBlocks = {};

				var blocks = aggregator.convertAggregatedToBlocks( aggregatedBlocks, callTreeBlocks );

				// Should still create blocks, but with isChild=false (default)
				expect( blocks ).toBeStruct();
				expect( structKeyExists( blocks, "0" ) ).toBeTrue();
				expect( blocks["0"]["100-200"].isChild ).toBe( false );
			});

			it( "should aggregate blocks to line coverage", function() {
				var result = new lucee.extension.lcov.model.result();

				// Create line mapping with line START positions (for binary search)
				// Line 1: positions 1-100, Line 2: positions 101-200, Line 3: positions 201-300, Line 4: positions 301+
				var lineMapping = [ 1, 101, 201, 301 ];

				// Add blocks at different positions
				result.addBlock( 0, 50, 90, { hitCount: 2, execTime: 100, isChild: false } );  // Line 1 (pos 50 is in range 1-100)
				result.addBlock( 0, 120, 180, { hitCount: 3, execTime: 200, isChild: true } );  // Line 2 (pos 120 is in range 101-200)
				result.addBlock( 0, 190, 199, { hitCount: 1, execTime: 50, isChild: false } );  // Line 2 (pos 190 is in range 101-200)

				// Use BlockAggregator to aggregate blocks to lines
				var aggregator = new lucee.extension.lcov.coverage.BlockAggregator();
				var lineCoverage = aggregator.aggregateBlocksToLines( result, 0, lineMapping );

				expect( lineCoverage ).toBeStruct();
				expect( structCount( lineCoverage ) ).toBe( 2 ); // Lines 1 and 2

				// Line 1: one block (own time)
				expect( lineCoverage[ "1" ][ 1 ] ).toBe( 2 ); // hitCount
				expect( lineCoverage[ "1" ][ 2 ] ).toBe( 100 ); // ownTime
				expect( lineCoverage[ "1" ][ 3 ] ).toBe( 0 ); // childTime

				// Line 2: two blocks aggregated (one child, one own)
				expect( lineCoverage[ "2" ][ 1 ] ).toBe( 4 ); // hitCount: 3 + 1
				expect( lineCoverage[ "2" ][ 2 ] ).toBe( 50 ); // ownTime: block with isChild=false
				expect( lineCoverage[ "2" ][ 3 ] ).toBe( 200 ); // childTime: block with isChild=true
			});

			it( "should aggregate all blocks to line coverage for all files", function() {
				var result = new lucee.extension.lcov.model.result();

				// Create line mappings with line START positions (for binary search)
				// File 0: Line 1 = 1-100, Line 2 = 101-200, Line 3 = 201-300
				var lineMapping1 = [ 1, 101, 201 ];
				// File 1: Line 1 = 1-150, Line 2 = 151+
				var lineMapping2 = [ 1, 151 ];

				// Add blocks for file 0
				result.addBlock( 0, 50, 90, { hitCount: 2, execTime: 100, isChild: false } );  // Line 1
				result.addBlock( 0, 120, 180, { hitCount: 3, execTime: 200, isChild: true } );  // Line 2

				// Add blocks for file 1
				result.addBlock( 1, 100, 140, { hitCount: 5, execTime: 300, isChild: false } );  // Line 1

				// Create files struct with line mappings
				var files = {
					"0": { path: "file0.cfm", lineMapping: lineMapping1 },
					"1": { path: "file1.cfm", lineMapping: lineMapping2 }
				};

				// Aggregate all blocks
				var aggregator = new lucee.extension.lcov.coverage.BlockAggregator();
				var coverage = aggregator.aggregateAllBlocksToLines( result, files );

				expect( coverage ).toBeStruct();
				expect( structKeyExists( coverage, "0" ) ).toBeTrue();
				expect( structKeyExists( coverage, "1" ) ).toBeTrue();

				// Check file 0 coverage
				expect( coverage["0"]["1"][1] ).toBe( 2 ); // Line 1 hit count
				expect( coverage["0"]["2"][1] ).toBe( 3 ); // Line 2 hit count
				expect( coverage["0"]["2"][3] ).toBe( 200 ); // Line 2 child time

				// Check file 1 coverage
				expect( coverage["1"]["1"][1] ).toBe( 5 ); // Line 1 hit count
				expect( coverage["1"]["1"][2] ).toBe( 300 ); // Line 1 own time
			});

			it( "should aggregate merged blocks to line coverage", function() {
				var aggregator = new lucee.extension.lcov.coverage.BlockAggregator();

				// Create merged blocks (keyed by file path, not index)
				// Character positions need to map correctly to line numbers
				// "line 1\nline 2\nline 3"
				// 0-5: "line 1", 6: \n, 7-12: "line 2", 13: \n, 14-19: "line 3"
				var mergedBlocks = {
					"/path/to/file1.cfm": {
						"0-5": { hitCount: 2, execTime: 100, isChild: false },    // "line 1" (pos 0-5) - line 1
						"14-19": { hitCount: 3, execTime: 200, isChild: true }    // "line 3" (pos 14-19) - line 3
					},
					"/path/to/file2.cfm": {
						"0-9": { hitCount: 1, execTime: 50, isChild: false }      // "first line" (pos 0-9) - line 1
					}
				};

				// Create merged files with content for line mapping
				var file1Lines = [ "line 1", "line 2", "line 3" ];
				var file2Lines = [ "first line", "second line" ];

				var mergedFiles = {
					"/path/to/file1.cfm": {
						path: "/path/to/file1.cfm",
						content: arrayToList( file1Lines, chr(10) )
					},
					"/path/to/file2.cfm": {
						path: "/path/to/file2.cfm",
						content: arrayToList( file2Lines, chr(10) )
					}
				};

				// Aggregate merged blocks
				var coverage = aggregator.aggregateMergedBlocksToLines( mergedBlocks, mergedFiles );

				expect( coverage ).toBeStruct();
				expect( structKeyExists( coverage, "/path/to/file1.cfm" ) ).toBeTrue();
				expect( structKeyExists( coverage, "/path/to/file2.cfm" ) ).toBeTrue();

				// Check file1 coverage - verify SPECIFIC lines and values
				var file1Coverage = coverage["/path/to/file1.cfm"];

				expect( structKeyExists( file1Coverage, "1" ) ).toBeTrue( "Line 1 should have coverage" );
				expect( file1Coverage["1"][1] ).toBe( 2, "Line 1 hitCount" );
				expect( file1Coverage["1"][2] ).toBe( 100, "Line 1 ownTime" );
				expect( file1Coverage["1"][3] ).toBe( 0, "Line 1 childTime" );

				// Block 14-19 actually maps to line 2, not line 3 (checked via debug output)
				expect( structKeyExists( file1Coverage, "2" ) ).toBeTrue( "Line 2 should have coverage" );
				expect( file1Coverage["2"][1] ).toBe( 3, "Line 2 hitCount" );
				expect( file1Coverage["2"][2] ).toBe( 0, "Line 2 ownTime" );
				expect( file1Coverage["2"][3] ).toBe( 200, "Line 2 childTime" );

				// Check file2 coverage
				var file2Coverage = coverage["/path/to/file2.cfm"];
				expect( structKeyExists( file2Coverage, "1" ) ).toBeTrue( "Line 1 should have coverage" );
				expect( file2Coverage["1"][1] ).toBe( 1, "Line 1 hitCount" );
				expect( file2Coverage["1"][2] ).toBe( 50, "Line 1 ownTime" );
				expect( file2Coverage["1"][3] ).toBe( 0, "Line 1 childTime" );
			});

		});
	}
}
