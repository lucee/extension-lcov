component accessors="true" {

	/**
	* Initialize the AST component with options
	* @options Configuration options struct (optional)
	*/
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
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
	* Given a parsed AST, returns the number of lines instrumented (non-whitespace, non-comment).
	* This simplified approach counts all non-empty, non-comment lines for LCOV compliance.
	* @ast The AST struct as parsed from JSON.
	* @return Struct with count and executableLines map
	*/
	public struct function countExecutableLinesFromAst(required struct ast) {
		// For LCOV compliance, we'll count non-empty, non-comment lines
		// First, try to get the source lines from the AST structure
		var sourceLines = [];
		
		// Try to extract source lines from the AST if available
		if (structKeyExists(arguments.ast, "sourceLines")) {
			sourceLines = arguments.ast.sourceLines;
		} else {
			// Fallback: return a conservative estimate based on AST structure
			var executableLines = {};
			
			// Simple AST traversal to collect any line numbers
			var traverse = function(node) {
				if (!isStruct(node) && !isArray(node)) {
					return;
				}
				
				if (isArray(node)) {
					for (var i = 1; i <= arrayLen(node); i++) {
						traverse(node[i]);
					}
					return;
				}
				
				// Collect any line numbers from nodes
				if (structKeyExists(node, "start") && isStruct(node.start) && structKeyExists(node.start, "line")) {
					executableLines[node.start.line] = true;
				}
				
				// Traverse all properties
				for (var key in node) {
					if (structKeyExists(node, key) && !isNull(node[key])) {
						var value = node[key];
						if (isStruct(value) || isArray(value)) {
							traverse(value);
						}
					}
				}
			};
			
			traverse(arguments.ast);
			return {
				"count": structCount(executableLines),
				"executableLines": executableLines
			};
		}
		
		// Count non-empty, non-comment lines
		var instrumentedLineCount = 0;
		var executableLinesMap = {};
		for (var i = 1; i <= arrayLen(sourceLines); i++) {
			var line = trim(sourceLines[i]);
			
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
			executableLinesMap[i] = true;
		}
		
		// If no source lines available or count is 0, return minimum 1 for non-empty files
		if (instrumentedLineCount == 0) {
			if (structKeyExists(arguments.ast, "body") && 
					((isArray(arguments.ast.body) && arrayLen(arguments.ast.body) > 0) ||
					 (isStruct(arguments.ast.body) && structCount(arguments.ast.body) > 0))) {
				return {
					"count": 1,
					"executableLines": {"1": true}
				};
			}
			return {
				"count": 0,
				"executableLines": {}
			};
		}
		
		return {
			"count": instrumentedLineCount,
			"executableLines": executableLinesMap
		};
	}

	/**
	* Count non-empty, non-comment lines directly from source lines array.
	* This is more reliable for LCOV compliance than AST parsing.
	* @sourceLines Array of source code lines
	* @return Struct with count and executableLines map
	*/
	public struct function countExecutableLinesSimple(required array sourceLines) {
		var instrumentedLineCount = 0;
		var executableLines = {};
		
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