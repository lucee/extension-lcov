
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {

		describe( "compare getLineFromCharacterPosition implementation", () => {
			it( "should match stable and develop implementations", () => {
				var factory = new lucee.extension.lcov.CoverageComponentFactory();
				var developBlockProcessor = factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=true);
				var stableBlockProcessor = factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=false);
				var files = directoryList( "../artifacts", false, "path", "*.cfm" );
				var testCases = [];

				for( var file in files ){
					var develop = {
						lineMapping: developBlockProcessor.buildCharacterToLineMapping(fileRead(file))
					};
					develop.mappingLen = arrayLen(develop.lineMapping);

					var stable = {
						lineMapping: stableBlockProcessor.buildCharacterToLineMapping(fileRead(file))
					};
					stable.mappingLen = arrayLen(stable.lineMapping);

					expect( develop.mappingLen ).toBe( stable.mappingLen, "Mapping length should match for file " & file );
					expect( develop.mappingLen ).toBeGT( 0, "Mapping length should be > 0 for file " & file );

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
						develop: develop,
						stable: stable
					} );

				}

				arrayEach( testcases, function(testCase){
					for( var pos in testCase.positions ){
						var develop = testCase.develop;
						var stable = testCase.stable;
						// getLineFromCharacterPosition(charPos, filePath, lineMapping, mappingLen, minLine = 1)
						develop.line = developBlockProcessor.getLineFromCharacterPosition(pos, 
							testCase.filePath, develop.lineMapping, develop.mappingLen);
						stable.line = stableBlockProcessor.getLineFromCharacterPosition(pos, 
							testCase.filePath, stable.lineMapping, stable.mappingLen);

						expect( develop.line ).toBe( stable.line,
							"Mismatch at position " & pos & " in file " & testCase.filePath &
							": develop=" & develop.line & ", stable=" & stable.line
						);
					}
				});

			});

		})
	}
}
