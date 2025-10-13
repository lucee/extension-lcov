
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {

		describe( "test getLineFromCharacterPosition implementation", () => {
			it( "should correctly map character positions to lines", () => {
				var logger = new lucee.extension.lcov.Logger( level="none" );
				var blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=logger );
				var files = directoryList( "../artifacts", false, "path", "*.cfm" );
				var testCases = [];

				for( var file in files ){
					var mapping = {
						lineMapping: blockProcessor.buildCharacterToLineMapping( fileRead( file ) )
					};
					mapping.mappingLen = arrayLen( mapping.lineMapping );

					expect( mapping.mappingLen ).toBeGT( 0, "Mapping length should be > 0 for file " & file );

					// calculate some test positions (every 10th char up to length of file)
					var fileContent = fileRead(file);
					var fileLen = len(fileContent);
					var positions = [];

					for (var i = 1; i <= fileLen; i++) {
						if (i % 10 == 0) {
							arrayAppend(positions, i);
						}
					}

					arrayAppend( testCases, {
						filePath: file,
						positions: positions,
						mapping: mapping
					} );

				}

				arrayEach( testcases, function( testCase ) {
					for( var pos in testCase.positions ){
						var mapping = testCase.mapping;
						// getLineFromCharacterPosition(charPos, filePath, lineMapping, mappingLen, minLine = 1)
						var line = blockProcessor.getLineFromCharacterPosition( pos,
							testCase.filePath, mapping.lineMapping, mapping.mappingLen );

						expect( line ).toBeGT( 0, "Should return valid line number for position " & pos & " in file " & testCase.filePath );
					}
				});

			});

		})
	}
}
