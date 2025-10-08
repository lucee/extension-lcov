component {
	/**
	 * Generates the HTML for the index page.
	 * @results Array of result model objects (model/result.cfc)
	 */
	public string function generateIndexHtmlContent(required array results, required any htmlEncoder, required string displayUnit) {
		var heatmapData = calculateCoverageHeatmapData(arguments.results, arguments.displayUnit);

		var header = new HtmlReportHeader();
		var htmlAssets = new HtmlAssets();
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.displayUnit);
		var html = '<!DOCTYPE html>
		<html lang="en">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Code Coverage Reports Index</title>
				<link rel="alternate" type="application/json" href="index.json">
				<link rel="alternate" type="text/markdown" href="index.md">
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
		// Calculate total lines, percent covered, and total execution time for summary
		var totalLinesHit = 0;
		var totalLinesFound = 0;
		var totalExecutionTimeMicroseconds = 0;
		for (var result in arguments.results) {
			if (isNumeric(result["totalLinesHit"])) totalLinesHit += result["totalLinesHit"];
			if (isNumeric(result["totalLinesFound"])) totalLinesFound += result["totalLinesFound"];
			if (structKeyExists(result, "executionTime") && isNumeric(result["executionTime"])) {
				// Convert from source unit to microseconds before summing
				var sourceUnit = structKeyExists(result, "unit") ? result["unit"] : "μs";
				var executionTimeMicros = timeFormatter.convertTime(result["executionTime"], sourceUnit, "μs");
				totalExecutionTimeMicroseconds += executionTimeMicros;
			}
		}
		var percentCovered = (totalLinesFound > 0) ? numberFormat(100.0 * totalLinesHit / totalLinesFound, "00.0") & '%' : '0%';

		// Format total execution time - always include units for summary clarity
		var totalTimeDisplay = timeFormatter.formatTime(totalExecutionTimeMicroseconds, arguments.displayUnit, true);

		html &= '<div class="summary" data-coverage-summary'
			& ' data-total-reports=''' & arrayLen(arguments.results) & ''''
			& ' data-total-lines=''' & totalLinesFound & ''''
			& ' data-lines-hit=''' & totalLinesHit & ''''
			& ' data-percent-covered=''' & percentCovered & '''>'
			& '<strong>Total Reports:</strong> <span class="total-reports">' & arrayLen(arguments.results) & '</span> | '
			& '<strong>Coverage:</strong> <span class="total-coverage">' & percentCovered & '</span> | '
			& '<strong>Total Execution Time:</strong> <span class="total-execution-time">' & totalTimeDisplay & '</span> | '
			& '<strong>Generated:</strong> <span class="generated-timestamp">' & lsDateTimeFormat(now()) & '</span>'
			& '</div>';

		// Check for minimum time warnings across all results
		var hasMinTimeWarnings = false;
		for (var result in arguments.results) {
			if (structKeyExists(result, "minTimeNano") && isNumeric(result["minTimeNano"]) && result["minTimeNano"] > 0) {
				hasMinTimeWarnings = true;
				break;
			}
		}

		// Add global minimum time warning if any reports have it
		if (hasMinTimeWarnings) {
			html &= '<div class="min-time-warning">
				   <strong>&##9888; Coverage Warning:</strong> One or more reports may have incomplete coverage data due to minimum execution time filtering. See individual reports for details.
				   </div>';
		}

		if (arrayLen(arguments.results) == 0) {
			html &= '<div class="no-reports">No coverage reports found.</div>';
		} else {
			html &= '<table class="reports-table sortable-table">
				<thead>
					<tr>
						<th data-sort-type="text">Script Name</th>
						<th data-sort-type="numeric">Coverage</th>
						<th data-sort-type="numeric" style="font-style: italic;" data-dir="asc">Percentage (%)</th>
						<th data-sort-type="numeric" data-execution-time-header>' & timeFormatter.getExecutionTimeHeader() & '</th>
						<th data-sort-type="numeric" title="Time spent in called functions">Child Time</th>
						<th data-sort-type="numeric" title="Time spent in own code (Execution - Child)">Own Time</th>
					</tr>
				</thead>
				<tbody>';

			// Sort results by coverage percentage (ascending - worst to best)
			arraySort(arguments.results, function(a, b) {
				var percentA = (isNumeric(a["totalLinesHit"]) && isNumeric(a["totalLinesFound"]) && a["totalLinesFound"] > 0) ? 100.0 * a["totalLinesHit"] / a["totalLinesFound"] : -1;
				var percentB = (isNumeric(b["totalLinesHit"]) && isNumeric(b["totalLinesFound"]) && b["totalLinesFound"] > 0) ? 100.0 * b["totalLinesHit"] / b["totalLinesFound"] : -1;
				return percentA - percentB; // Ascending order (worst first)
			});

			for (var result in arguments.results) {
				// Get required properties from report summary struct (from index.json)
				var scriptName = result["scriptName"];
				var htmlFile = result["htmlFile"];
				var totalLinesHit = result["totalLinesHit"];
				var totalLinesFound = result["totalLinesFound"];
				var percentCovered = (isNumeric(totalLinesHit) && isNumeric(totalLinesFound) && totalLinesFound > 0) ? numberFormat(100.0 * totalLinesHit / totalLinesFound, "0.0") : '-';
				var formattedTime = "";
				// Use totalExecutionTime from stats (in source unit from .exl file)
				var sourceUnit = timeFormatter.getUnitInfo(result.unit).symbol;
				var timeValue = timeFormatter.convertTime(result.totalExecutionTime, sourceUnit, "μs");
				var formattedTime = timeFormatter.format(timeValue);
				var timestamp = result.timestamp;

				// Calculate heatmap classes for coverage percentage and execution time
				var coverageClass = "";
				var executionClass = "";

				// Coverage percentage heatmap
				// For coverage: higher values get higher levels (brighter green)
				if (isNumeric(totalLinesHit) && isNumeric(totalLinesFound) && totalLinesFound > 0 && arrayLen(heatmapData.coverageRanges) > 0) {
					var percentage = 100.0 * totalLinesHit / totalLinesFound;
					var level = heatmapData.bucketCalculator.getValueLevel(percentage, heatmapData.coverageRanges, "asc");
					coverageClass = " coverage-heatmap-level-" & level;
				}

				// Execution time heatmap - include zero values and missing data
				// For execution times: lower values get higher levels (greener)
				if (arrayLen(heatmapData.executionRanges) > 0) {
					var execTime = 0; // Default to 0 for missing execution data
					if (structKeyExists(result, "executionTime") && isNumeric(result["executionTime"])) {
						execTime = result["executionTime"];
					}
					var level = heatmapData.bucketCalculator.getValueLevel(execTime, heatmapData.executionRanges, "desc");
					executionClass = " execution-heatmap-level-" & level;
				}

				// Extract call tree metrics from file stats
				var childTimeSourceUnit = result.totalChildTime;
				// Convert to microseconds for sorting
				var childTimeSort = timeFormatter.convertTime(childTimeSourceUnit, sourceUnit, "μs");
				// Convert to display unit for formatting
				var childTimeDisplayUnit = timeFormatter.convertTime(childTimeSourceUnit, sourceUnit, arguments.displayUnit);
				var childTime = childTimeDisplayUnit > 0 ? timeFormatter.format(childTimeDisplayUnit) : "";

				// Calculate own time (execution time minus child time, both in microseconds)
				var ownTimeValue = timeValue - childTimeSort;
				if (ownTimeValue < 0) ownTimeValue = 0; // Ensure non-negative
				var ownTime = ownTimeValue > 0 ? timeFormatter.format(ownTimeValue) : "";

				// Calculate heatmap classes for child and own time (use source unit values)
				var childTimeClass = "";
				var ownTimeClass = "";
				if (arrayLen(heatmapData.executionRanges) > 0) {
					// Convert own time back to source unit for heatmap calculation
					var ownTimeSourceUnit = timeFormatter.convertTime(ownTimeValue, "μs", sourceUnit);
					var childLevel = heatmapData.bucketCalculator.getValueLevel(childTimeSourceUnit, heatmapData.executionRanges, "desc");
					childTimeClass = " execution-heatmap-level-" & childLevel;
					var ownLevel = heatmapData.bucketCalculator.getValueLevel(ownTimeSourceUnit, heatmapData.executionRanges, "desc");
					ownTimeClass = " execution-heatmap-level-" & ownLevel;
				}

				html &= '<tr data-file-row data-html-file="' & arguments.htmlEncoder.htmlAttributeEncode(htmlFile) & '" data-script-name="' & arguments.htmlEncoder.htmlAttributeEncode(scriptName) & '">';
				html &= '<td class="script-name"><a href="' & arguments.htmlEncoder.htmlAttributeEncode(htmlFile) & '">' & arguments.htmlEncoder.htmlEncode(scriptName) & '</a></td>';
				html &= '<td class="coverage">' & totalLinesHit & ' / ' & totalLinesFound & '</td>';
				html &= '<td class="percentage' & coverageClass & '">' & percentCovered & '</td>';
				// Add data-value with raw microsecond value for proper numeric sorting
				html &= '<td class="execution-time' & executionClass & '" data-execution-time-cell data-value="' & timeValue & '">' & formattedTime & '</td>';
				html &= '<td class="child-time' & childTimeClass & '" data-sort-value="' & childTimeSort & '">' & childTime & '</td>';
				html &= '<td class="own-time' & ownTimeClass & '" data-sort-value="' & ownTimeValue & '">' & ownTime & '</td>';
				html &= '</tr>' & chr(10);
			}

			html &= '</tbody></table>';
		}

			html &= '</div>';

			// Add version footer
			var footer = new lucee.extension.lcov.reporter.HtmlFooter();
			html &= footer.generateFooter();

			html &= htmlAssets.getDarkModeScript();
			html &= htmlAssets.getTableSortScript();
			html &= '</body></html>';
			return html;
	}

	/**
	 * Calculates heatmap data for coverage percentages and execution times
	 * @results Array of result model objects
	 * @return struct containing bucketCalculator, coverage ranges, execution ranges, and css
	 */
	private struct function calculateCoverageHeatmapData(required array results, required any displayUnit) {
		var bucketCalculator = new heatmap.bucketCalculator();
		var cssGenerator = new heatmap.cssGenerator();
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
		var bucketCounts = bucketCalculator.calculateOptimalBucketCounts(coveragePercentages, executionTimes, 5);
		var coverageRanges = [];
		var executionRanges = [];

		// Generate coverage percentage heatmap CSS
		if (arrayLen(coveragePercentages) > 0) {
			coverageRanges = bucketCalculator.calculateRanges(coveragePercentages, bucketCounts.countBucketCount);

			// Coverage: use green gradient - darker for better contrast with white text
			var coverageMinColor = {r: 50, g: 150, b: 50}; // Darker green
			var coverageMaxColor = {r: 0, g: 100, b: 0}; // Very dark green
			arrayAppend(cssRules, cssGenerator.generateCssRules(
				coveragePercentages,
				bucketCounts.countBucketCount,
				"reports-table",
				"percentage.coverage-heatmap-level",
				coverageMinColor,
				coverageMaxColor,
				"asc",
				"%",
				"Coverage Percentage Heatmap"
			), true);
		}

		// Generate execution time heatmap CSS
		if (arrayLen(executionTimes) > 0) {
			executionRanges = bucketCalculator.calculateRanges(executionTimes, bucketCounts.timeBucketCount);

			// Execution time: use blue gradient - medium blue to dark blue
			var executionMinColor = {r: 100, g: 100, b: 200}; // Medium blue
			var executionMaxColor = {r: 0, g: 0, b: 150}; // Dark blue
			arrayAppend(cssRules, cssGenerator.generateCssRules(
				executionTimes,
				bucketCounts.timeBucketCount,
				"reports-table",
				"execution-time.execution-heatmap-level",
				executionMinColor,
				executionMaxColor,
				"desc",
				arguments.displayUnit,
				"Execution Time Heatmap"
			), true);
			// Generate CSS for child-time column (same ranges as execution time)
			arrayAppend(cssRules, cssGenerator.generateCssRules(
				executionTimes,
				bucketCounts.timeBucketCount,
				"reports-table",
				"child-time.execution-heatmap-level",
				executionMinColor,
				executionMaxColor,
				"desc",
				arguments.displayUnit,
				"Child Time Heatmap"
			), true);
			// Generate CSS for own-time column (same ranges as execution time)
			arrayAppend(cssRules, cssGenerator.generateCssRules(
				executionTimes,
				bucketCounts.timeBucketCount,
				"reports-table",
				"own-time.execution-heatmap-level",
				executionMinColor,
				executionMaxColor,
				"desc",
				arguments.displayUnit,
				"Own Time Heatmap"
			), true);
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
