component accessors="true" {

	/**
	 * Utility: Group blocks by fileIdx: { fileIdx: [block, block, ...] }
	 */
	public function combineChunkResults(chunkResults) {
		var blocksByFile = {};
		for (var chunkBlocks in chunkResults) {
			for (var b = 1; b <= arrayLen(chunkBlocks); b++) {
				var block = chunkBlocks[b];
				var fileIdx = block[1];
				if (!structKeyExists(blocksByFile, fileIdx)) blocksByFile[fileIdx] = [];
				arrayAppend(blocksByFile[fileIdx], block);
			}
		}
		return blocksByFile;
	}


	/**
	 * Private helper: Shared logic for mapping blocks to line-based coverage, grouped by fileIdx
	 * the lucee coverage data sometimes spans a large block of code, which for LCOV purposes we want to ignore, if a larger block covers smaller lines or blocks, it should be ignored
	 */
	public struct function processBlocks(blocksByFile, files, lineMappingsCache, boolean blocksAreLineBased = false) {
		var coverage = {};
		var perFileResults = [];
		structEach(blocksByFile, function(fileIdx, blocks) {
			if (!structKeyExists(files, fileIdx)) return;
			var filePath = files[fileIdx].path;
			var lineMapping = lineMappingsCache[filePath];
			var mappingLen = arrayLen(lineMapping);
			var f = {};
			
			// Filter out large blocks that encompass smaller, more specific blocks
			var filteredBlocks = filterOverlappingBlocks(blocks, blocksAreLineBased, lineMapping, mappingLen, filePath);
			
			for (var b = 1; b <= arrayLen(filteredBlocks); b++) {
				var block = filteredBlocks[b];
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
				for (var l = startLine; l <= endLine; l++) {
					if (!structKeyExists(f, l)) {
						f[l] = [1, block[4]];
					} else {
						f[l][1] += 1;
						f[l][2] += block[4];
					}
				}
			}
			perFileResults.append({fileIdx=fileIdx, fileCoverage=f});
		}, true); // true = parallel

		for (var result in perFileResults) {
			coverage[result.fileIdx] = result.fileCoverage;
		}
		return coverage;
	}

	/**
	 * Utility: Accumulate line coverage for a file and line range
	 */
	public void function accumulateLineCoverage(coverage, r) {
		for (var l = arguments.r[2]; l <= arguments.r[3]; l++) {
			if (!structKeyExists(arguments.coverage, arguments.r[1])) {
				arguments.coverage[arguments.r[1]] = {};
			}
			if (!structKeyExists(arguments.coverage[arguments.r[1]], l)) {
				arguments.coverage[arguments.r[1]][l] = [1, int(arguments.r[4])];
			} else {
				var lineData = arguments.coverage[arguments.r[1]][l];
				lineData[1] += 1;
				lineData[2] += int(arguments.r[4]);
			}
		}
	}

	/**
	 * Utility: Get the line number for a given character position in a file.
	 * This is a copy of the parser's method for utility use.
	 */
	public numeric function getLineFromCharacterPosition(charPos, path, lineMapping, mappingLen) {
		var lineStarts = lineMapping;
		var len = mappingLen;
		var low = 1;
		var high = len;
		while (low <= high) {
			var mid = int((low + high) / 2);
			if (mid == len) {
				return lineStarts[mid] <= arguments.charPos ? mid : mid - 1;
			} else if (lineStarts[mid] <= arguments.charPos && arguments.charPos < lineStarts[mid + 1]) {
				return mid;
			} else if (lineStarts[mid] > arguments.charPos) {
				high = mid - 1;
			} else {
				low = mid + 1;
			}
		}
		return 0;
	}

	/**
	* Builds a mapping of character positions to line numbers for a file.
	* Returns an array where each element represents the character position where that line starts.
	*/
	public array function buildCharacterToLineMapping(string fileContent) {
		var lineStarts = [1];
		var currentPos = 1;
		var newlinePos = 0;

		// Find newlines in chunks rather than character by character
		while (true) {
			newlinePos = find(chr(10), arguments.fileContent, currentPos);
			if (newlinePos == 0) break;

			arrayAppend(lineStarts, newlinePos + 1);
			currentPos = newlinePos + 1;
		}

		return lineStarts;
	}


	public struct function parseMetadata(array lines) {
		var metadata = {};
		for (var metaLine in arguments.lines) {
			var parts = listToArray(metaLine, ":", true, true);
			if (arrayLen(parts) >= 2) {
				metadata[parts[1]] = listRest(metaLine, ":");
			}
		}
		return metadata;
	}

	/*
	* Calculates coverage stats for a file's lineCoverage struct
	*/
	public struct function calculateCoverageStats( struct result ) {
		var stats = {
			"totalLinesFound": 0,
			"totalLinesHit": 0,
			"totalExecutions": 0,
			"totalExecutionTime": 0,
			"files": {}
		};
		var statsTemplate = {
			"linesFound": 0,
			"linesHit": 0,
			"totalExecutions": 0,
			"totalExecutionTime": 0,
			"executedLines": {}
		};
		for (var filePath in result.source.files) {
			stats.files[ filePath ] = duplicate( statsTemplate );

			stats.files[ filePath ].linesFound += result.source.files[ filePath ].linesFound;
			stats.totalLinesFound += result.source.files[ filePath ].linesFound;

			if ( structKeyExists( result.coverage, filePath ) ) {
				var filecoverage = result.coverage[ filePath ];
				var fileLinesHit = arrayLen( structKeyArray( filecoverage ) );
				stats.totalLinesHit += fileLinesHit;
				stats.files[ filePath ].linesHit += fileLinesHit;
				for ( var lineNum in filecoverage ) {
					var lineData = filecoverage[ lineNum ];
					stats.totalExecutions += lineData[ 1 ];
					stats.totalExecutionTime += lineData[ 2 ];
					stats.files[ filePath ].totalExecutions += lineData[ 1 ];
					stats.files[ filePath ].totalExecutionTime += lineData[ 2 ];
					// stats.executedLines[ lineNum ] = lineData;
				}
			}
		}
		return stats;
	}

	/**
	 * Filter out large blocks that encompass smaller, more specific blocks
	 * This removes whole-file or large function blocks when smaller execution blocks exist within them
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
			if (current.startLine <= 1 && current.span >= 10) { // Heuristic for whole-file coverage
				// systemOutput("WARNING whole-file coverage for file: " & filePath & " (" & current.startLine & "-" & current.endLine & ")", true);
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
				
				// Check if this block encompasses any already kept blocks
				for (var j = 1; j <= arrayLen(keptBlocks); j++) {
					var kept = keptBlocks[j];
					if (kept.startLine >= current.startLine && kept.endLine <= current.endLine && kept.span < current.span) {
						// Current block encompasses a smaller kept block, don't keep current
						shouldKeep = false;
						break;
					}
				}
				
				if (shouldKeep) {
					// Remove any existing kept blocks that this current block is more specific than
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

}