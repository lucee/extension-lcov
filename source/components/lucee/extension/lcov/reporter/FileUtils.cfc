/**
* Utility functions for file path handling and manipulation shared across reporters
*/
component {

	/**
	* Clean script name to make it safe for use as filename, preserving query parameter info
	* @scriptName The script name from metadata (may contain URL parameters, slashes, etc)
	* @return Clean filename-safe string with query parameters preserved as underscores
	*/
	public string function cleanScriptNameForFilename(required string scriptName) {
		var cleaned = arguments.scriptName;

		// Remove leading slash
		cleaned = reReplace( cleaned, "^/", "" );

		// Handle query parameters - preserve them but make them filename-safe
		if (find("?", cleaned)) {
			var scriptPart = listFirst( cleaned, "?" );
			var queryPart = listLast( cleaned, "?" );

			// Clean up the query parameters to be filename-safe
			queryPart = replace( queryPart, "=", "_", "all" );  // param=value becomes param_value
			queryPart = replace( queryPart, "&", "_", "all" );  // param1&param2 becomes param1_param2
			queryPart = replace( queryPart, "%", "_", "all" );  // URL encoded characters
			queryPart = replace( queryPart, "+", "_", "all" );  // URL encoded spaces

			// Recombine with underscore separator
			cleaned = scriptPart & "_" & queryPart;
		}

		// Convert filesystem-unsafe characters to underscores
		cleaned = replace( cleaned, "/", "_", "all" );  // Convert slashes to underscores
		cleaned = replace( cleaned, ".", "_", "all" );  // Convert dots to underscores
		cleaned = replace( cleaned, ":", "_", "all" );  // Convert colons to underscores (Windows drive letters, etc)
		cleaned = replace( cleaned, "*", "_", "all" );  // Convert asterisks to underscores
		cleaned = replace( cleaned, "?", "_", "all" );  // Convert any remaining question marks to underscores
		cleaned = replace( cleaned, '"', "_", "all" );  // Convert quotes to underscores
		cleaned = replace( cleaned, "<", "_", "all" );  // Convert less-than to underscores
		cleaned = replace( cleaned, ">", "_", "all" );  // Convert greater-than to underscores
		cleaned = replace( cleaned, "|", "_", "all" );  // Convert pipes to underscores
		cleaned = replace( cleaned, " ", "_", "all" );  // Convert spaces to underscores
		cleaned = replace( cleaned, "##", "_", "all" );  // Convert hash symbols to underscores

		return cleaned;
	}

	/**
	* Ensures a directory path ends with a path separator
	* @directory The directory path to check
	* @return Directory path with trailing separator
	*/
	public string function ensureDirectoryEndsWithSeparator(required string directory) {
		if (len(arguments.directory) && !right(arguments.directory, 1) == "/" && !right(arguments.directory, 1) == "\") {
			return arguments.directory & "/";
		}
		return arguments.directory;
	}

	/**
	* Creates an output file path with proper extension
	* @result The result model instance
	* @outputDir Optional output directory override
	* @extension File extension (e.g., ".html", ".md")
	* @return Full path to output file
	*/
	public string function createOutputPath(required result result, string outputDir = "", required string extension) {
		var directory = len(arguments.outputDir) ? arguments.outputDir : getDirectoryFromPath( arguments.result.getExeLog() );

		// Check directory exists first to avoid expandPath issues with non-existent directories
		if (!directoryExists(directory)) {
			throw(message="Output directory does not exist: " & directory);
		}

		// Ensure directory ends with separator
		directory = ensureDirectoryEndsWithSeparator( directory );

		var fileName = arguments.result.getOutputFilename();
		// Require outputFilename to be set, fail fast if not present
		if (len(fileName) eq 0) {
			throw(message="Result model must have outputFilename set for report generation.");
		}

		// Ensure correct extension
		var extLen = len(arguments.extension);
		if (!right(fileName, extLen) == arguments.extension) {
			fileName &= arguments.extension;
		}

		// Don't use expandPath - it has issues with directories in certain contexts
		var fullPath = directory & fileName;
		return fullPath;
	}

	/**
	* Safely contracts a file path, falling back to original path if contraction fails
	* @filePath The file path to contract
	* @return Contracted path or original if contraction fails
	*/
	public string function safeContractPath(required string filePath) {
		try {
			var contractedPath = contractPath(arguments.filePath);
			return (isNull(contractedPath) || contractedPath == "null" || contractedPath contains "null")
				? arguments.filePath : contractedPath;
		} catch (any e) {
			return arguments.filePath;
		}
	}

	/**
	* Calculate relative path from one directory to another
	* @fromPath Absolute path to the directory to calculate from (e.g., HTML output dir)
	* @toPath Absolute path to the target file or directory
	* @return Relative path from fromPath to toPath
	*/
	public string function calculateRelativePath(required string fromPath, required string toPath) {
		// Normalize paths - replace backslashes with forward slashes
		var from = replace( arguments.fromPath, "\", "/", "all" );
		var to = replace( arguments.toPath, "\", "/", "all" );

		// Remove trailing slashes
		from = reReplace( from, "/$", "" );
		to = reReplace( to, "/$", "" );

		// Split paths into parts
		var fromParts = listToArray( from, "/" );
		var toParts = listToArray( to, "/" );

		// Find common base path
		var commonLength = 0;
		var minLength = min( arrayLen( fromParts ), arrayLen( toParts ) );
		for ( var i = 1; i <= minLength; i++ ) {
			if ( fromParts[ i ] == toParts[ i ] ) {
				commonLength = i;
			} else {
				break;
			}
		}

		// Build relative path
		var relativeParts = [];

		// Add ".." for each remaining directory in fromPath
		var upLevels = arrayLen( fromParts ) - commonLength;
		for ( var i = 1; i <= upLevels; i++ ) {
			arrayAppend( relativeParts, ".." );
		}

		// Add remaining parts from toPath
		for ( var i = commonLength + 1; i <= arrayLen( toParts ); i++ ) {
			arrayAppend( relativeParts, toParts[ i ] );
		}

		// Join with forward slashes
		return arrayLen( relativeParts ) > 0 ? arrayToList( relativeParts, "/" ) : ".";
	}
}
