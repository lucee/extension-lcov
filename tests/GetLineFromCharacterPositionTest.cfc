
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {

		describe( "compare getLineFromCharacterPosition implementation", () => {
			it( "should match stable and develop implementations", () => {
				var developParser = new lucee.extension.lcov.develop.ExecutionLogParser();
				var stableParser = new lucee.extension.lcov.ExecutionLogParser();
				var files = directoryList( "tests/artifacts", false, "path", "*.cfm" );
				var testCases = [];

				for( var file in files ){
					var optimised = {
						lineMapping: developParser.buildCharacterToLineMapping(fileRead(file)),
						mappingLen: arrayLen(optimised.lineMapping)
					};

					var stable = {
						lineMapping: stableParser.buildCharacterToLineMapping(fileRead(file)),
						mappingLen: arrayLen(stable.lineMapping)
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
						stable: stable
					} );

				}

				for( var file in testCases ){
					var testCase = testCases[file];

					for( var pos in testCase.positions ){
						var optimised = testCase.optimised;
						var stable = testCase.stable;
						optimised.line = developParser.getLineFromCharacterPosition(pos, optimised.lineMapping, optimised.mappingLen);
						stable.line = stableParser.getLineFromCharacterPosition(pos, stable.lineMapping, stable.mappingLen);
						expect( optimised.line ).toBe( stable.line,
							"Mismatch at position " & pos & " in file " & testCase.filePath &
							": develop=" & optimised.line & ", stable=" & stable.line
						);
					}
				}
			});

		})
	}
}
