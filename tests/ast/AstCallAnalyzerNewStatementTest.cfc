component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.testDataGenerator = new "../GenerateTestData"( testName="AstCallAnalyzerNewStatement" );
	}

	function run() {
		describe("AstCallAnalyzer new statement detection", function() {

			it("should detect new statements in component functions", function() {
				// Get artifact path
				var artifactsDir = variables.testDataGenerator.getSourceArtifactsDir();
				var filePath = artifactsDir & "/ast/simple-new-statements.cfc";
					// WORKAROUND: astFromString() treats .cfc files as StringLiteral (Lucee bug)
				var ast = astFromPath( filePath );
				var logger = new lucee.extension.lcov.Logger( level="trace" );
				var analyzer = new lucee.extension.lcov.ast.AstCallAnalyzer( logger=logger );

				var functions = analyzer.extractFunctions( ast );

				// Should find init and createStuff functions
				expect( arrayLen( functions ) ).toBeGTE( 2, "Should find at least 2 functions (init and createStuff)" );

				// Check init function has 2 new statements
				var initFunc = "";
				for ( var func in functions ) {
					if ( structKeyExists( func, "name" ) && func.name == "init" ) {
						initFunc = func;
						break;
					}
				}

				expect( isStruct( initFunc ) ).toBeTrue( "Should find init function" );
				expect( structKeyExists( initFunc, "calls" ) ).toBeTrue( "init function should have calls array" );
				expect( isArray( initFunc.calls ) ).toBeTrue( "calls should be an array" );

				// Count new statements in init
				var newCalls = [];
				for ( var call in initFunc.calls ) {
					if ( structKeyExists( call, "name" ) && (left( call.name, 4 ) == "new " || call.name == "_createcomponent") ) {
						arrayAppend( newCalls, call );
					}
				}

				if ( arrayLen( newCalls ) < 2 ) {
					fail( "Expected at least 2 new statements in init, found: " & arrayLen( newCalls ) );
				}

				expect( arrayLen( newCalls ) ).toBeGTE( 2, "Should find 2 new statements in init function (Logger, ComponentFactory)" );

				// Check createStuff function has 2 new statements
				var createStuffFunc = "";
				for ( var func in functions ) {
					if ( structKeyExists( func, "name" ) && func.name == "createStuff" ) {
						createStuffFunc = func;
						break;
					}
				}

				expect( isStruct( createStuffFunc ) ).toBeTrue( "Should find createStuff function" );
				expect( structKeyExists( createStuffFunc, "calls" ) ).toBeTrue( "createStuff function should have calls array" );

				// Count new statements in createStuff
				var createStuffNewCalls = [];
				for ( var call in createStuffFunc.calls ) {
					if ( structKeyExists( call, "name" ) && (left( call.name, 4 ) == "new " || call.name == "_createcomponent") ) {
						arrayAppend( createStuffNewCalls, call );
					}
				}

				if ( arrayLen( createStuffNewCalls ) < 2 ) {
					fail( "Expected at least 2 new statements in createStuff, found: " & arrayLen( createStuffNewCalls ) );
				}

				expect( arrayLen( createStuffNewCalls ) ).toBeGTE( 2, "Should find 2 new statements in createStuff function" );
			});

		});
	}

}
