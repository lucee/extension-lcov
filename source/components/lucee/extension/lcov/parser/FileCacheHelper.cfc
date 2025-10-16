/**
 * FileCacheHelper.cfc
 *
 * Handles file content caching and line mapping during parsing.
 * Maintains caches to avoid re-reading and re-processing files.
 */
component {

	property name="logger" type="any";
	property name="fileContentsCache" type="struct" default="#{}#";
	property name="lineMappingsCache" type="struct" default="#{}#";

	public function init(required any logger, required any blockProcessor) {
		variables.logger = arguments.logger;
		variables.blockProcessor = arguments.blockProcessor;
		variables.fileContentsCache = {};
		variables.lineMappingsCache = {};
		return this;
	}

	/**
	 * Ensures a file's content is cached in memory.
	 * If already cached, does nothing. If not cached, reads from disk.
	 * @path File path to cache
	 */
	public void function ensureFileCached(required string path) {
		if (!structKeyExists(variables.fileContentsCache, arguments.path)) {
			if (!fileExists(arguments.path)) {
				throw(
					type="ExecutionLogParser.SourceFileNotFound",
					message="Source file not found: " & arguments.path,
					detail="The execution log references a source file that does not exist on disk."
				);
			}
			variables.fileContentsCache[arguments.path] = fileRead(arguments.path);
		}
	}

	/**
	 * Ensures a file's line mapping is cached in memory.
	 * Requires file content to be cached first.
	 * @path File path to build line mapping for
	 */
	public void function ensureLineMappingCached(required string path) {
		if (!structKeyExists(variables.lineMappingsCache, arguments.path)) {
			ensureFileCached(arguments.path);
			variables.lineMappingsCache[arguments.path] = variables.blockProcessor.buildCharacterToLineMapping(
				variables.fileContentsCache[arguments.path]
			);
		}
	}

	/**
	 * Gets cached file content.
	 * @path File path
	 * @return string File content
	 */
	public string function getFileContent(required string path) {
		ensureFileCached(arguments.path);
		return variables.fileContentsCache[arguments.path];
	}

	/**
	 * Gets cached line mapping.
	 * @path File path
	 * @return array Line mapping array
	 */
	public array function getLineMapping(required string path) {
		ensureLineMappingCached(arguments.path);
		return variables.lineMappingsCache[arguments.path];
	}

	/**
	 * Reads a file as an array of lines, using cached content.
	 * NOTE: Case-insensitive in Lucee, so readFileAsArrayBylines() also works (typo compatibility)
	 * @path File path
	 * @return array Array of lines
	 */
	public array function readFileAsArrayByLines(required string path) {
		ensureFileCached(arguments.path);
		return listToArray(variables.fileContentsCache[arguments.path], chr(10), true, false);
	}

	/**
	 * Returns the line mappings cache for batch operations.
	 * @return struct Line mappings cache
	 */
	public struct function getLineMappingsCache() {
		return variables.lineMappingsCache;
	}

	/**
	 * NEW API: Get all file data (content, lineMapping, sourceLines) in a single call.
	 * Replaces the pattern of calling ensureFileCached, ensureLineMappingCached,
	 * getFileContent, getLineMapping, and readFileAsArrayByLines separately.
	 *
	 * @path File path
	 * @return struct { content: string, lineMapping: array, sourceLines: array }
	 */
	public struct function getFileData(required string path) {
		// Ensure both file content and line mapping are cached
		ensureFileCached(arguments.path);
		ensureLineMappingCached(arguments.path);

		// Return all data in a single struct
		return {
			"content": variables.fileContentsCache[arguments.path],
			"lineMapping": variables.lineMappingsCache[arguments.path],
			"sourceLines": listToArray(variables.fileContentsCache[arguments.path], chr(10), true, false)
		};
	}

}
