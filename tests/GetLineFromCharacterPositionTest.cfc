
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {

		describe( "compare getLineFromCharacterPosition implementation", () => {
			it( "should match original and optimized implementations", () => {
				var optimizedParser = new lucee.extension.lcov.ExecutionLogParserOptimized();
				var originalParser = new lucee.extension.lcov.ExecutionLogParser();
				var files = directoryList( "tests/artifacts", false, "path", "*.cfm" );
				var testCases = [];

				for( var file in files ){
					var optimised = {
						lineMapping: optimizedParser.buildCharacterToLineMapping(fileRead(file)),
						mappingLen: arrayLen(optimised.lineMapping)
					};

					var original = {
						lineMapping: originalParser.buildCharacterToLineMapping(fileRead(file)),
						mappingLen: arrayLen(original.lineMapping)
					};

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
						optimised: optimised,
						original: original
					} );

				}

				for( var file in testCases ){
					var testCase = testCases[file];	

					for( var pos in testCase.positions ){
						var optimised = testCase.optimised;
						var original = testCase.original;
						optimised.line = optimizedParser.getLineFromCharacterPosition(pos, optimised.lineMapping, optimised.mappingLen);
						original.line = originalParser.getLineFromCharacterPosition(pos, original.lineMapping, original.mappingLen);	
						expect( optimised.line ).toBe( original.line,
							"Mismatch at position " & pos & " in file " & testCase.filePath &
							": optimized=" & optimised.line & ", original=" & original.line
						);
					}
				}
			});

		})
	}
}
