component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logger = new lucee.extension.lcov.Logger(logLevel="debug");
		variables.testDataGenerator = new "../GenerateTestData"(
			testName = "IfBlockDoubleCountTest",
			artifactsSubFolder = "blocks"
		);

		// Generate test data for both artifacts
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: request.SERVERADMINPASSWORD,
			fileFilter: "if-*.cfm"
		);
	}

	/**
	 * @displayName "Given if statement with braces, When aggregating to lines, Then container block time should NOT double-count with body block time"
	 */
	function testIfBlockNotDoubleCounted() {
		// Parse execution logs
		var processor = new lucee.extension.lcov.ExecutionLogProcessor(
			options = {logLevel: "debug"}
		);
		var parseResult = processor.parseExecutionLogs(variables.testData.coverageDir);
		var jsonFilePaths = parseResult.jsonFilePaths;

		expect(jsonFilePaths).notToBeEmpty("Should have generated JSON files");

		// Load the first JSON file - this has blocks, not line-level coverage yet
		var jsonData = deserializeJSON(fileRead(jsonFilePaths[1]));

		// Get the first (and only) file index from the JSON
		var fileIdx = structKeyArray(jsonData.files)[1];

		systemOutput("", true);
		systemOutput("Blocks in JSON:", true);

		// Find the if statement block (around char position 369-474 from our artifact)
		var ifContainerBlock = "";
		var ifBodyBlock = "";

		cfloop(collection=jsonData.aggregated, key="local.blockKey", item="local.blockData") {
			systemOutput("  Block " & blockKey & ": isChild=" & blockData[6], true);
			// Block format: [fileIdx, startPos, endPos, hitCount, time, isChild]
			var startPos = blockData[2];
			var endPos = blockData[3];
			var time = blockData[5];
			var isChild = blockData[6];

			// The if statement container (369-474)
			if (startPos == "369" && endPos == "474") {
				ifContainerBlock = blockData;
				systemOutput("    ^ IF CONTAINER: time=" & time & "μs, isChild=" & isChild, true);
			}
			// The body block inside the if (around 445-469)
			if (startPos == "445" && endPos == "469") {
				ifBodyBlock = blockData;
				systemOutput("    ^ IF BODY: time=" & time & "μs, isChild=" & isChild, true);
			}
		}
		systemOutput("", true);

		expect(ifContainerBlock).notToBeEmpty("Should have found if container block (369-474)");
		expect(ifBodyBlock).notToBeEmpty("Should have found if body block (445-469)");

		// The container block should be marked as isChild=true (it's a container)
		// The body block should be marked as isChild=false (it's a child of the container)
		var containerIsChild = ifContainerBlock[6];
		var bodyIsChild = ifBodyBlock[6];

		systemOutput("Container block isChild: " & containerIsChild, true);
		systemOutput("Body block isChild: " & bodyIsChild, true);
		systemOutput("", true);

		// Good! Overlap detection correctly identified this as a container (isChild=true)
		expect(containerIsChild).toBeTrue("Overlap detection: Container block should be marked as isChild=true");
		expect(bodyIsChild).toBeFalse("Overlap detection: Body block should be marked as isChild=false");

		// Now check if AST agrees - get AST metadata for the file
		var artifactPath = variables.testDataGenerator.getSourceArtifactsDir() & "if-block-double-count.cfm";
		var fileContent = fileRead(artifactPath);
		var astParserHelper = new lucee.extension.lcov.parser.AstParserHelper(logger=variables.logger);
		var ast = astParserHelper.parseFileAst(artifactPath, fileContent);
		var astMetadataExtractor = new lucee.extension.lcov.ast.AstMetadataExtractor(logger=variables.logger);
		var metadata = astMetadataExtractor.extractMetadata(ast, artifactPath);

		// Find the AST node for the if statement (block 369-474)
		var ifAstNode = "";
		if (structKeyExists(metadata, "astNodes")) {
			cfloop(collection=metadata.astNodes, key="local.blockKey", item="local.astNode") {
				if (blockKey == "369-474") {
					ifAstNode = astNode;
					break;
				}
			}
		}

		expect(ifAstNode).notToBeEmpty("Should have found AST node for if statement (369-474)");
		systemOutput("AST node for if statement: astNodeType=" & (ifAstNode.astNodeType ?: "none") & ", isBlock=" & (ifAstNode.isBlock ?: 0), true);

		// THE BUG: AST says isBlock=0 but overlap says isChild=true (block container)
		// They should AGREE! When AST says isBlock=true, it confirms the overlap detection
		expect(ifAstNode.isBlock).toBeTrue("AST should mark if-with-braces as block container (isBlock=true)");
	}

	/**
	 * @displayName "Given if statement without braces, When checking EXL blocks, Then EXL still creates a container block"
	 */
	function testIfWithoutBracesAlsoCreatesContainer() {
		// Parse execution logs (same as first test)
		var processor = new lucee.extension.lcov.ExecutionLogProcessor(
			options = {logLevel: "debug"}
		);
		var parseResult = processor.parseExecutionLogs(variables.testData.coverageDir);
		var jsonFilePaths = parseResult.jsonFilePaths;

		expect(jsonFilePaths).notToBeEmpty("Should have generated JSON files");

		// The processor combines files, so we need to look in the raw directory
		var rawJsonFiles = directoryList(
			path = variables.testData.coverageDir,
			filter = "*.json",
			recurse = false,
			type = "file"
		);

		expect(rawJsonFiles).notToBeEmpty("Should have raw JSON files");

		// Find the JSON file for if-without-braces.cfm
		var targetJsonPath = "";
		cfloop(array=rawJsonFiles, item="local.jsonPath") {
			var jsonData = deserializeJSON(fileRead(jsonPath));
			if (structKeyExists(jsonData, "metadata") && findNoCase("if-without-braces", jsonData.metadata["script-name"])) {
				targetJsonPath = jsonPath;
				break;
			}
		}

		expect(targetJsonPath).notToBeEmpty("Should have found JSON for if-without-braces.cfm");

		var jsonData = deserializeJSON(fileRead(targetJsonPath));
		var fileIdx = structKeyArray(jsonData.files)[1];

		systemOutput("", true);
		systemOutput("Blocks in EXL for if-without-braces.cfm:", true);

		// TRUTH: EXL files create a container block even without braces!
		// This is because Lucee tracks the execution timing of the if statement
		// which includes the condition evaluation + body execution
		var ifContainerBlock = "";
		var ifBodyBlock = "";

		cfloop(collection=jsonData.aggregated, key="local.blockKey", item="local.blockData") {
			var startPos = blockData[2];
			var endPos = blockData[3];
			var time = blockData[5];
			var isChild = blockData[6];

			systemOutput("  Block " & blockKey & ": time=" & time & "μs, isChild=" & isChild, true);

			// The if statement container (317-365)
			if (startPos == "317" && endPos == "365") {
				ifContainerBlock = blockData;
				systemOutput("    ^ IF CONTAINER (without braces): time=" & time & "μs, isChild=" & isChild, true);
			}
			// The body statement (338-362)
			if (startPos == "338" && endPos == "362") {
				ifBodyBlock = blockData;
				systemOutput("    ^ IF BODY: time=" & time & "μs, isChild=" & isChild, true);
			}
		}
		systemOutput("", true);

		expect(ifContainerBlock).notToBeEmpty("EXL creates a container block even for if-without-braces (317-365)");
		expect(ifBodyBlock).notToBeEmpty("EXL creates a body block (338-362)");

		// The container is marked as isChild=true (it's a container in EXL)
		// The body is marked as isChild=false (it's a child of the container)
		var containerIsChild = ifContainerBlock[6];
		var bodyIsChild = ifBodyBlock[6];

		expect(containerIsChild).toBeTrue("Container block is marked as isChild=true (it contains other blocks)");
		expect(bodyIsChild).toBeFalse("Body block is marked as isChild=false (it's contained by the if)");

		// The container time includes the body time - this demonstrates the double-counting issue
		var containerTime = ifContainerBlock[5];
		var bodyTime = ifBodyBlock[5];

		systemOutput("Container time: " & containerTime & "μs", true);
		systemOutput("Body time: " & bodyTime & "μs", true);
		systemOutput("Difference (condition overhead): " & (containerTime - bodyTime) & "μs", true);
		systemOutput("", true);

		// The container time should be >= body time (it includes the body + condition evaluation)
		expect(containerTime).toBeGTE(bodyTime, "Container time should include body time");
	}
}
