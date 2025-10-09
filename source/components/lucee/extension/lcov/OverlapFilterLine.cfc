component displayname="OverlapFilterLine" accessors="true" {

	/**
	 * Initialize the line-based overlap filter
	 * @options Configuration options struct (optional)
	 */
	public function init(struct options = {}) {
		variables.options = arguments.options;
		var logLevel = variables.options.logLevel ?: "none";
		variables.logger = new lucee.extension.lcov.Logger(level=logLevel);
		return this;
	}

	/**
	 * Process line-based blocks with overlap detection
	 * Blocks are already defined by line numbers [fileIdx, startLine, endLine, execTime]
	 */
	public struct function filter(blocksByFile, files, lineMappingsCache) {
		var startTime = getTickCount();
		var coverage = [=];

		// Process each file's blocks
		for (var fileIdx in arguments.blocksByFile) {
			if (!structKeyExists(arguments.files, fileIdx)) continue;

			var blocks = arguments.blocksByFile[fileIdx];
			var f = {};

			// Get executable lines for this file
			var executableLines = structKeyExists(arguments.files[fileIdx], "executableLines")
				? arguments.files[fileIdx].executableLines : {};

			// Filter overlapping blocks
			var filteredBlocks = filterOverlappingBlocks(blocks);

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
		variables.logger.debug("OverlapFilterLine: Completed " & structCount(coverage)
			& " files in " & totalTime & "ms");
		return coverage;
	}

	/**
	 * Filter overlapping blocks for line-based data
	 * Blocks are already defined by line numbers [fileIdx, startLine, endLine, execTime]
	 */
	private array function filterOverlappingBlocks(blocks) {
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
}