/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {

	// Instance variable to store display unit
	variables.displayUnit = "micro";
	variables.outputDir = "";
	
	/**
	* Constructor/init function
	*/
	public function init(string displayUnit = "micro", boolean verbose = false) {
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
	 * Generates an HTML report using the new result struct format
	 * @result The parsed result struct from the new parser (should contain metadata, files, fileCoverage, coverage, source)
	 */
	public string function generateHtmlReport(struct result) {
		if (!structKeyExists(arguments.result, "coverage") || structIsEmpty(arguments.result.coverage)) {
			logger("No coverage data found in " & arguments.result.exeLog & ", skipping HTML report generation");
			return; // Skip empty files
		}

		if (!extensionExists("37C61C0A-5D7E-4256-8572639BE0CF5838")) {
			throw(message="HTML report generation requires the ESAPI extension for security encoding functions. Please install the ESAPI extension first.", type="extension.dependency");
		}

		var htmlWriter = new HtmlWriter(variables.displayUnit);
		var html = htmlWriter.generateHtmlContent(result);
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
		if (!extensionExists("37C61C0A-5D7E-4256-8572639BE0CF5838")) {
			throw(message="HTML index generation requires the ESAPI extension for security encoding functions. Please install the ESAPI extension first.", type="extension.dependency");
		}

		var htmlWriter = new HtmlWriter(variables.displayUnit);

		var indexJsonPath = outputDirectory & "/index-data.json";

		// Load index data or create empty structure
		var indexData = [];
		if (fileExists(indexJsonPath)) {
			var jsonContent = fileRead(indexJsonPath);
			if (len(trim(jsonContent)) > 0) {
				indexData = deserializeJSON(jsonContent);
			}
		}

		// Sort by coverage, totalLines / totalLinesFound (highest first)
		if (arrayLen(indexData) > 0) {
			arraySort(indexData, function(a, b) {
				var coverageA = a.totalLinesHit / a.totalLinesFound;
				var coverageB = b.totalLinesHit / b.totalLinesFound;
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

		var reportEntry = {
			"htmlFile": getFileFromPath( arguments.htmlPath ),
			"scriptName": result.metadata[ "script-name" ] ?: "unknown",
			"executionTime": result.metadata[ "execution-time" ] ?: "N/A",
			"unit": result.metadata[ "unit" ] ?: "μs",
			"timestamp": now(),
			"fullPath": arguments.htmlPath,
			"totalLinesFound": arguments.result.stats.totalLinesFound,
			"totalLinesHit": arguments.result.stats.totalLinesHit,
			"totalExecutions": arguments.result.stats.totalExecutions,
			"totalExecutionTime": arguments.result.stats.totalExecutionTime
		};

		var indexJsonPath = getDirectoryFromPath( arguments.htmlPath ) & "index-data.json";

		// Load existing index data or create new
		var indexData = [];
		if ( fileExists( indexJsonPath ) ) {
			var jsonContent = fileRead( indexJsonPath );
			if ( len( trim( jsonContent ) ) > 0) {
				indexData = deserializeJSON( jsonContent );
			}
		}
		arrayAppend( indexData, reportEntry );
		fileWrite( indexJsonPath, serializeJSON( var=indexData, compact=false ) );
		return reportEntry;
	}

	/**
	* Creates a human-friendly HTML filename from the .exl path and metadata
	*/
	private string function createHtmlPath(struct result) {
		// Extract the number prefix from the .exl filename
		var fileName = getFileFromPath( result.exeLog );
		var numberPrefix = listFirst( fileName, "-" );
		var scriptName = result.metadata[ "script-name" ] ?: "unknown";

		// Clean up script name: remove leading slash and convert remaining slashes to underscores
		scriptName = reReplace( scriptName, "^/", "" ); // Remove leading slash
		scriptName = replace( scriptName, "/", "_", "all" ); // Convert slashes to underscores
		scriptName = replace( scriptName, ".", "_", "all" ); // Convert dots to underscores

		// Create the base filename: number-scriptname
		var directory = len(variables.outputDir) ? variables.outputDir : getDirectoryFromPath( result.exeLog );
		// Ensure directory ends with separator
		if (len(directory) && !right(directory, 1) == "/" && !right(directory, 1) == "\") {
			directory = directory & "/";
		}
		var baseFileName = numberPrefix & "-" & scriptName;
		var newFileName = baseFileName & ".html";
		var fullPath = directory & newFileName;

		// Check for filename conflicts and add suffix if needed
		var suffix = 1;
		while (fileExists( fullPath )) {
			newFileName = baseFileName & "-" & suffix & ".html";
			fullPath = directory & newFileName;
			suffix++;
			// Safety check to prevent infinite loop
			if ( suffix > 1000 ) {
				break;
			}
		}

		return fullPath;
	}

}