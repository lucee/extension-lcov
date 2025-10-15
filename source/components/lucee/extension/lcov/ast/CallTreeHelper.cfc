/**
 * CallTreeHelper - Utility for mapping call tree data to line numbers for display
 *
 * This component:
 * - Maps line numbers to function names using lineRange data from call tree
 * - Provides lookup functionality for display purposes (e.g., HTML reports)
 * - Note: Requires lineRange to be set on call tree blocks (currently not implemented)
 * - May be deprecated if function names are not displayed in reports
 */
component {

	/**
	 * Get function name for a specific line from call tree data
	 * @callTree Call tree data (can be full or filtered by file)
	 * @lineNumber Line number to look up
	 * @return Function name or empty string if not in a function
	 */
	public string function getFunctionAtLine(required struct callTree, required numeric lineNumber) {
		for (var blockKey in arguments.callTree) {
			var block = arguments.callTree[blockKey];

			// Check if line is within this block's line range
			if (structKeyExists(block, "lineRange") && isArray(block.lineRange) && arrayLen(block.lineRange) >= 2) {
				if (arguments.lineNumber >= block.lineRange[1] && arguments.lineNumber <= block.lineRange[2]) {
					// Found the containing function
					if (structKeyExists(block, "function") && structKeyExists(block.function, "name")) {
						return block.function.name;
					}
				}
			}
		}

		return "";
	}

	/**
	 * Build a map of line numbers to function names from call tree data
	 * @callTree Call tree data (can be full or filtered by file)
	 * @return Struct with line numbers as keys and function names as values
	 */
	public struct function buildLineFunctionMap(required struct callTree) {
		var lineMap = structNew("regular");

		for (var blockKey in arguments.callTree) {
			var block = arguments.callTree[blockKey];

			if (structKeyExists(block, "lineRange") && isArray(block.lineRange) &&
				arrayLen(block.lineRange) >= 2 &&
				structKeyExists(block, "function") &&
				structKeyExists(block.function, "name")) {

				// Map all lines in this range to the function name
				for (var line = block.lineRange[1]; line <= block.lineRange[2]; line++) {
					lineMap[line] = block.function.name;
				}
			}
		}

		return lineMap;
	}
}