component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level="none" );
		variables.parser = new lucee.extension.lcov.ExecutionLogParser( logger=variables.logger );
	variables.testDataGenerator = new "../GenerateTestData"(testName="ExecutionLogParserTest");
		// Generate test data if needed
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
	}
	
	function testParserExists() {
		expect(variables.parser).toBeInstanceOf("ExecutionLogParser");
	}

	function testParseFiles(){
		expect(directoryExists(variables.testData.coverageDir)).toBeTrue("Coverage directory should exist");

		// Phase 1: Parse .exl files
		var processor = new lucee.extension.lcov.ExecutionLogProcessor( options={logLevel: variables.logLevel} );
		var parseResult = processor.parseExecutionLogs( variables.testData.coverageDir );
		var jsonFilePaths = parseResult.jsonFilePaths;
		expect(arrayLen(jsonFilePaths)).toBeGT(0, "Should find some .exl files");

		// Phase 2: Extract AST metadata
		var astMetadataGenerator = new lucee.extension.lcov.ast.AstMetadataGenerator( logger=variables.logger );
		var astMetadataPath = astMetadataGenerator.generate( variables.testData.coverageDir, parseResult.allFiles );

		// Phase 3: Build line coverage
		var lineCoverageBuilder = new lucee.extension.lcov.coverage.LineCoverageBuilder( logger=variables.logger );
		lineCoverageBuilder.buildCoverage( jsonFilePaths, astMetadataPath );

		// Test each result
		for (var jsonPath in jsonFilePaths) {
			// Skip ast-metadata.json
			if ( findNoCase( "ast-metadata", jsonPath ) ) {
				continue;
			}

			// Load enriched result
			var jsonContent = fileRead( jsonPath );
			var result = new lucee.extension.lcov.model.result();
			var data = deserializeJSON( jsonContent );
			for (var key in data) {
				var setter = "set" & key;
				if ( structKeyExists( result, setter ) ) {
					result[setter]( data[key] );
				}
			}

			//expect(result.validate(throw=false)).toBeEmpty();
			expect(result.getFiles()).notToBeEmpty("Files should not be empty for " & jsonPath);
			expect(result.getCoverage()).notToBeEmpty("Coverage should not be empty for " & jsonPath);
			expect(result.getExeLog()).notToBeEmpty("ExeLog should not be empty for " & jsonPath);
			expect(result.getMetadata()).notToBeEmpty("Metadata should not be empty for " & jsonPath);

			var keys = {
				"metadata": "struct",
				"coverage": "struct",
				"exelog": "string",
				"stats": "struct",
				"files": "struct"
			};

			var json = result.getData();

			for (var key in keys) {
				expect(json).toHaveKey(key, "Parsed struct should have [" & key & "] for " & jsonPath);
				expect(json[key]).toBeTypeOf(keys[key], "Parsed struct should have correct type for [" & key & "] in " & jsonPath);
			}

			var requiredStatsKeys = [
				"totalLinesFound", "totalLinesHit", "totalLinesSource", "totalExecutions", "totalExecutionTime"
			];
			for (var statKey in requiredStatsKeys) {
				expect(json.stats).toHaveKey(statKey, "[stats] should have key [" & statKey & "] for " & jsonPath);
			}

			var requiredFileStatsKeys = [
				"linesFound", "linesHit", "linesSource", "totalExecutions", "totalExecutionTime"
			];

			// There should be at least one file entry
			expect(structCount(json.files)).toBeGT(0, "[files] should not be empty for " & jsonPath);
			for (var fileKey in json.files) {
				var fileStats = json.files[fileKey];
				for (var statKey in requiredFileStatsKeys) {
					expect(fileStats).toHaveKey(statKey, "[files][" & fileKey & "] should have key [" & statKey & "] for " & jsonPath);
				}
			}

		}
	}
}