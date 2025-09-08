/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {

	// Instance variable to store display unit
	variables.displayUnit = "micro";
	
	/**
	* Constructor/init function
	*/
	public function init(string displayUnit = "micro") {
		variables.displayUnit = arguments.displayUnit;
		return this;
	}

	/**
	 * Generates an HTML report using the new result struct format
	 * @result The parsed result struct from the new parser (should contain metadata, files, fileCoverage, coverage, source)
	 */
	public string function generateHtmlReport(struct result) {
		if (!structKeyExists(arguments.result, "coverage") || structIsEmpty(arguments.result.coverage)) {
			systemOutput("No coverage data found in " & arguments.result.exeLog & ", skipping HTML report generation", true);
			return; // Skip empty files
		}

		var htmlWriter = new codeCoverageHtmlWriter(variables.displayUnit);
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
		var htmlWriter = new codeCoverageHtmlWriter(variables.displayUnit);

		var indexJsonPath = outputDirectory & "index-data.json";

		if (!fileExists(indexJsonPath)) {
			throw "No index data found, skipping index.html generation";
		}

		// Load index data
		var jsonContent = fileRead(indexJsonPath);
		var indexData = [];
		if (len(trim(jsonContent)) > 0) {
			indexData = deserializeJSON(jsonContent);
		}

		if ( arrayLen( indexData ) == 0 ) {
			throw "No reports found in index data";
		}

		// Sort by coverage, totalLines / totalLinesFound (highest first)
		arraySort(indexData, function(a, b) {
			var coverageA = a.totalLinesHit / a.totalLinesFound;
			var coverageB = b.totalLinesHit / b.totalLinesFound;
			if (coverageA != coverageB) {
				return coverageB - coverageA;
			}
			return true;
		});

		// Generate HTML content
		var html = htmlWriter.generateIndexHtmlContent( indexData );

		// Write index.html file
		var indexHtmlPath = arguments.outputDirectory & "index.html";
		fileWrite(indexHtmlPath, html);

		systemOutput("Generated index.html with " & arrayLen( indexData ) & " reports", true);
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
		var directory = getDirectoryFromPath( result.exeLog );
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