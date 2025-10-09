component displayname="CoverageBlockProcessor" accessors="true" {

	/**
	* Initialize the utils component with options
	* @options Configuration options struct (optional)
	*/
	public function init(struct options = {}) {
		// Store options and initialize logger
		variables.options = arguments.options;
		var logLevel = variables.options.logLevel ?: "none";
		variables.logger = new lucee.extension.lcov.Logger(level=logLevel);
		return this;
	}

	/**
	 * Process line-based blocks with overlap detection
	 * Blocks are already defined by line numbers [fileIdx, startLine, endLine, execTime]
	 */
	public struct function overlapFilterLineBased(blocksByFile, files, lineMappingsCache) {
		var startTime = getTickCount();
		var coverage = [=];

		// Process each file's blocks
		for (var fileIdx in arguments.blocksByFile) {
			if (!structKeyExists(arguments.files, fileIdx)) continue;

			var filePath = arguments.files[fileIdx].path;
			var lineMapping = arguments.lineMappingsCache[filePath];
			var mappingLen = arrayLen(lineMapping);
			var blocks = arguments.blocksByFile[fileIdx];
			var f = {};

			// Get executable lines for this file
			var executableLines = structKeyExists(arguments.files[fileIdx], "executableLines")
				? arguments.files[fileIdx].executableLines : {};

			// Filter overlapping blocks (line-based)
			var filteredBlocks = filterOverlappingBlocksLineBased(blocks);

			// Process line-based blocks
			for (var b = 1; b <= arrayLen(filteredBlocks); b++) {
				var block = filteredBlocks[b];
				var startLine = block[2];
				var endLine = block[3];

				if (startLine == 0) startLine = 1;
				if (endLine == 0) endLine = startLine;

				// Add execution time to each line in the range
				for (var l = startLine; l <= endLine; l++) {
					if (structKeyExists(executableLines, l)) {
						if (!structKeyExists(f, l)) {
							f[l] = [1, block[4]];
						} else {
							f[l][1] += 1;
							f[l][2] += block[4];
						}
					}
				}
			}

			coverage[fileIdx] = f;
		}

		var totalTime = getTickCount() - startTime;
		variables.logger.debug("overlapFilterLineBased: Completed " & structCount(coverage)
			& " files in " & totalTime & "ms");
		return coverage;
	}

	/**
	 * Process position-based (character offset) blocks with overlap detection
	 * Blocks are defined by character positions [fileIdx, startPos, endPos, execTime]
	 * Distributes execution time across spanned lines to avoid inflation
	 */
	public struct function overlapFilterPositionBased(blocksByFile, files, lineMappingsCache) {
		var startTime = getTickCount();
		var coverage = [=];

		// Process each file's blocks
		for (var fileIdx in arguments.blocksByFile) {
			if (!structKeyExists(arguments.files, fileIdx)) continue;

			var filePath = arguments.files[fileIdx].path;
			var lineMapping = arguments.lineMappingsCache[filePath];
			var mappingLen = arrayLen(lineMapping);
			var blocks = arguments.blocksByFile[fileIdx];
			var f = {};

			// Get executable lines for this file
			var executableLines = structKeyExists(arguments.files[fileIdx], "executableLines")
				? arguments.files[fileIdx].executableLines : {};

			// Filter overlapping blocks (position-based)
			var filteredBlocks = filterOverlappingBlocksPositionBased(blocks, lineMapping, mappingLen);

			// Process position-based blocks
			for (var b = 1; b <= arrayLen(filteredBlocks); b++) {
				var block = filteredBlocks[b];

				// Convert character positions to line numbers
				var startLine = LinePositionUtils::getLineFromCharacterPosition(block[2], lineMapping, mappingLen);
				var endLine = LinePositionUtils::getLineFromCharacterPosition(block[3], lineMapping, mappingLen, startLine);

				if (startLine == 0) startLine = 1;
				if (endLine == 0) endLine = startLine;

				// Calculate how many executable lines this block spans
				var executableLineCount = 0;
				for (var l = startLine; l <= endLine; l++) {
					if (structKeyExists(executableLines, l)) {
						executableLineCount++;
					}
				}

				// Distribute execution time evenly across executable lines
				var timePerLine = executableLineCount > 0 ? (block[4] / executableLineCount) : block[4];

				// Add distributed execution time to each line
				for (var l = startLine; l <= endLine; l++) {
					if (structKeyExists(executableLines, l)) {
						if (!structKeyExists(f, l)) {
							f[l] = [1, timePerLine];
						} else {
							f[l][1] += 1;
							f[l][2] += timePerLine;
						}
					}
				}
			}

			coverage[fileIdx] = f;
		}

		var totalTime = getTickCount() - startTime;
		variables.logger.debug("overlapFilterPositionBased: Completed " & structCount(coverage)
			& " files in " & totalTime & "ms");
		return coverage;
	}

	/**
	 * Character position to line conversion with binary search optimization
	 */
	public numeric function getLineFromCharacterPosition(charPos, filePath, lineMapping, mappingLen, minLine = 1) {
		// Fail fast if mapping is invalid
		if (!isArray(arguments.lineMapping) || arguments.mappingLen == 0) {
			throw 'getLineFromCharacterPosition: Invalid lineMapping or mappingLen=0. ' & serializeJSON(var=arguments);
		}

		// Use optimized utility function
		var result = LinePositionUtils::getLineFromCharacterPosition(
			arguments.charPos,
			arguments.lineMapping,
			arguments.mappingLen,
			arguments.minLine
		);

		// NOTE: LinePositionUtils returns 0 for invalid positions, but this component
		// expects a fallback to line 1 for backward compatibility
		return result == 0 ? 1 : result;
	}

	/**
	* Filter overlapping blocks for line-based data
	* Blocks are already defined by line numbers [fileIdx, startLine, endLine, execTime]
	*/
	private array function filterOverlappingBlocksLineBased(blocks) {
		var filteredBlocks = [];
		var blockRanges = [];

		// Build block ranges for comparison
		for (var i = 1; i <= arrayLen(blocks); i++) {
			var block = blocks[i];
			var startLine = block[2];
			var endLine = block[3];

			if (startLine == 0) startLine = 1;
			if (endLine == 0) endLine = startLine;

			blockRanges.append({
				index: i,
				startLine: startLine,
				endLine: endLine,
				span: endLine - startLine + 1,
				block: block
			});
		}

		// Check for whole-file blocks
		var hasWholeFileBlock = false;
		for (var i = 1; i <= arrayLen(blockRanges); i++) {
			if (blockRanges[i].startLine <= 1 && blockRanges[i].span >= 10) {
				hasWholeFileBlock = true;
				break;
			}
		}

		if (hasWholeFileBlock) {
			// Sort by span size (smallest first)
			arraySort(blockRanges, function(a, b) {
				return a.span - b.span;
			});

			// Keep only the most specific blocks
			var keptBlocks = [];
			for (var i = 1; i <= arrayLen(blockRanges); i++) {
				var current = blockRanges[i];
				var shouldKeep = true;

				// Check if this block is encompassed by a smaller block we're keeping
				for (var j = 1; j <= arrayLen(keptBlocks); j++) {
					var kept = keptBlocks[j];
					if (kept.startLine >= current.startLine && kept.endLine <= current.endLine && kept.span < current.span) {
						shouldKeep = false;
						break;
					}
				}

				if (shouldKeep) {
					// Remove any blocks this one encompasses
					var newKeptBlocks = [];
					for (var k = 1; k <= arrayLen(keptBlocks); k++) {
						var existing = keptBlocks[k];
						if (!(current.startLine <= existing.startLine && current.endLine >= existing.endLine && current.span > existing.span)) {
							newKeptBlocks.append(existing);
						}
					}
					newKeptBlocks.append(current);
					keptBlocks = newKeptBlocks;
				}
			}

			// Convert back to blocks array
			for (var i = 1; i <= arrayLen(keptBlocks); i++) {
				filteredBlocks.append(keptBlocks[i].block);
			}
		} else {
			// No whole-file blocks detected, return original blocks
			filteredBlocks = blocks;
		}

		return filteredBlocks;
	}

	/**
	* Filter overlapping blocks for position-based (character offset) data
	* Blocks are defined by character positions [fileIdx, startPos, endPos, execTime]
	*/
	private array function filterOverlappingBlocksPositionBased(blocks, lineMapping, mappingLen) {
		var filteredBlocks = [];
		var blockRanges = [];
		// Convert all blocks to line ranges for comparison
		for (var i = 1; i <= arrayLen(blocks); i++) {
			var block = blocks[i];
			var startLine = 0;
			var endLine = 0;
				if (blocksAreLineBased) {
					startLine = block[2];
					endLine = block[3];
				} else {
					startLine = LinePositionUtils::getLineFromCharacterPosition(block[2], lineMapping, mappingLen);
					endLine = LinePositionUtils::getLineFromCharacterPosition(block[3], lineMapping, mappingLen);
				}
			if (startLine == 0) startLine = 1;
			if (endLine == 0) endLine = startLine;
			blockRanges.append({
				index: i,
				startLine: startLine,
				endLine: endLine,
				span: endLine - startLine + 1,
				block: block
			});
		}
		// Check for whole-file blocks and warn
		var isWholeFile = false;
		for (var i = 1; i <= arrayLen(blockRanges); i++) {
			var current = blockRanges[i];
			if (current.startLine <= 1 && current.span >= 10) {
				isWholeFile = true;
			}
		}
		// If we have whole-file blocks, filter them out aggressively
		if (isWholeFile) {
			// Sort by span size (smallest first)
			arraySort(blockRanges, function(a, b) {
				return a.span - b.span;
			});
			// Keep only the most specific blocks
			var keptBlocks = [];
			for (var i = 1; i <= arrayLen(blockRanges); i++) {
				var current = blockRanges[i];
				var shouldKeep = true;
				for (var j = 1; j <= arrayLen(keptBlocks); j++) {
					var kept = keptBlocks[j];
					if (kept.startLine >= current.startLine && kept.endLine <= current.endLine && kept.span < current.span) {
						shouldKeep = false;
						break;
					}
				}
				if (shouldKeep) {
					var newKeptBlocks = [];
					for (var k = 1; k <= arrayLen(keptBlocks); k++) {
						var existing = keptBlocks[k];
						if (!(current.startLine >= existing.startLine && current.endLine <= existing.endLine && current.span < existing.span)) {
							newKeptBlocks.append(existing);
						}
					}
					newKeptBlocks.append(current);
					keptBlocks = newKeptBlocks;
				}
			}
			// Convert back to blocks array
			for (var i = 1; i <= arrayLen(keptBlocks); i++) {
				filteredBlocks.append(keptBlocks[i].block);
			}
		} else {
			// No whole-file blocks detected, return original blocks
			filteredBlocks = blocks;
		}
		return filteredBlocks;
	}

	/**
	 * Character to line mapping with improved string processing
	 */
	public array function buildCharacterToLineMapping(string fileContent) {
		var lineStarts = [1];
		var currentPos = 1;
		var contentLen = len(arguments.fileContent);

		// OPTIMIZATION: Process in chunks for better performance
		var chunkSize = 1000;
		while (currentPos < contentLen) {
			var endPos = min(currentPos + chunkSize, contentLen);
			var chunk = mid(arguments.fileContent, currentPos, endPos - currentPos);
			var chunkPos = 1;

			while (true) {
				var newlinePos = find(chr(10), chunk, chunkPos);
				if (newlinePos == 0) break;

				arrayAppend(lineStarts, currentPos + newlinePos);
				chunkPos = newlinePos + 1;
			}

			currentPos = endPos;
		}

		return lineStarts;
	}


	public void function ensureDirectoryExists(required string directoryPath) {
		if (!directoryExists(arguments.directoryPath)) {
			directoryCreate(arguments.directoryPath, true);
		}
	}

}