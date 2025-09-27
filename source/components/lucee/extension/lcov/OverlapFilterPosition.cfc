component displayname="OverlapFilterPosition" accessors="true" {

	/**
	 * Initialize the position-based overlap filter
	 * @options Configuration options struct (optional)
	 */
	public function init(struct options = {}) {
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
		return this;
	}

	
	/**
	 * Filter overlapping position-based blocks
	 * Returns filtered blocks still in character position format
	 */
	public struct function filter(blocksByFile, files, lineMappingsCache) {
		var startTime = getTickCount();
		var result = {};

		// Process each file's blocks
		for (var fileIdx in arguments.blocksByFile) {
			var blocks = arguments.blocksByFile[fileIdx];
			// Filter overlapping blocks based on character positions
			result[fileIdx] = filterOverlappingBlocks(blocks);
		}

		var totalTime = getTickCount() - startTime;
		logger("OverlapFilterPosition: Filtered " & structCount(result)
			& " files in " & totalTime & "ms");
		return result;
	}

	/**
	 * Filter overlapping blocks for position-based (character offset) data
	 * Blocks are defined by character positions [fileIdx, startPos, endPos, execTime]
	 */
	private array function filterOverlappingBlocks(blocks) {
		var filteredBlocks = [];

		// Sort blocks by span size (smallest first)
		var blockRanges = [];
		for (var i = 1; i <= arrayLen(blocks); i++) {
			var block = blocks[i];
			blockRanges.append({
				index: i,
				startPos: block[2],
				endPos: block[3],
				span: block[3] - block[2],
				block: block
			});
		}

		// Sort by span size (smallest first)
		arraySort(blockRanges, function(a, b) {
			return a.span - b.span;
		});

		// Keep only the most specific blocks (smallest that aren't contained within other blocks)
		var keptBlocks = [];
		for (var i = 1; i <= arrayLen(blockRanges); i++) {
			var current = blockRanges[i];
			var shouldKeep = true;

			// Check if this block is fully contained within any block we're already keeping
			for (var j = 1; j <= arrayLen(keptBlocks); j++) {
				var kept = keptBlocks[j];
				// If an existing block fully contains this block, skip it
				if (kept.startPos <= current.startPos && kept.endPos >= current.endPos) {
					shouldKeep = false;
					break;
				}
			}

			// Also check if this block would contain any already-kept blocks
			// If so, skip it (prefer the more specific blocks we already have)
			if (shouldKeep) {
				for (var j = 1; j <= arrayLen(keptBlocks); j++) {
					var kept = keptBlocks[j];
					// If this block would fully contain an existing block, skip it
					if (current.startPos <= kept.startPos && current.endPos >= kept.endPos) {
						shouldKeep = false;
						break;
					}
				}
			}

			if (shouldKeep) {
				keptBlocks.append(current);
			}
		}

		// Convert back to blocks array
		for (var i = 1; i <= arrayLen(keptBlocks); i++) {
			filteredBlocks.append(keptBlocks[i].block);
		}

		return filteredBlocks;
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

}