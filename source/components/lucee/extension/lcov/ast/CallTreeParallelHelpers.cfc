/**
 * CallTreeParallelHelpers - Helper functions for parallel call tree processing
 *
 * This component contains methods used by CallTreeAnalyzer for parallel execution.
 * Separated to keep CallTreeAnalyzer cleaner and focused on orchestration.
 */
component {

	// Constants for tag checking - using arrays for fast lookups
	variables.CALL_TAGS = [ "include", "cfinclude", "module", "cfmodule", "invoke", "cfinvoke", "import", "cfimport" ];
	variables.SKIP_KEYS = [ "type", "name", "fullname", "start", "end" ];

	/**
	 * Process a single file to extract calls - for parallel execution
	 * fileInfo is: [fileIdx, file, filePath, cached, fileCalls, astCallAnalyzer, helper]
	 */
	public function processFileForCalls( required array fileInfo ) localmode=true {
		var fileIdx = fileInfo[ 1 ];
		var file = fileInfo[ 2 ];
		var filePath = fileInfo[ 3 ];
		var wasCached = fileInfo[ 4 ];
		var fileCalls = fileInfo[ 5 ];
		var astCallAnalyzer = fileInfo[ 6 ];
		var helper = fileInfo[ 7 ];

		// If already cached, just return it
		if ( wasCached ) {
			return {
				fileIdx: fileIdx,
				filePath: filePath,
				calls: fileCalls,
				wasCached: true,
				hasPath: structKeyExists( file, "path" )
			};
		}

		// Cache miss - extract calls from AST
		fileCalls = [];

		// Extract all functions to get their calls
		var functions = astCallAnalyzer.extractFunctions( file.ast );

		// Collect all calls from all functions (excluding built-in functions)
		cfloop( array=functions, item="local.func" ) {
			cfloop( array=func.calls, item="local.call" ) {
				// Skip built-in functions - they're part of normal execution, not child time
				if ( !( call.isBuiltIn ?: false ) && call.position > 0 ) {
					arrayAppend( fileCalls, {
						position: call.position,
						type: call.type,
						name: call.name,
						isBuiltIn: false
					} );
				}
			}
		}

		// Also extract CFML tags and top-level function calls directly from the AST body
		helper.extractCFMLTagsAndCalls( file.ast, fileCalls );

		return {
			fileIdx: fileIdx,
			filePath: filePath,
			calls: fileCalls,
			wasCached: false,
			hasPath: structKeyExists( file, "path" )
		};
	}

	/**
	 * Process a chunk of blocks - for parallel execution
	 * chunkInfo is: [blocks array, callsMap]
	 * callsMap is nested: {fileIdx: {position: {isChildTime, isBuiltIn, functionName}}}
	 */
	public function processBlockChunk( required array chunkInfo ) localmode=true {
		var blocks = chunkInfo[ 1 ];
		var callsMap = chunkInfo[ 2 ];
		var result = structNew( "regular" );

		cfloop( array=blocks, item="local.blockInfo" ) {
			var blockKey = blockInfo[ 1 ];
			var blockData = blockInfo[ 2 ];

			// Validate array format: [fileIdx, startPos, endPos, count, totalTime]
			if ( !isArray( blockData ) || arrayLen( blockData ) != 5 ) {
				throw "Aggregated block must be array with exactly 5 elements [fileIdx, startPos, endPos, count, totalTime], got: " & serializeJSON( blockData );
			}

			var fileIdx = blockData[ 1 ];
			var startPos = blockData[ 2 ];
			var endPos = blockData[ 3 ];
			var count = blockData[ 4 ];
			var executionTime = blockData[ 5 ];

			// Check if this block matches a function call position
			var isChildTime = false;
			var isBuiltIn = false;

			// Check calls from this file using nested struct lookup
			var fileCalls = callsMap[ fileIdx ] ?: {};
			cfloop( collection=fileCalls, key="local.position" ) {
				if ( position >= startPos && position <= endPos ) {
					var callInfo = fileCalls[ position ];
					isChildTime = callInfo.isChildTime ?: true;
					isBuiltIn = callInfo.isBuiltIn ?: false;
					break;
				}
			}

			// Store in chunk result
			result[ blockKey ] = {
				"fileIdx": fileIdx,
				"startPos": startPos,
				"endPos": endPos,
				"count": count,
				"executionTime": executionTime,
				"isChildTime": isChildTime,
				"isBuiltIn": isBuiltIn
			};
		}

		return result;
	}

	/**
	 * Extract CFML tags and function calls from AST nodes - for parallel execution
	 */
	public void function extractCFMLTagsAndCalls( required any node, required array fileCalls ) localmode=true {
		var node = arguments.node;
		var fileCalls = arguments.fileCalls;

		if ( isStruct( node ) ) {
			// Check if this is a CFML tag
			if ( structKeyExists( node, "type" ) ) {
				var nodeType = node.type;

				// Ensure nodeType is a string
				if ( !isSimpleValue( nodeType ) ) {
					nodeType = "";
				}

				// Check for function calls (CallExpression) - only track user-defined functions
				if ( nodeType === "CallExpression" ) {
					// Skip built-in functions - they're part of normal execution, not child time
					var isBuiltIn = node.isBuiltIn ?: false;

					var position = 0;
					if ( structKeyExists( node, "start" ) ) {
						if ( isStruct( node.start ) && structKeyExists( node.start, "offset" ) ) {
							position = node.start.offset;
						} else if ( isNumeric( node.start ) ) {
							position = node.start;
						}
					}

					var callName = "";
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

					if ( !isBuiltIn && position > 0 ) {
						arrayAppend( fileCalls, {
							position: position,
							type: "CallExpression",
							name: callName,
							isBuiltIn: false
						} );
					}
				}
				// Check for CFML tags
				else if ( nodeType === "CFMLTag" ) {
					var tagName = node.name ?: "";
					var fullName = node.fullname ?: tagName;
					// Check array first - most common case (include, module, invoke, etc)
					var isCallTag = arrayContains( variables.CALL_TAGS, tagName );

					// Only do string processing if not already a call tag
					if ( !isCallTag ) {
						isCallTag = left( fullName, 3 ) === "cf_" || find( ":", fullName ) > 0;
					}

					if ( isCallTag ) {
						// Get position
						var position = 0;
						if ( structKeyExists( node, "start" ) ) {
							if ( isStruct( node.start ) && structKeyExists( node.start, "offset" ) ) {
								position = node.start.offset;
							} else if ( isNumeric( node.start ) ) {
								position = node.start;
							}
						}

						if ( position > 0 ) {
							arrayAppend( fileCalls, {
								position: position,
								type: "CFMLTag",
								name: fullName,
								tagName: tagName,
								isBuiltIn: node.isBuiltIn ?: false
							} );
						}
					}
				}
			}

			// Recursively search children
			cfloop( collection=node, key="local.key" ) {
				if ( !arrayContains( variables.SKIP_KEYS, key ) && !isNull( node[ key ] ) ) {
					this.extractCFMLTagsAndCalls( node[ key ], fileCalls );
				}
			}
		}
		else if ( isArray( node ) ) {
			cfloop( array=node, item="local.item" ) {
				this.extractCFMLTagsAndCalls( item, fileCalls );
			}
		}
	}
}
