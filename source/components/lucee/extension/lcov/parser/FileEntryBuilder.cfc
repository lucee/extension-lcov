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
	 * IMPORTANT: includeSourceCode and includeAst parameters control cache file size.
	 * Defaults (false/false) create minimal ~1KB JSONs. Set to true for full report generation (261KB+).
	 *
	 * @fileIndex File index from .exl file
	 * @path File path
	 * @ast Parsed AST object
	 * @lineMapping Line mapping array
	 * @fileContent Full file content string
	 * @sourceLines Array of source lines
	 * @includeSourceCode Whether to include source code in the result (default false for minimal JSONs)
	 * @includeAst Whether to include AST in the result (default false for minimal JSONs)
	 * @return struct File entry struct
	 */
	public struct function buildFileEntry(
		required string fileIndex,
		required string path,
		required any ast,
		required array lineMapping,
		required string fileContent,
		required array sourceLines,
		boolean includeSourceCode = false,
		boolean includeAst = false
	) {
		// Count executable lines using AST
		var lineInfo = variables.executableLineCounter.countExecutableLinesFromAst(arguments.ast);

		var fileEntry = {
			"path": arguments.path,
			"linesSource": arrayLen(arguments.lineMapping),
			"linesFound": lineInfo.count,
			"executableLines": lineInfo.executableLines  // Temporary - used for zero-count population then removed
		};

		// Include AST if requested (needed for CallTree analysis)
		if (arguments.includeAst) {
			fileEntry.ast = arguments.ast;
		}

		// CRITICAL DECISION POINT: Include source code or not?
		if (arguments.includeSourceCode) {
			// BLOAT MODE: Include source code in result object
			// This makes cache files 261KB+ but is needed for immediate report generation
			fileEntry.lines = arguments.sourceLines;
			fileEntry.content = arguments.fileContent;
		} else {
			// MINIMAL MODE: Exclude source code from result object
			// This makes cache files 20KB (90% reduction!)
			// Source code can be hydrated later from disk using fileEntry.path
			variables.logger.trace("Building minimal file entry for [" & arguments.path & "] - source code excluded");
		}

		return fileEntry;
	}

}
