/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {
	
	// Instance variable for HTML assets
	variables.htmlAssets = new HtmlAssets();
	
	// Instance variable for heatmap calculations
	variables.heatmapCalculator = new Heatmap();
	
	// Instance variable to store display unit
	variables.displayUnit = "micro";
	
	/**
	* Constructor/init function
	*/
	public HtmlWriter function init(string displayUnit = "micro") {
		variables.displayUnit = getUnitInfo(arguments.displayUnit);
		return this;
	}

	/**
	* Generates the HTML content for the execution report
	*/
	public string function generateHtmlContent(struct result) {
		var scriptName = result.metadata["script-name"];
		var originalUnit = result.metadata["unit"] ?: "μs";
		
		// Convert execution time and get display unit info
		var executionTime = result.metadata["execution-time"] ?: "N/A";
		var executionTime = convertTimeUnit(executionTime, originalUnit, variables.displayUnit);

		var fileCoverageJson = replace(arguments.result.exeLog, ".exl", "-fileCoverage.json");
		
		// Calculate total coverage summary
		var totalLinesFound = arguments.result.stats.totalLinesFound ?: 0;
		var totalLinesHit = arguments.result.stats.totalLinesHit ?: 0;
		var coveragePercent = totalLinesFound > 0 ? numberFormat(100.0 * totalLinesHit / totalLinesFound, "9.9") : "0.0";
		
		var html = '<!DOCTYPE html>
	<html lang="en">
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>' & encodeForHtml(scriptName) & ' - Execution Report</title>
		<style>' & variables.htmlAssets.getCommonCss() & '</style>
	</head>
	<body>
		<div class="container">
			<div class="header-section">
				<div class="header-top">
					<div class="header-content">
						<h2 class="report-type">Lucee Code Coverage Report</h2>
						<h1>' & encodeForHtml(scriptName) & ' <span class="file-path-subtitle">('
							& encodeForHtml(executionTime.time) 
							& ' ' & encodeForHtml(executionTime.unit) & ')</span></h1>
					</div>
					<button id="dark-mode-toggle" class="dark-mode-toggle" onclick="toggleDarkMode()" title="Toggle dark mode">
						<span class="toggle-icon">&##127769;</span>
					</button>
				</div>
				<div class="timestamp">Generated: ' & lsDateTimeFormat(now()) & '</div>
				<div class="coverage-summary">
					<strong>Coverage Summary:</strong> ' & totalLinesHit & ' of ' & totalLinesFound & ' lines covered (' & coveragePercent & '%)
				</div>
			</div>
			<a href="index.html" class="back-link">Back to Index</a>
			<p class="file-links"><strong>Log Files:</strong> <a href="'
				& encodeForHtmlAttribute(arguments.result.exeLog) & '" target="_blank" class="file-link">'
				& encodeForHtml(listLast(arguments.result.exeLog, "/\\"))
				& '</a> &nbsp;|&nbsp; <strong>Coverage JSON:</strong>'
				& ' <a href="' & encodeForHtmlAttribute(fileCoverageJson) & '" target="_blank" class="file-link">'
					& encodeForHtml(listLast(fileCoverageJson, "/\\")) & '</a></p>';

		for (var filePath in arguments.result.source.files ) {
			// Only show files that are in the files (were referenced in this .exl file)
			html &= generateFileSection( filePath, result );
		}

		html &= '
		</div>';
		
		// Add dark mode toggle script
		html &= variables.htmlAssets.getDarkModeScript();
		
		html &= '
	</body>
	</html>';
		return html;
	}

	/**
	* Generates HTML section for a single file showing covered lines
	*/
	private string function generateFileSection( string filePath, struct result ) {
		
		// Create VS Code link for the file
		var vscodeLink = "vscode://file/" & replace( arguments.filePath, "\", "/", "all" );
		if ( !structKeyExists( arguments.result.coverage, arguments.filePath ) ) {
			systemOutput( " -----error ", true );
			systemOutput( serializeJSON( var=result, compact=false ), true );
			throw "No coverage data for file: " & arguments.filePath;
		}
		var html = '<div class="file-section">
			<div class="file-header">
				<h3><a href="' & vscodeLink & '" class="file-header-link">'
					& encodeForHtml( contractPath( arguments.result.source.files[ arguments.filePath] .path ) )
				& '</a></h3>
			</div>
			<div class="file-content">';

		var totalExecutions = arguments.result.stats.totalExecutions;
		var totalExecution = convertTimeUnit(arguments.result.stats.totalExecutionTime, "μs", variables.displayUnit);
		var stats = arguments.result.stats.files[ arguments.filePath ];
		
		var timeDisplay = totalExecution.time & " " & totalExecution.unit;
		html &= '<div class="stats">
			<strong>Executions:</strong> ' & totalExecutions & ' |
			<strong>Total Execution Time:</strong> ' & timeDisplay & ' |
			<strong>Lines Covered:</strong> ' & stats.linesHit & ' of ' & stats.linesFound & '
		</div>';

		// PASS 1: Calculate all intensities and generate scoped CSS
		var executedLines = arguments.result.coverage[ arguments.filePath ];
		var fileLines = arguments.result.source.files[ arguments.filePath ].lines;
		var executableLines = {};
		if (structKeyExists(arguments.result.source.files[arguments.filePath], "executableLines")) {
			executableLines = arguments.result.source.files[arguments.filePath].executableLines;
		}

		// Create unique CSS class identifier from file path
		var hashValue = hash(arguments.filePath, "md5");
		var fileId = "file-" & left(hashValue, 8);
		var tableClass = "file-table-" & fileId;

		// Calculate max values for color coding
		var maxCount = 0;
		var maxTime = 0;
		for ( var lineNum in executedLines)  {
			if ( executedLines[ lineNum ][ 1 ] > maxCount ) {
				maxCount = executedLines[ lineNum ][ 1 ];
			}
			if ( executedLines[ lineNum ][ 2 ] > maxTime ) {
				maxTime = executedLines[ lineNum ][ 2 ];
			}
		}

		// PASS 1: Calculate heatmap styles and generate scoped CSS
		var heatmapData = variables.heatmapCalculator.calculateHeatmapStyles(executedLines, fileLines, tableClass);
		var cssRules = heatmapData.cssRules;
		var lineClasses = heatmapData.lineClasses;

		// Add scoped CSS for this table
		html &= '<style>' & chr(10) & chr(9) & arrayToList(cssRules, chr(10) & chr(9)) & chr(10) & '</style>';

		html &= '<table class="code-table ' & tableClass & '">
			<thead>
				<tr>
					<th class="line-number">Line</th>
					<th class="code-cell">Code</th>
					<th class="exec-count">Count</th>
					<th class="exec-time">Time (' & displayUnit.symbol & ')</th>
				</tr>
			</thead>
			<tbody>';

		// PASS 2: Generate table rows using CSS classes
		for (var i = 1; i <= arrayLen( fileLines ); i++) {
			var lineKey = toString(i);
			var lineData = structKeyExists( executedLines, lineKey ) ? executedLines[ lineKey ] : [];
			var len = ArrayLen( lineData );
			var isExecutable = structIsEmpty(executableLines) || structKeyExists(executableLines, lineKey);
			var rowClass = len > 0 ? "executed" : (isExecutable ? "not-executed" : "non-executable");
			var execCount = ( len >= 1 && lineData[ 1 ] ?: 0 ) > 0 ? numberFormat( lineData[ 1 ] ) : "";
			var rawExecTime = ( len >= 2 && lineData[ 2 ] ?: 0 ) > 0 ? lineData[ 2 ] : 0;
			var execTime = convertTimeUnit(rawExecTime, "μs", variables.displayUnit);
			var execTime = (execTime.time == -1) ? "" : ( execTime.time & " " & execTime.unit);

			// Get CSS classes for this line
			var classes = lineClasses[lineKey];
			var countClass = classes.countClass != "" ? "exec-count " & classes.countClass : "exec-count";
			var timeClass = classes.timeClass != "" ? "exec-time " & classes.timeClass : "exec-time";

			html &= '<tr class="' & rowClass & '">
				<td class="line-number">' & i & '</td>
				<td class="code-cell">' & encodeForHtml(fileLines[i]) & '</td>
				<td class="' & countClass & '">' & execCount & '</td>
				<td class="' & timeClass & '">' & execTime & '</td>
			</tr>';
		}

		html &= '</tbody></table>';
		
		// Add legend
		html &= generateLegendHtml();
		
		html &= '</div></div>';
		return html;
	}


	/**
	* Generates the HTML content for the index page
	*/
	public string function generateIndexHtmlContent(array reportData) {
		var html = '<!DOCTYPE html>
	<html lang="en">
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>Code Coverage Reports Index</title>
		<style>' & variables.htmlAssets.getCommonCss() & '</style>
		<script>
			document.addEventListener(''DOMContentLoaded'', function() {
				// Add click handlers to table rows
				const tableRows = document.querySelectorAll(''.reports-table tbody tr'');
				tableRows.forEach(function(row) {
					row.addEventListener(''click'', function() {
						const htmlFile = this.getAttribute(''data-html-file'');
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
				<div class="header-content">
					<h1>Code Coverage Reports</h1>
				</div>
				<button id="dark-mode-toggle" class="dark-mode-toggle" onclick="toggleDarkMode()" title="Toggle dark mode">
					<span class="toggle-icon">&##127769;</span>
				</button>
			</div>
			<div class="summary">
				<strong>Total Reports:</strong> ' & arrayLen(arguments.reportData) & ' |
				<strong>Generated:</strong> ' & lsDateTimeFormat(now()) & '
			</div>';

		if (arrayLen(arguments.reportData) == 0) {
			html &= '<div class="no-reports">No coverage reports found.</div>';
		} else {
			html &= '<table class="reports-table">
				<thead>
					<tr>
						<th>Script Name</th>
						<th>Coverage</th>
						<th>Execution Time</th>
					</tr>
				</thead>
				<tbody>';

			for (var report in arguments.reportData) {
				var formattedTime = numberFormat(report.executionTime);
				var timestamp = LsDateTimeFormat(report.timestamp);

				// Per-file code coverage stats
				var linesInstrumented = structKeyExists(report, "totalLinesHit") ? report.totalLinesHit : "-";
				var totalLines = structKeyExists(report, "totalLinesFound") ? report.totalLinesFound : "-";
				var percentCovered = (isNumeric(linesInstrumented) && isNumeric(totalLines) && totalLines > 0) ? numberFormat(100.0 * linesInstrumented / totalLines, "9.9") & '%' : '-';

				html &= '<tr data-html-file="' & encodeForHtmlAttribute(report.htmlFile) & '">
					<td class="script-name">' & encodeForHtml(report.scriptName) & '</td>';

					//'<td><a href="' & encodeForHtmlAttribute(report.htmlFile) & '" class="html-link">' & encodeForHtml(report.htmlFile) & '</a></td>';
				html &= '<td class="coverage">' & linesInstrumented & ' / ' & totalLines & ' (' & percentCovered & ')</td>
					<td class="execution-time">' & formattedTime & ' ' & encodeForHtml(report.unit) & '</td>
				</tr>';
			}

			html &= '</tbody></table>';
		}

		html &= '
		</div>';
		
		// Add dark mode toggle script
		html &= variables.htmlAssets.getDarkModeScript();
		
		html &= '
	</body>
	</html>';
		return html;
	}

	/**
	* Returns unit information for display
	*/
	public function getUnitInfo(string unit) {
		var units = getUnits();
		return structKeyExists(units, arguments.unit) ? units[arguments.unit] : units["micro"];
	}

	public function getUnits(){
		return {
			"seconds": { symbol: "s", name: "seconds" },
			"milli": { symbol: "ms", name: "milliseconds" },
			"micro": { symbol: "μs", name: "microseconds" },
			"nano": { symbol: "ns", name: "nanoseconds" }
		};
	}

	/**
	* Converts time between different units
	*/
	public struct function convertTimeUnit(numeric value, string fromUnit, struct toUnit) {
		if (!isNumeric(arguments.value) || arguments.value == 0) {
			return { time: -1, unit: toUnit.symbol };
		}
		
		// Conversion factors to microseconds (base unit)
		var toMicros = {
			"s": 1000000,
			"ms": 1000,
			"μs": 1,
			"ns": 0.001,
			"seconds": 1000000,
			"milli": 1000,
			"micro": 1,
			"nano": 0.001
		};
		
		// Convert to microseconds first, then to target unit
		var micros = arguments.value * (structKeyExists(toMicros, arguments.fromUnit) ? toMicros[arguments.fromUnit] : 1);
		var targetFactor = structKeyExists(toMicros, arguments.toUnit.symbol) ? toMicros[arguments.toUnit.symbol] : 1;

		return {
			time: numberFormat( int( micros / targetFactor ) ),
			unit: arguments.toUnit.symbol
		};
	}

	/**
	* Generates the HTML for the coverage legend
	*/
	private string function generateLegendHtml() {
		var html = '<div class="coverage-legend">
			<h4 class="legend-title">Legend</h4>
			<table class="code-table legend-table">
				<tr class="executed">
					<td class="legend-description">Executed lines - Code that was run during testing</td>
				</tr>
				<tr class="not-executed">
					<td class="legend-description">Not executed - Executable code that was not run</td>
				</tr>
				<tr class="non-executable">
					<td class="legend-description">Non-executable - Comments, empty lines (not counted in coverage)</td>
				</tr>
			</table>
		</div>';
		
		return html;
	}

}