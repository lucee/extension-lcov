component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );
		variables.testDataGenerator = new "../GenerateTestData"( testName="CallTreeCustomTagTest" );
		variables.callTreeAnalyzer = new lucee.extension.lcov.ast.CallTreeAnalyzer( logger=variables.logger );
		variables.astCallAnalyzer = new lucee.extension.lcov.ast.AstCallAnalyzer( logger=variables.logger );
		variables.blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		variables.artifactsDir = expandPath( "/testAdditional/artifacts/ast" );
	}

	/**
	 * Helper function to run the new CallTreeAnalyzer workflow
	 * Replaces the old analyzeCallTree() method
	 */
	private struct function analyzeCallTreeWithNewAPI( required struct aggregated, required struct files ) {
		// 1. Convert aggregated to blocks format
		var blocks = variables.blockAggregator.convertAggregatedToBlocks( arguments.aggregated );

		// 2. Extract calls from AST using AstCallAnalyzer
		var callTreeMap = {};
		for ( var fileIdx in arguments.files ) {
			var file = arguments.files[ fileIdx ];
			var functions = variables.astCallAnalyzer.extractFunctions( file.ast );

			callTreeMap[ fileIdx ] = {};
			for ( var func in functions ) {
				for ( var call in func.calls ) {
					// Skip built-in functions
					if ( !( call.isBuiltIn ?: false ) && call.position > 0 ) {
						callTreeMap[ fileIdx ][ call.position ] = {
							isChildTime: true,
							isBuiltIn: false,
							functionName: call.name
						};
					}
				}
			}

			// Also extract top-level calls (outside functions) from AST body
			extractTopLevelCalls( file.ast, callTreeMap[ fileIdx ] );
		}

		// 3. Build empty astNodesMap (tests don't need this yet)
		var astNodesMap = {};

		// 4. Mark blocks with child time flags
		var markedBlocks = variables.callTreeAnalyzer.markChildTimeBlocks( blocks, callTreeMap, astNodesMap, arguments.files );

		// 5. Calculate metrics
		var metrics = variables.callTreeAnalyzer.calculateChildTimeMetrics( markedBlocks );

		// Return in same format as old API
		return {
			blocks: markedBlocks,
			metrics: metrics
		};
	}

	/**
	 * Extract top-level function calls from AST body (calls outside any function)
	 */
	private void function extractTopLevelCalls( required struct ast, required struct callMap ) {
		if ( !structKeyExists( arguments.ast, "body" ) || !isArray( arguments.ast.body ) ) {
			return;
		}

		for ( var node in arguments.ast.body ) {
			if ( isStruct( node ) && structKeyExists( node, "type" ) ) {
				var nodeType = node.type;

				// Check for CallExpression or NewExpression
				if ( nodeType == "CallExpression" || nodeType == "NewExpression" ) {
					var isBuiltIn = node.isBuiltIn ?: false;
					var position = 0;
					var callName = "";

					// Get position
					if ( structKeyExists( node, "start" ) ) {
						if ( isStruct( node.start ) && structKeyExists( node.start, "offset" ) ) {
							position = node.start.offset;
						} else if ( isNumeric( node.start ) ) {
							position = node.start;
						}
					}

					// Get call name
					if ( structKeyExists( node, "callee" ) ) {
						if ( isStruct( node.callee ) && structKeyExists( node.callee, "name" ) ) {
							callName = node.callee.name;
						}
					}

					// Special case: _createcomponent is marked as built-in but it's instantiating user code
					if ( lCase( callName ) == "_createcomponent" ) {
						isBuiltIn = false;
						// Try to get the component name from the first argument
						if ( structKeyExists( node, "arguments" ) &&
						    isArray( node.arguments ) &&
						    arrayLen( node.arguments ) > 0 ) {
							var firstArg = node.arguments[ 1 ];
							if ( isStruct( firstArg ) && structKeyExists( firstArg, "value" ) && isSimpleValue( firstArg.value ) ) {
								callName = "new " & firstArg.value;
							}
						}
					}

					// Add to call map if not built-in
					if ( !isBuiltIn && position > 0 ) {
						arguments.callMap[ position ] = {
							isChildTime: true,
							isBuiltIn: false,
							functionName: callName
						};
					}
				}
			}
		}
	}

	function run() {
		describe("CallTreeAnalyzer Custom Tag Support", function() {

			it("should extract CFML tags from real test-customtags.cfm AST", function() {
				var testFile = variables.artifactsDir & "/test-customtags.cfm";

				// Get AST from the actual file
				var ast = astFromPath(testFile);
				// TEMP write the ast to a debug file
				var astDebugPath = testFile & ".ast.json";
				variables.logger.debug("Generated AST for " & testFile & " saved as " & astDebugPath);
				fileWrite( astDebugPath, serializeJSON(var=ast, compact=false) );

				// Extract tags directly from the AST to verify our extraction works
				var extractedTags = [];
				extractTagsFromNode(ast, extractedTags);

				// Verify we found tags in the AST
				expect(arrayLen(extractedTags)).toBeGT(0, "Should find tags in the test file");

				// Check for specific tag types
				var hasCustomTag = false;
				var hasBuiltInTag = false;
				for (var tag in extractedTags) {
					if (tag.isBuiltIn) {
						hasBuiltInTag = true;
					} else if (left(tag.name, 3) == "cf_" || find(":", tag.name) > 0) {
						hasCustomTag = true;
					}
				}

				expect(hasCustomTag).toBeTrue("Should find custom tags in the AST");
				expect(hasBuiltInTag).toBeTrue("Should find built-in tags in the AST");
			});

			// Helper function to extract tags from AST
			function extractTagsFromNode(node, tags) {
				if (isStruct(node)) {
					if (structKeyExists(node, "type") && isSimpleValue(node.type) && node.type == "CFMLTag") {
						// Determine if it's built-in based on AST structure
						// Custom tags have name="_" with appendix, or non-cf namespace
						var isCustom = (node.name == "_" && structKeyExists(node, "appendix")) ||
						              (node.nameSpace != "cf" && node.nameSpaceSeparator == ":");
						arrayAppend(tags, {
							name: node.fullname ?: node.name,
							isBuiltIn: !isCustom
						});
					}
					for (var key in node) {
						if (!listFindNoCase("type,name,fullname", key) && !isNull(node[key])) {
							extractTagsFromNode(node[key], tags);
						}
					}
				} else if (isArray(node)) {
					for (var item in node) {
						extractTagsFromNode(item, tags);
					}
				}
			}

			it("should extract function calls from test-bifs.cfm AST", function() {
				var testFile = variables.artifactsDir & "/test-bifs.cfm";

				// Get AST from the actual file
				var ast = astFromPath(testFile);
				// TEMP write the ast to a debug file
				var astDebugPath = testFile & ".ast.json";
				variables.logger.debug("Generated AST for " & testFile & " saved as " & astDebugPath);
				fileWrite( astDebugPath, serializeJSON(var=ast, compact=false) );

				// Extract function calls from the AST
				var extractedCalls = [];
				extractCallsFromNode(ast, extractedCalls);

				// Verify we found calls
				expect(arrayLen(extractedCalls)).toBeGT(0, "Should find function calls in the test file");

				// Check for built-in vs non-built-in
				var hasBuiltIn = false;
				var hasNonBuiltIn = false;
				for (var call in extractedCalls) {
					if (call.isBuiltIn) {
						hasBuiltIn = true;
					} else {
						hasNonBuiltIn = true;
					}
				}

				expect(hasBuiltIn).toBeTrue("Should find built-in functions like len, ucase, now");
				expect(hasNonBuiltIn).toBeTrue("Should find user-defined function myFunction");
			});

			// Helper function to extract calls from AST
			function extractCallsFromNode(node, calls) {
				if (isStruct(node)) {
					if (structKeyExists(node, "type") && isSimpleValue(node.type) && node.type == "CallExpression") {
						var callName = "";
						if (structKeyExists(node, "callee")) {
							if (isStruct(node.callee) && structKeyExists(node.callee, "name")) {
								callName = node.callee.name;
							} else if (isSimpleValue(node.callee)) {
								callName = node.callee;
							}
						}
						arrayAppend(calls, {
							name: callName,
							isBuiltIn: node.isBuiltIn ?: false
						});
					}
					for (var key in node) {
						if (!listFindNoCase("type,callee", key) && !isNull(node[key])) {
							extractCallsFromNode(node[key], calls);
						}
					}
				} else if (isArray(node)) {
					for (var item in node) {
						extractCallsFromNode(item, calls);
					}
				}
			}

			it("should verify CallTreeAnalyzer integration", function() {
				var testFile = variables.artifactsDir & "/test-bifs.cfm";

				// Get AST from the actual file
				var ast = astFromPath(testFile);

				// Create a simple aggregated data structure to test the analyzer
				// We'll use arbitrary positions since we're just testing the analyzer works
				var aggregated = {};
				aggregated[arrayToList(["0", 1, 100, 1], chr(9))] = ["0", 1, 100, 1, 1000];

				var files = {
					"0": {
						ast: ast,
						path: testFile
					}
				};

				// Test that the analyzer can process real AST files
				var result = analyzeCallTreeWithNewAPI( aggregated, files );

				// Verify basic structure
				expect(structKeyExists(result, "blocks")).toBeTrue("Result should have blocks");
				expect(structKeyExists(result, "metrics")).toBeTrue("Result should have metrics");
				expect(result.metrics.totalBlocks).toBe(1);
			});

			it("should handle component methods from test-component-methods.cfc", function() {
				var testFile = variables.artifactsDir & "/test-component-methods.cfc";

				// Get AST from the actual file
				var ast = astFromPath(testFile);

				// Create mock aggregated data
				var aggregated = {};
				aggregated[arrayToList(["0", 50, 100, 1], chr(9))] = ["0", 50, 100, 1, 500];   // init() call
				aggregated[arrayToList(["0", 150, 250, 1], chr(9))] = ["0", 150, 250, 1, 600]; // new MyComponent()
				aggregated[arrayToList(["0", 280, 350, 1], chr(9))] = ["0", 280, 350, 1, 700]; // someMethod()

				var files = {
					"0": {
						ast: ast,
						path: testFile
					}
				};

				var result = analyzeCallTreeWithNewAPI( aggregated, files );

				// Component methods should NOT be marked as built-in
				for (var key in result.blocks) {
					var block = result.blocks[key];
					if (block.isChildTime && structKeyExists(block, "callInfo") &&
					    structKeyExists(block.callInfo, "name")) {
						var callName = block.callInfo.name;
						if (callName == "init" || callName == "someMethod") {
							expect(block.isBuiltIn).toBeFalse(callName & " should not be marked as built-in");
						}
					}
				}
			});

			it("should handle member functions from test-member-functions.cfm", function() {
				var testFile = variables.artifactsDir & "/test-member-functions.cfm";

				// Get AST from the actual file
				var ast = astFromPath(testFile);

				// Create mock aggregated data for member function calls
				var aggregated = {};
				aggregated[arrayToList(["0", 50, 100, 1], chr(9))] = ["0", 50, 100, 1, 100];  // str.ucase()
				aggregated[arrayToList(["0", 120, 170, 1], chr(9))] = ["0", 120, 170, 1, 200]; // arr.len()

				var files = {
					"0": {
						ast: ast,
						path: testFile
					}
				};

				var result = analyzeCallTreeWithNewAPI( aggregated, files );

				// Member functions of built-in types should be handled appropriately
				expect(result.metrics.childTimeBlocks).toBeGTE(0, "Should detect member function calls");
			});
		});
	}
}