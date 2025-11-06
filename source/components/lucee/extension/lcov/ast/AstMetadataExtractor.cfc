/**
 * Extracts metadata from AST for caching.
 *
 * Performs ONE AST traversal to extract:
 * 1. CallTree positions (function call locations)
 * 2. Executable line counts (which lines have executable code)
 *
 * This avoids duplicate AST parsing - both extractions happen in one pass.
 */
component {

	property name="logger";
	property name="astCallAnalyzer";
	property name="executableLineCounter";
	property name="astParserHelper";

	/**
	 * @logger Logger instance (optional)
	 */
	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( logLevel="ERROR" );
		variables.astCallAnalyzer = new lucee.extension.lcov.ast.AstCallAnalyzer( logger=variables.logger );
		variables.executableLineCounter = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );
		variables.astParserHelper = new lucee.extension.lcov.parser.AstParserHelper( logger=variables.logger );
		variables.callTreeHelper = new lucee.extension.lcov.ast.CallTreeParallelHelpers();
		return this;
	}

	/**
	 * Extract all metadata from AST (CallTree + executable lines + node types).
	 *
	 * @ast The parsed AST object
	 * @filePath The file path (for logging/debugging)
	 * @return Struct with {callTree, executableLineCount, executableLines, astNodes}
	 */
	public struct function extractMetadata(required any ast, required string filePath) localmode=true {
		var startTime = getTickCount();

		// 1. Extract CallTree positions using AstCallAnalyzer
		var functions = variables.astCallAnalyzer.extractFunctions( arguments.ast );
		var callTree = structNew( "regular" );

		// Extract all calls from all functions
		// Key by position only (no fileIdx yet - that's determined per-request in annotateCallTree)
		cfloop( array=functions, item="local.func" ) {
			// Add calls from this function's body
			if ( structKeyExists( func, "calls" ) && isArray( func.calls ) ) {
				cfloop( array=func.calls, item="local.call" ) {
					if ( structKeyExists( call, "position" ) ) {
						// Skip built-in functions - they are own time, not child time
						// UDFs = child time (execution goes into user code)
						// BIFs = own time (execute directly, no user code to traverse)
						var isBuiltIn = call.isBuiltIn ?: false;
						if ( !isBuiltIn ) {
							// Store by position only - CallTreeAnnotator will add fileIdx prefix in annotateCallTree
							var key = call.position;
							callTree[key] = {
								"isChildTime": true,
								"isBuiltIn": false,
								"functionName": call.name ?: "",
								"astNodeType": call.type ?: "CallExpression",
								"isBlock": false  // Calls are executable, not blocks
							};
						}
					}
				}
			}
		}

		// 1b. ALSO extract top-level calls from AST body (for .cfm files and top-level scripts)
		// This is essential for .cfm files which have code at the root level, not in functions
		var topLevelCalls = [];
		variables.callTreeHelper.extractCFMLTagsAndCalls( arguments.ast, topLevelCalls );

		// Add top-level calls to callTree
		cfloop( array=topLevelCalls, item="local.call" ) {
			if ( structKeyExists( call, "position" ) && call.position > 0 ) {
				// Skip built-in functions - they are own time, not child time
				var isBuiltIn = call.isBuiltIn ?: false;
				if ( !isBuiltIn ) {
					callTree[call.position] = {
						"isChildTime": true,
						"isBuiltIn": false,
						"functionName": call.name ?: "",
						"astNodeType": call.type ?: "CallExpression",
						"isBlock": false  // Calls are executable, not blocks
					};
				}
			}
		}

		// 1c. Extract ALL AST nodes with position data for block enrichment
		var astNodes = extractAllAstNodes( arguments.ast );

		// 2. Extract executable lines using ExecutableLineCounter
		var lineInfo = variables.executableLineCounter.countExecutableLinesFromAst( arguments.ast );

		var elapsedTime = getTickCount() - startTime;
		variables.logger.debug( "Extracted metadata for [#arguments.filePath#] in #elapsedTime#ms: #structCount(callTree)# call positions, #structCount(astNodes)# AST nodes, #lineInfo.count# executable lines" );

		return {
			"callTree": callTree,
			"executableLineCount": lineInfo.count,
			"executableLines": lineInfo.executableLines,
			"astNodes": astNodes
		};
	}

	/**
	 * Extract ALL AST nodes with position and type information.
	 * This includes both container blocks and executable blocks.
	 *
	 * @ast The parsed AST object
	 * @return Struct keyed by "startPos-endPos" with node metadata
	 */
	private struct function extractAllAstNodes(required any ast) localmode=true {
		var nodes = structNew( "regular" );
		var blockTypes = [
			"CFMLTag",
			"Program",
			"BlockStatement",
			"FunctionDeclaration",
			"IfStatement",
			"ForStatement",
			"ForOfStatement",
			"WhileStatement",
			"DoWhileStatement",
			"SwitchStatement",
			"TryStatement"
		];

		traverseAstNodes( arguments.ast, nodes, blockTypes );

		return nodes;
	}

	/**
	 * Recursively traverse AST and extract node information.
	 *
	 * @node Current AST node
	 * @nodes Output struct to populate
	 * @blockTypes List of node types that are blocks (contain child blocks)
	 */
	private void function traverseAstNodes(
		required any node,
		required struct nodes,
		required array blockTypes
	) {
		if ( isStruct( arguments.node ) ) {
			// Extract position and type if available
			if ( structKeyExists( arguments.node, "type" ) &&
			     structKeyExists( arguments.node, "start" ) &&
			     structKeyExists( arguments.node, "end" ) ) {

				var nodeType = arguments.node.type;
				if ( !isSimpleValue( nodeType ) ) {
					nodeType = "";
				}

				// Get positions
				var startPos = isStruct( arguments.node.start ) ?
					arguments.node.start.offset :
					arguments.node.start;
				var endPos = isStruct( arguments.node.end ) ?
					arguments.node.end.offset :
					arguments.node.end;

				// Only store if we have valid positions
				if ( startPos > 0 && endPos > startPos ) {
					var key = startPos & "-" & endPos;
					var isBlock = arrayContains( arguments.blockTypes, nodeType ) > 0;

					// Extract tag name for CFMLTag nodes
					var tagName = "";
					if ( nodeType == "CFMLTag" && structKeyExists( arguments.node, "name" ) ) {
						tagName = arguments.node.name;

						// CFMLTag is only a block if it has a body (e.g. cfloop, cfif with braces)
						// Tags without bodies (cfinclude, cfset, cfparam) are NOT blocks
						if ( isBlock && !structKeyExists( arguments.node, "body" ) ) {
							isBlock = false;
						}
					}

					// Control structures (IfStatement, ForStatement, etc.) are only blocks if they have braces
					// If-with-braces has consequent.type == "BlockStatement"  
					// If-without-braces has consequent.type == "CallExpression" or other single statement
					if ( isBlock && nodeType == "IfStatement" && structKeyExists( arguments.node, "consequent" ) ) {
						var consequentType = isStruct( arguments.node.consequent ) && structKeyExists( arguments.node.consequent, "type" ) ?
							arguments.node.consequent.type : "";
						if ( consequentType != "BlockStatement" ) {
							isBlock = false;
						}
					}

					arguments.nodes[key] = {
						"astNodeType": nodeType,
						"isBlock": isBlock,
						"startPos": startPos,
						"endPos": endPos,
						"tagName": tagName					
					};
				}
			}

			// Recursively traverse all child nodes
			cfloop( collection=arguments.node, key="local.key" ) {
				if ( !isNull( arguments.node[key] ) ) {
					traverseAstNodes( arguments.node[key], arguments.nodes, arguments.blockTypes );
				}
			}
		}
		else if ( isArray( arguments.node ) ) {
			cfloop( array=arguments.node, item="local.item" ) {
				traverseAstNodes( item, arguments.nodes, arguments.blockTypes );
			}
		}
	}

	/**
	 * Extract metadata for multiple files (batch processing).
	 *
	 * @files Struct of {fileIdx: {path: "..."}} or array of file paths
	 * @return Struct keyed by file path with metadata for each
	 */
	public struct function extractMetadataForFiles(required any files) localmode=true {
		var metadata = structNew( "regular" );
		var filePaths = [];

		// Normalize input to array of paths
		if ( isStruct( arguments.files ) ) {
			cfloop( collection=arguments.files, key="local.idx", value="local.fileData" ) {
				arrayAppend( filePaths, fileData.path );
			}
		} else if ( isArray( arguments.files ) ) {
			filePaths = arguments.files;
		} else {
			throw( type="AstMetadataExtractor.InvalidInput", message="files must be struct or array" );
		}

		// Extract metadata for each unique file
		cfloop( array=filePaths, item="local.filePath" ) {
			if ( !fileExists( filePath ) ) {
				variables.logger.warn( "Skipping metadata extraction for missing file: #filePath#" );
				continue;
			}

			// Parse AST using AstParserHelper (has fallback logic for .cfm files)
			var ast = variables.astParserHelper.parseFileAst( filePath, fileRead( filePath ) );
			metadata[filePath] = extractMetadata( ast, filePath );
		}

		return metadata;
	}

}
