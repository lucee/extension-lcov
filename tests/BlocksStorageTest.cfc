component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.testDataGenerator = new GenerateTestData( testName="BlocksStorageTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts( request.SERVERADMINPASSWORD );
	}

	function run() {
		describe( "Block-level storage in result model", function() {

			it( "should store and retrieve blocks for a file", function() {
				var result = new lucee.extension.lcov.model.result();

				// Set up blocks for file 0
				var fileBlocks = {
					"100-200": { hitCount: 5, execTime: 1000, isChild: false },
					"300-400": { hitCount: 2, execTime: 500, isChild: true }
				};

				result.setBlocksForFile( 0, fileBlocks );

				var retrieved = result.getBlocksForFile( 0 );
				expect( retrieved ).toBeStruct();
				expect( structCount( retrieved ) ).toBe( 2 );
				expect( retrieved[ "100-200" ].hitCount ).toBe( 5 );
				expect( retrieved[ "100-200" ].isChild ).toBe( false );
				expect( retrieved[ "300-400" ].isChild ).toBe( true );
			});

			it( "should return empty struct for file with no blocks", function() {
				var result = new lucee.extension.lcov.model.result();
				var blocks = result.getBlocksForFile( 999 );
				expect( blocks ).toBeStruct();
				expect( structCount( blocks ) ).toBe( 0 );
			});

			it( "should add individual blocks", function() {
				var result = new lucee.extension.lcov.model.result();

				result.addBlock( 0, 100, 200, { hitCount: 1, execTime: 100, isChild: false } );
				result.addBlock( 0, 300, 400, { hitCount: 2, execTime: 200, isChild: true } );

				var blocks = result.getBlocksForFile( 0 );
				expect( structCount( blocks ) ).toBe( 2 );
				expect( blocks[ "100-200" ].hitCount ).toBe( 1 );
				expect( blocks[ "300-400" ].hitCount ).toBe( 2 );
			});

			it( "should parse .exl file and populate blocks", function() {
				// Use generated test data and process it with ExecutionLogProcessor
				var processor = new lucee.extension.lcov.ExecutionLogProcessor();
				var jsonFilePaths = processor.parseExecutionLogs( variables.testData.coverageDir );

				expect( arrayLen( jsonFilePaths ) ).toBeGT( 0, "Should have generated at least one JSON file" );

				// Read the JSON file to get the result model
				var jsonFile = jsonFilePaths[ 1 ];
				expect( fileExists( jsonFile ) ).toBeTrue( "JSON file should exist: " & jsonFile );

				var jsonData = deserializeJSON( fileRead( jsonFile ) );
				expect( jsonData ).toBeStruct();

				// Check that blocks were populated in the JSON
				expect( jsonData ).toHaveKey( "blocks" );
				var blocks = jsonData.blocks;
				expect( blocks ).toBeStruct();
				expect( structCount( blocks ) ).toBeGT( 0, "Should have at least one file with blocks" );

				// Check first file has blocks
				var fileKeys = structKeyArray( blocks );
				var firstFile = fileKeys[ 1 ];
				var fileBlocks = blocks[ firstFile ];

				expect( structCount( fileBlocks ) ).toBeGT( 0, "File should have at least one block" );

				// Verify block structure
				for ( var blockKey in fileBlocks ) {
					var block = fileBlocks[ blockKey ];
					expect( block ).toHaveKey( "hitCount" );
					expect( block ).toHaveKey( "execTime" );
					expect( block ).toHaveKey( "isChild" );
					expect( isBoolean( block.isChild ) ).toBeTrue( "isChild should be boolean" );
					break; // Just check first block
				}
			});

		});
	}
}
