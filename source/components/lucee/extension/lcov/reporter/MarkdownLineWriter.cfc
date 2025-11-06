/**
* CFC responsible for generating Markdown coverage reports from result models
* Markdown reports are easier to parse programmatically and view in CLI/editors
*/
component {

	variables.fileUtils = new FileUtils();
	variables.displayUnit = "μs";
	variables.showUnexecutedLines = false;

	/**
	* Constructor/init function
	*/
	public MarkdownLineWriter function init(required Logger logger, string displayUnit = "μs") {
		variables.logger = arguments.logger;
		variables.displayUnit = arguments.displayUnit;
		return this;
	}

	/**
	* Set whether to show unexecuted lines in the output
	*/
	public void function setShowUnexecutedLines(required boolean show) {
		variables.showUnexecutedLines = arguments.show;
	}

	/**
	* Generates the Markdown content for a coverage report
	* @result The result model instance
	* @return String containing the full Markdown report
	*/
	public string function generateMarkdownContent(required result result) {
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter( variables.displayUnit );
		var nl = chr(10);
		var parts = [];

		// Title
		var scriptName = arguments.result.getMetadataProperty("script-name");
		var prefix = arguments.result.getIsFile() ? "File: " : "Request: ";
		var displayName = prefix & scriptName;

		arrayAppend( parts, repeatString("##", 2) & " Coverage Report: " & displayName );
		arrayAppend( parts, "" );

		// Summary Section
		arrayAppend( parts, repeatString("##", 4) & " Summary" );
		arrayAppend( parts, "" );

		var totalLinesFound = arguments.result.getStatsProperty("totalLinesFound");
		var totalLinesHit = arguments.result.getStatsProperty("totalLinesHit");
		var coveragePercent = totalLinesFound > 0 ? numberFormat((totalLinesHit / totalLinesFound) * 100, "0.00") : "0.00";

		arrayAppend( parts, "- **Total Lines:** " & totalLinesFound );
		arrayAppend( parts, "- **Lines Hit:** " & totalLinesHit );
		arrayAppend( parts, "- **Coverage:** " & coveragePercent & "%" );

		var totalExecutions = arguments.result.getStatsProperty("totalExecutions");
		arrayAppend( parts, "- **Total Executions:** " & numberFormat(totalExecutions) );

		var totalExecutionTime = arguments.result.getStatsProperty("totalExecutionTime");
		var unitName = arguments.result.getMetadataProperty("unit");
		var sourceUnit = timeFormatter.getUnitInfo(unitName).symbol;
		var totalTimeMicros = timeFormatter.convertTime(totalExecutionTime, sourceUnit, "μs");
		var totalTimeDisplay = timeFormatter.formatTime(totalTimeMicros, variables.displayUnit, true);
		arrayAppend( parts, "- **Total Time:** " & totalTimeDisplay );

		// Child time if available (in source unit from .exl file)
		var totalChildTime = arguments.result.getStatsProperty("totalChildTime");
		if (totalChildTime > 0) {
			var childTimeMicros = timeFormatter.convertTime(totalChildTime, sourceUnit, "μs");
			var childTimeDisplay = timeFormatter.formatTime(childTimeMicros, variables.displayUnit, true);
			arrayAppend( parts, "- **Child Time:** " & childTimeDisplay );
		}

		// Add request execution time from metadata for request-level reports (not per-file)
		if (!arguments.result.getIsFile()) {
			var requestExecutionTime = arguments.result.getMetadataProperty("execution-time");
			if (isDefined("requestExecutionTime") && isNumeric(requestExecutionTime)) {
				var reqTimeMicros = timeFormatter.convertTime(requestExecutionTime, sourceUnit, "μs");
				var reqTimeDisplay = timeFormatter.formatTime(reqTimeMicros, variables.displayUnit, true);
				arrayAppend( parts, "- **Request Execution Time (metadata):** " & reqTimeDisplay );
			}
		}
		arrayAppend( parts, "- **Source Unit:** " & sourceUnit );

		arrayAppend( parts, "" );

		// File Details Section
		arrayAppend( parts, repeatString("##", 4) & " Files" );
		arrayAppend( parts, "" );

		var filesStruct = arguments.result.getFiles();
		var fileIndexes = structKeyArray(filesStruct);
		arraySort(fileIndexes, "numeric", "asc");

		// Iterate through each file
		for (var fileIndex in fileIndexes) {
			var fileSection = generateFileSection( fileIndex, arguments.result, timeFormatter, sourceUnit );
			arrayAppend( parts, fileSection );
		}

		return arrayToList(parts, nl);
	}

	/**
	* Generates the markdown for a single file's coverage section
	* @fileIndex The file index
	* @result The result model
	* @timeFormatter The time formatter instance
	* @sourceUnit The source time unit
	* @return String markdown for this file section
	*/
	private string function generateFileSection(required numeric fileIndex, required result result,
			required any timeFormatter, required string sourceUnit) {
		var nl = chr(10);
		var parts = [];

		var fileData = arguments.result.getFileItem(arguments.fileIndex);
		var filePath = fileData.path;
		var fileCoverage = arguments.result.getCoverageForFile(arguments.fileIndex);

		// File header
		arrayAppend( parts, repeatString("##", 5) & " File: " & variables.fileUtils.safeContractPath(filePath) );
		arrayAppend( parts, "" );

		// File stats
		arrayAppend( parts, "- **Lines Found:** " & fileData.linesFound );
		arrayAppend( parts, "- **Lines Hit:** " & fileData.linesHit );
		arrayAppend( parts, "- **Executions:** " & numberFormat(fileData.totalExecutions) );

		var fileTime = fileData.totalExecutionTime;
		var fileTimeMicros = arguments.timeFormatter.convertTime(fileTime, arguments.sourceUnit, "μs");
		var fileTimeDisplay = arguments.timeFormatter.formatTime(fileTimeMicros, variables.displayUnit, true);
		arrayAppend( parts, "- **Total Time:** " & fileTimeDisplay );

		if (structKeyExists(fileData, "totalChildTime") && fileData.totalChildTime > 0) {
			var fileChildTimeMicros = arguments.timeFormatter.convertTime(fileData.totalChildTime, arguments.sourceUnit, "μs");
			var fileChildTimeDisplay = arguments.timeFormatter.formatTime(fileChildTimeMicros, variables.displayUnit, true);
			arrayAppend( parts, "- **Child Time:** " & fileChildTimeDisplay );
		}

		arrayAppend( parts, "" );

		// Line details
		if (!structIsEmpty(fileCoverage)) {
			arrayAppend( parts, repeatString("##", 6) & " Lines" );
			arrayAppend( parts, "" );

			// Load source lines from AST file
			var astFilePath = fileData.astFile;
			var astData = deserializeJSON(fileRead(astFilePath));
			var fileLines = astData.lines;

			for (var lineNum = 1; lineNum <= arrayLen(fileLines); lineNum++) {
				var lineData = fileCoverage[lineNum] ?: [];
				var hasData = arrayLen(lineData) > 0;

				// Skip unexecuted lines if flag is false
				if (!hasData && !variables.showUnexecutedLines) {
					continue;
				}

				var lineCode = fileLines[lineNum];

				if (hasData) {
					var count = lineData[1];
					var execTime = lineData[2];
					var blockType = lineData[3];

					// Only show executed lines
					if (count > 0 || execTime > 0) {
						arrayAppend( parts, "**Line " & lineNum & ":** `" & escapeMarkdown(lineCode) & "`" );
						arrayAppend( parts, "" );

						if (count > 0) {
							arrayAppend( parts, "- Executed: " & numberFormat(count) & " times" );
						}

						// Map blockType to label: 0=Own, 1=Child, 2=Own, 3=Child
						if (execTime > 0) {
							var timeTypeLabels = ["Own", "Child", "Own", "Child"];
							var timeType = timeTypeLabels[blockType + 1]; // +1 for 1-based array

							var timeMicros = arguments.timeFormatter.convertTime(execTime, arguments.sourceUnit, "μs");
							var timeDisplay = arguments.timeFormatter.formatTime(timeMicros, variables.displayUnit, true);
							arrayAppend( parts, "- Time (" & timeType & "): " & timeDisplay );

							// Add average if count > 1
							if (count > 1) {
								var avgMicros = timeMicros / count;
								var avgDisplay = arguments.timeFormatter.formatTime(avgMicros, variables.displayUnit, true);
								arrayAppend( parts, "- Avg: " & avgDisplay );
							}
						}

						arrayAppend( parts, "" );
					}
				} else if (variables.showUnexecutedLines) {
					// Show unexecuted line
					arrayAppend( parts, "**Line " & lineNum & ":** `" & escapeMarkdown(lineCode) & "`" );
					arrayAppend( parts, "" );
					arrayAppend( parts, "- Not executed" );
					arrayAppend( parts, "" );
				}
			}
		}

		return arrayToList(parts, nl);
	}

	/**
	* Generates an index.md file listing all Markdown reports
	* @indexData Array of report entries (already sorted)
	* @outputDirectory The directory containing the reports
	* @return Path to the generated index.md file
	*/
	public string function generateIndexMarkdown(required array indexData, required string outputDirectory) {
		// Generate Markdown content
		var markdown = generateIndexMarkdownContent(arguments.indexData);

		// Write index.md file
		var indexMarkdownPath = arguments.outputDirectory & "/index.md";
		fileWrite(indexMarkdownPath, markdown);

		variables.logger.debug("Generated index.md with " & arrayLen(arguments.indexData) & " reports");
		return indexMarkdownPath;
	}

	/**
	* Generates the Markdown content for the index file
	* @indexData Array of report entries from index.json
	* @return String containing the full Markdown index
	*/
	private string function generateIndexMarkdownContent(required array indexData) {
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter(variables.displayUnit);
		var nl = chr(10);
		var parts = [];

		// Title
		arrayAppend(parts, repeatString("##", 2) & " Coverage Reports Index");
		arrayAppend(parts, "");
		arrayAppend(parts, "Generated: " & dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"));
		arrayAppend(parts, "");

		if (arrayLen(arguments.indexData) == 0) {
			arrayAppend(parts, "_No reports available._");
			return arrayToList(parts, nl);
		}

		// Summary stats
		var totalReports = arrayLen(arguments.indexData);
		var totalLinesFound = 0;
		var totalLinesHit = 0;
		var totalExecutions = 0;
		var totalExecutionTimeMicros = 0;

		cfloop( array=arguments.indexData, item="local.entry" ) {
			totalLinesFound += entry.totalLinesFound;
			totalLinesHit += entry.totalLinesHit;
			totalExecutions += entry.totalExecutions;

			// Convert execution time to microseconds for summing
			if (structKeyExists(entry, "totalExecutionTime") && isNumeric(entry.totalExecutionTime)) {
				var sourceUnit = timeFormatter.getUnitInfo(entry.unit).symbol;
				var timeMicros = timeFormatter.convertTime(entry.totalExecutionTime, sourceUnit, "μs");
				totalExecutionTimeMicros += timeMicros;
			}
		}

		var overallCoverage = totalLinesFound > 0 ? numberFormat((totalLinesHit / totalLinesFound) * 100, "0.00") : "0.00";
		var totalTimeDisplay = timeFormatter.formatTime(totalExecutionTimeMicros, variables.displayUnit, true);

		arrayAppend(parts, repeatString("##", 4) & " Summary");
		arrayAppend(parts, "");
		arrayAppend(parts, "- **Total Reports:** " & totalReports);
		arrayAppend(parts, "- **Total Lines Found:** " & numberFormat(totalLinesFound));
		arrayAppend(parts, "- **Total Lines Hit:** " & numberFormat(totalLinesHit));
		arrayAppend(parts, "- **Overall Coverage:** " & overallCoverage & "%");
		arrayAppend(parts, "- **Total Executions:** " & numberFormat(totalExecutions));
		arrayAppend(parts, "- **Total Execution Time:** " & totalTimeDisplay);
		arrayAppend(parts, "");

		// Reports table
		arrayAppend(parts, repeatString("##", 4) & " Reports");
		arrayAppend(parts, "");

		// For index table, use nanoseconds for consistency (avoids rounding and mixed units)
		// This is easier for LLMs to parse since all times are in the same unit
		var tableDisplayUnit = variables.displayUnit == "auto" ? "nano" : variables.displayUnit;
		var unitSymbol = timeFormatter.getUnitInfo(tableDisplayUnit).symbol;
		var unitSuffix = " (" & unitSymbol & ")";

		arrayAppend(parts, "| Script | Coverage | Lines Hit | Lines Found | Executions | Total Time" & unitSuffix & " | Child Time" & unitSuffix & " | Own Time" & unitSuffix & " |");
		arrayAppend(parts, "|--------|----------|-----------|-------------|------------|------------|------------|----------|");

		cfloop( array=arguments.indexData, item="local.entry" ) {
			var coverage = entry.totalLinesFound > 0 ? numberFormat((entry.totalLinesHit / entry.totalLinesFound) * 100, "0.00") : "0.00";
			var scriptName = entry.scriptName ?: "unknown";
			var mdFile = replace(entry.htmlFile, ".html", ".md");
			var scriptLink = "[" & scriptName & "](" & mdFile & ")";

			// totalExecutionTime is actually ownTime (child time counted in function bodies where it executes)
			var sourceUnit = timeFormatter.getUnitInfo(entry.unit).symbol;
			var ownTimeMicros = timeFormatter.convertTime(entry.totalExecutionTime, sourceUnit, "μs");

			// Format child time (stored in source unit from .exl file, convert to microseconds)
			var childTimeSourceUnit = entry.totalChildTime ?: 0;
			var childTimeMicros = timeFormatter.convertTime(childTimeSourceUnit, sourceUnit, "μs");

			// Calculate TOTAL time = Own + Child
			var timeMicros = ownTimeMicros + childTimeMicros;
			var timeDisplay = timeFormatter.formatTime(timeMicros, tableDisplayUnit, false);
			var childTimeDisplay = childTimeMicros > 0 ? timeFormatter.formatTime(childTimeMicros, tableDisplayUnit, false) : "";
			var ownTimeDisplay = ownTimeMicros > 0 ? timeFormatter.formatTime(ownTimeMicros, tableDisplayUnit, false) : "";

			arrayAppend(parts, "| " & scriptLink & " | " & coverage & "% | " & numberFormat(entry.totalLinesHit) & " | " & numberFormat(entry.totalLinesFound) & " | " & numberFormat(entry.totalExecutions) & " | " & timeDisplay & " | " & childTimeDisplay & " | " & ownTimeDisplay & " |");
		}

		arrayAppend(parts, "");
		return arrayToList(parts, nl);
	}

	/**
	* Escapes special Markdown characters in code snippets
	* @text The text to escape
	* @return Escaped text safe for Markdown
	*/
	private string function escapeMarkdown(required string text) {
		var escaped = arguments.text;
		// Escape backticks in code by using backslash
		escaped = replace(escaped, "`", "\`", "all");
		return escaped;
	}

}
