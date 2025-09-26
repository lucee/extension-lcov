/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {

    variables.displayUnit = { symbol: "μs", name: "micro", factor: 1 };
    variables.outputDir = "";
	
	/**
	* Constructor/init function
	*/
	public function init(string displayUnit = "μs", boolean verbose = false) {
		variables.displayUnit = arguments.displayUnit;
		variables.verbose = arguments.verbose;
		return this;
	}
	
	/**
	* Private logging function that respects verbose setting
	* @message The message to log
	*/
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	* Set the output directory for HTML file generation
	*/
	public void function setOutputDir(required string outputDir) {
		variables.outputDir = arguments.outputDir;
	}

	/**
	 * Generates an HTML report using the result model instance (must be lucee.extension.lcov.model.result)
	 * @result The parsed result model instance (must have getMetadataProperty, getStatsProperty, etc.)
	 */
	public string function generateHtmlReport(required result result) {
		if (!isInstanceOf(arguments.result, "lucee.extension.lcov.model.result")) {
			throw(message="generateHtmlReport requires a lucee.extension.lcov.model.result instance, got: " & getMetaData(arguments.result).name);
		}
		if (!isStruct(arguments.result.getCoverage()) || structIsEmpty(arguments.result.getCoverage())) {
			logger("No coverage data found in " & arguments.result.getExeLog() & ", skipping HTML report generation");
			return; // Skip empty files
		}

		var htmlWriter = new HtmlWriter(variables.displayUnit);
		var html = htmlWriter.generateHtmlContent(result, variables.displayUnit);
		var htmlPath = createHtmlPath(result);
		fileWrite(htmlPath, html);

		// Track this report in the index data
		trackReportInIndex(htmlPath, result);
		return htmlPath;
	}

	/**
	* Generates an index.html file listing all HTML reports
	*/
	public string function generateIndexHtml(string outputDirectory) {

		var htmlWriter = new HtmlWriter(variables.displayUnit);

		var indexJsonPath = outputDirectory & "/index.json";

		// Load index data or create empty structure
		var indexData = [];
		if (fileExists(indexJsonPath)) {
			var jsonContent = fileRead(indexJsonPath);
			if (len(trim(jsonContent)) > 0) {
				indexData = deserializeJSON(jsonContent);
			}
		}

		// Sort by coverage, linesHit / linesFound (highest first, fail-fast)
		if (arrayLen(indexData) > 0) {
			arraySort(indexData, function(a, b) {
				   if (!structKeyExists(a, "totalLinesHit") || !structKeyExists(a, "totalLinesFound") || !structKeyExists(b, "totalLinesHit") || !structKeyExists(b, "totalLinesFound")) {
					   throw "Missing totalLinesHit/totalLinesFound in index entry during sort.";
				   }
				   var coverageA = (a.totalLinesFound > 0) ? (a.totalLinesHit / a.totalLinesFound) : -1;
				   var coverageB = (b.totalLinesFound > 0) ? (b.totalLinesHit / b.totalLinesFound) : -1;
				   // Sort entries with zero linesFound to the end
				   if (coverageA != coverageB) {
					   return coverageB - coverageA;
				   }
				   return 0;
			});
		}

		// Generate HTML content
		var html = htmlWriter.generateIndexHtmlContent( indexData );

		// Write index.html file
		var indexHtmlPath = arguments.outputDirectory & "/index.html";
		fileWrite(indexHtmlPath, html);

		logger("Generated index.html with " & arrayLen( indexData ) & " reports");
		return indexHtmlPath;
	}

	/**
	* Tracks a generated HTML report in the index JSON file
	*/
	private struct function trackReportInIndex( string htmlPath, struct result ) {

		// Use explicit, fail-fast coverage stats
		if (!isNumeric(result.getStatsProperty("totalLinesFound")) || !isNumeric(result.getStatsProperty("totalLinesHit"))) {
			throw "Missing totalLinesFound/totalLinesHit in result stats for " & arguments.htmlPath;
		}
		var reportEntry = {
			"htmlFile": getFileFromPath( arguments.htmlPath ),
			"scriptName": result.getMetadataProperty("script-name") ?: "unknown",
			"executionTime": result.getMetadataProperty("execution-time") ?: "N/A",
			"unit": result.getMetadataProperty("unit") ?: "bcs",
			"timestamp": now(),
			"fullPath": expandPath(arguments.htmlPath),
			"totalLinesFound": result.getStatsProperty("totalLinesFound"),
			"totalLinesHit": result.getStatsProperty("totalLinesHit"),
			"totalExecutions": result.getStatsProperty("totalExecutions"),
			"totalExecutionTime": result.getStatsProperty("totalExecutionTime"),
			"minTimeNano": result.getMetadataProperty("min-time-nano", 0)
		};

		var indexJsonPath = getDirectoryFromPath( arguments.htmlPath ) & "index.json";

		// Load existing index data or create new
		var indexData = [];
		if ( fileExists( indexJsonPath ) ) {
			var jsonContent = fileRead( indexJsonPath );
			if ( len( trim( jsonContent ) ) > 0) {
				indexData = deserializeJSON( jsonContent );
			}
		}

		// Check if entry already exists for this HTML file to prevent duplicates
		var existingIndex = -1;
		for (var i = 1; i <= arrayLen(indexData); i++) {
			if (structKeyExists(indexData[i], "htmlFile") && indexData[i].htmlFile == reportEntry.htmlFile) {
				existingIndex = i;
				break;
			}
		}

		if (existingIndex > 0) {
			// Update existing entry
			indexData[existingIndex] = reportEntry;
		} else {
			// Add new entry
			arrayAppend( indexData, reportEntry );
		}
		fileWrite( indexJsonPath, serializeJSON( var=indexData, compact=false ) );
		return reportEntry;
	}

	/**
	* Creates a human-friendly HTML filename from the .exl path and metadata
	*/
	private string function createHtmlPath(struct result) {
		var directory = len(variables.outputDir) ? variables.outputDir : getDirectoryFromPath( result.getExeLog() );

		// Check directory exists first to avoid expandPath issues with non-existent directories
		if (!directoryExists(directory)) {
			throw(message="HTML output directory does not exist: " & directory);
		}

		// Ensure directory ends with separator
		if (len(directory) && !right(directory, 1) == "/" && !right(directory, 1) == "\") {
			directory = directory & "/";
		}

		var newFileName = result.getOutputFilename();
		// Require outputFilename to be set, fail fast if not present
		if (len(newFileName) eq 0) {
			throw(message="Result model must have outputFilename set for HTML report generation.");
		}
		// Ensure .html extension
		if (!right(newFileName, 5) == ".html") {
			newFileName &= ".html";
		}
		// Don't use expandPath - it has issues with directories in certain contexts
		var fullPath = directory & newFileName;
		return fullPath;
	}

	/**
	* Clean script name to make it safe for use as filename, preserving query parameter info
	* @scriptName The script name from metadata (may contain URL parameters, slashes, etc)
	* @return Clean filename-safe string with query parameters preserved as underscores
	*/
	private string function cleanScriptNameForFilename(required string scriptName) {
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

}