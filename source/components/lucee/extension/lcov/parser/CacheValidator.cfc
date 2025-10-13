/**
 * CacheValidator.cfc
 *
 * Handles validation of cached .exl.json files.
 * Checks checksums and option hashes to determine if cache is valid.
 */
component {

	property name="logger" type="any";

	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Attempts to load a cached result if valid.
	 * @exlPath Path to .exl file
	 * @allowList Allow list for validation
	 * @blocklist Block list for validation
	 * @includeCallTree Whether call tree is included
	 * @return struct with {valid: boolean, result: result object or null}
	 */
	public struct function loadCachedResultIfValid(
		required string exlPath,
		required array allowList,
		required array blocklist,
		required boolean includeCallTree
	) {
		var jsonPath = reReplace(arguments.exlPath, "\.exl$", ".json");

		if (!fileExists(jsonPath) || !fileExists(arguments.exlPath)) {
			return {valid: false};
		}

		try {
			// Calculate current .exl file checksum
			var currentChecksum = fileInfo(arguments.exlPath).checksum;

			// Parse JSON directly and check checksum and options
			var cachedData = deserializeJSON(fileRead(jsonPath));
			var cachedChecksum = cachedData.exlChecksum ?: "";

			// Create options hash for comparison
			var currentOptionsHash = calculateOptionsHash(
				arguments.allowList,
				arguments.blocklist,
				arguments.includeCallTree
			);
			var cachedOptionsHash = cachedData.optionsHash ?: "";

			if (len(cachedChecksum) && cachedChecksum == currentChecksum && currentOptionsHash == cachedOptionsHash) {
				variables.logger.debug("Using cached result for [" & getFileFromPath(arguments.exlPath) & "]");
				// Use the static fromJson method but disable validation to avoid schema issues
				var cachedResult = new lucee.extension.lcov.model.result().fromJson(fileRead(jsonPath), false);
				return {valid: true, result: cachedResult};
			} else {
				variables.logger.debug("Checksum mismatch for [" & arguments.exlPath & "] - re-parsing (cached: " & cachedChecksum & ", current: " & currentChecksum & ")");
				// Delete outdated cached file
				fileDelete(jsonPath);
				return {valid: false};
			}
		} catch (any e) {
			variables.logger.debug("Failed to load cached result for [" & arguments.exlPath & "]: " & e.message & " - re-parsing");
			// Delete invalid cached file
			try {
				fileDelete(jsonPath);
			} catch (any deleteError) {
				// Ignore deletion errors
			}
			return {valid: false};
		}
	}

	/**
	 * Calculates an options hash for cache validation.
	 * @allowList Allow list
	 * @blocklist Block list
	 * @includeCallTree Whether call tree is included
	 * @return string MD5 hash of options
	 */
	public string function calculateOptionsHash(
		required array allowList,
		required array blocklist,
		required boolean includeCallTree
	) {
		return hash(serializeJSON([arguments.allowList, arguments.blocklist, arguments.includeCallTree]), "MD5");
	}

}
