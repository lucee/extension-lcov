
component {
	/**
	 * Generates the HTML for a single file's coverage section.
	 * @fileIndex The canonical file index (numeric)
	 * @result The result object (model/result.cfc)
	 */
	public string function generateFileSection(required numeric fileIndex, required result result, 
				required any htmlEncoder, required any heatmapCalculator, required any displayUnit) localmode=true {
		var legend = new HtmlLegend();
		var htmlUtils = new lucee.extension.lcov.reporter.HtmlUtils();
		// Look up filePath from the model using fileIndex
		var fileData = result.getFiles()[arguments.fileIndex];
		if (!isStruct(fileData) || !structKeyExists(fileData, "path")) {
			throw "No file path found for fileIndex: " & arguments.fileIndex;
		}
		var filePath = fileData.path;
		var vscodeLink = "vscode://file/" & replace(filePath, "\", "/", "all");
		if (!structKeyExists(result.getCoverage(), arguments.fileIndex)) {
			throw "No coverage data for fileIndex: " & arguments.fileIndex & " (no fileIndex mapping found)";
		}
		var html = '<div class="file-section" data-file-section data-file-index="' & arguments.fileIndex & '" data-filename="' & htmlEncoder.htmlAttributeEncode(filePath) & '">'
			& '<div class="file-header">'
				& '<h3><a href="' & vscodeLink & '" class="file-header-link">'
				& htmlEncoder.htmlEncode(result.getFileDisplayPath(filePath))
				& '</a></h3>'
			& '</div>'
			& '<div class="file-content">';

		var stats = result.getFileItem(arguments.fileIndex);
		if (!isStruct(stats) || !structKeyExists(stats, "linesFound") || !structKeyExists(stats, "linesHit")) {
			throw "Missing per-file coverage stats for fileIndex: " & arguments.fileIndex;
		}
		var totalExecutionTime = result.getStatsProperty("totalExecutionTime");
		// Convert totalExecutionTime to microseconds (formatTime expects μs) based on metadata unit
		var sourceUnit = result.getMetadataProperty("unit", "μs");
		var totalExecutionTimeMicros = htmlUtils.convertTime(totalExecutionTime, sourceUnit, "μs");
		var timeDisplay = htmlUtils.formatTime(totalExecutionTimeMicros, displayUnit.symbol, 2);
		html &= '<div class="stats">'
			& '<strong>Lines Executed:</strong> <span class="lines-executed">' & numberFormat(stats.totalExecutions) & '</span> | '
			& '<strong>Total Execution Time:</strong> <span class="total-execution-time">' & timeDisplay & '</span> | '
			& '<strong>Lines Covered:</strong> <span class="lines-covered">' & stats.linesHit & ' of ' & stats.linesFound & '</span>'
			& '</div>';

		var coverage = result.getCoverageForFile(arguments.fileIndex);
		var fileLines = result.getFileLines(arguments.fileIndex);
		var executableLines = result.getExecutableLines(arguments.fileIndex);

		var hashValue = hash(filePath, "md5");
		var fileId = "file-" & left(hashValue, 8);
		var tableClass = "file-table-" & fileId;

		// Extract data and create agnostic heatmaps
		var countValues = [];
		var timeValues = [];

		for (var i = 1; i <= arrayLen(fileLines); i++) {
			var lineKey = i; //toString(i);
			var lineData = structKeyExists(coverage, lineKey) ? coverage[lineKey] : [];
			var len = arrayLen(lineData);

			if (len > 0) {
				if (len != 2) {
					throw(type="InvalidDataStructure", message="Line execution data must contain exactly 2 elements [count, time]", detail="Line #i# has #len# elements: #serializeJSON(lineData)#");
				}

				var countVal = lineData[1] ?: 0;
				var timeVal = lineData[2] ?: 0;
				if (countVal > 0) arrayAppend(countValues, countVal);
				if (isNumeric(lineData[2])) arrayAppend(timeValues, timeVal);
			}
		}

		var cssRules = [];
		var countHeatmap = {};
		var timeHeatmap = {};

		// Generate count heatmap (red colors)
		if (arrayLen(countValues) > 0) {
			var countMinColor = {r: 200, g: 100, b: 100}; // Medium red
			var countMaxColor = {r: 150, g: 0, b: 0}; // Dark red
			countHeatmap = heatmapCalculator.generate(
				countValues,
				min(5, max(1, arrayLen(countValues))),
				tableClass,
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
		if (arrayLen(timeValues) > 0) {
			var timeMinColor = {r: 100, g: 100, b: 200}; // Medium blue
			var timeMaxColor = {r: 0, g: 0, b: 150}; // Dark blue
			timeHeatmap = heatmapCalculator.generate(
				timeValues,
				min(10, max(1, arrayLen(timeValues))),
				tableClass,
				"exec-time.time-level",
				timeMinColor,
				timeMaxColor,
				"desc",
				"μs",
				"Execution Time Heatmap"
			);
			arrayAppend(cssRules, timeHeatmap.cssRules, true);
		}

		html &= '<style>' & chr(10) & chr(9) & arrayToList(cssRules, chr(10) & chr(9)) & chr(10) & '</style>';
		html &= '<table class="code-table sortable-table ' & tableClass & '">'
			& '<thead>'
				& '<tr>'
					& '<th class="line-number" data-sort-type="numeric">Line</th>'
					& '<th class="code-cell" data-sort-type="text">Code</th>'
					& '<th class="exec-count" data-sort-type="numeric">Count</th>'
					& '<th class="exec-time" data-sort-type="numeric" data-execution-time-header>Time (' & displayUnit.symbol & ')</th>'
				& '</tr>'
			& '</thead>'
			& '<tbody>';

		for (var i = 1; i <= arrayLen(fileLines); i++) {
			var lineKey = i;// toString(i);
			var lineData = structKeyExists(coverage, lineKey) ? coverage[lineKey] : [];
			var len = arrayLen(lineData);
			var isExecutable = structIsEmpty(executableLines) || structKeyExists(executableLines, lineKey);
			var rowClass = len > 0 ? "executed" : (isExecutable ? "not-executed" : "non-executable");
			var execCount = (len >= 1 && lineData[1] ?: 0) > 0 ? numberFormat(lineData[1]) : "";
			var execTime = "";
			if (len >= 2 && isNumeric(lineData[2])) {
				// Has execution time data (including zero)
				// Use actual source unit from metadata like the total execution time does
				var convertedTime = htmlUtils.convertTime(lineData[2], sourceUnit, displayUnit.symbol);
				// For discrete units (ns, μs, ms), show as integers. For seconds, show with decimals.
				if (displayUnit.symbol == "s") {
					execTime = numberFormat(convertedTime, "0.0000");
				} else {
					// For ns, μs, ms - no decimal places
					execTime = numberFormat(convertedTime, "0");
				}
			}
			// Use heatmap functions to get classes
			var countClass = "exec-count";
			var timeClass = "exec-time";

			if (len > 0) {
				var countVal = lineData[1] ?: 0;
				var timeVal = lineData[2] ?: 0;

				if (countVal > 0 && structKeyExists(countHeatmap, "getValueClass")) {
					var additionalCountClass = countHeatmap.getValueClass(countVal);
					if (additionalCountClass != "") countClass &= " " & additionalCountClass;
				}

				if (len >= 2 && isNumeric(lineData[2]) && structKeyExists(timeHeatmap, "getValueClass")) {
					var additionalTimeClass = timeHeatmap.getValueClass(timeVal);
					if (additionalTimeClass != "") timeClass &= " " & additionalTimeClass;
				}
			}
			var nl = chr(10);
			html &= '<tr class="' & rowClass & '" data-line-row data-line-number="' & i & '" data-line-hit="' & (len > 0 ? "true" : "false") & '">'  & nl
				& '<td class="line-number">' & i & '</td>' & nl
				& '<td class="code-cell">' & htmlEncoder.htmlEncode(fileLines[i]) & '</td>' & nl
				& '<td class="' & countClass & '">' & execCount & '</td>' & nl
				& '<td class="' & timeClass & '" data-execution-time-cell>' & execTime & '</td>' & nl
				& '</tr>' & nl;
		}

		html &= '</tbody></table>';
		html &= legend.generateLegendHtml();
		html &= '</div></div>';
		return html;
	}
}
