/**
 * CallTreeAnalyzer - Analyzes execution blocks to identify child time
 *
 * This component:
 * - Identifies which execution blocks represent child time (time in called functions)
 * - Marks blocks that are function calls, especially built-in functions
 * - Provides simplified metrics focused on child time identification
 * - Works with position-based data from execution logs, not line numbers
 */
component {

	// Cache for per-file call extraction to avoid repeated AST analysis across .exl files
	variables.fileCallCache = {};

	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Analyzes execution blocks to identify which represent child time
	 * @aggregated The aggregated execution blocks (position-based format)
	 * @files File information including AST data
	 * @return Struct containing blocks marked as child time
	 */
	public struct function analyzeCallTree(required struct aggregated, required struct files) {
		var startTime = getTickCount();

		variables.logger.trace( "CallTreeAnalyzer: Starting analysis with " & structCount( arguments.aggregated ) & " blocks and " & structCount( arguments.files ) & " files" );

		// Create AST call analyzer instance
		var astCallAnalyzer = new AstCallAnalyzer( logger=variables.logger );
		var astStart = getTickCount();

		// Extract all function calls from AST for all files
		var callsMap = extractAllCalls( arguments.files, astCallAnalyzer );

		variables.logger.trace( "CallTreeAnalyzer: extractAllCalls completed in " & ( getTickCount() - astStart ) & "ms, found " & structCount( callsMap ) & " call positions" );

		// Mark blocks that represent child time (function calls)
		var markStart = getTickCount();
		var markedBlocks = markChildTimeBlocks( arguments.aggregated, callsMap );

		variables.logger.trace( "CallTreeAnalyzer: markChildTimeBlocks completed in " & ( getTickCount() - markStart ) & "ms" );

		var metricsStart = getTickCount();
		var metrics = calculateChildTimeMetrics( markedBlocks );

		variables.logger.trace( "CallTreeAnalyzer: calculateChildTimeMetrics completed in " & ( getTickCount() - metricsStart ) & "ms" );
		variables.logger.trace( "CallTreeAnalyzer: Total analysis time: " & ( getTickCount() - startTime ) & "ms" );

		return {
			blocks: markedBlocks,
			metrics: metrics
		};
	}

	/**
	 * Extract all function calls from AST data across all files
	 * @files File information including AST
	 * @astCallAnalyzer The AST call analyzer component
	 * @return Struct mapping call positions to call info
	 */
	private struct function extractAllCalls(required struct files, required any astCallAnalyzer) {
		var callsMap = {};
		var fileCount = 0;
		var totalFiles = structCount( arguments.files );
		var cacheHits = 0;
		var cacheMisses = 0;

		variables.logger.trace( "extractAllCalls: Processing " & totalFiles & " files" );

		for ( var fileIdx in arguments.files ) {
			var file = arguments.files[ fileIdx ];
			fileCount++;

t		// Fail fast if no AST available
			if ( !structKeyExists( file, "ast" ) || !isStruct( file.ast ) ) {
				var filePath = structKeyExists( file, "path" ) ? file.path : "unknown file (fileIdx: " & fileIdx & ")";
				throw( type="MissingAST", message="No AST available for file: " & filePath );
			}

			var filePath = structKeyExists( file, "path" ) ? file.path : fileIdx;
			var fileStart = getTickCount();
			var fileCalls = [];

			// Check cache first (only use cache if we have a real file path)
			if ( structKeyExists( file, "path" ) && structKeyExists( variables.fileCallCache, filePath ) ) {
				fileCalls = variables.fileCallCache[ filePath ];
				cacheHits++;
			} else {
				// Cache miss - extract calls from AST
				cacheMisses++;

				// Extract all functions to get their calls
				var functions = arguments.astCallAnalyzer.extractFunctions(file.ast);

				// Collect all calls from all functions (excluding built-in functions)
				for (var func in functions) {
					if (structKeyExists(func, "calls") && isArray(func.calls)) {
						for (var call in func.calls) {
							// Skip built-in functions - they're part of normal execution, not child time
							var isBuiltIn = structKeyExists(call, "isBuiltIn") ? call.isBuiltIn : false;
							if (!isBuiltIn && structKeyExists(call, "position") && call.position > 0) {
								arrayAppend(fileCalls, {
									position: call.position,
									type: call.type,
									name: call.name,
									isBuiltIn: false
								});
							}
						}
					}
				}

				// Also extract CFML tags and top-level function calls directly from the AST body
				extractCFMLTagsAndCalls(file.ast, fileCalls);

				// Store in cache (only if we have a real file path)
				if (structKeyExists(file, "path")) {
					variables.fileCallCache[filePath] = fileCalls;
				}
			}

			// Add file calls to callsMap with current fileIdx
			for (var call in fileCalls) {
				var key = arrayToList([fileIdx, call.position], chr(9));
				callsMap[key] = {
					fileIdx: fileIdx,
					position: call.position,
					type: call.type,
					name: call.name,
					isBuiltIn: call.isBuiltIn
				};
			}
		}

		return callsMap;
	}


	/**
	 * Extract CFML tags and function calls from AST nodes
	 */
	private void function extractCFMLTagsAndCalls(required any node, required array fileCalls) {
		if (isStruct(arguments.node)) {
			// Check if this is a CFML tag
			if (structKeyExists(arguments.node, "type")) {
				var nodeType = arguments.node.type;

				// Ensure nodeType is a string
				if (!isSimpleValue(nodeType)) {
					nodeType = "";
				}

				// Check for function calls (CallExpression) - only track user-defined functions
				if (nodeType == "CallExpression") {
					// Skip built-in functions - they're part of normal execution, not child time
					var isBuiltIn = arguments.node.isBuiltIn ?: false;

					var position = 0;
					if (structKeyExists(arguments.node, "start")) {
						if (isStruct(arguments.node.start) && structKeyExists(arguments.node.start, "offset")) {
							position = arguments.node.start.offset;
						} else if (isNumeric(arguments.node.start)) {
							position = arguments.node.start;
						}
					}

					var callName = "";
					if (structKeyExists(arguments.node, "callee")) {
						if (isStruct(arguments.node.callee) && structKeyExists(arguments.node.callee, "name")) {
							callName = arguments.node.callee.name;
						}
					}

					// Special case: _createcomponent is marked as built-in but it's instantiating user code
					if (lCase(callName) == "_createcomponent") {
						isBuiltIn = false;
						// Try to get the component name from the first argument
						if (structKeyExists(arguments.node, "arguments") &&
						    isArray(arguments.node.arguments) &&
						    arrayLen(arguments.node.arguments) > 0) {
							var firstArg = arguments.node.arguments[1];
							if (isStruct(firstArg) && structKeyExists(firstArg, "value")) {
								callName = "new " & firstArg.value;
							}
						}
					}

					if (!isBuiltIn && position > 0) {
						arrayAppend(arguments.fileCalls, {
							position: position,
							type: "CallExpression",
							name: callName,
							isBuiltIn: false
						});
					}
				}
				// Check for CFML tags
				else if (nodeType == "CFMLTag") {
					// should we fall back here to an empty string?
					var fullName = arguments.node.fullname ?: (arguments.node.name ?: "");

					// Check if this is a custom tag or a call-type tag
					var isCustomTag = left(fullName, 3) == "cf_" || find(":", fullName) > 0;
					var tagName = arguments.node.name ?: "";
					// Support both cf-prefixed and script-style tags
					var isCallTag = listFindNoCase("include,cfinclude,module,cfmodule,invoke,cfinvoke,import,cfimport", tagName) > 0;

					if (isCustomTag || isCallTag) {
						// Get position
						var position = 0;
						if (structKeyExists(arguments.node, "start")) {
							if (isStruct(arguments.node.start) && structKeyExists(arguments.node.start, "offset")) {
								position = arguments.node.start.offset;
							} else if (isNumeric(arguments.node.start)) {
								position = arguments.node.start;
							}
						}

						if (position > 0) {
							arrayAppend(arguments.fileCalls, {
								position: position,
								type: "CFMLTag",
								name: fullName,
								tagName: tagName,
								isBuiltIn: arguments.node.isBuiltIn ?: false
							});
						}
					}
				}
			}

			// Recursively search children
			for (var key in arguments.node) {
				if (!listFindNoCase("type,name,fullname,start,end", key) && !isNull(arguments.node[key])) {
					extractCFMLTagsAndCalls(arguments.node[key], arguments.fileCalls);
				}
			}
		}
		else if (isArray(arguments.node)) {
			for (var item in arguments.node) {
				extractCFMLTagsAndCalls(item, arguments.fileCalls);
			}
		}
	}

	/**
	 * Mark execution blocks that represent child time (function calls)
	 */
	private struct function markChildTimeBlocks(required struct aggregated, required struct callsMap) {
		var markedBlocks = {};

		for (var blockKey in arguments.aggregated) {
			// The aggregated value is an array: [fileIdx, startPos, endPos, count, totalTime]
			var blockData = arguments.aggregated[blockKey];

			// Validate array format: [fileIdx, startPos, endPos, count, totalTime]
			if (!isArray(blockData) || arrayLen(blockData) != 5) {
				throw "Aggregated block must be array with exactly 5 elements [fileIdx, startPos, endPos, count, totalTime], got: " & serializeJSON(blockData);
			}

			var fileIdx = blockData[1];
			var startPos = blockData[2];
			var endPos = blockData[3];
			var count = blockData[4];
			var executionTime = blockData[5];  // Total execution time is at index 5

			// Check if this block matches a function call position
			var isChildTime = false;
			var isBuiltIn = false;

			// Look for calls that overlap with this block
			for (var callKey in arguments.callsMap) {
				var call = arguments.callsMap[callKey];
				if (call.fileIdx == fileIdx &&
				    call.position >= startPos &&
				    call.position <= endPos) {
					isChildTime = true;
					isBuiltIn = call.isBuiltIn ?: false;
					break;
				}
			}

			// Store marked block
			markedBlocks[blockKey] = {
				"fileIdx": fileIdx,
				"startPos": startPos,
				"endPos": endPos,
				"count": count,
				"executionTime": executionTime,
				"isChildTime": isChildTime,
				"isBuiltIn": isBuiltIn
			};
		}

		return markedBlocks;
	}

	/**
	 * Calculate metrics based on child time blocks
	 */
	private struct function calculateChildTimeMetrics(required struct markedBlocks) {
		var metrics = {
			"totalBlocks": structCount(arguments.markedBlocks),
			"childTimeBlocks": 0,
			"builtInBlocks": 0
		};

		for (var blockKey in arguments.markedBlocks) {
			var block = arguments.markedBlocks[blockKey];

			if (block.isChildTime) {
				metrics.childTimeBlocks++;

				if (block.isBuiltIn) {
					metrics.builtInBlocks++;
				}
			}
		}

		return metrics;
	}

	/**
	 * Get summary metrics for marked blocks
	 */
	public struct function getCallTreeMetrics(required struct result) {
		if (!structKeyExists(arguments.result, "blocks") ||
		    !structKeyExists(arguments.result, "metrics")) {
			return {
				"totalBlocks": 0,
				"childTimeBlocks": 0,
				"builtInBlocks": 0
			};
		}

		return arguments.result.metrics;
	}
}