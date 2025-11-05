component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logger = new lucee.extension.lcov.Logger(logLevel="ERROR");
		variables.testDataGenerator = new "../GenerateTestData"(
			testName = "IfBlockContainerDetectionTest",
			artifactsSubFolder = "blocks"
		);

		// Generate test data
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: request.SERVERADMINPASSWORD,
			fileFilter: "if-block-double-count.cfm"
		);
	}

	/**
	 * @displayName "Given if statement with braces, When analyzing AST, Then it should be marked as block container (isBlock=true)"
	 */
	function testIfWithBracesIsBlockContainer() {
		// Get the artifact source file
		var artifactPath = variables.testDataGenerator.getSourceArtifactsDir() & "if-block-double-count.cfm";
		expect(fileExists(artifactPath)).toBeTrue("Artifact file should exist");

		// Extract AST metadata directly from the source file
		var fileContent = fileRead(artifactPath);
		var astParserHelper = new lucee.extension.lcov.parser.AstParserHelper(logger=variables.logger);
		var ast = astParserHelper.parseFileAst(artifactPath, fileContent);

		var astMetadataExtractor = new lucee.extension.lcov.ast.AstMetadataExtractor(logger=variables.logger);
		var metadata = astMetadataExtractor.extractMetadata(ast, artifactPath);

		systemOutput("", true);
		systemOutput("AST Nodes for if-block-double-count.cfm:", true);

		// Look for the if statement block (around line 15)
		// The if statement with braces should create an AST node marked as block container
		var foundIfBlock = false;

		if (structKeyExists(metadata, "astNodes")) {
			cfloop(collection=metadata.astNodes, key="local.blockKey", item="local.astNode") {
				systemOutput("  Block " & blockKey & ": astNodeType=" & (astNode.astNodeType ?: "none") &
					", isBlock=" & (astNode.isBlock ?: false) &
					", tagName=" & (astNode.tagName ?: ""), true);

				// The if statement block should be marked as block container
				if (structKeyExists(astNode, "astNodeType") && astNode.astNodeType == "IfStatement") {
					foundIfBlock = true;
					expect(astNode).toHaveKey("isBlock", "If statement should have isBlock flag");
					expect(astNode.isBlock).toBeTrue("If statement with braces should be marked as block container (isBlock=true)");
				}
			}
		}

		systemOutput("", true);

		// We should have found at least the if block
		expect(foundIfBlock).toBeTrue("Should have found if statement block in AST");
	}

	/**
	 * @displayName "Given if statement body, When analyzing AST, Then body should NOT be marked as block container"
	 */
	function testIfBodyIsNotBlockContainer() {
		// Get the artifact source file
		var artifactPath = variables.testDataGenerator.getSourceArtifactsDir() & "if-block-double-count.cfm";

		// Extract AST metadata directly from the source file
		var fileContent = fileRead(artifactPath);
		var astParserHelper = new lucee.extension.lcov.parser.AstParserHelper(logger=variables.logger);
		var ast = astParserHelper.parseFileAst(artifactPath, fileContent);

		var astMetadataExtractor = new lucee.extension.lcov.ast.AstMetadataExtractor(logger=variables.logger);
		var metadata = astMetadataExtractor.extractMetadata(ast, artifactPath);

		// The body of the if (line 17) should NOT be a block container
		// It's just a regular statement
		if (structKeyExists(metadata, "astNodes")) {
			cfloop(collection=metadata.astNodes, key="local.blockKey", item="local.astNode") {
				// Skip the if statement itself
				if (structKeyExists(astNode, "astNodeType") && astNode.astNodeType == "IfStatement") {
					continue;
				}
				// Skip function declarations (they are block containers)
				if (structKeyExists(astNode, "astNodeType") && astNode.astNodeType == "FunctionDeclaration") {
					continue;
				}

				// Other blocks inside should NOT be block containers (isBlock should be 0 or false)
				if (structKeyExists(astNode, "isBlock")) {
					expect(astNode.isBlock).toBe(0, "Non-block statements should have isBlock=0, got: " & astNode.isBlock);
				}
			}
		}
	}
}
