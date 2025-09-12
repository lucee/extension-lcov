/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {
	
	// Instance variable for HTML assets
	variables.htmlAssets = new HtmlAssets();
	
	// Instance variable for heatmap calculations
	variables.heatmapCalculator = new Heatmap();
	
	// Instance variable for HTML encoding
	variables.htmlEncoder = new HtmlEncoder();
	
	// Instance variable to store display unit struct
	variables.displayUnit = { symbol: "μs", name: "micro", factor: 1 };
	
	// Instance variable for report header
	variables.header = new HtmlReportHeader();
	
	// Instance variable for file section
	variables.fileSection = new HtmlFileSection();
	
	// Instance variable for legend
	variables.legend = new HtmlLegend();
	
	// Instance variable for index
	variables.index = new HtmlIndex();
	
	// Instance variable for utility functions
	variables.utils = new HtmlUtils();
	
	/**
	* Constructor/init function
	* Accepts either a displayUnit struct or a string ("micro", "ms", "s").
	* Always stores a struct with name, symbol, and factor.
	*/
	public HtmlWriter function init(struct displayUnit = { symbol: "μs", name: "micro", factor: 1 }) {
		if (isStruct(arguments.displayUnit)) {
			variables.displayUnit = arguments.displayUnit;
		} else if (isSimpleValue(arguments.displayUnit)) {
			// Accept string: "micro", "ms", "s"
			var unit = lcase(arguments.displayUnit);
			switch (unit) {
				case "ms":
					variables.displayUnit = { symbol: "ms", name: "ms", factor: 1000 };
					break;
				case "s":
					variables.displayUnit = { symbol: "s", name: "s", factor: 1000000 };
					break;
				default:
					variables.displayUnit = { symbol: "μs", name: "micro", factor: 1 };
			}
		} else {
			// Fallback to default
			variables.displayUnit = { symbol: "μs", name: "micro", factor: 1 };
		}
		return this;
	}

	/**
	* Generates the HTML content for the execution report
	*/
	public string function generateHtmlContent(result) {
		// result is a model/result.cfc object
		var scriptName = result.getMetadataProperty("script-name");
		var time = result.getMetadataProperty("execution-time");
		var unit = result.getMetadataProperty("unit");
		var value = time;
		var outUnit = displayUnit.name;
		// Basic conversion: ms <-> micro <-> s
		if (unit == "ms" && variables.displayUnit.name == "micro") value = time * 1000;
		else if (unit == "ms" && variables.displayUnit.name == "s") value = time / 1000;
		else if (unit == "micro" && variables.displayUnit.name == "ms") value = time / 1000;
		else if (unit == "micro" && variables.displayUnit.name == "s") value = time / 1000000;
		else if (unit == "s" && variables.displayUnit.name == "ms") value = time * 1000;
		else if (unit == "s" && variables.displayUnit.name == "micro") value = time * 1000000;
		else outUnit = unit;
		var execTimeValue = value;
		var execTimeUnit = outUnit;
		var fileCoverageJson = replace(result.getExeLog(), ".exl", ".json");
		var linesFound = result.getStatsProperty("totalLinesFound");
		var linesHit = result.getStatsProperty("totalLinesHit");
		if (!isNumeric(linesFound) || !isNumeric(linesHit)) {
			throw "Missing or invalid coverage stats: linesFound=" & linesFound & ", linesHit=" & linesHit;
		}
		var coveragePercent = linesFound > 0 ? numberFormat(100.0 * linesHit / linesFound, "9.9") : "0.0";

		// Extract filename and directory for tab-friendly title
	var fileName = listLast(scriptName, "/\\");
	var dirPath = listDeleteAt(scriptName, listLen(scriptName, "/\\"), "/\\");
	var shortDir = listLast(dirPath, "/\\");
	var tabTitle = fileName & " - " & shortDir & " - LCOV";

	var html = '<!DOCTYPE html>
	<html lang="en">
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>' & variables.htmlEncoder.htmlEncode(tabTitle) & '</title>
		<style>' & variables.htmlAssets.getCommonCss() & '</style>
	</head>
	<body>
		<div class="container">
			<div class="header-section">
				<div class="header-top">
					<div class="header-content">'
						& variables.header.getReportTitleHeader() & '
						<h1>' & variables.htmlEncoder.htmlEncode(scriptName) & ' <span class="file-path-subtitle">('
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
				   </div>
			</div>
			<a href="index.html" class="back-link">Back to Index</a>
			<p class="file-links"><strong>Log Files:</strong> <a href="'
				& variables.htmlEncoder.htmlAttributeEncode(result.getExeLog()) & '" target="_blank" class="file-link">'
				& variables.htmlEncoder.htmlEncode(listLast(result.getExeLog(), "/\\"))
				& '</a> &nbsp;|&nbsp; <strong>Coverage JSON:</strong>'
				& ' <a href="' & variables.htmlEncoder.htmlAttributeEncode(fileCoverageJson) & '" target="_blank" class="file-link">'
					& variables.htmlEncoder.htmlEncode(listLast(fileCoverageJson, "/\\")) & '</a></p>';

		// Loop over canonical fileIndex keys in result.getFiles()
		var filesStruct = result.getFiles();
		for (var fileIndex in filesStruct) {
			if (!isNumeric(fileIndex)) continue; // Only process numeric fileIndex keys
			html &= variables.fileSection.generateFileSection(fileIndex, result, variables.htmlEncoder, variables.heatmapCalculator, variables.displayUnit);
		}

		html &= '</div>';
		html &= variables.htmlAssets.getDarkModeScript();
		html &= '</body>\n</html>';
		return html;
	}

	/**
	* Generates the HTML content for the index page
	*/
	public string function generateIndexHtmlContent(array reportData) {
		return variables.index.generateIndexHtmlContent(reportData, variables.htmlEncoder, variables.displayUnit);
	}

	// Utility methods moved to HtmlUtils.cfc
}