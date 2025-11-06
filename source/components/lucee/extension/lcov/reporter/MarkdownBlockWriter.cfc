/**
 * Block-based Markdown reporter - generates detailed block-level coverage reports
 * Designed for LLM analysis and detailed debugging (unlike line-based reports)
 */
component {

	variables.fileUtils = new FileUtils();
	variables.displayUnit = "μs";

	/**
	 * Constructor/init function
	 */
	public MarkdownBlockWriter function init(required Logger logger, string displayUnit = "μs") {
		variables.logger = arguments.logger;
		variables.displayUnit = arguments.displayUnit;
		return this;
	}

	/**
	 * Generates block-based markdown report
	 * @result The result model instance
	 * @outputDir Output directory for markdown files
	 * @options Markdown generation options
	 * @return Path to generated markdown file
	 */
	public string function generate(required result result, required string outputDir, required struct options) {
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter( variables.displayUnit );
		var nl = chr(10);
		var parts = [];

		// Title
		var scriptName = arguments.result.getMetadataProperty("script-name");
		var prefix = arguments.result.getIsFile() ? "File: " : "Request: ";
		var displayName = prefix & scriptName;

		arrayAppend( parts, "#### Block-Level Coverage Report: " & displayName );
		arrayAppend( parts, "" );
		arrayAppend( parts, "Generated: " & dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss") );
		arrayAppend( parts, "" );

		// Summary
		var totalLinesFound = arguments.result.getStatsProperty("totalLinesFound");
		var totalLinesHit = arguments.result.getStatsProperty("totalLinesHit");
		var coveragePercent = totalLinesFound > 0 ? numberFormat((totalLinesHit / totalLinesFound) * 100, "0.00") : "0.00";

		arrayAppend( parts, "#### Summary" );
		arrayAppend( parts, "" );
		arrayAppend( parts, "- **Coverage:** " & coveragePercent & "% (" & totalLinesHit & "/" & totalLinesFound & " lines)" );
		arrayAppend( parts, "- **Total Executions:** " & numberFormat(arguments.result.getStatsProperty("totalExecutions")) );

		var totalExecutionTime = arguments.result.getStatsProperty("totalExecutionTime");
		var unitName = arguments.result.getMetadataProperty("unit");
		var sourceUnit = timeFormatter.getUnitInfo(unitName).symbol;
		var totalTimeMicros = timeFormatter.convertTime(totalExecutionTime, sourceUnit, "μs");
		var totalTimeDisplay = timeFormatter.formatTime(totalTimeMicros, variables.displayUnit, true);
		arrayAppend( parts, "- **Total Time:** " & totalTimeDisplay );

		arrayAppend( parts, "" );

		// Get options
		var sortBy = arguments.options.sortBy ?: "time-desc";
		var contextLines = arguments.options.contextLines ?: 2;
		var minTime = arguments.options.minTime ?: 0;
		var minAvg = arguments.options.minAvg ?: 0;
		var minHitCount = arguments.options.minHitCount ?: 0;

		arrayAppend( parts, "###### Report Options" );
		arrayAppend( parts, "" );
		arrayAppend( parts, "- **Sort By:** " & sortBy );
		arrayAppend( parts, "- **Context Lines:** " & contextLines );
		if (minTime > 0) {
			arrayAppend( parts, "- **Min Time Filter:** " & timeFormatter.formatTime(minTime, variables.displayUnit, true) );
		}
		if (minAvg > 0) {
			arrayAppend( parts, "- **Min Avg Filter:** " & timeFormatter.formatTime(minAvg, variables.displayUnit, true) );
		}
		if (minHitCount > 0) {
			arrayAppend( parts, "- **Min Hit Count Filter:** " & minHitCount );
		}
		arrayAppend( parts, "" );

		// Process each file
		var filesStruct = arguments.result.getFiles();
		var fileIndexes = structKeyArray(filesStruct);
		arraySort(fileIndexes, "numeric", "asc");

		for (var fileIdx in fileIndexes) {
			var fileSection = generateFileSection(
				fileIdx,
				arguments.result,
				timeFormatter,
				sourceUnit,
				sortBy,
				contextLines,
				minTime,
				minAvg,
				minHitCount
			);
			arrayAppend( parts, fileSection );
		}

		var markdown = arrayToList(parts, nl);
		var markdownPath = variables.fileUtils.createOutputPath( arguments.result, arguments.outputDir, ".md" );
		fileWrite(markdownPath, markdown);

		variables.logger.debug("Generated block-based markdown: " & markdownPath);
		return markdownPath;
	}

	/**
	 * Generates markdown for a single file's blocks
	 */
	private string function generateFileSection(
		required numeric fileIdx,
		required result result,
		required any timeFormatter,
		required string sourceUnit,
		required string sortBy,
		required numeric contextLines,
		required numeric minTime,
		required numeric minAvg,
		required numeric minHitCount
	) {
		var nl = chr(10);
		var parts = [];

		var fileData = arguments.result.getFileItem(arguments.fileIdx);
		var filePath = fileData.path;

		arrayAppend( parts, "#### File: " & variables.fileUtils.safeContractPath(filePath) );
		arrayAppend( parts, "" );

		// Get blocks for this file
		var blocks = arguments.result.getBlocks();
		if (!structKeyExists(blocks, arguments.fileIdx)) {
			arrayAppend( parts, "_No blocks found for this file._" );
			arrayAppend( parts, "" );
			return arrayToList(parts, nl);
		}

		var fileBlocks = blocks[arguments.fileIdx];

		// Convert blocks to array for sorting/filtering
		var blockArray = [];
		cfloop( collection=fileBlocks, key="local.blockKey", value="local.block" ) {
			var keyParts = listToArray(blockKey, "-");
			var startPos = keyParts[1];
			var endPos = keyParts[2];

			// Calculate average time
			var avgTime = block.hitCount > 0 ? (block.execTime / block.hitCount) : 0;

			// Apply filters
			if (arguments.minTime > 0 && block.execTime < arguments.minTime) {
				continue;
			}
			if (arguments.minAvg > 0 && avgTime < arguments.minAvg) {
				continue;
			}
			if (arguments.minHitCount > 0 && block.hitCount < arguments.minHitCount) {
				continue;
			}

			arrayAppend( blockArray, {
				startPos: startPos,
				endPos: endPos,
				hitCount: block.hitCount,
				execTime: block.execTime,
				avgTime: avgTime,
				blockType: block.blockType ?: 0,
				isBlock: block.isBlock ?: false,
				astNodeType: block.astNodeType ?: "",
				tagName: block.tagName ?: ""
			});
		}

		// Sort blocks
		blockArray = sortBlocks(blockArray, arguments.sortBy);

		if (arrayLen(blockArray) == 0) {
			arrayAppend( parts, "_No blocks match the filter criteria._" );
			arrayAppend( parts, "" );
			return arrayToList(parts, nl);
		}

		arrayAppend( parts, "**Blocks:** " & arrayLen(blockArray) & " (after filtering)" );
		arrayAppend( parts, "" );

		// Load source data from AST file
		var astFilePath = fileData.astFile;
		var astData = deserializeJSON(fileRead(astFilePath));
		var fileLines = astData.lines;
		var lineMapping = astData.lineMapping;

		// Generate block sections
		for (var block in blockArray) {
			var blockSection = generateBlockSection(
				block,
				arguments.timeFormatter,
				arguments.sourceUnit,
				fileLines,
				lineMapping,
				arguments.contextLines
			);
			arrayAppend( parts, blockSection );
		}

		return arrayToList(parts, nl);
	}

	/**
	 * Sort blocks based on sort option
	 */
	private array function sortBlocks(required array blocks, required string sortBy) {
		switch (arguments.sortBy) {
			case "time-desc":
				arraySort(arguments.blocks, function(a, b) { return b.execTime - a.execTime; });
				break;
			case "time-asc":
				arraySort(arguments.blocks, function(a, b) { return a.execTime - b.execTime; });
				break;
			case "avg-desc":
				arraySort(arguments.blocks, function(a, b) { return b.avgTime - a.avgTime; });
				break;
			case "avg-asc":
				arraySort(arguments.blocks, function(a, b) { return a.avgTime - b.avgTime; });
				break;
			case "hitCount":
				arraySort(arguments.blocks, function(a, b) { return b.hitCount - a.hitCount; });
				break;
			case "position":
				arraySort(arguments.blocks, function(a, b) { return a.startPos - b.startPos; });
				break;
			default:
				// Default to time-desc
				arraySort(arguments.blocks, function(a, b) { return b.execTime - a.execTime; });
		}
		return arguments.blocks;
	}

	/**
	 * Generate markdown for a single block
	 */
	private string function generateBlockSection(
		required struct block,
		required any timeFormatter,
		required string sourceUnit,
		required array fileLines,
		required array lineMapping,
		required numeric contextLines
	) {
		var nl = chr(10);
		var parts = [];

		// Block header
		var blockKey = arguments.block.startPos & "-" & arguments.block.endPos;
		arrayAppend( parts, "###### Block: " & blockKey );
		arrayAppend( parts, "" );

		// Block metadata
		var blockTypeLabel = getBlockTypeLabel(arguments.block.blockType, arguments.block.isBlock);
		arrayAppend( parts, "- **Type:** " & blockTypeLabel );
		arrayAppend( parts, "- **Position:** " & arguments.block.startPos & " → " & arguments.block.endPos );
		arrayAppend( parts, "- **Hits:** " & numberFormat(arguments.block.hitCount) );

		// Time
		var timeMicros = arguments.timeFormatter.convertTime(arguments.block.execTime, arguments.sourceUnit, "μs");
		var timeDisplay = arguments.timeFormatter.formatTime(timeMicros, variables.displayUnit, true);
		arrayAppend( parts, "- **Total Time:** " & timeDisplay );

		// Average time
		if (arguments.block.hitCount > 1) {
			var avgMicros = timeMicros / arguments.block.hitCount;
			var avgDisplay = arguments.timeFormatter.formatTime(avgMicros, variables.displayUnit, true);
			arrayAppend( parts, "- **Avg Time:** " & avgDisplay );
		}

		// AST info
		if (len(arguments.block.astNodeType) > 0) {
			arrayAppend( parts, "- **AST Node:** " & arguments.block.astNodeType );
		}
		if (len(arguments.block.tagName) > 0) {
			arrayAppend( parts, "- **Tag:** " & arguments.block.tagName );
		}

		arrayAppend( parts, "" );

		// Source context
		variables.logger.debug("Block #arguments.block.startPos#-#arguments.block.endPos#: lineMapping length=#arrayLen(arguments.lineMapping)#, fileLines length=#arrayLen(arguments.fileLines)#");
		if (arrayLen(arguments.lineMapping) > 0) {
			var startLine = getLineFromPosition(arguments.block.startPos, arguments.lineMapping);
			var endLine = getLineFromPosition(arguments.block.endPos, arguments.lineMapping);
			variables.logger.debug("Block #arguments.block.startPos#-#arguments.block.endPos#: startLine=#startLine#, endLine=#endLine#");

			if (startLine > 0 && endLine > 0) {
				var contextStart = max(1, startLine - arguments.contextLines);
				var contextEnd = min(arrayLen(arguments.fileLines), endLine + arguments.contextLines);

				arrayAppend( parts, "**Source Context (lines " & contextStart & "-" & contextEnd & "):**" );
				arrayAppend( parts, "" );
				arrayAppend( parts, "```cfml" );

				for (var lineNum = contextStart; lineNum <= contextEnd; lineNum++) {
					var lineCode = arguments.fileLines[lineNum];
					var prefix = (lineNum >= startLine && lineNum <= endLine) ? "→ " : "  ";
					arrayAppend( parts, prefix & lineNum & ": " & lineCode );
				}

				arrayAppend( parts, "```" );
				arrayAppend( parts, "" );
			}
		}

		return arrayToList(parts, nl);
	}

	/**
	 * Get block type label from blockType and isBlock flags
	 */
	private string function getBlockTypeLabel(required numeric blockType, required boolean isBlock) {
		if (arguments.isBlock) {
			return "Block";
		}

		switch (arguments.blockType) {
			case 0:
			case 2:
				return "Own";
			case 1:
			case 3:
				return "Child";
			default:
				return "Unknown";
		}
	}

	/**
	 * Find line number from character position using lineMapping
	 */
	private numeric function getLineFromPosition(required numeric position, required array lineMapping) {
		for (var i = 1; i <= arrayLen(arguments.lineMapping); i++) {
			if (arguments.lineMapping[i] > arguments.position) {
				return max(1, i - 1);
			}
		}
		return arrayLen(arguments.lineMapping);
	}

}
