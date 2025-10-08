component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe( "buildCharacterToLineMapping - verify correct format", function() {

			it( "should return array of line start positions", function() {
				var processor = new lucee.extension.lcov.CoverageBlockProcessor();

				// Simple 3-line file
				var content = "line 1" & chr(10) & "line 2" & chr(10) & "line 3";
				// Positions: 1-6: "line 1", 7: \n, 8-13: "line 2", 14: \n, 15-20: "line 3"

				var lineMapping = processor.buildCharacterToLineMapping( content );

				// Should return line START positions: [1, 8, 15]
				expect( lineMapping ).toBeArray();
				expect( arrayLen( lineMapping ) ).toBe( 3, "Should have 3 line starts" );
				expect( lineMapping[ 1 ] ).toBe( 1, "Line 1 starts at position 1" );
				expect( lineMapping[ 2 ] ).toBe( 8, "Line 2 starts at position 8" );
				expect( lineMapping[ 3 ] ).toBe( 15, "Line 3 starts at position 15" );
			});

			it( "should handle empty file", function() {
				var processor = new lucee.extension.lcov.CoverageBlockProcessor();
				var lineMapping = processor.buildCharacterToLineMapping( "" );

				expect( arrayLen( lineMapping ) ).toBe( 1, "Empty file has 1 line start at position 1" );
				expect( lineMapping[ 1 ] ).toBe( 1 );
			});

			it( "should handle file with no newlines", function() {
				var processor = new lucee.extension.lcov.CoverageBlockProcessor();
				var lineMapping = processor.buildCharacterToLineMapping( "single line" );

				expect( arrayLen( lineMapping ) ).toBe( 1, "Single line file has 1 line start" );
				expect( lineMapping[ 1 ] ).toBe( 1 );
			});

			it( "should handle file with multiple newlines", function() {
				var processor = new lucee.extension.lcov.CoverageBlockProcessor();

				// 5 lines
				var lines = [ "first", "second", "third", "fourth", "fifth" ];
				var content = arrayToList( lines, chr(10) );

				var lineMapping = processor.buildCharacterToLineMapping( content );

				expect( arrayLen( lineMapping ) ).toBe( 5, "Should have 5 line starts" );
				expect( lineMapping[ 1 ] ).toBe( 1, "Line 1 starts at position 1" );
				// "first\n" = 6 chars, so line 2 starts at 7
				expect( lineMapping[ 2 ] ).toBe( 7, "Line 2 starts after 'first' + newline" );
			});

		});
	}
}
