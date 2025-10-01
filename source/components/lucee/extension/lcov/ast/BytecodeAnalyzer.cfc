/**
 * Extract line numbers from compiled bytecode using javap.
 * This represents the ground truth of what Lucee's execution logger tracks.
 */
component {

	/**
	 * Initialize BytecodeAnalyzer
	 * @logLevel Log level for debugging bytecode extraction
	 */
	public function init(string logLevel="none") {
		variables.logger = new lucee.extension.lcov.Logger(level=arguments.logLevel);
		return this;
	}

	/**
	 * Extract line numbers from compiled bytecode's LineNumberTable.
	 * This represents the ground truth of what Lucee's execution logger tracks.
	 *
	 * @sourceFilePath Absolute path to the source CFML file
	 * @return Struct where keys are line numbers that have bytecode
	 */
	public struct function extractLineNumberTable(required string sourceFilePath) {
		var lineNumbers = {};

		// Find the compiled .class file in cfclasses directory
		var classFilePath = findCompiledClassFile(arguments.sourceFilePath);
		variables.logger.debug("Found class file: " & classFilePath);

		if (len(classFilePath) == 0) {
			variables.logger.debug("No compiled .class file found for: " & arguments.sourceFilePath);
			return lineNumbers;
		}

		// Read bytecode using javap
		lineNumbers = readLineNumberTableFromBytecode(classFilePath);
		variables.logger.debug("Extracted " & structCount(lineNumbers) & " line numbers from bytecode");

		return lineNumbers;
	}

	/**
	 * Find the compiled .class file for a source file.
	 * Looks in common cfclasses directories.
	 *
	 * @sourceFilePath Absolute path to the source file
	 * @return Path to .class file, or empty string if not found
	 */
	private string function findCompiledClassFile(required string sourceFilePath) {
		// Common location for compiled classes
		var searchPaths = [
			expandPath("{lucee-server}/cfclasses")
		];

		// Convert source path to expected class name pattern
		// e.g., d:\work\lucee-extensions\extension-lcov\tests\artifacts\kitchen-sink-example.cfm
		// becomes something like: kitchen_sink_example_cfm*.class
		var fileName = getFileFromPath(arguments.sourceFilePath);
		var baseName = replaceNoCase(fileName, ".cfm", "", "all");
		baseName = replaceNoCase(baseName, ".cfc", "", "all");
		baseName = replace(baseName, "-", "_", "all");

		// Search for the class file
		for (var searchPath in searchPaths) {
			if (directoryExists(searchPath)) {
				var foundFiles = directoryList(
					path = searchPath,
					recurse = true,
					listInfo = "path",
					filter = baseName & "*$cf.class"
				);

				if (arrayLen(foundFiles) > 0) {
					// Return the most recently modified one
					arraySort(foundFiles, "textnocase");
					return foundFiles[arrayLen(foundFiles)];
				}
			}
		}

		return "";
	}

	/**
	 * Read LineNumberTable from bytecode using javap.
	 *
	 * @classFilePath Path to the .class file
	 * @return Struct where keys are line numbers
	 */
	private struct function readLineNumberTableFromBytecode(required string classFilePath) {
		var lineNumbers = {};

		// Use javap to get the verbose output including LineNumberTable
		var result = "";
		execute name="javap" arguments="-v ""#arguments.classFilePath#""" variable="result" timeout="10";

		variables.logger.debug("Javap output length: " & len(result));

		// Parse the LineNumberTable from javap output
		// Look for lines like: "line 5: 0" or "line 10: 23"
		// Split on newlines (handle both Unix \n and Windows \r\n)
		var lines = result.split("\r?\n");
		var inLineNumberTable = false;

		for (var line in lines) {
			line = trim(line);

			// Detect when we enter a LineNumberTable section
			if (findNoCase("LineNumberTable:", line)) {
				inLineNumberTable = true;
				continue;
			}

			// Detect when we leave the LineNumberTable section
			if (inLineNumberTable && (len(line) == 0 || !findNoCase("line ", line))) {
				inLineNumberTable = false;
				continue;
			}

			// Parse line number entries: "line 5: 0"
			if (inLineNumberTable && findNoCase("line ", line)) {
				// Extract the number after "line " using reReplace
				var lineNum = val(reReplace(line, "^.*line\s+(\d+):.*$", "\1"));
				if (lineNum > 0) {
					lineNumbers[lineNum] = true;
				}
			}
		}

		return lineNumbers;
	}

}