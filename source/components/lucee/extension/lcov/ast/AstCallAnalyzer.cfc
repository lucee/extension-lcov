/**
 * AstCallAnalyzer - Analyzes AST to extract function definitions and call sites
 *
 * This component analyzes Lucee's AST structure to identify:
 * - Function definitions and their boundaries
 * - Function call expressions (UDFs and BIFs)
 * - CFML tag invocations (include, module, invoke)
 * - Built-in vs user-defined distinctions via isBuiltIn flag
 *
 * Used by CallTreeAnalyzer to determine which execution blocks contain
 * function calls (child time) vs pure computation (own time).
 */
component {

	// Constants for tag checking - using arrays for fast lookups
	variables.CALL_TAGS = [ "include", "cfinclude", "module", "cfmodule", "invoke", "cfinvoke", "import", "cfimport" ];
	variables.SKIP_KEYS_TRAVERSE = [ "type", "name", "start", "end", "line" ];
	variables.SKIP_KEYS_EXTRACT = [ "type", "name", "start", "end" ];

	/**
	 * @logger Logger - Logger instance
	 */
	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Extract all function definitions from an AST
	 * @ast The abstract syntax tree from Lucee
	 * @return Array of function information structs
	 */
	public array function extractFunctions(required struct ast) localmode=true {
		var functions = [];

		if (structKeyExists(arguments.ast, "body")) {
			traverseForFunctions(arguments.ast.body, functions, "");
		}

		return functions;
	}

	/**
	 * Traverse AST nodes looking for function definitions
	 */
	private void function traverseForFunctions(
		required any node,
		required array functions,
		required string parentScope
	) {
		if (isStruct(arguments.node)) {
			// Check node type for function-like structures
			if (structKeyExists(arguments.node, "type")) {
				var nodeType = arguments.node.type;

				// Ensure nodeType is a string for comparison
				if (!isSimpleValue(nodeType)) {
					nodeType = "";
				}

////variables.logger.trace("traverseForFunctions: nodeType=" & nodeType);
				// Handle different function definition patterns
				if (nodeType === "FunctionDeclaration" ||
				    nodeType === "FunctionExpression" ||
				    nodeType === "function") {

					var funcInfo = extractFunctionInfo(arguments.node, arguments.parentScope);
					arrayAppend(arguments.functions, funcInfo);

					// Recursively check function body for nested functions
					if (structKeyExists(arguments.node, "body")) {
						traverseForFunctions(
							arguments.node.body,
							arguments.functions,
							funcInfo.name
						);
					}
					return; // Don't traverse further - we already handled the body
				}
				// Component methods
				else if (nodeType === "component" && structKeyExists(arguments.node, "body")) {
					var componentName = arguments.node.name ?: "Component";

					cfloop( array=arguments.node.body, item="local.member" ) {
						if (isStruct(member) && structKeyExists(member, "type") &&
						    (member.type === "function" || member.type === "FunctionDeclaration")) {

							var methodInfo = extractFunctionInfo(member, componentName);
							arrayAppend(arguments.functions, methodInfo);

							// Check method body for nested functions
							if (structKeyExists(member, "body")) {
								traverseForFunctions(
									member.body,
									arguments.functions,
									methodInfo.name
								);
							}
						}
					}
					return; // Don't traverse further - we already handled component members
				}
			}

			// Recursively traverse all child nodes
			cfloop( collection=arguments.node, key="local.key" ) {
				if (!arrayContains(variables.SKIP_KEYS_TRAVERSE, key)) {
					// Skip null values (e.g., ReturnStatement with no argument)
					if (!isNull(arguments.node[key])) {
						traverseForFunctions(
							arguments.node[key],
							arguments.functions,
							arguments.parentScope
						);
					}
				}
			}
		}
		else if (isArray(arguments.node)) {
			cfloop( array=arguments.node, item="local.item" ) {
				traverseForFunctions(item, arguments.functions, arguments.parentScope);
			}
		}
	}

	/**
	 * Extract detailed information from a function node
	 */
	private struct function extractFunctionInfo(required struct functionNode, required string parentScope) localmode=true {
		var info = {
			name: "",
			fullName: "",
			parentScope: arguments.parentScope,
			startPos: 0,
			endPos: 0,
			startLine: 0,
			endLine: 0,
			calls: [],
			parameters: [],
			isPublic: true,
			returnType: "any"
		};

		// Get function name
		if (structKeyExists(arguments.functionNode, "name")) {
			// Ensure name is a string - AST might have it as a struct
			if (isSimpleValue(arguments.functionNode.name)) {
				info.name = arguments.functionNode.name;
			} else if (isStruct(arguments.functionNode.name) && structKeyExists(arguments.functionNode.name, "value")) {
				// AST has name as {"type":"StringLiteral","value":"method","raw":"\"method\""}
				info.name = arguments.functionNode.name.value;
			} else if (isStruct(arguments.functionNode.name) && structKeyExists(arguments.functionNode.name, "name")) {
				info.name = arguments.functionNode.name.name;
			} else {
				info.name = "anonymous";
			}
		} else if (structKeyExists(arguments.functionNode, "id") &&
					isStruct(arguments.functionNode.id) &&
					structKeyExists(arguments.functionNode.id, "name")) {
			info.name = arguments.functionNode.id.name;
		} else {
			info.name = "anonymous";
		}

		// Build full name with scope
		info.fullName = len(arguments.parentScope) ?
			arguments.parentScope & "." & info.name :
			info.name;

		// Get position information
		if (structKeyExists(arguments.functionNode, "start")) {
			if (isStruct(arguments.functionNode.start)) {
				info.startPos = arguments.functionNode.start.offset;
				info.startLine = arguments.functionNode.start.line;
			} else {
				info.startPos = arguments.functionNode.start;
			}
		}

		if (structKeyExists(arguments.functionNode, "end")) {
			if (isStruct(arguments.functionNode.end)) {
				info.endPos = arguments.functionNode.end.offset;
				info.endLine = arguments.functionNode.end.line;
			} else {
				info.endPos = arguments.functionNode.end;
			}
		}

		// Get access modifier
		if (structKeyExists(arguments.functionNode, "access")) {
			info.isPublic = arguments.functionNode.access !== "private";
		}

		// Get return type if specified
		if (structKeyExists(arguments.functionNode, "returnType")) {
			info.returnType = arguments.functionNode.returnType;
		}

		// Extract parameters
		if (structKeyExists(arguments.functionNode, "params") && isArray(arguments.functionNode.params)) {
			cfloop( array=arguments.functionNode.params, item="local.param" ) {
				arrayAppend(info.parameters, {
					name: param.name ?: "unnamed",
					type: param.type ?: "any",
					required: param.required ?: false
				});
			}
		}

		// Find function calls within this function
		if (structKeyExists(arguments.functionNode, "body")) {
			findCallsRecursive(arguments.functionNode.body, info.calls);
		}

		return info;
	}

	/**
	 * Recursively find call expressions
	 */
	private void function findCallsRecursive(required any node, required array calls) localmode=true {
		var node = arguments.node;  // Cache for performance
		var calls = arguments.calls;

		if (isStruct(node)) {
			if (structKeyExists(node, "type")) {
				var nodeType = node.type;

				// Ensure nodeType is a string for comparison
				if (!isSimpleValue(nodeType)) {
					nodeType = "";
				}

				// Different types of function calls
				// NOTE: MemberExpression is NOT a call - it's property access (e.g., obj.property)
				// CallExpression handles method calls where callee is a MemberExpression (e.g., obj.method())
				if (nodeType === "CallExpression" ||
				    nodeType === "NewExpression" ||
				    nodeType === "TaggedTemplateExpression") {

					var callName = extractCallName(node);
					//variables.logger.trace("findCallsRecursive: found " & nodeType & ", name=" & callName);
					var callInfo = {
						type: nodeType,
						name: callName,
						line: 0,
						position: 0,
						isBuiltIn: node.isBuiltIn ?: false
					};

					// Special case: _createcomponent is marked as built-in but it's instantiating user code
					if (lCase(callName) === "_createcomponent") {
						callInfo.isBuiltIn = false;
						// Try to get the component name from the first argument
						if (structKeyExists(node, "arguments") &&
						    isArray(node.arguments) &&
						    arrayLen(node.arguments) > 0) {
							var firstArg = node.arguments[1];
							if (isStruct(firstArg) && structKeyExists(firstArg, "value") && isSimpleValue(firstArg.value)) {
								callInfo.name = "new " & firstArg.value;
							}
						}
					}

					// Get position
					if (structKeyExists(node, "start")) {
						if (isStruct(node.start)) {
							callInfo.position = node.start.offset;
							callInfo.line = node.start.line;
						} else {
							callInfo.position = node.start;
						}
					} else if (structKeyExists(node, "line")) {
						callInfo.line = node.line;
					}

					arrayAppend(calls, callInfo);
				}
				// Handle CFML tags (includes, modules, custom tags)
				else if (nodeType === "CFMLTag") {
					var tagName = node.name ?: "";
					var fullName = node.fullname ?: tagName;

					// Track all CFML tags that represent function/module calls
					var callInfo = {
						type: "CFMLTag",
						name: fullName,
						tagName: tagName,
						line: 0,
						position: 0,
						isBuiltIn: node.isBuiltIn ?: false
					};

					// Extract the target (template, name, component, etc.) for specific tags
					if (structKeyExists(node, "attributes") && isArray(node.attributes)) {
						cfloop( array=node.attributes, item="local.attr" ) {
							if (isStruct(attr) && structKeyExists(attr, "name")) {
								if (attr.name === "template" || attr.name === "name" || attr.name === "component") {
									// attr.value might be a struct (complex expression) - only use if simple string
									var attrValue = attr.value ?: "";
									callInfo.target = isSimpleValue( attrValue ) ? attrValue : "";
									if (len(callInfo.target)) {
										callInfo.name = fullName & ":" & callInfo.target;
									}
									break;
								}
							}
						}
					}

					// Get position
					if (structKeyExists(node, "start")) {
						if (isStruct(node.start)) {
							callInfo.position = node.start.offset;
							callInfo.line = node.start.line;
						} else {
							callInfo.position = node.start;
						}
					}

					// Only add tags that could represent child time (function/module calls)
					// Skip pure structural tags like cfset, cfif, etc. unless they're custom tags
					var isCustomTag = left(fullName, 3) === "cf_" || find(":", fullName) > 0;
					var isCallTag = arrayContains(variables.CALL_TAGS, tagName);

					if (isCustomTag || isCallTag) {
						arrayAppend(calls, callInfo);
					}
				}
				// Handle dynamic invocations and closures
				else if (nodeType === "ClosureExpression" || nodeType === "LambdaExpression") {
					// Track anonymous function definitions as they might be called
					var callInfo = {
						type: nodeType,
						name: nodeType === "ClosureExpression" ? "closure" : "lambda",
						line: 0,
						position: 0,
						isBuiltIn: false  // Closures and lambdas are always user code
					};

					// Get position
					if (structKeyExists(node, "start")) {
						if (isStruct(node.start)) {
							callInfo.position = node.start.offset;
							callInfo.line = node.start.line;
						} else {
							callInfo.position = node.start;
						}
					}

					arrayAppend(calls, callInfo);
				}
			}

			// Traverse children
			cfloop( collection=node, key="local.key" ) {
				if (!arrayContains(variables.SKIP_KEYS_EXTRACT, key) && !isNull(node[key])) {
					findCallsRecursive(node[key], calls);
				}
			}
		}
		else if (isArray(node)) {
			cfloop( array=node, item="local.item" ) {
				findCallsRecursive(item, calls);
			}
		}
	}

	/**
	 * Extract the name of the function being called
	 */
	private string function extractCallName(required struct callNode) localmode=true {
		var callNode = arguments.callNode;  // Cache for performance

		// Direct function call
		if (structKeyExists(callNode, "callee")) {
			var callee = callNode.callee;  // Cache - accessed 12 times

			if (isSimpleValue(callee)) {
				return callee;
			}
			else if (isStruct(callee)) {
				// Named function
				if (structKeyExists(callee, "name") && isSimpleValue(callee.name)) {
					return callee.name;
				}
				// Member expression (object.method)
				else if (structKeyExists(callee, "property")) {
					var property = callee.property;  // Cache this too
					if (isStruct(property) && structKeyExists(property, "name")) {
						return isSimpleValue(property.name) ? property.name : "unknown";
					}
					else if (isSimpleValue(property)) {
						return property;
					}
				}
				// Identifier
				else if (structKeyExists(callee, "type") && callee.type === "Identifier") {
					return (structKeyExists(callee, "name") && isSimpleValue(callee.name)) ? callee.name : "unknown";
				}
			}
		}
		// New expression
		else if (structKeyExists(callNode, "constructor")) {
			var constructor = callNode.constructor;  // Cache
			if (isSimpleValue(constructor)) {
				return "new " & constructor;
			}
			else if (isStruct(constructor) && structKeyExists(constructor, "name")) {
				return isSimpleValue(constructor.name) ? "new " & constructor.name : "new unknown";
			}
		}

		return "unknown";
	}

	/**
	 * Build a map of functions by position for quick lookup
	 * @functions Array of function info structs
	 * @return Struct keyed by "startPos-endPos" with function info as values
	 */
	public struct function buildFunctionMap(required array functions) localmode=true {
		var map = structNew( "regular" );

		cfloop( array=arguments.functions, item="local.func" ) {
			var key = func.startPos & "-" & func.endPos;
			map[key] = func;
		}

		return map;
	}

	/**
	 * Find which function contains a given position
	 * @position The character position in the file
	 * @functions Array of function info structs
	 * @return Function info struct or empty struct if not found
	 */
	public struct function findContainingFunction(required numeric position, required array functions) localmode=true {
		var bestMatch = structNew( "regular" );
		var smallestRange = 999999999;

		cfloop( array=arguments.functions, item="local.func" ) {
			// Check if position is within this function
			if (arguments.position >= func.startPos && arguments.position <= func.endPos) {
				var range = func.endPos - func.startPos;

				// Keep the smallest containing function (most specific)
				if (range < smallestRange) {
					smallestRange = range;
					bestMatch = func;
				}
			}
		}

		return bestMatch;
	}
}