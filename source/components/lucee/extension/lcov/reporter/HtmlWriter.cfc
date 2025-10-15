/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {
	
	variables.htmlAssets = new HtmlAssets();
	variables.heatmapCalculator = new Heatmap();
	variables.htmlEncoder = new HtmlEncoder();
	variables.displayUnit = { symbol: "μs", name: "micro", factor: 1 };
	variables.header = new HtmlReportHeader();
	variables.fileSection = new HtmlFileSection();
	variables.legend = new HtmlLegend();
	variables.index = new HtmlIndex();
	variables.fileUtils = new FileUtils();
	variables.footer = new lucee.extension.lcov.reporter.HtmlFooter();
	
	/**
	* Constructor/init function
	* Accepts either a displayUnit struct or a string ("micro", "ms", "s").
	* Always stores a struct with name, symbol, and factor.
	*/
	public HtmlWriter function init(required Logger logger, string displayUnit = "μs") {
		variables.logger = arguments.logger;
		variables.displayUnit = arguments.displayUnit;
		return this;
	}

	/**
	* Generates the HTML content for the execution report
	*/
	public string function generateHtmlContent(result) {
		// result is a model/result.cfc object
		var scriptName = result.getMetadataProperty("script-name");
		var outputFilename = result.getOutputFilename();
		var prefix = result.getIsFile() ? "File: " : "Request: ";
		var displayName = prefix & scriptName;
		var time = result.getMetadataProperty("execution-time");
		var unit = result.getMetadataProperty("unit");

		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(variables.displayUnit);
		var timeMicros = timeFormatter.convertTime(time, unit, "μs");
		var timeDisplay = timeFormatter.format(timeMicros);

		// Extract value and unit from formatted display
		var parts = listToArray(timeDisplay, " ");
		var execTimeValue = reReplace(parts[1], ",", "", "all"); // Remove commas for numeric operations
		var execTimeUnit = arrayLen(parts) > 1 ? parts[2] : variables.displayUnit;
		var fileCoverageJson = result.getOutputFilename() & ".json";
		var linesFound = result.getStatsProperty("totalLinesFound");
		var linesHit = result.getStatsProperty("totalLinesHit");
		if (!isNumeric(linesFound) || !isNumeric(linesHit)) {
			throw "Missing or invalid coverage stats: linesFound=" & linesFound & ", linesHit=" & linesHit;
		}
		var coveragePercent = linesFound > 0 ? numberFormat(100.0 * linesHit / linesFound, "9.9") : "0.0";

		// Check for minimum execution time warning
		var minTimeNano = result.getMetadataProperty("min-time-nano", 0);
		var hasMinTimeWarning = isNumeric(minTimeNano) && minTimeNano > 0;

		// Extract filename and directory for tab-friendly title
		var pathArray = listToArray(scriptName, "/\");
		var fileName = arrayLen(pathArray) > 0 ? pathArray[arrayLen(pathArray)] : scriptName;
		var shortDir = arrayLen(pathArray) > 1 ? pathArray[arrayLen(pathArray) - 1] : "";
		var tabTitle = fileName & (shortDir != "" ? " - " & shortDir : "") & " - LCOV";

		var html = '<!DOCTYPE html>
		<html lang="en">
		<head>
			<meta charset="UTF-8">
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<title>' & variables.htmlEncoder.htmlEncode(tabTitle) & '</title>
			<link rel="alternate" type="application/json" href="' & variables.htmlEncoder.htmlEncode(outputFilename) & '.json">
			<link rel="alternate" type="text/markdown" href="' & variables.htmlEncoder.htmlEncode(outputFilename) & '.md">
			' & variables.htmlAssets.getCommonCss() & '
		</head>
		<body>
			<div class="container">
				<div class="header-section">
					<div class="header-top">
						<div class="header-content">'
							& variables.header.getReportTitleHeader() & '
							<h1>' & variables.htmlEncoder.htmlEncode(displayName) & ' <span class="file-path-subtitle">('
								& variables.htmlEncoder.htmlEncode(numberFormat(execTimeValue))
								& ' ' & variables.htmlEncoder.htmlEncode(execTimeUnit) & ')</span></h1>
						</div>
						<button id="dark-mode-toggle" class="dark-mode-toggle" onclick="toggleDarkMode()" title="Toggle dark mode">
							<span class="toggle-icon">&##127769;</span>
						</button>
					</div>
					<div class="timestamp">Generated: ' & lsDateTimeFormat(now()) & '</div>
					<div class="coverage-summary" data-coverage-summary>
						<strong>Coverage Summary:</strong> ' & linesHit & ' of ' & linesFound & ' lines covered (' & coveragePercent & '%)
					</div>';

		// Add minimum time warning if applicable
		if (hasMinTimeWarning) {
			var unitSymbol = result.getMetadataProperty("unit", "ns");
			html &= '<div class="min-time-warning">
				   <strong>&##9888; Coverage Warning:</strong> Coverage data may be incomplete due to minimum execution time filter (min-time: ' & minTimeNano & ' ' & unitSymbol & ')
				   </div>';
		}

		html &= '</div>
			<a href="index.html" class="back-link">Back to Index</a>
			<p class="file-links">';

		// Only show log file link if exeLog exists (not in per-file mode)
		var exeLog = result.getExeLog();
		if (len(trim(exeLog)) > 0 && fileExists(exeLog)) {
			var exeLogFilename = listLast(exeLog, "/\\");
			html &= '<a href="' & variables.htmlEncoder.htmlAttributeEncode(exeLogFilename) & '" target="_blank" class="file-link">Log</a> &nbsp;|&nbsp; ';
		}

		// Add JSON and Markdown links
		var fileCoverageMarkdown = result.getOutputFilename() & ".md";
		html &= '<a href="' & variables.htmlEncoder.htmlAttributeEncode(fileCoverageJson) & '" target="_blank" class="file-link">JSON</a>';
		html &= ' &nbsp;|&nbsp; <a href="' & variables.htmlEncoder.htmlAttributeEncode(fileCoverageMarkdown) & '" target="_blank" class="file-link">Markdown</a>';
		html &= '</p>';

		// Loop over canonical fileIndex keys in result.getFiles() - sorted numerically
		var filesStruct = result.getFiles();
		var fileIndexes = structKeyArray(filesStruct);
		arraySort(fileIndexes, "numeric", "asc");

		// add logger event
		//var event =variables.logger.beginEvent("HTMLReportGeneration");
		for (var fileIndex in fileIndexes) {
			if (!isNumeric(fileIndex)) throw(type="InvalidFileIndex", message="Only numeric fileIndex keys are allowed [fileIndex=#fileIndex#]");

			html &= variables.fileSection.generateFileSection(fileIndex, result, variables.htmlEncoder, variables.heatmapCalculator, variables.displayUnit);

		}
		//variables.logger.commitEvent(event);

		html &= '</div>';

		// Add version footer
		html &= variables.footer.generateFooter();

		html &= variables.htmlAssets.getDarkModeScript();
		html &= variables.htmlAssets.getTableSortScript();
		html &= '</body></html>';
		return html;
		systemOutput("", true);
		systemOutput("", true);
	}

	/**
	* Generates the HTML content for the index page
	*/
	public string function generateIndexHtmlContent(array reportData) {
		return variables.index.generateIndexHtmlContent(reportData, variables.htmlEncoder, variables.displayUnit);
	}
}