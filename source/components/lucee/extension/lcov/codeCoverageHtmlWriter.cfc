/**
* CFC responsible for generating HTML coverage reports from .exl files
*/
component {
	
	// Instance variable to store display unit
	variables.displayUnit = "micro";
	
	/**
	* Constructor/init function
	*/
	public codeCoverageHtmlWriter function init(string displayUnit = "micro") {
		variables.displayUnit = arguments.displayUnit;
		return this;
	}

	/**
	* Generates the HTML content for the execution report
	*/
	public string function generateHtmlContent(struct result) {
		var scriptName = result.metadata["script-name"];
		var executionTime = result.metadata["execution-time"] ?: "N/A";
		var originalUnit = result.metadata["unit"] ?: "μs";
		
		// Convert execution time and get display unit info
		var convertedTime = convertTimeUnit(executionTime, originalUnit, variables.displayUnit);
		var displayUnitInfo = getUnitInfo(variables.displayUnit);
		
		var formattedExecutionTime = numberFormat(convertedTime);
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
		<style>' & getCommonCss() & '</style>
	</head>
	<body>
		<div class="container">
			<div class="header-section">
				<h2 class="report-type">Lucee Code Coverage Report</h2>
				<h1>' & encodeForHtml(scriptName) & ' <span style="color: ##666; font-size: 0.7em;">('
					& encodeForHtml(formattedExecutionTime) & ' ' & encodeForHtml(displayUnitInfo.symbol) & ')</span></h1>
				<div class="timestamp">Generated: ' & lsDateTimeFormat(now()) & '</div>
				<div class="coverage-summary">
					<strong>Coverage Summary:</strong> ' & totalLinesHit & ' of ' & totalLinesFound & ' lines covered (' & coveragePercent & '%)
				</div>
			</div>
			<a href="index.html" class="back-link">← Back to Index</a>
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
		</div>
	</body>
	</html>';
		return html;
	}

	/**
	* Generates HTML section for a single file showing covered lines
	*/
	private string function generateFileSection( string filePath, struct result ) {
		// Get display unit info for this function
		var displayUnitInfo = getUnitInfo(variables.displayUnit);
		
		// Create VS Code link for the file
		var vscodeLink = "vscode://file/" & replace( arguments.filePath, "\", "/", "all" );
		if ( !structKeyExists( arguments.result.coverage, arguments.filePath ) ) {
			systemOutput( " -----error ", true );
			systemOutput( serializeJSON( var=result, compact=false ), true );
			throw "No coverage data for file: " & arguments.filePath;
		}
		var html = '<div class="file-section">
			<div class="file-header">
				<h3><a href="' & vscodeLink & '" style="color: white; text-decoration: none;">'
					& encodeForHtml( contractPath( arguments.result.source.files[ arguments.filePath] .path ) )
				& '</a></h3>
			</div>
			<div class="file-content">';

		
		var totalExecutions = arguments.result.stats.totalExecutions;
		var totalExecutionTime = arguments.result.stats.totalExecutionTime;
		var stats = arguments.result.stats.files[ arguments.filePath ];
		
		// Generate stats with actual execution time when available
		var convertedTotalTime = convertTimeUnit(totalExecutionTime, "μs", variables.displayUnit);
		var timeDisplay = totalExecutionTime > 0 ? numberFormat( convertedTotalTime ) & " " & displayUnitInfo.symbol : "N/A " & displayUnitInfo.symbol;
		html &= '<div class="stats">
			<strong>Executions:</strong> ' & numberFormat(totalExecutions) & ' |
			<strong>Total Execution Time:</strong> ' & timeDisplay & ' |
			<strong>Lines Covered:</strong> ' & stats.linesHit & ' of ' & stats.linesFound & '
		</div>';

		// Create table with headers
		html &= '<table class="code-table">
			<thead>
				<tr>
					<th class="line-number">Line</th>
					<th class="code-cell">Code</th>
					<th class="exec-count">Count</th>
					<th class="exec-time">Time (' & displayUnitInfo.symbol & ')</th>
				</tr>
			</thead>
			<tbody>';

		// Calculate max values for color coding
		var executedLines = arguments.result.coverage[ arguments.filePath ];
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
		var fileLines = arguments.result.source.files[ arguments.filePath ].lines;

		// Display each line in table rows
		for (var i = 1; i <= arrayLen( fileLines ); i++) {
			var lineKey = toString(i);
			var lineData = structKeyExists( executedLines, lineKey ) ? executedLines[ lineKey ] : [];
			var len = ArrayLen( lineData );
			var rowClass = len > 0 ? "executed" : "";
			var execCount = ( len >= 1 && lineData[ 1 ] ?: 0 ) > 0 ? numberFormat( lineData[ 1 ] ) : "";
			var rawExecTime = ( len >= 2 && lineData[ 2 ] ?: 0 ) > 0 ? lineData[ 2 ] : 0;
			var convertedExecTime = convertTimeUnit(rawExecTime, "μs", variables.displayUnit);
			var execTime = rawExecTime > 0 ? numberFormat( convertedExecTime ) : "";

			// Calculate color intensities (0-255) based on relative values
			var countIntensity = ( len >= 1 && lineData[ 1 ] ?: 0 ) > 0 && maxCount > 0 ?
				int( ( lineData[ 1 ] / maxCount ) * 255 ) : 0;
			var timeIntensity = ( len >= 2 && lineData[ 2 ] ?: 0 ) > 0 && maxTime > 0 ?
				int( ( lineData[ 2 ] / maxTime ) * 255 ) : 0;

			// Generate background colors (white to red)
			var countStyle = countIntensity > 0 ?
				'style="background-color: rgb(255, ' & (255 - countIntensity) & ', ' & (255 - countIntensity) & ');"' : '';
			var timeStyle = timeIntensity > 0 ?
				'style="background-color: rgb(255, ' & (255 - timeIntensity) & ', ' & (255 - timeIntensity) & ');"' : '';

			html &= '<tr class="' & rowClass & '">
				<td class="line-number">' & i & '</td>
				<td class="code-cell">' & encodeForHtml(fileLines[i]) & '</td>
				<td class="exec-count" ' & countStyle & '>' & execCount & '</td>
				<td class="exec-time" ' & timeStyle & '>' & execTime & '</td>
			</tr>';
		}

		html &= '</tbody></table>';
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
		<style>' & getCommonCss() & '</style>
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
			<h1>Code Coverage Reports</h1>
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
		</div>
	</body>
	</html>';
		return html;
	}

	/**
	* Returns the common CSS for both HTML pages
	*/
	private string function getCommonCss() {
		return '
	body { font-family: Arial, sans-serif; margin: 20px; background-color: ##f5f5f5; }
	.container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
	.header-section { margin-bottom: 20px; border-bottom: 2px solid ##007acc; padding-bottom: 15px; }
	.report-type { color: ##666; font-size: 0.9em; margin: 0 0 5px 0; font-weight: normal; text-transform: uppercase; letter-spacing: 1px; }
	h1 { color: ##333; margin: 0 0 10px 0; }
	.timestamp { color: ##666; font-size: 0.85em; margin-bottom: 8px; }
	.coverage-summary { color: ##007acc; font-size: 1em; font-weight: bold; }
	.file-links { font-size: 0.9em; color: ##666; margin-bottom: 15px; }
	.file-link { color: ##888; text-decoration: none; font-family: monospace; }
	.file-link:hover { color: ##007acc; text-decoration: underline; }
	h2 { color: ##007acc; margin-top: 30px; }
	.metadata { background: ##f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
	.metadata dt { font-weight: bold; color: ##495057; }
	.metadata dd { margin-left: 20px; margin-bottom: 5px; }
	.file-section { margin-bottom: 30px; border: 1px solid ##ddd; border-radius: 5px; }
	.file-header { background: ##007acc; color: white; padding: 10px; border-radius: 5px 5px 0 0; cursor: pointer; user-select: text !important; }
	.file-header h3 { user-select: text !important; }
	.file-header a { color: white; text-decoration: none; display: block; user-select: text !important; }
	.file-header a:hover { text-decoration: underline; }
	.file-header:hover { background: ##0056b3; }
	.file-content { padding: 15px; }
	.code-table { width: 100%; border-collapse: collapse; font-family: "Courier New", monospace; }
	.code-table th { background: ##f8f9fa; padding: 8px; text-align: left; border-bottom: 2px solid ##dee2e6; font-weight: bold; }
	.code-table td { padding: 4px 8px; border-bottom: 1px solid ##e9ecef; white-space: pre-wrap; vertical-align: top; }
	.code-table tr.executed { background-color: ##d4edda; }
	.code-table .line-number { width: 50px; text-align: right; color: ##6c757d; font-weight: normal; }
	.code-table .exec-count { width: 80px; text-align: right; color: ##000; font-weight: bold; }
	.code-table .exec-time { width: 100px; text-align: right; color: ##000; }
	.code-table .code-cell { font-family: "Courier New", monospace; }
	.no-executions { color: ##6c757d; font-style: italic; }
	.stats { background: ##e7f3ff; padding: 10px; border-radius: 5px; margin-top: 10px; }
	h3 { margin: 0 !important; padding: 0 !important; }
	.back-link { display: inline-block; margin-bottom: 15px; padding: 8px 16px; background: ##007acc; color: white; text-decoration: none; border-radius: 4px; font-size: 0.9em; }
	.back-link:hover { background: ##005f9e; text-decoration: none; color: white; }
	.summary { background: ##e7f3ff; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
	.reports-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
	.reports-table th { background: ##007acc; color: white; padding: 12px; text-align: left; border-bottom: 2px solid ##dee2e6; }
	.reports-table td { padding: 10px 12px; border-bottom: 1px solid ##e9ecef; vertical-align: top; }
	.reports-table tr:hover { background-color: ##f8f9fa; }
	.reports-table tbody tr { cursor: pointer; }
	.reports-table tbody tr:hover { background-color: ##e3f2fd; }
	.script-name { font-weight: bold; color: ##007acc; }
	.html-link { color: ##28a745; text-decoration: none; font-family: monospace; }
	.html-link:hover { text-decoration: underline; }
	.execution-time { font-family: monospace; color: ##6c757d; }
	.timestamp { color: ##6c757d; font-size: 0.9em; }
	.no-reports { color: ##6c757d; font-style: italic; text-align: center; padding: 40px; }
	';
	}

	/**
	* Returns unit information for display
	*/
	private public function getUnitInfo(string unit) {
		var units = {
			"seconds": { symbol: "s", name: "seconds" },
			"milli": { symbol: "ms", name: "milliseconds" },
			"micro": { symbol: "μs", name: "microseconds" },
			"nano": { symbol: "ns", name: "nanoseconds" }
		};
		return structKeyExists(units, arguments.unit) ? units[arguments.unit] : units["micro"];
	}

	/**
	* Converts time between different units
	*/
	public numeric function convertTimeUnit(numeric value, string fromUnit, string toUnit) {
		if (!isNumeric(arguments.value) || arguments.value == 0) {
			return 0;
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
		var targetFactor = structKeyExists(toMicros, arguments.toUnit) ? toMicros[arguments.toUnit] : 1;
		
		return micros / targetFactor;
	}

}