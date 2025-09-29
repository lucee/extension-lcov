component accessors="true" {

	/**
	* Initialize the AST component with options
	* @options Configuration options struct (optional)
	*/
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = arguments.options.verbose ?: false;
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
	* Private logging function that respects verbose setting
	* @message The message to log
	*/
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	* Improved AST executable line counter: only counts unique, valid executable statement lines.
	* Never returns more executable lines than source lines.
	* See: https://github.com/lucee/lucee-docs/blob/master/docs/technical-specs/ast.yaml
	* @ast The AST struct as parsed from JSON.
	* @throwOnError If true, throw on out-of-range or excess lines; if false, clamp.
	* @return Struct with count and executableLines map
	*/
	public struct function countExecutableLinesFromAst(required struct ast, boolean throwOnError = true) {

		throw "don't use ast for now, use simple line counting";

		var executableLines = {};
		var sourceLines = [];
		if (structKeyExists(arguments.ast, "sourceLines")) {
			sourceLines = arguments.ast.sourceLines;
		}

		// Only count top-level executable statements in the main script block
		var mainBlock = [];
		// Find the main cfscript block (body of the root node)
		if (structKeyExists(arguments.ast, "body") && isArray(arguments.ast.body) && arrayLen(arguments.ast.body) > 0) {
			for (var i = 1; i <= arrayLen(arguments.ast.body); i++) {
				var node = arguments.ast.body[i];
				if (isStruct(node) && structKeyExists(node, "type") && node.type == "CFMLTag" && structKeyExists(node, "name") && lcase(node.name) == "script" && structKeyExists(node, "body") && isStruct(node.body) && structKeyExists(node.body, "body") && isArray(node.body.body)) {
					mainBlock = node.body.body;
					break;
				}
			}
		}
		// Fallback: if not found, try ast.body directly (for non-cfscript files)
		if (arrayLen(mainBlock) == 0 && structKeyExists(arguments.ast, "body") && isArray(arguments.ast.body)) {
			mainBlock = arguments.ast.body;
		}
		// Build a set of non-empty, non-comment source lines
		var validSourceLines = {};
		for (var i = 1; i <= arrayLen(sourceLines); i++) {
			var line = trim(sourceLines[i]);
			if (line == "" || left(line,2) == "//") continue;
			validSourceLines[i] = true;
		}

		// Only count top-level executable statements that map to valid source lines
		for (var i = 1; i <= arrayLen(mainBlock); i++) {
			var stmt = mainBlock[i];
			if (isStruct(stmt) && structKeyExists(stmt, "type") && arrayFindNoCase(variables.executableTypes, stmt.type)) {
				if (structKeyExists(stmt, "start") && isStruct(stmt.start) && structKeyExists(stmt.start, "line")) {
					var lineNum = stmt.start.line;
					if (structKeyExists(validSourceLines, lineNum)) {
						executableLines[lineNum] = true;
					}
				}
			}
		}

		// Validate or clamp
		var maxLine = arrayLen(sourceLines);
		var invalidLines = [];
		var filteredLines = {};
		for (var n in executableLines) {
			if (n > 0 && (maxLine == 0 || n <= maxLine)) {
				filteredLines[n] = true;
			} else {
				arrayAppend(invalidLines, n);
			}
		}
		var foundCount = structCount(executableLines);
		if (arguments.throwOnError) {
			if (arrayLen(invalidLines) > 0) {
				throw(message="Executable lines out of range: " & serializeJSON(invalidLines) & " (maxLine=" & maxLine & ")", type="ExecutableLineCounter.OutOfRange");
			}
			if (maxLine > 0 && foundCount > maxLine) {
				throw(message="linesFound (" & foundCount & ") exceeds linesSource (" & maxLine & ")", type="ExecutableLineCounter.TooMany");
			}
			return {
				"count": foundCount,
				"executableLines": executableLines
			};
		} else {
			// Clamp: only return valid lines
			return {
				"count": structCount(filteredLines),
				"executableLines": filteredLines
			};
		}
	}

	/**
	* Count non-empty, non-comment lines directly from source lines array.
	* This is more reliable for LCOV compliance than AST parsing.
	* @sourceLines Array of source code lines
	* @return Struct with count and executableLines map
	*/
	public struct function countExecutableLinesSimple(required array sourceLines) {
		var instrumentedLineCount = 0;
		var executableLines = [=];

		for (var i = 1; i <= arrayLen(arguments.sourceLines); i++) {
			var line = trim(arguments.sourceLines[i]);

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