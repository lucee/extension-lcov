/**
 * FileFilterHelper.cfc
 *
 * Handles allow/blocklist filtering for source files during parsing.
 * Extracted from ExecutionLogParser to eliminate duplication and improve testability.
 */
component {

	property name="logger" type="any";

	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Determines if a file should be skipped based on allow/blocklist rules.
	 * @path File path to check
	 * @allowList Array of allowed patterns (empty array = allow all)
	 * @blocklist Array of blocked patterns
	 * @return boolean True if file should be skipped, false if it should be processed
	 */
	public boolean function shouldSkipFile(required string path, required array allowList, required array blocklist) {
		// Check allowList first (if present, file must match to proceed)
		if (arrayLen(arguments.allowList) > 0) {
			var foundInAllowList = false;
			for (var pattern in arguments.allowList) {
				if (matchesPattern(arguments.path, pattern)) {
					foundInAllowList = true;
					break;
				}
			}
			if (!foundInAllowList) {
				variables.logger.debug("Skipping file [" & arguments.path & "] - not in allowList");
				return true;
			}
		}

		// Check blocklist (if matches any pattern, skip)
		for (var pattern in arguments.blocklist) {
			if (matchesPattern(arguments.path, pattern)) {
				variables.logger.debug("Skipping file [" & arguments.path & "] - found in blocklist pattern [" & pattern & "]");
				return true;
			}
		}

		return false;
	}

	/**
	 * Checks if a path matches a pattern (substring match).
	 * Normalizes both path and pattern to use platform-specific separators.
	 * @path File path to check
	 * @pattern Pattern to match against
	 * @return boolean True if pattern found in path
	 */
	private boolean function matchesPattern(required string path, required string pattern) {
		var normalizedPath = normalizePathForComparison(arguments.path);
		var normalizedPattern = normalizePathForComparison(arguments.pattern);
		return find(normalizedPattern, normalizedPath) > 0;
	}

	/**
	 * Normalizes a path for comparison by converting all separators to platform-specific ones.
	 * @path Path to normalize
	 * @return string Normalized path
	 */
	private string function normalizePathForComparison(required string path) {
		var normalized = replace(arguments.path, "/", server.separator.file, "all");
		normalized = replace(normalized, "\", server.separator.file, "all");
		return normalized;
	}

}
