component accessors="true" {

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
	 * Merge coverage results by file path from multiple .exl parsing results
	 * @results Struct of parsed results from multiple .exl files
	 * @return Struct with mergedCoverage and sorted files array
	 */
	public struct function mergeResultsByFile(required struct results) {
		logger("Merging results from " & structCount(arguments.results) & " .exl files");
		
		var merged = {
			files: {},
			coverage: {}
		};

		for (var src in arguments.results) {
			var coverage = arguments.results[src].coverage;
			var files = arguments.results[src].source.files;
			var mapping = {};

			for (var f in files) {
				if (!structKeyExists(merged.files, files[f].path)) {
					merged.files[files[f].path] = files[f];
				}
				mapping[f] = files[f].path;
			}

			for (var f in coverage) {
				var realFile = mapping[f];
				if (!structKeyExists(merged.coverage, realFile)) {
					merged.coverage[realFile] = {};
				}
				for (var l in coverage[f]) {
					if (!structKeyExists(merged.coverage[realFile], l)) {
						merged.coverage[realFile][l] = [0, 0];
					}
					var lineData = merged.coverage[realFile][l];
					var srcLineData = coverage[f][l];
					lineData[1] += srcLineData[1];
					lineData[2] += srcLineData[2];
				}
			}
		}

		var files = structKeyArray(merged.files);
		arraySort(files, "textnocase");
		
		logger("Merged coverage data for " & arrayLen(files) & " unique files");
		
		return {
			"mergedCoverage": merged,
			"files": files
		};
	}

	/**
	 * Calculate LCOV-style statistics from merged coverage data
	 * @fileCoverage Struct containing files and coverage data (merged format)
	 * @return Struct with stats per file path
	 */
	public struct function calculateLcovStats(required struct fileCoverage) {
		logger("Calculating LCOV stats for " & structCount(arguments.fileCoverage.files) & " files");
		
		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;
		var stats = {};

		for (var file in files) {
			var data = coverage[file];
			var lineNumbers = structKeyArray(data);
			
			// Count actual lines hit (with hit count > 0)
			var linesHit = 0;
			for (var line in lineNumbers) {
				if (data[line][1] > 0) {
					linesHit++;
				}
			}

			var linesFoundValue = structKeyExists(files[file], "linesFound") ? files[file].linesFound : arrayLen(lineNumbers);
			stats[files[file].path] = {
				"linesFound": linesFoundValue,
				"linesHit": linesHit,
				"lineCount": structKeyExists(files[file], "lineCount") ? files[file].lineCount : 0
			};
			
			logger("File stats: " & files[file].path & " (LF:" & linesFoundValue & ", LH:" & linesHit & ")");
		}

		logger("Calculated LCOV stats for " & structCount(stats) & " files");
		return stats;
	}

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

		// Use structEach with parallel=true and directly populate coverage struct (thread-safe)
		structEach(blocksByFile, function(fileIdx, blocks) {
			if (!structKeyExists(files, fileIdx)) return;
			var filePath = files[fileIdx].path;
			var lineMapping = lineMappingsCache[filePath];
			var mappingLen = arrayLen(lineMapping);
			var f = {};
			
			// Get executable lines for this file to filter execution hits
			var executableLines = structKeyExists(files[fileIdx], "executableLines") ? files[fileIdx].executableLines : {};
			
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
					// Only count execution hits for lines that are actually executable
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
			// Directly assign to coverage struct - thread-safe since each fileIdx is unique
			coverage[fileIdx] = f;
		}, true); // true = parallel, safe now that we're not using shared array

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

	/**
	 * Calculate detailed statistics from parsed results including per-file breakdown
	 * @results Struct of parsed results from multiple .exl files
	 * @processingTimeMs Optional processing time to include in stats
	 * @return Struct with detailed coverage statistics
	 */
	public struct function calculateDetailedStats(required struct results, numeric processingTimeMs = 0) {
		var executedFiles = 0;
		var fileStats = {};

		for (var resultFile in arguments.results) {
			var result = arguments.results[resultFile];
			var hasExecutedCode = false;

			// Build per-file stats from raw coverage data
			if (structKeyExists(result, "source") && structKeyExists(result.source, "files")) {
				for (var fileIndex in result.source.files) {
					var fileInfo = result.source.files[fileIndex];
					var filePath = fileInfo.path;
					
					if (!structKeyExists(fileStats, filePath)) {
						fileStats[filePath] = {
							"totalLines": val(fileInfo.linesFound ?: 0),
							"coveredLines": 0,
							"coveragePercentage": 0,
							"coveredLineNumbers": {}
						};
					}

					// Calculate covered lines for this file (track unique line numbers)
					if (structKeyExists(result, "coverage") && structKeyExists(result.coverage, fileIndex)) {
						var fileCoverage = result.coverage[fileIndex];
						for (var line in fileCoverage) {
							if (val(fileCoverage[line][1]) > 0) {
								fileStats[filePath].coveredLineNumbers[line] = true;
								hasExecutedCode = true;
							}
						}
					}
				}
			}

			// Count files that had any executed code
			if (hasExecutedCode) {
				executedFiles++;
			}
		}

		// Calculate global totals by summing up per-file stats
		var globalTotalLines = 0;
		var globalCoveredLines = 0;
		for (var filePath in fileStats) {
			globalTotalLines += fileStats[filePath].totalLines;
			globalCoveredLines += fileStats[filePath].coveredLines;
		}
		
		var coveragePercentage = globalTotalLines > 0 ? (globalCoveredLines / globalTotalLines) * 100 : 0;

		// Calculate final coverage percentages and clean up temporary tracking data
		for (var filePath in fileStats) {
			// Update covered lines count based on unique line numbers
			fileStats[filePath].coveredLines = structCount(fileStats[filePath].coveredLineNumbers);
			
			// Calculate percentage - should reflect actual coverage, not capped
			if (fileStats[filePath].totalLines > 0) {
				fileStats[filePath].coveragePercentage = 
					(fileStats[filePath].coveredLines / fileStats[filePath].totalLines) * 100;
			}
			
			// Clean up temporary tracking data
			if (structKeyExists(fileStats[filePath], "coveredLineNumbers")) {
				structDelete(fileStats[filePath], "coveredLineNumbers");
			}
		}

		return {
			"totalLines": globalTotalLines,
			"coveredLines": globalCoveredLines,
			"coveragePercentage": coveragePercentage,
			"totalFiles": structCount(fileStats),
			"executedFiles": executedFiles,
			"processingTimeMs": arguments.processingTimeMs,
			"fileStats": fileStats
		};
	}

	/**
	 * Utility method to ensure a directory exists
	 * @directoryPath The directory path to check/create
	 */
	public void function ensureDirectoryExists(required string directoryPath) {
		if (!directoryExists(arguments.directoryPath)) {
			directoryCreate(arguments.directoryPath, true);
		}
	}

}