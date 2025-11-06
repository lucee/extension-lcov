/**
 * CacheValidator.cfc
 *
 * Handles validation of cached .exl.json files.
 * Checks checksums and option hashes to determine if cache is valid.
 */
component {

	property name="logger" type="any";

	/**
	 * Initialize cache validator with logger
	 * @logger Logger instance for debugging and tracing
	 * @return This instance
	 */
	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Attempts to load a cached result if valid.
	 * @exlPath Path to .exl file
	 * @allowList Allow list for validation
	 * @blocklist Block list for validation
	 * @return struct with {valid: boolean, result: result object or null}
	 */
	public struct function loadCachedResultIfValid(
		required string exlPath,
		required array allowList,
		required array blocklist
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
				arguments.blocklist
			);
			var cachedOptionsHash = cachedData.optionsHash ?: "";

			// Debug: show what's being hashed
			//variables.logger.debug("Options being hashed: allowList=#serializeJSON(arguments.allowList)#, blocklist=#serializeJSON(arguments.blocklist)#");

			if (len(cachedChecksum) && cachedChecksum == currentChecksum && currentOptionsHash == cachedOptionsHash) {
				variables.logger.debug("Using cached result for [" & getFileFromPath(arguments.exlPath) & "]");
				// Use the static fromJson method but disable validation to avoid schema issues
				var cachedResult = new lucee.extension.lcov.model.result().fromJson(fileRead(jsonPath), false);
				return {valid: true, result: cachedResult};
			} else {
				// Determine what changed to provide clear debug logging
				var reasons = [];
				if (cachedChecksum != currentChecksum) {
					arrayAppend( reasons, "checksum changed (cached: " & cachedChecksum & ", current: " & currentChecksum & ")" );
				}
				if (cachedOptionsHash != currentOptionsHash) {
					arrayAppend( reasons, "options hash changed (cached: " & cachedOptionsHash & ", current: " & currentOptionsHash & ")" );
				}
				if (arrayLen(reasons) == 0) {
					arrayAppend( reasons, "cache validation failed (missing checksum or hash)" );
				}
				variables.logger.info("Cache invalid for [" & getFileFromPath(arguments.exlPath) & "] - " & arrayToList(reasons, "; ") & " - re-parsing");
				// Delete outdated cached file
				fileDelete(jsonPath);
				return {valid: false};
			}
		} catch (any e) {
			variables.logger.info("Failed to load cached result for [" & arguments.exlPath & "]: " & e.message & " - re-parsing");
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
	 * @return string MD5 hash of options
	 */
	public string function calculateOptionsHash(
		required array allowList,
		required array blocklist
	) {
		var json = serializeJSON([arguments.allowList, arguments.blocklist]);
		var hashValue = hash(json, "MD5");
		//variables.logger.debug("calculateOptionsHash: JSON=[#json#], hash=#hashValue#");
		return hashValue;
	}

}
