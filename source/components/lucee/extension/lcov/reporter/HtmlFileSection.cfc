
component {
	/**
	 * Generates the HTML for a single file's coverage section.
	 * @fileIndex The canonical file index (numeric)
	 * @result The result object (model/result.cfc)
	 */
	public string function generateFileSection(required numeric fileIndex, required result result, 
				required any htmlEncoder, required any heatmapCalculator, required any displayUnit) {
		var legend = new HtmlLegend();
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
		var totalExecution = result.getTotalExecutionTimeStruct(displayUnit.name);
		var timeDisplay = numberFormat(totalExecution.time) & " " & totalExecution.unit;
		html &= '<div class="stats">'
			& '<strong>Lines Executed:</strong> ' & stats.totalExecutions & ' | '
			& '<strong>Total Execution Time:</strong> ' & timeDisplay & ' | '
			& '<strong>Lines Covered:</strong> ' & stats.linesHit & ' of ' & stats.linesFound
			& '</div>';

		var executedLines = result.getCoverageForFile(arguments.fileIndex);
		var fileLines = result.getFileLines(arguments.fileIndex);
		var executableLines = result.getExecutableLines(arguments.fileIndex);

		var hashValue = hash(filePath, "md5");
		var fileId = "file-" & left(hashValue, 8);
		var tableClass = "file-table-" & fileId;

		var heatmapData = heatmapCalculator.calculateHeatmapStyles(executedLines, fileLines, tableClass);
		var cssRules = heatmapData.cssRules;
		var lineClasses = heatmapData.lineClasses;

		html &= '<style>' & chr(10) & chr(9) & arrayToList(cssRules, chr(10) & chr(9)) & chr(10) & '</style>';
		html &= '<table class="code-table ' & tableClass & '">'
			& '<thead>'
				& '<tr>'
					& '<th class="line-number">Line</th>'
					& '<th class="code-cell">Code</th>'
					& '<th class="exec-count">Count</th>'
					& '<th class="exec-time">Time (' & displayUnit.symbol & ')</th>'
				& '</tr>'
			& '</thead>'
			& '<tbody>';

		for (var i = 1; i <= arrayLen(fileLines); i++) {
			var lineKey = toString(i);
			var lineData = structKeyExists(executedLines, lineKey) ? executedLines[lineKey] : [];
			var len = arrayLen(lineData);
			var isExecutable = structIsEmpty(executableLines) || structKeyExists(executableLines, lineKey);
			var rowClass = len > 0 ? "executed" : (isExecutable ? "not-executed" : "non-executable");
			var execCount = (len >= 1 && lineData[1] ?: 0) > 0 ? numberFormat(lineData[1]) : "";
			var execTime = "";
			if (len >= 2 && isNumeric(lineData[2])) {
				// Has execution time data (including zero)
				var htmlUtils = new lucee.extension.lcov.reporter.HtmlUtils();
				var execTimeStruct = htmlUtils.convertTimeUnit(lineData[2], "μs", displayUnit);
				execTime = execTimeStruct.time & " " & execTimeStruct.unit;
			}
			var classes = lineClasses[lineKey];
			var countClass = isStruct(classes) && classes.countClass != "" ? "exec-count " & classes.countClass : "exec-count";
			var timeClass = isStruct(classes) && classes.timeClass != "" ? "exec-time " & classes.timeClass : "exec-time";

			html &= '<tr class="' & rowClass & '" data-line-row data-line-number="' & i & '" data-line-hit="' & (len > 0 ? "true" : "false") & '">' 
				& '<td class="line-number">' & i & '</td>'
				& '<td class="code-cell">' & htmlEncoder.htmlEncode(fileLines[i]) & '</td>'
				& '<td class="' & countClass & '">' & execCount & '</td>'
				& '<td class="' & timeClass & '">' & execTime & '</td>'
				& '</tr>';
		}

		html &= '</tbody></table>';
		html &= legend.generateLegendHtml();
		html &= '</div></div>';
		return html;
	}
}
