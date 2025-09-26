
component {
	/**
	 * Generates the HTML for a single file's coverage section.
	 * @fileIndex The canonical file index (numeric)
	 * @result The result object (model/result.cfc)
	 */
	public string function generateFileSection(required numeric fileIndex, required result result,
				required any htmlEncoder, required any heatmapCalculator, required any displayUnit) localmode=true {
		var legend = new HtmlLegend();
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter();

		var filePath = result.getFileItem(arguments.fileIndex, "path");
		var html = generateFileHeader(arguments.fileIndex, filePath, arguments.result, arguments.htmlEncoder);

		var stats = result.getFileItem(arguments.fileIndex);
		var totalExecutionTime = result.getStatsProperty("totalExecutionTime");
		var unitName = result.getMetadataProperty("unit");
		var sourceUnit = timeFormatter.getUnitInfo(unitName).symbol;
		html &= generateStatsSection(stats, totalExecutionTime, timeFormatter, sourceUnit, arguments.displayUnit);
		if ( result.getFileItem(arguments.fileIndex, "linesHit") eq 0 )
			throw "No coverage data for fileIndex: " & arguments.fileIndex & " (linesHit is zero)";
			
		var coverage = result.getCoverageForFile(arguments.fileIndex);
		var fileLines = result.getFileLines(arguments.fileIndex);
		var executableLines = result.getExecutableLines(arguments.fileIndex);

		var tableClass = "file-table-" & left(hash(filePath, "md5"), 8);

		// Generate heatmaps
		var executionData = extractExecutionData(coverage, fileLines);
		var heatmapData = generateHeatmaps(executionData.countValues, executionData.timeValues, tableClass, heatmapCalculator);

		html &= generateTableHeader(tableClass, displayUnit, heatmapData.cssRules);
		html &= generateTableRows(coverage, fileLines, executableLines,
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
				var timeVal = lineData[2];
				if (countVal > 0) arrayAppend(countValues, countVal);
				if (timeVal > 0) arrayAppend(timeValues, timeVal);
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
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter();
		var html = '<style>' & chr(10) & chr(9) & arrayToList(arguments.cssRules, chr(10) & chr(9)) & chr(10) & '</style>';
		html &= '<table class="code-table sortable-table ' & arguments.tableClass & '">'
			& '<thead>'
				& '<tr>'
					& '<th class="line-number" data-sort-type="numeric">Line</th>'
					& '<th class="code-cell" data-sort-type="text">Code</th>'
					& '<th class="exec-count" data-sort-type="numeric">Count</th>'
					& '<th class="exec-time" data-sort-type="numeric" data-execution-time-header>' & timeFormatter.getExecutionTimeHeader(arguments.displayUnit) & '</th>'
				& '</tr>'
			& '</thead>'
			& '<tbody>';
		return html;
	}

	/**
	 * Generates the table rows HTML
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
	private string function generateTableRows(required struct coverage, required array fileLines,
			required struct executableLines, required struct countHeatmap, required struct timeHeatmap,
			required any htmlEncoder, required any timeFormatter, required string sourceUnit, required string displayUnit) {
		var html = "";
		var nl = chr(10);

		for (var i = 1; i <= arrayLen(arguments.fileLines); i++) {
			var lineData = arguments.coverage[i] ?: [];
			var hasData = arrayLen(lineData) > 0;
			var rowClass = hasData ? "executed" : (structKeyExists(arguments.executableLines, i) ? "not-executed" : "non-executable");

			var execCount = "";
			var execTime = "";
			var countClass = "exec-count";
			var timeClass = "exec-time";

			if (hasData) {
				var countVal = lineData[1];
				var timeVal = lineData[2];

				execCount = countVal > 0 ? numberFormat(countVal) : "";

				// Format execution time
				if (timeVal > 0) {
					var timeMicros = arguments.timeFormatter.convertTime(timeVal, arguments.sourceUnit, "μs");
					execTime = arguments.timeFormatter.formatTime(timeMicros, arguments.displayUnit, true); // Include units
				}

				// Apply heatmap classes
				if (countVal > 0) {
					var additionalCountClass = arguments.countHeatmap.getValueClass(countVal);
					if (additionalCountClass != "") countClass &= " " & additionalCountClass;
				}

				if (timeVal > 0) {
					var additionalTimeClass = arguments.timeHeatmap.getValueClass(timeVal);
					if (additionalTimeClass != "") timeClass &= " " & additionalTimeClass;
				}
			}

			html &= '<tr class="' & rowClass & '" data-line-row data-line-number="' & i & '" data-line-hit="' & (hasData ? "true" : "false") & '">'  & nl
				& '<td class="line-number">' & i & '</td>' & nl
				& '<td class="code-cell">' & arguments.htmlEncoder.htmlEncode(arguments.fileLines[i]) & '</td>' & nl
				& '<td class="' & countClass & '">' & execCount & '</td>' & nl
				& '<td class="' & timeClass & '" data-execution-time-cell data-sort-value="' & (hasData && arrayLen(lineData) >= 2 ? arguments.timeFormatter.convertTime(lineData[2], arguments.sourceUnit, "μs") : 0) & '">' & execTime & '</td>' & nl
				& '</tr>' & nl;
		}

		return html;
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
				"exec-count.count-level",
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
				"exec-time.time-level",
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
			required result result, required any htmlEncoder) {
		var vscodeLink = "vscode://file/" & replace(arguments.filePath, "\", "/", "all");
		return '<div class="file-section" data-file-section data-file-index="' & arguments.fileIndex & '" data-filename="' & arguments.htmlEncoder.htmlAttributeEncode(arguments.filePath) & '">'
			& '<div class="file-header">'
				& '<h3><a href="' & vscodeLink & '" class="file-header-link">'
				& arguments.htmlEncoder.htmlEncode(arguments.result.getFileDisplayPath(arguments.filePath))
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
		var timeDisplay = arguments.timeFormatter.formatTime(totalExecutionTimeMicros, arguments.displayUnit);
		return '<div class="stats">'
			& '<strong>Lines Executed:</strong> <span class="lines-executed">' & numberFormat(arguments.stats.totalExecutions) & '</span> | '
			& '<strong>Total Execution Time:</strong> <span class="total-execution-time">' & timeDisplay & '</span> | '
			& '<strong>Lines Covered:</strong> <span class="lines-covered">' & arguments.stats.linesHit & ' of ' & arguments.stats.linesFound & '</span>'
			& '</div>';
	}
}
