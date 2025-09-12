component {
	/**
	 * Generates the HTML for the index page.
	 * @results Array of result model objects (model/result.cfc)
	 */
	public string function generateIndexHtmlContent(required array results, required any htmlEncoder, required any displayUnit) {
		var heatmapData = calculateCoverageHeatmapData(arguments.results);

		var header = new HtmlReportHeader();
		var htmlAssets = new HtmlAssets();
		var html = '<!DOCTYPE html>
		<html lang="en">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Code Coverage Reports Index</title>
				<style>' & htmlAssets.getCommonCss() & chr(10) & heatmapData.css & '</style>
				<script>
				document.addEventListener("DOMContentLoaded", function() {
					const tableRows = document.querySelectorAll(".reports-table tbody tr");
					tableRows.forEach(function(row) {
					row.addEventListener("click", function() {
						const htmlFile = this.getAttribute("data-html-file");
						if (htmlFile) {
						window.location.href = htmlFile;
						}
					});
					});
				});
			</script>
			</head>
			<body>
				<div class="container">
					<div class="header-top">
						<div class="header-content">'
						& header.getReportTitleHeader() & '
						<h1>Code Coverage Reports</h1>
					</div>
						<button id="dark-mode-toggle" class="dark-mode-toggle" onclick="toggleDarkMode()" title="Toggle dark mode">
						<span class="toggle-icon">&##127769;</span>
					</button>
				</div>';
		// Calculate total lines and percent covered for summary
		var totalLinesHit = 0;
		var totalLinesFound = 0;
		for (var result in arguments.results) {
			if (isNumeric(result["totalLinesHit"])) totalLinesHit += result["totalLinesHit"];
			if (isNumeric(result["totalLinesFound"])) totalLinesFound += result["totalLinesFound"];
		}
		var percentCovered = (totalLinesFound > 0) ? numberFormat(100.0 * totalLinesHit / totalLinesFound, "00.0") & '%' : '0%';
		html &= '<div class="summary" data-coverage-summary'
			& ' data-total-reports=''' & arrayLen(arguments.results) & ''''
			& ' data-total-lines=''' & totalLinesFound & ''''
			& ' data-lines-hit=''' & totalLinesHit & ''''
			& ' data-percent-covered=''' & percentCovered & '''>'
			& '<strong>Total Reports:</strong> ' & arrayLen(arguments.results) & ' | '
			& '<strong>Coverage:</strong> ' & percentCovered & ' | '
			& '<strong>Generated:</strong> ' & lsDateTimeFormat(now())
			& '</div>';

		if (arrayLen(arguments.results) == 0) {
			html &= '<div class="no-reports">No coverage reports found.</div>';
		} else {
			html &= '<table class="reports-table">
				<thead>
					<tr>
						<th>Script Name</th>
						<th>Coverage</th>
						<th>Percentage</th>
						<th>Execution Time</th>
					</tr>
				</thead>
				<tbody>';

			for (var result in arguments.results) {
				// Get required properties from report summary struct (from index.json)
				var scriptName = result["scriptName"];
				var htmlFile = result["htmlFile"];
				var totalLinesHit = result["totalLinesHit"];
				var totalLinesFound = result["totalLinesFound"];
				var percentCovered = (isNumeric(totalLinesHit) && isNumeric(totalLinesFound) && totalLinesFound > 0) ? numberFormat(100.0 * totalLinesHit / totalLinesFound, "0.0") & '%' : '-';
				var formattedTime = "";
				var displayUnit = "";
				if (structKeyExists(result, "executionTime") && isNumeric(result["executionTime"])) {
					formattedTime = numberFormat(result["executionTime"]);
					displayUnit = structKeyExists(result, "unit") ? result["unit"] : "";
				}
				var timestamp = structKeyExists(result, "timestamp") ? result["timestamp"] : "";

				// Calculate heatmap classes for coverage percentage and execution time
				var coverageClass = "";
				var executionClass = "";

				// Coverage percentage heatmap
				if (isNumeric(totalLinesHit) && isNumeric(totalLinesFound) && totalLinesFound > 0 && arrayLen(heatmapData.coverageRanges) > 0) {
					var percentage = 100.0 * totalLinesHit / totalLinesFound;
					var level = heatmapData.bucketCalculator.getValueLevel(percentage, heatmapData.coverageRanges);
					coverageClass = " coverage-heatmap-level-" & level;
				}

				// Execution time heatmap - include zero values and missing data
				if (arrayLen(heatmapData.executionRanges) > 0) {
					var execTime = 0; // Default to 0 for missing execution data
					if (structKeyExists(result, "executionTime") && isNumeric(result["executionTime"])) {
						execTime = result["executionTime"];
					}
					var level = heatmapData.bucketCalculator.getValueLevel(execTime, heatmapData.executionRanges);
					executionClass = " execution-heatmap-level-" & level;
				}

				html &= '<tr data-file-row data-html-file="' & arguments.htmlEncoder.htmlAttributeEncode(htmlFile) & '" data-script-name="' & arguments.htmlEncoder.htmlAttributeEncode(scriptName) & '">';
				html &= '<td class="script-name">' & arguments.htmlEncoder.htmlEncode(scriptName) & '</td>';
				html &= '<td class="coverage">' & totalLinesHit & ' / ' & totalLinesFound & '</td>';
				html &= '<td class="percentage' & coverageClass & '">' & percentCovered & '</td>';
				html &= '<td class="execution-time' & executionClass & '">' & formattedTime & ' ' & arguments.htmlEncoder.htmlAttributeEncode(displayUnit) & '</td>';
				html &= '</tr>' & chr(10);
			}

			html &= '</tbody></table>';
		}

			html &= '</div>';
			html &= htmlAssets.getDarkModeScript();
			html &= '</body></html>';
			return html;
	}

	/**
	 * Calculates heatmap data for coverage percentages and execution times
	 * @results Array of result model objects
	 * @return struct containing bucketCalculator, coverage ranges, execution ranges, and css
	 */
	private struct function calculateCoverageHeatmapData(required array results) {
		var bucketCalculator = new heatmap.bucketCalculator();
		var colorGenerator = new heatmap.colorGenerator();
		var coveragePercentages = [];
		var executionTimes = [];

		// Collect coverage percentages and execution times for heatmap calculation
		for (var result in arguments.results) {
			// Coverage percentages
			if (isNumeric(result["totalLinesHit"]) && isNumeric(result["totalLinesFound"]) && result["totalLinesFound"] > 0) {
				var percentage = 100.0 * result["totalLinesHit"] / result["totalLinesFound"];
				arrayAppend(coveragePercentages, percentage);
			}

			// Execution times - include zero values for heatmap calculation
			if (structKeyExists(result, "executionTime") && isNumeric(result["executionTime"]) && result["executionTime"] >= 0) {
				arrayAppend(executionTimes, result["executionTime"]);
			}
		}

		var cssRules = [];

		// Calculate heatmap buckets for coverage percentages
		var coverageBucketCount = min(5, max(1, arrayLen(coveragePercentages)));
		var coverageRanges = [];

		if (arrayLen(coveragePercentages) > 0) {
			coverageRanges = bucketCalculator.calculateRanges(coveragePercentages, coverageBucketCount);

			// Generate CSS for coverage heatmap using green base color
			var coverageBaseColor = {r: 0, g: 128, b: 0}; // Green for coverage percentages
			arrayAppend(cssRules, "/* Coverage Percentage Heatmap */");

			for (var level = 1; level <= coverageBucketCount; level++) {
				var coverageClass = "coverage-heatmap-level-" & level;
				var coverageColor = colorGenerator.generateGradientColor(coverageBaseColor, level, coverageBucketCount);
				var textColor = colorGenerator.getContrastTextColor(level, coverageBucketCount);
				arrayAppend(cssRules, ".reports-table .percentage." & coverageClass & " { background-color: " & coverageColor & "; color: " & textColor & "; border-radius: 3px; padding: 2px 5px; }");
			}
		}

		// Calculate heatmap buckets for execution times
		var executionBucketCount = min(5, max(1, arrayLen(executionTimes)));
		var executionRanges = [];

		if (arrayLen(executionTimes) > 0) {
			executionRanges = bucketCalculator.calculateRanges(executionTimes, executionBucketCount);

			// Generate CSS for execution time heatmap using red base color
			var executionBaseColor = {r: 255, g: 0, b: 0}; // Red for execution times
			arrayAppend(cssRules, "");
			arrayAppend(cssRules, "/* Execution Time Heatmap */");

			for (var level = 1; level <= executionBucketCount; level++) {
				var executionClass = "execution-heatmap-level-" & level;
				var executionColor = colorGenerator.generateGradientColor(executionBaseColor, level, executionBucketCount);
				var textColor = colorGenerator.getContrastTextColor(level, executionBucketCount);
				arrayAppend(cssRules, ".reports-table .execution-time." & executionClass & " { background-color: " & executionColor & "; color: " & textColor & "; border-radius: 3px; padding: 2px 5px; }");
			}
		}

		var combinedCss = arrayToList(cssRules, chr(10));

		return {
			"bucketCalculator": bucketCalculator,
			"coverageRanges": coverageRanges,
			"executionRanges": executionRanges,
			"css": combinedCss
		};
	}
}
