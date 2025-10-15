component accessors="true" {

	/**
	* Initialize the AST component with options
	* @options Configuration options struct (optional)
	*/
	public function init(required Logger logger, struct options = {}) {
		// Store options and logger
		variables.logger = arguments.logger;
		variables.options = arguments.options;
				// List of node types that represent executable statements (expand as needed)
		variables.executableTypes = [
			"ExpressionStatement", "IfStatement", "SwitchCase", "WhileStatement", "ForStatement",
			"ForInStatement", "ForOfStatement", "ReturnStatement", "BreakStatement", "ContinueStatement",
			"ThrowStatement", "TryStatement", "DoWhileStatement", "VariableDeclaration", "AssignmentExpression",
			"FunctionDeclaration", "CallExpression", "EchoStatement", "IncludeStatement", "SwitchStatement"
		];
		return this;
	}

	/**
	* Recursively traverse AST nodes to find all lines that Lucee will track.
	*
	* IMPORTANT: We mark any line that has an AST node with a line number.
	* This represents what Lucee's ResourceExecutionLog will track in .exl files.
	* The AST naturally only contains nodes for executable code, not empty lines or pure comments.
	*
	* @nodes Array of AST nodes to traverse
	* @executableLines Struct to populate with executable line numbers (passed by reference)
	*/
	private void function traverseNodes(nodes, executableLines) localmode="modern" {
		cfloop( array=arguments.nodes, item="local.node" ) {
			if (!isStruct(node)) continue;

			// If this AST node has a line number, Lucee will track it
			// The AST only contains nodes for actual code, not empty lines or pure comments
			if (structKeyExists(node, "start") && isStruct(node.start) && structKeyExists(node.start, "line")) {
				var lineNum = node.start.line;
				arguments.executableLines[lineNum] = true;
			}

			// Recursively traverse ALL properties in the node
			// This ensures we find all executable lines regardless of AST structure
			cfloop( collection=node, item="local.key" ) {
				// Skip metadata properties that don't contain executable code
				if (key == "start" || key == "end" || key == "type" || key == "sourceLines") {
					continue;
				}

				// Skip keys that don't exist or have null values
				if (!structKeyExists(node, key)) {
					continue;
				}

				var value = node[key];

				// Skip null values
				if (isNull(value)) {
					continue;
				}

				// Recursively traverse arrays
				if (isArray(value)) {
					traverseNodes(value, arguments.executableLines);
				}
				// Recursively traverse nested structs
				else if (isStruct(value)) {
					traverseNodes([value], arguments.executableLines);
				}
			}
		}
	}

	/**
	* AST-based executable line counter: counts lines that Lucee's ResourceExecutionLog will track.
	*
	* IMPORTANT: "Executable line" means a line that Lucee's execution logger tracks in .exl files.
	* This is determined by:
	* 1. The line contains an AST node (statement/expression that executes)
	* 2. The line is not empty and not a pure comment
	*
	* This method traverses the AST to find all nodes with line numbers, which represents
	* what Lucee will actually track during execution. This ensures that coverage data
	* from .exl files will match our executableLines, preventing linesHit=0 bugs.
	*
	* See: https://github.com/lucee/lucee-docs/blob/master/docs/technical-specs/ast.yaml
	* @ast The AST struct as parsed from JSON.
	* @throwOnError If true, throw on out-of-range or excess lines; if false, clamp.
	* @return Struct with count and executableLines map
	*/
	public struct function countExecutableLinesFromAst(required struct ast, boolean throwOnError = true) localmode="modern" {
		var event = variables.logger.beginEvent("ExecutableLineCounter");

		var executableLines = structNew( "regular" );
		var sourceLines = [];
		if (structKeyExists(arguments.ast, "sourceLines")) {
			sourceLines = arguments.ast.sourceLines;
		}

		// Traverse the entire AST recursively to find all lines that Lucee tracks
		// Each AST node with a line number represents a line Lucee will track in .exl files
		// The AST naturally excludes empty lines and pure comments
		if (structKeyExists(arguments.ast, "body") && isArray(arguments.ast.body)) {
			traverseNodes(arguments.ast.body, executableLines);
		}

		// Validate or clamp
		var maxLine = arrayLen(sourceLines);
		var invalidLines = [];
		var filteredLines = structNew( "regular" );
		cfloop( collection=executableLines, item="local.n" ) {
			if (n > 0 && (maxLine == 0 || n <= maxLine)) {
				filteredLines[n] = true;
			} else {
				arrayAppend(invalidLines, n);
			}
		}
		var foundCount = structCount(executableLines);

		event["sourceLines"] = maxLine;
		event["executableLines"] = foundCount;

		if (arguments.throwOnError) {
			if (arrayLen(invalidLines) > 0) {
				event["invalidLines"] = arrayLen(invalidLines);
				variables.logger.commitEvent(event);
				throw(message="Executable lines out of range: " & serializeJSON(invalidLines) & " (maxLine=" & maxLine & ")", type="ExecutableLineCounter.OutOfRange");
			}
			if (maxLine > 0 && foundCount > maxLine) {
				variables.logger.commitEvent(event);
				throw(message="linesFound (" & foundCount & ") exceeds linesSource (" & maxLine & ")", type="ExecutableLineCounter.TooMany");
			}
			variables.logger.commitEvent(event);
			return {
				"count": foundCount,
				"executableLines": executableLines
			};
		} else {
			// Clamp: only return valid lines
			event["filteredLines"] = structCount(filteredLines);
			variables.logger.commitEvent(event);
			return {
				"count": structCount(filteredLines),
				"executableLines": filteredLines
			};
		}
	}

	/**
	* Count non-empty, non-comment lines directly from source lines array.
	* @deprecated Use countExecutableLinesFromAst() instead. This method over-counts non-executable lines.
	* @sourceLines Array of source code lines
	* @return Struct with count and executableLines map
	*/
	public struct function countExecutableLinesSimple(required array sourceLines) {
		var instrumentedLineCount = 0;
		var executableLines = [=];

		cfloop( array=arguments.sourceLines, index="local.i", item="local.sourceLine" ) {
			var line = trim(sourceLine);

			// Skip empty lines
			if (len(line) == 0) {
				continue;
			}

			// Skip pure comment lines (starting with // or /* or *)
			if (reFind("^(//|/\*|\*)", line)) {
				continue;
			}

			// Count this as an instrumentable line
			instrumentedLineCount++;
			executableLines[i] = true;
		}

		return {
			"count": instrumentedLineCount,
			"executableLines": executableLines
		};
	}
}