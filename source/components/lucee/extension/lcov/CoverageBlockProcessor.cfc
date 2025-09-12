component displayname="CoverageBlockProcessor" accessors="true" {

	/**
	* Initialize the utils component with options
	* @options Configuration options struct (optional)
	*/
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
		return this;
	}

	/**
	* Private logging function that respects verbose setting
	* @message The message to log
	*/
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	 * Process blocks with streamlined overlap detection and caching
	 * Major performance improvements over original version
	 */
	public struct function excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, boolean blocksAreLineBased = false) {
		var startTime = getTickCount();
		var totalBlocks = 0;

		// Count total blocks for logging
		for (var fileIdx in arguments.blocksByFile) {
			totalBlocks += arrayLen(arguments.blocksByFile[fileIdx]);
		}

		var coverage = {};
		var executableLinesCache = {};
		for (var fileIdx in arguments.files) {
			executableLinesCache[fileIdx] = structKeyExists(arguments.files[fileIdx], "executableLines") ?
				arguments.files[fileIdx].executableLines : {};
		}

		// Process each file's blocks
		for (var fileIdx in arguments.blocksByFile) {
			if (!structKeyExists(arguments.files, fileIdx)) continue;

			var filePath = arguments.files[fileIdx].path;
			var lineMapping = arguments.lineMappingsCache[filePath];
			var mappingLen = arrayLen(lineMapping);
			var blocks = arguments.blocksByFile[fileIdx];
			var f = {};

			// Get pre-computed executable lines for this file
			var executableLines = executableLinesCache[fileIdx];

			// Use overlap-aware filtering to match original logic and pass all tests
			var filteredBlocks = filterOverlappingBlocks(blocks, arguments.blocksAreLineBased, lineMapping, mappingLen, filePath);

			// OPTIMIZATION: Process blocks in batch with minimal conversions
			for (var b = 1; b <= arrayLen(filteredBlocks); b++) {
				var block = filteredBlocks[b];
				var startLine = 0;
				var endLine = 0;

				if (arguments.blocksAreLineBased) {
					startLine = block[2];
					endLine = block[3];
				} else {
					// Use optimized character position lookup
					   startLine = getLineFromCharacterPosition(block[2], filePath, lineMapping, mappingLen);
					   endLine = getLineFromCharacterPosition(block[3], filePath, lineMapping, mappingLen, startLine);
				}

				if (startLine == 0) startLine = 1;
				if (endLine == 0) endLine = startLine;

				// OPTIMIZATION: Only process executable lines
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
		logger("excludeOverlappingBlocks: Completed " & structCount(coverage)
			& " files in " & totalTime & "ms ===");
		return coverage;
	}

	/**
	 * Character position to line conversion with binary search optimization
	 */
	public numeric function getLineFromCharacterPosition(charPos, filePath, lineMapping, mappingLen, minLine = 1) {
		// Fail fast if mapping is invalid
		if (!isArray(arguments.lineMapping) || arguments.mappingLen == 0) {
			throw 'getLineFromCharacterPosition: Invalid lineMapping or mappingLen=0. Args: charPos=' & arguments.charPos & ', mappingLen=' & arguments.mappingLen & ', minLine=' & arguments.minLine & ', lineMappingType=' & (isArray(arguments.lineMapping) ? 'array' : typeOf(arguments.lineMapping));
		}
		// Use minLine hint for sequential processing, i.e. startLine when processing endline
		var low = arguments.minLine;
		var high = arguments.mappingLen;

		while (low <= high) {
			var mid = int((low + high) / 2);

			if (mid == arguments.mappingLen) {
				return arguments.lineMapping[mid] <= arguments.charPos ? mid : mid - 1;
			} else if (arguments.lineMapping[mid] <= arguments.charPos
				&& arguments.charPos < arguments.lineMapping[mid + 1]) {
				return mid;
			} else if (arguments.lineMapping[mid] > arguments.charPos) {
				high = mid - 1;
			} else {
				low = mid + 1;
			}
		}

		return 1; // Not found, default to first line
	}

	/**
	* Streamlined overlap detection with character-based filtering
	*/
	private array function filterOverlappingBlocks(blocks, blocksAreLineBased, lineMapping, mappingLen, filePath) {
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
					startLine = getLineFromCharacterPosition(block[2], filePath, lineMapping, mappingLen);
					endLine = getLineFromCharacterPosition(block[3], filePath, lineMapping, mappingLen);
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