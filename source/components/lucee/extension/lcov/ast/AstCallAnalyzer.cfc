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

	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Extract all function definitions from an AST
	 * @ast The abstract syntax tree from Lucee
	 * @return Array of function information structs
	 */
	public array function extractFunctions(required struct ast) {
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

							variables.logger.trace("traverseForFunctions: nodeType=" & nodeType);
				// Handle different function definition patterns
				if (nodeType == "FunctionDeclaration" ||
				    nodeType == "FunctionExpression" ||
				    nodeType == "function") {

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
				else if (nodeType == "component" && structKeyExists(arguments.node, "body")) {
					var componentName = arguments.node.name ?: "Component";

					for (var member in arguments.node.body) {
						if (isStruct(member) && structKeyExists(member, "type") &&
						    (member.type == "function" || member.type == "FunctionDeclaration")) {

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
			for (var key in arguments.node) {
				if (!listFindNoCase("type,name,start,end,line", key)) {
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
			for (var item in arguments.node) {
				traverseForFunctions(item, arguments.functions, arguments.parentScope);
			}
		}
	}

	/**
	 * Extract detailed information from a function node
	 */
	private struct function extractFunctionInfo(required struct functionNode, required string parentScope) {
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
			info.isPublic = arguments.functionNode.access != "private";
		}

		// Get return type if specified
		if (structKeyExists(arguments.functionNode, "returnType")) {
			info.returnType = arguments.functionNode.returnType;
		}

		// Extract parameters
		if (structKeyExists(arguments.functionNode, "params") && isArray(arguments.functionNode.params)) {
			for (var param in arguments.functionNode.params) {
				arrayAppend(info.parameters, {
					name: param.name ?: "unnamed",
					type: param.type ?: "any",
					required: param.required ?: false
				});
			}
		}

		// Find function calls within this function
		if (structKeyExists(arguments.functionNode, "body")) {
			info.calls = findFunctionCalls(arguments.functionNode.body);
		}

		return info;
	}

	/**
	 * Find all function calls within an AST node
	 */
	private array function findFunctionCalls(required any node) {
		var calls = [];
		findCallsRecursive(arguments.node, calls);
		return calls;
	}

	/**
	 * Recursively find call expressions
	 */
	private void function findCallsRecursive(required any node, required array calls) {
		if (isStruct(arguments.node)) {
			if (structKeyExists(arguments.node, "type")) {
				var nodeType = arguments.node.type;

				// Ensure nodeType is a string for comparison
				if (!isSimpleValue(nodeType)) {
					nodeType = "";
				}

				// Different types of function calls
				if (nodeType == "CallExpression" ||
				    nodeType == "MemberExpression" ||
				    nodeType == "NewExpression" ||
				    nodeType == "TaggedTemplateExpression") {

					var callName = extractCallName(arguments.node);
									variables.logger.trace("findCallsRecursive: found " & nodeType & ", name=" & callName);
					var callInfo = {
						type: nodeType,
						name: callName,
						line: 0,
						position: 0,
						isBuiltIn: arguments.node.isBuiltIn ?: false
					};

					// Special case: _createcomponent is marked as built-in but it's instantiating user code
					if (lCase(callName) == "_createcomponent") {
						callInfo.isBuiltIn = false;
						// Try to get the component name from the first argument
						if (structKeyExists(arguments.node, "arguments") &&
						    isArray(arguments.node.arguments) &&
						    arrayLen(arguments.node.arguments) > 0) {
							var firstArg = arguments.node.arguments[1];
							if (isStruct(firstArg) && structKeyExists(firstArg, "value")) {
								callInfo.name = "new " & firstArg.value;
							}
						}
					}

					// Get position
					if (structKeyExists(arguments.node, "start")) {
						if (isStruct(arguments.node.start)) {
							callInfo.position = arguments.node.start.offset;
							callInfo.line = arguments.node.start.line;
						} else {
							callInfo.position = arguments.node.start;
						}
					} else if (structKeyExists(arguments.node, "line")) {
						callInfo.line = arguments.node.line;
					}

					arrayAppend(arguments.calls, callInfo);
				}
				// Handle CFML tags (includes, modules, custom tags)
				else if (nodeType == "CFMLTag") {
					var tagName = arguments.node.name ?: "";
					var fullName = arguments.node.fullname ?: tagName;

					// Track all CFML tags that represent function/module calls
					var callInfo = {
						type: "CFMLTag",
						name: fullName,
						tagName: tagName,
						line: 0,
						position: 0,
						isBuiltIn: arguments.node.isBuiltIn ?: false
					};

					// Extract the target (template, name, component, etc.) for specific tags
					if (structKeyExists(arguments.node, "attributes") && isArray(arguments.node.attributes)) {
						for (var attr in arguments.node.attributes) {
							if (isStruct(attr) && structKeyExists(attr, "name")) {
								if (attr.name == "template" || attr.name == "name" || attr.name == "component") {
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
					if (structKeyExists(arguments.node, "start")) {
						if (isStruct(arguments.node.start)) {
							callInfo.position = arguments.node.start.offset;
							callInfo.line = arguments.node.start.line;
						} else {
							callInfo.position = arguments.node.start;
						}
					}

					// Only add tags that could represent child time (function/module calls)
					// Skip pure structural tags like cfset, cfif, etc. unless they're custom tags
					var isCustomTag = left(fullName, 3) == "cf_" || find(":", fullName) > 0;
					var isCallTag = listFindNoCase("include,cfinclude,module,cfmodule,invoke,cfinvoke,import,cfimport", tagName) > 0;

					if (isCustomTag || isCallTag) {
						arrayAppend(arguments.calls, callInfo);
					}
				}
				// Handle dynamic invocations and closures
				else if (nodeType == "ClosureExpression" || nodeType == "LambdaExpression") {
					// Track anonymous function definitions as they might be called
					var callInfo = {
						type: nodeType,
						name: nodeType == "ClosureExpression" ? "closure" : "lambda",
						line: 0,
						position: 0,
						isBuiltIn: false  // Closures and lambdas are always user code
					};

					// Get position
					if (structKeyExists(arguments.node, "start")) {
						if (isStruct(arguments.node.start)) {
							callInfo.position = arguments.node.start.offset;
							callInfo.line = arguments.node.start.line;
						} else {
							callInfo.position = arguments.node.start;
						}
					}

					arrayAppend(arguments.calls, callInfo);
				}
			}

			// Traverse children
			for (var key in arguments.node) {
				if (!listFindNoCase("type,name,start,end", key) && !isNull(arguments.node[key])) {
					findCallsRecursive(arguments.node[key], arguments.calls);
				}
			}
		}
		else if (isArray(arguments.node)) {
			for (var item in arguments.node) {
				findCallsRecursive(item, arguments.calls);
			}
		}
	}

	/**
	 * Extract the name of the function being called
	 */
	private string function extractCallName(required struct callNode) {
		// Direct function call
		if (structKeyExists(arguments.callNode, "callee")) {
			if (isSimpleValue(arguments.callNode.callee)) {
				return arguments.callNode.callee;
			}
			else if (isStruct(arguments.callNode.callee)) {
				// Named function
				if (structKeyExists(arguments.callNode.callee, "name") && isSimpleValue(arguments.callNode.callee.name)) {
					return arguments.callNode.callee.name;
				}
				// Member expression (object.method)
				else if (structKeyExists(arguments.callNode.callee, "property")) {
					if (isStruct(arguments.callNode.callee.property) &&
					    structKeyExists(arguments.callNode.callee.property, "name")) {
						return isSimpleValue(arguments.callNode.callee.property.name) ? arguments.callNode.callee.property.name : "unknown";
					}
					else if (isSimpleValue(arguments.callNode.callee.property)) {
						return arguments.callNode.callee.property;
					}
				}
				// Identifier
				else if (structKeyExists(arguments.callNode.callee, "type") &&
				         arguments.callNode.callee.type == "Identifier") {
					return (structKeyExists(arguments.callNode.callee, "name") && isSimpleValue(arguments.callNode.callee.name)) ? arguments.callNode.callee.name : "unknown";
				}
			}
		}
		// New expression
		else if (structKeyExists(arguments.callNode, "constructor")) {
			if (isSimpleValue(arguments.callNode.constructor)) {
				return "new " & arguments.callNode.constructor;
			}
			else if (isStruct(arguments.callNode.constructor) &&
			         structKeyExists(arguments.callNode.constructor, "name")) {
				return isSimpleValue(arguments.callNode.constructor.name) ? "new " & arguments.callNode.constructor.name : "new unknown";
			}
		}

		return "unknown";
	}

	/**
	 * Build a map of functions by position for quick lookup
	 * @functions Array of function info structs
	 * @return Struct keyed by "startPos-endPos" with function info as values
	 */
	public struct function buildFunctionMap(required array functions) {
		var map = {};

		for (var func in arguments.functions) {
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
	public struct function findContainingFunction(required numeric position, required array functions) {
		var bestMatch = {};
		var smallestRange = 999999999;

		for (var func in arguments.functions) {
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