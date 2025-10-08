component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	variables.testGen = "";

	function beforeAll() {
		variables.testGen = new "../GenerateTestData"( testName="GetLineFromPositionTest" );
	}

	function run() {
		describe( "getLineFromCharacterPosition - integration with real lineMapping", function() {

			it( "should correctly map character positions to line numbers", function() {
				var processor = new lucee.extension.lcov.CoverageBlockProcessor();

				// Create realistic file content
				var lines = [ "line 1", "line 2", "line 3", "line 4" ];
				var content = arrayToList( lines, chr(10) );
				// "line 1\nline 2\nline 3\nline 4"
				// Positions: 1-6: line 1, 7: \n, 8-13: line 2, 14: \n, 15-20: line 3, 21: \n, 22-27: line 4

				var lineMapping = processor.buildCharacterToLineMapping( content );
				var mappingLen = arrayLen( lineMapping );

				// Test various positions
				var lineNum1 = processor.getLineFromCharacterPosition( 1, "", lineMapping, mappingLen );
				expect( lineNum1 ).toBe( 1, "Position 1 should be line 1" );

				var lineNum6 = processor.getLineFromCharacterPosition( 6, "", lineMapping, mappingLen );
				expect( lineNum6 ).toBe( 1, "Position 6 should be line 1" );

				var lineNum8 = processor.getLineFromCharacterPosition( 8, "", lineMapping, mappingLen );
				expect( lineNum8 ).toBe( 2, "Position 8 should be line 2" );

				var lineNum13 = processor.getLineFromCharacterPosition( 13, "", lineMapping, mappingLen );
				expect( lineNum13 ).toBe( 2, "Position 13 should be line 2" );

				var lineNum15 = processor.getLineFromCharacterPosition( 15, "", lineMapping, mappingLen );
				expect( lineNum15 ).toBe( 3, "Position 15 should be line 3" );

				var lineNum22 = processor.getLineFromCharacterPosition( 22, "", lineMapping, mappingLen );
				expect( lineNum22 ).toBe( 4, "Position 22 should be line 4" );
			});

			it( "should work with real CFML file content", function() {
				var processor = new lucee.extension.lcov.CoverageBlockProcessor();

				// Get artifact path from GenerateTestData
				var artifactPath = variables.testGen.getSourceArtifactsDir() & "/kitchen-sink-example.cfm";
				var content = fileRead( artifactPath );

				var lineMapping = processor.buildCharacterToLineMapping( content );
				var mappingLen = arrayLen( lineMapping );

				// Test that we can map positions from the .exl file
				// From earlier debug: block "431-444" should map to line 34 (simple = new SimpleComponent())
				// But first, let's just verify the function works without errors

				// Get line for position 1 (should be line 1)
				var line1 = processor.getLineFromCharacterPosition( 1, artifactPath, lineMapping, mappingLen );
				expect( line1 ).toBeGT( 0, "Should return valid line number for position 1" );

				// Get line for position 100 (should be some early line)
				var line100 = processor.getLineFromCharacterPosition( 100, artifactPath, lineMapping, mappingLen );
				expect( line100 ).toBeGT( 0, "Should return valid line number for position 100" );
				expect( line100 ).toBeLTE( 10, "Position 100 should be in first 10 lines" );
			});

		});
	}
}
