component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "trace";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );

		// Generate 2x test data
		variables.testDataGenerator = new GenerateTestData( testName="FileIdRemappingTest-2x" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword = request.SERVERADMINPASSWORD,
			fileFilter = "multiple/basic.cfm",
			iterations = 2
		);
	}

	function run() {
		describe( "File ID Remapping", function() {

			it( "should correctly merge when file IDs differ between .exl files", function() {
				testReversedFileKeys();
			});
		});
	}

	private function testReversedFileKeys() {
		var sourceDir = variables.testData.coverageDir;
		var reversedDir = createReversedExlFiles( sourceDir );
		var outputDir2x = generateJsonForOriginal( sourceDir );
		var outputDirModified = generateJsonForReversed( reversedDir );

		outputDebugInfo( sourceDir, reversedDir, outputDir2x, outputDirModified );
		validateIdenticalCoverage( outputDir2x, outputDirModified );
	}

	private string function createReversedExlFiles( required string sourceDir ) {
		var reversedDir = variables.testDataGenerator.getOutputDir( "reversed" );
		directoryCreate( reversedDir, true, true );

		var exlFiles = directoryList( arguments.sourceDir, false, "array", "*.exl" );

		for ( var exlFile in exlFiles ) {
			var exlContent = fileRead( exlFile );
			var modifiedContent = changeFileIdFromZeroToOne( exlContent );
			var fileName = getFileFromPath( exlFile );
			fileWrite( reversedDir & "/" & fileName, modifiedContent );
		}

		return reversedDir;
	}

	private string function changeFileIdFromZeroToOne( required string exlContent ) {
		var lines = arguments.exlContent.split( chr(10) );
		var result = [];
		var inMetadata = true;
		var fileMapping = {};
		var fileCount = 0;

		// First pass: count files and build file mapping
		for ( var line in lines ) {
			var cleanLine = line.endsWith( chr(13) ) ? left( line, len( line ) - 1 ) : line;
			if ( reFind( "^\d+:", cleanLine ) ) {
				var fileId = listFirst( cleanLine, ":" );
				fileMapping[ fileId ] = fileCount;
				fileCount++;
			}
		}

		// Build remapping: if 2 files, reverse them; if more, randomize
		var idRemapping = {};
		if ( fileCount == 2 ) {
			idRemapping[ "0" ] = 1;
			idRemapping[ "1" ] = 0;
		} else if ( fileCount > 2 ) {
			var newIds = [];
			for ( var i = 0; i < fileCount; i++ ) {
				arrayAppend( newIds, i );
			}
			// Fisher-Yates shuffle
			for ( var i = arrayLen( newIds ); i > 1; i-- ) {
				var j = randRange( 1, i );
				var temp = newIds[ i ];
				newIds[ i ] = newIds[ j ];
				newIds[ j ] = temp;
			}
			for ( var oldId = 0; oldId < fileCount; oldId++ ) {
				idRemapping[ oldId & "" ] = newIds[ oldId + 1 ];
			}
		} else {
			// Single file: change 0 to 1
			idRemapping[ "0" ] = 1;
		}

		// Second pass: apply remapping
		inMetadata = true;
		for ( var line in lines ) {
			var cleanLine = line.endsWith( chr(13) ) ? left( line, len( line ) - 1 ) : line;

			if ( inMetadata ) {
				if ( reFind( "^\d+:", cleanLine ) ) {
					var oldId = listFirst( cleanLine, ":" );
					var newId = idRemapping[ oldId ];
					var filePath = listRest( cleanLine, ":" );
					arrayAppend( result, newId & ":" & filePath );
					continue;
				}
				if ( reFind( "^\d+\t", cleanLine ) ) {
					inMetadata = false;
				} else {
					arrayAppend( result, cleanLine );
					continue;
				}
			}

			// Remap file IDs in coverage lines
			var firstTabPos = find( chr(9), cleanLine );
			if ( firstTabPos > 0 ) {
				var oldId = left( cleanLine, firstTabPos - 1 );
				if ( structKeyExists( idRemapping, oldId ) ) {
					var newId = idRemapping[ oldId ];
					arrayAppend( result, newId & mid( cleanLine, firstTabPos, len( cleanLine ) ) );
				} else {
					arrayAppend( result, cleanLine );
				}
			} else {
				arrayAppend( result, cleanLine );
			}
		}

		return arrayToList( result, chr(13) & chr(10) );
	}

	private string function generateJsonForOriginal( required string sourceDir ) {
		var outputDir = variables.testDataGenerator.getOutputDir( "json-original" );
		lcovGenerateJson(
			executionLogDir = arguments.sourceDir,
			outputDir = outputDir,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);
		return outputDir;
	}

	private string function generateJsonForReversed( required string reversedDir ) {
		var outputDir = variables.testDataGenerator.getOutputDir( "json-modified" );
		lcovGenerateJson(
			executionLogDir = arguments.reversedDir,
			outputDir = outputDir,
			options = { separateFiles: true, logLevel: variables.logLevel }
		);
		return outputDir;
	}

	private void function outputDebugInfo( required string sourceDir, required string reversedDir, required string outputDir2x, required string outputDirModified ) {
		var json2x = deserializeJSON( fileRead( arguments.outputDir2x & "/file-F72B577-basic.cfm.json" ) );
		var jsonMod = deserializeJSON( fileRead( arguments.outputDirModified & "/file-F72B577-basic.cfm.json" ) );

		systemOutput( "=== json-original (fileID=0) coverage ===" );
		systemOutput( serializeJSON( json2x.coverage ) );
		systemOutput( "=== json-modified (fileID=1) coverage ===" );
		systemOutput( serializeJSON( jsonMod.coverage ) );

		systemOutput( "=== Per-request JSON from sourceDir (fileID=0) - count: #arrayLen(directoryList(arguments.sourceDir, false, 'array', '*.json'))# ===" );
		var exlFiles1 = directoryList( arguments.sourceDir, false, "array", "*.json" );
		for ( var jsonFile in exlFiles1 ) {
			var perReqJson = deserializeJSON( fileRead( jsonFile ) );
			systemOutput( "File: " & getFileFromPath( jsonFile ) & " coverage: " & serializeJSON( perReqJson.coverage ) );
		}

		systemOutput( "=== Per-request JSON from reversedDir (fileID=1) - count: #arrayLen(directoryList(arguments.reversedDir, false, 'array', '*.json'))# ===" );
		var exlFiles2 = directoryList( arguments.reversedDir, false, "array", "*.json" );
		for ( var jsonFile in exlFiles2 ) {
			var perReqJson = deserializeJSON( fileRead( jsonFile ) );
			systemOutput( "File: " & getFileFromPath( jsonFile ) & " coverage: " & serializeJSON( perReqJson.coverage ) );
		}

		systemOutput( "=== Total .json files being merged ===" );
		systemOutput( "sourceDir (.exl): " & arrayLen(directoryList(arguments.sourceDir, false, 'array', '*.exl')) );
		systemOutput( "reversedDir (.exl): " & arrayLen(directoryList(arguments.reversedDir, false, 'array', '*.exl')) );
	}

	private void function validateIdenticalCoverage( required string outputDir2x, required string outputDirModified ) {
		var jsonFiles2x = directoryList( arguments.outputDir2x, false, "array", "file-*.json" );
		var jsonFilesMod = directoryList( arguments.outputDirModified, false, "array", "file-*.json" );

		expect( arrayLen( jsonFiles2x ) ).toBe( arrayLen( jsonFilesMod ), "Should have same number of files" );

		for ( var jsonFile2x in jsonFiles2x ) {
			var fileName = getFileFromPath( jsonFile2x );
			var jsonFileMod = arguments.outputDirModified & "/" & fileName;

			expect( fileExists( jsonFileMod ) ).toBeTrue( "Modified run should have matching file: #fileName#" );

			var json2x = deserializeJSON( fileRead( jsonFile2x ) );
			var jsonMod = deserializeJSON( fileRead( jsonFileMod ) );

			var coverage2x = json2x.coverage;
			var coverageMod = jsonMod.coverage;

			expect( structCount( coverage2x ) ).toBe( structCount( coverageMod ), "#fileName#: Should have same number of coverage entries" );

			for ( var fileKey in coverage2x ) {
				expect( structKeyExists( coverageMod, fileKey ) ).toBeTrue( "#fileName#: File key #fileKey# should exist in both" );

				var lines2x = coverage2x[ fileKey ];
				var linesMod = coverageMod[ fileKey ];

				for ( var lineNum in lines2x ) {
					var hitCount2x = lines2x[ lineNum ][ 1 ];
					var hitCountMod = linesMod[ lineNum ][ 1 ];

					expect( hitCountMod ).toBe( hitCount2x, "#fileName# Line #lineNum#: Hit counts should match (original=#hitCount2x#, modified=#hitCountMod#)" );
				}
			}
		}
	}
}
