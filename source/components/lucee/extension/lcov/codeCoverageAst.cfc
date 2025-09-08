component accessors="true" {

	/**
	* Given a parsed AST, returns the number of lines instrumented (non-whitespace, non-comment).
	* This simplified approach counts all non-empty, non-comment lines for LCOV compliance.
	* @ast The AST struct as parsed from JSON.
	* @return Number of code lines (not whitespace or comments).
	*/
	public numeric function countInstrumentedLines(required struct ast) {
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
			return structCount(executableLines);
		}
		
		// Count non-empty, non-comment lines
		var instrumentedLineCount = 0;
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
		}
		
		// If no source lines available or count is 0, return minimum 1 for non-empty files
		if (instrumentedLineCount == 0) {
			if (structKeyExists(arguments.ast, "body") && 
					((isArray(arguments.ast.body) && arrayLen(arguments.ast.body) > 0) ||
					 (isStruct(arguments.ast.body) && structCount(arguments.ast.body) > 0))) {
				return 1;
			}
			return 0;
		}
		
		return instrumentedLineCount;
	}

	/**
	* Count non-empty, non-comment lines directly from source lines array.
	* This is more reliable for LCOV compliance than AST parsing.
	* @sourceLines Array of source code lines
	* @return Number of instrumentable lines
	*/
	public numeric function countSourceLines(required array sourceLines) {
		var instrumentedLineCount = 0;
		
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
		}
		
		return instrumentedLineCount;
	}
}