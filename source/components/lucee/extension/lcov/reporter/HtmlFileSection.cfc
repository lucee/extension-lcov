
component {
	/**
	 * Generates the HTML for a single file's coverage section.
	 * @fileIndex The canonical file index (numeric)
	 * @result The result object (model/result.cfc)
	 */
	public string function generateFileSection(required numeric fileIndex, required result result,
				required any htmlEncoder, required any heatmapCalculator, required any displayUnit) localmode=true {
		var legend = new HtmlLegend();
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.displayUnit);
		var fileUtils = new lucee.extension.lcov.reporter.FileUtils();

		var filePath = result.getFileItem(arguments.fileIndex, "path");
		var html = generateFileHeader(arguments.fileIndex, filePath, arguments.result, arguments.htmlEncoder, fileUtils);

		var stats = result.getFileItem(arguments.fileIndex);
		var totalExecutionTime = result.getStatsProperty("totalExecutionTime");
		var unitName = result.getMetadataProperty("unit");
		var sourceUnit = timeFormatter.getUnitInfo(unitName).symbol;
		html &= generateStatsSection(stats, totalExecutionTime, timeFormatter, sourceUnit, arguments.displayUnit);

		var coverage = result.getCoverageForFile(arguments.fileIndex);
		var fileLines = result.getFileLines(arguments.fileIndex);

		var tableClass = "file-table-" & left(hash(filePath, "md5"), 8);

		// Generate heatmaps
		var executionData = extractExecutionData(coverage, fileLines);
		var heatmapData = generateHeatmaps(executionData.countValues, executionData.timeValues, tableClass, heatmapCalculator);

		html &= generateTableHeader(tableClass, displayUnit, heatmapData.cssRules);
		html &= generateTableRows(arguments.fileIndex, coverage, fileLines,
			heatmapData.countHeatmap, heatmapData.timeHeatmap,
			htmlEncoder, timeFormatter, sourceUnit, displayUnit);

		html &= '</tbody></table>';
		html &= legend.generateLegendHtml();
		html &= '</div></div>';
		return html;
	}

	/**
	 * Extracts count and time values from coverage data for heatmap generation
	 * @coverage The coverage data structure
	 * @fileLines Array of file lines
	 * @return Struct with countValues and timeValues arrays
	 */
	private struct function extractExecutionData(required struct coverage, required array fileLines) {
		var countValues = [];
		var timeValues = [];

		for (var i = 1; i <= arrayLen(arguments.fileLines); i++) {
			var lineData = arguments.coverage[i] ?: [];

			if (arrayLen(lineData) > 0) {
				var countVal = lineData[1];
				var ownTime = lineData[2];
				var childTime = lineData[3];
				// Total execution time = ownTime + childTime
				var totalTime = ownTime + childTime;

				if (countVal > 0) arrayAppend(countValues, countVal);
				if (totalTime > 0) arrayAppend(timeValues, totalTime);
			}
		}

		return {
			countValues: countValues,
			timeValues: timeValues
		};
	}


	/**
	 * Generates the table header HTML
	 * @tableClass CSS class for the table
	 * @displayUnit The display unit object with symbol
	 * @cssRules Array of CSS rules to include
	 * @return String HTML for the table opening and header
	 */
	private string function generateTableHeader(required string tableClass, required string displayUnit, required array cssRules) {
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(arguments.displayUnit);
		// Don't include unit in header if displayUnit is "auto" (unit varies by value)
		var unitSuffix = arguments.displayUnit == "auto" ? "" : " (" & timeFormatter.getUnitInfo(arguments.displayUnit).symbol & ")";
		var html = '<style>' & chr(10) & chr(9) & arrayToList(arguments.cssRules, chr(10) & chr(9)) & chr(10) & '</style>';
		html &= '<table class="code-table sortable-table ' & arguments.tableClass & '">'
			& '<thead>'
				& '<tr>'
					& '<th class="line-number" data-sort-type="numeric">Line</th>'
					& '<th class="code-cell" data-sort-type="text">Code</th>'
					& '<th class="exec-count" data-sort-type="numeric">Count</th>'
					& '<th class="total-time" data-sort-type="numeric" data-execution-time-header>Total' & unitSuffix & '</th>'
					& '<th class="child-time" data-sort-type="numeric">Child' & unitSuffix & '</th>'
					& '<th class="own-time" data-sort-type="numeric">Own' & unitSuffix & '</th>'
				& '</tr>'
			& '</thead>'
			& '<tbody>';
		return html;
	}

	/**
	 * Generates the table rows HTML
	 * @fileIndex The canonical file index (numeric)
	 * @coverage The coverage data structure
	 * @fileLines Array of file lines
	 * @executableLines Structure of executable lines
	 * @countHeatmap Count heatmap object
	 * @timeHeatmap Time heatmap object
	 * @htmlEncoder HTML encoder
	 * @timeFormatter Time formatter
	 * @sourceUnit Source time unit
	 * @displayUnit Display unit object
	 * @return String HTML for table rows
	 */
	private string function generateTableRows(required numeric fileIndex, required struct coverage, required array fileLines,
			required struct countHeatmap, required struct timeHeatmap,
			required any htmlEncoder, required any timeFormatter, required string sourceUnit, required string displayUnit) {
		// Use array for StringBuilder pattern - much faster than string concatenation
		var htmlParts = [];
		var nl = chr(10);

		// Pre-cache for performance
		var fileLineCount = arrayLen(arguments.fileLines);

		// Reserve capacity to minimize array resizing (7 parts per row for 6 columns)
		arrayResize(htmlParts, fileLineCount * 7);
		var partIndex = 0;

		for (var i = 1; i <= fileLineCount; i++) {
			var lineData = arguments.coverage[i] ?: [];
			var hasData = arrayLen(lineData) > 0 && lineData[1] > 0;  // Check hitCount > 0, not just array existence
			// Coverage now contains all executable lines (including zero-counts), so check coverage keys
			var rowClass = hasData ? "executed" : (structKeyExists(arguments.coverage, i) ? "not-executed" : "non-executable");

			var execCount = "";
			var totalTime = "";
			var childTime = "";
			var ownTime = "";
			var countClass = "exec-count";
			var totalTimeClass = "total-time";
			var childTimeClass = "child-time";
			var ownTimeClass = "own-time";
			var totalTimeSortValue = 0;
			var childTimeSortValue = 0;
			var ownTimeSortValue = 0;

			if (hasData) {
				var countVal = lineData[1];
				var ownTimeVal = lineData[2];
				var childTimeVal = lineData[3];

				execCount = countVal > 0 ? numberFormat(countVal) : "";

				// Calculate total time (own + child)
				var totalTimeVal = ownTimeVal + childTimeVal;
				if (totalTimeVal > 0) {
					var totalTimeMicros = arguments.timeFormatter.convertTime(totalTimeVal, arguments.sourceUnit, "μs");
					totalTime = arguments.timeFormatter.format(totalTimeMicros);
					totalTimeSortValue = totalTimeMicros;
					var additionalTotalTimeClass = arguments.timeHeatmap.getValueClass(totalTimeVal);
					if (additionalTotalTimeClass != "") totalTimeClass &= " " & additionalTotalTimeClass;
				}

				// Format child time if present
				if (childTimeVal > 0) {
					var childTimeMicros = arguments.timeFormatter.convertTime(childTimeVal, arguments.sourceUnit, "μs");
					childTime = arguments.timeFormatter.format(childTimeMicros);
					childTimeSortValue = childTimeMicros;
					var additionalChildTimeClass = arguments.timeHeatmap.getValueClass(childTimeVal);
					if (additionalChildTimeClass != "") childTimeClass &= " " & additionalChildTimeClass;
				}

				// Format own time if present
				if (ownTimeVal > 0) {
					var ownTimeMicros = arguments.timeFormatter.convertTime(ownTimeVal, arguments.sourceUnit, "μs");
					ownTime = arguments.timeFormatter.format(ownTimeMicros);
					ownTimeSortValue = ownTimeMicros;
					var additionalOwnTimeClass = arguments.timeHeatmap.getValueClass(ownTimeVal);
					if (additionalOwnTimeClass != "") ownTimeClass &= " " & additionalOwnTimeClass;
				}

				// Apply heatmap classes for count
				if (countVal > 0) {
					var additionalCountClass = arguments.countHeatmap.getValueClass(countVal);
					if (additionalCountClass != "") countClass &= " " & additionalCountClass;
				}
			}

			// Build HTML using array parts (StringBuilder pattern)
			htmlParts[++partIndex] = '<tr class="' & rowClass & '" data-line-row data-line-number="' & i & '" data-line-hit="' & (hasData ? "true" : "false") & '">' & nl;
			htmlParts[++partIndex] = '<td class="line-number"><a href="##F' & arguments.fileIndex & '-L' & i & '" id="F' & arguments.fileIndex & '-L' & i & '" class="line-anchor">' & i & '</a></td>' & nl;
			htmlParts[++partIndex] = '<td class="code-cell">' & arguments.htmlEncoder.htmlEncode(arguments.fileLines[i]) & '</td>' & nl;
			htmlParts[++partIndex] = '<td class="' & countClass & '">' & execCount & '</td>' & nl;
			htmlParts[++partIndex] = '<td class="' & totalTimeClass & '" data-execution-time-cell data-sort-value="' & totalTimeSortValue & '">' & totalTime & '</td>' & nl;
			htmlParts[++partIndex] = '<td class="' & childTimeClass & '" data-child-time-cell data-sort-value="' & childTimeSortValue & '">' & childTime & '</td>' & nl;
			htmlParts[++partIndex] = '<td class="' & ownTimeClass & '" data-own-time-cell data-sort-value="' & ownTimeSortValue & '">' & ownTime & '</td>' & nl;
			htmlParts[++partIndex] = '</tr>' & nl;
		}

		// Single join at the end - much faster than repeated concatenation
		return arrayToList(htmlParts, "");
	}

	/**
	 * Generates heatmaps and CSS rules for count and time data
	 * @countValues Array of execution count values
	 * @timeValues Array of execution time values
	 * @tableClass CSS class for the table
	 * @heatmapCalculator The heatmap calculator instance
	 * @return Struct with countHeatmap, timeHeatmap, and cssRules
	 */
	private struct function generateHeatmaps(required array countValues, required array timeValues,
			required string tableClass, required any heatmapCalculator) {
		var cssRules = [];
		var countHeatmap = {};
		var timeHeatmap = {};

		// Generate count heatmap (red colors)
		if (arrayLen(arguments.countValues) > 0) {
			var countMinColor = {r: 200, g: 100, b: 100}; // Medium red
			var countMaxColor = {r: 150, g: 0, b: 0}; // Dark red
			countHeatmap = arguments.heatmapCalculator.generate(
				arguments.countValues,
				min(5, max(1, arrayLen(arguments.countValues))),
				arguments.tableClass,
				"count-level",
				countMinColor,
				countMaxColor,
				"asc",
				"",
				"Execution Count Heatmap"
			);
			arrayAppend(cssRules, countHeatmap.cssRules, true);
		}

		// Generate time heatmap (blue colors)
		if (arrayLen(arguments.timeValues) > 0) {
			var timeMinColor = {r: 100, g: 100, b: 200}; // Medium blue
			var timeMaxColor = {r: 0, g: 0, b: 150}; // Dark blue
			timeHeatmap = arguments.heatmapCalculator.generate(
				arguments.timeValues,
				min(10, max(1, arrayLen(arguments.timeValues))),
				arguments.tableClass,
				"time-level",
				timeMinColor,
				timeMaxColor,
				"desc",
				"μs",
				"Execution Time Heatmap"
			);
			arrayAppend(cssRules, timeHeatmap.cssRules, true);
		}

		return {
			countHeatmap: countHeatmap,
			timeHeatmap: timeHeatmap,
			cssRules: cssRules
		};
	}


	/**
	 * Generates the initial HTML structure and header
	 * @fileIndex The canonical file index
	 * @filePath The file path
	 * @result The result object
	 * @htmlEncoder HTML encoder
	 * @return String HTML for file header section
	 */
	private string function generateFileHeader(required numeric fileIndex, required string filePath,
			required result result, required any htmlEncoder, required any fileUtils) {
		var vscodeLink = "vscode://file/" & replace(arguments.filePath, "\", "/", "all");
		return '<div class="file-section" data-file-section data-file-index="' & arguments.fileIndex & '" data-filename="' & arguments.htmlEncoder.htmlAttributeEncode(arguments.filePath) & '">'
			& '<div class="file-header">'
				& '<h3><a href="' & vscodeLink & '" class="file-header-link">'
				& arguments.htmlEncoder.htmlEncode(arguments.fileUtils.safeContractPath(arguments.filePath))
				& '</a></h3>'
			& '</div>'
			& '<div class="file-content">';
	}

	/**
	 * Generates the stats section HTML
	 * @stats File statistics
	 * @totalExecutionTime Total execution time
	 * @timeFormatter Time formatter
	 * @sourceUnit Source time unit
	 * @displayUnit Display unit object
	 * @return String HTML for stats section
	 */
	private string function generateStatsSection(required struct stats, required numeric totalExecutionTime,
			required any timeFormatter, required string sourceUnit, required string displayUnit) {
		var totalExecutionTimeMicros = arguments.timeFormatter.convertTime(arguments.totalExecutionTime, arguments.sourceUnit, "μs");
		var timeDisplay = arguments.timeFormatter.formatTime(totalExecutionTimeMicros, arguments.displayUnit, true);

		// Format Child Time if available (convert from source unit to microseconds)
		var childTimeDisplay = "";
		if (structKeyExists(arguments.stats, "totalChildTime") && arguments.stats.totalChildTime > 0) {
			var childTimeMicros = arguments.timeFormatter.convertTime(arguments.stats.totalChildTime, arguments.sourceUnit, "μs");
			childTimeDisplay = ' | <strong>Child Time:</strong> <span class="child-time">' & arguments.timeFormatter.formatTime(childTimeMicros, arguments.displayUnit, true) & '</span>';
		}

		return '<div class="stats">'
			& '<strong>Lines Executed:</strong> <span class="lines-executed">' & numberFormat(arguments.stats.totalExecutions) & '</span> | '
			& '<strong>Total Execution Time:</strong> <span class="total-execution-time">' & timeDisplay & '</span> | '
			& '<strong>Lines Covered:</strong> <span class="lines-covered">' & arguments.stats.linesHit & ' of ' & arguments.stats.linesFound & '</span>'
			& childTimeDisplay
			& '</div>';
	}
}
