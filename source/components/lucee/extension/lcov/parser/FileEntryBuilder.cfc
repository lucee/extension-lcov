/**
 * FileEntryBuilder.cfc
 *
 * Builds file entry structs for parsed results.
 * CRITICAL: Controls whether source code is loaded into the result object.
 */
component {

	property name="logger" type="any";
	property name="executableLineCounter" type="any";

	public function init(required any logger, required any executableLineCounter) {
		variables.logger = arguments.logger;
		variables.executableLineCounter = arguments.executableLineCounter;
		return this;
	}

	/**
	 * Builds a file entry struct for inclusion in result.files[].
	 *
	 * OPTIMIZATION: AST processing removed from parseExlFile phase.
	 * linesFound is now set to 0 here and populated later from AST metadata (extracted in batch).
	 * Source code (lines, content, lineMapping) is stored in AST files and loaded on demand by reporters.
	 *
	 * @fileIndex File index from .exl file
	 * @path File path
	 * @astFile Full path to AST file containing source data
	 * @return struct File entry struct
	 */
	public struct function buildFileEntry(
		required string fileIndex,
		required string path,
		required string astFile
	) {
		// OPTIMIZATION: Skip AST processing during parseExlFile phase
		// linesFound will be populated later from AST metadata (extracted once in batch)
		var fileEntry = {
			"path": arguments.path,
			"astFile": arguments.astFile,  // Full path to AST file containing lines, lineMapping, etc.
			"linesSource": 0,  // Will be populated later from AST metadata
			"linesFound": 0,  // Will be populated later from AST metadata
			"executableLines": {}  // Will be populated later from AST metadata (struct for backward compat!)
		};

		return fileEntry;
	}

}
