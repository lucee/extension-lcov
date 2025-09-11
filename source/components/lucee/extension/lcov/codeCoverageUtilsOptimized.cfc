component accessors="true" {
	// OPTIMIZED VERSION - For performance comparison and development
	// Based on codeCoverageUtils.cfc with major performance optimizations

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
	 * OPTIMIZED: Merge coverage results by file path from multiple .exl parsing results
	 * Uses pre-computed file mappings to avoid redundant lookups
	 * @results Struct of parsed results from multiple .exl files
	 * @return Struct with mergedCoverage and sorted files array
	 */
	public struct function mergeResultsByFile(required struct results) {
		var startTime = getTickCount();
		///logger("=== OPTIMIZED MERGE: Starting merge of " & structCount(arguments.results) & " .exl files ===");
		
		var merged = {
			files: {},
			coverage: {}
		};

		// OPTIMIZATION: Pre-build all file mappings to avoid repeated lookups
		var fileMappings = {};
		var totalSourceFiles = 0;
		
		for (var src in arguments.results) {
			var files = arguments.results[src].source.files;
			fileMappings[src] = {};
			
			for (var f in files) {
				if (!structKeyExists(merged.files, files[f].path)) {
					merged.files[files[f].path] = files[f];
					totalSourceFiles++;
				}
				fileMappings[src][f] = files[f].path;
			}
		}
		
		logger("Pre-computed file mappings: " & totalSourceFiles & " unique source files");

		// OPTIMIZATION: Process coverage with pre-computed mappings
		var totalCoverageLines = 0;
		for (var src in arguments.results) {
			var coverage = arguments.results[src].coverage;
			var mapping = fileMappings[src];

			for (var f in coverage) {
				var realFile = mapping[f];
				if (!structKeyExists(merged.coverage, realFile)) {
					merged.coverage[realFile] = {};
				}
				
				// OPTIMIZATION: Process line coverage in batch
				var sourceLines = structKeyArray(coverage[f]);
				for (var i = 1; i <= arrayLen(sourceLines); i++) {
					var l = sourceLines[i];
					if (!structKeyExists(merged.coverage[realFile], l)) {
						merged.coverage[realFile][l] = [0, 0];
					}
					var lineData = merged.coverage[realFile][l];
					var srcLineData = coverage[f][l];
					lineData[1] += srcLineData[1];
					lineData[2] += srcLineData[2];
					totalCoverageLines++;
				}
			}
		}

		var files = structKeyArray(merged.files);
		arraySort(files, "textnocase");
		
		var totalTime = getTickCount() - startTime;
		//logger("=== OPTIMIZED MERGE: Completed in " & totalTime & "ms ===");
		logger("Processed " & numberFormat(totalCoverageLines) 
			& " coverage lines for " & arrayLen(files) & " files");
		
		return {
			"mergedCoverage": merged,
			"files": files
		};
	}

	/**
	 * OPTIMIZED: Calculate LCOV-style statistics from merged coverage data
	 * Uses batch processing and reduced function calls
	 * @fileCoverage Struct containing files and coverage data (merged format)
	 * @return Struct with stats per file path
	 */
	public struct function calculateLcovStats(required struct fileCoverage) {
		var startTime = getTickCount();
		var fileCount = structCount(arguments.fileCoverage.files);
		//logger("=== OPTIMIZED LCOV STATS: Processing " & fileCount & " files ===");
		
		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;
		var stats = {};

		// OPTIMIZATION: Process all files in batch with minimal function calls
		for (var file in files) {
			var data = coverage[file];
			var lineNumbers = structKeyArray(data);
			
			// OPTIMIZATION: Count hits in single pass
			var linesHit = 0;
			for (var i = 1; i <= arrayLen(lineNumbers); i++) {
				if (data[lineNumbers[i]][1] > 0) {
					linesHit++;
				}
			}

			var linesFoundValue = structKeyExists(files[file], "linesFound") ? files[file].linesFound : arrayLen(lineNumbers);
			stats[files[file].path] = {
				"linesFound": linesFoundValue,
				"linesHit": linesHit,
				"lineCount": structKeyExists(files[file], "lineCount") ? files[file].lineCount : 0
			};
		}

		var totalTime = getTickCount() - startTime;
		logger("LCOV calculated: Completed " & structCount(stats) 
			& " files in " & numberFormat(totalTime) & "ms");
		return stats;
	}

	/**
	 * OPTIMIZED: Group blocks by fileIdx with reduced overhead
	 */
	public function combineChunkResults(chunkResults) {
		var startTime = getTickCount();
		var blocksByFile = {};
		var totalBlocks = 0;
		
		// OPTIMIZATION: Single pass with batch processing
		for (var c = 1; c <= arrayLen(chunkResults); c++) {
			var chunkBlocks = chunkResults[c];
			for (var b = 1; b <= arrayLen(chunkBlocks); b++) {
				var block = chunkBlocks[b];
				var fileIdx = block[1];
				if (!structKeyExists(blocksByFile, fileIdx)) blocksByFile[fileIdx] = [];
				arrayAppend(blocksByFile[fileIdx], block);
				totalBlocks++;
			}
		}
		
		var totalTime = getTickCount() - startTime;
		logger("Combined " & totalBlocks & " blocks for " & structCount(blocksByFile) & " files in " & totalTime & "ms");
		return blocksByFile;
	}

	/**
	 * OPTIMIZED: Process blocks with streamlined overlap detection and caching
	 * Major performance improvements over original version
	 */
	public struct function excludeOverlappingBlocks(blocksByFile, files, lineMappingsCache, boolean blocksAreLineBased = false) {
		var startTime = getTickCount();
		var totalBlocks = 0;
		
		// Count total blocks for logging
		for (var fileIdx in arguments.blocksByFile) {
			totalBlocks += arrayLen(arguments.blocksByFile[fileIdx]);
		}
		
		//logger("=== OPTIMIZED PROCESS BLOCKS: " & totalBlocks & " blocks, " & structCount(arguments.blocksByFile) & " files ===");
		var coverage = {};
		
		// OPTIMIZATION: Pre-compute executable lines for all files once
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
	 * OPTIMIZED: Character position to line conversion with binary search optimization
	 * Includes minLine hint for sequential processing
	 */
	public numeric function getLineFromCharacterPosition(charPos, filePath, lineMapping, mappingLen, minLine = 1) {
		// Fail fast if mapping is invalid
		if (!isArray(arguments.lineMapping) || arguments.mappingLen == 0) {
			throw 'getLineFromCharacterPosition: Invalid lineMapping or mappingLen=0. Args: charPos=' & arguments.charPos & ', mappingLen=' & arguments.mappingLen & ', minLine=' & arguments.minLine & ', lineMappingType=' & (isArray(arguments.lineMapping) ? 'array' : typeOf(arguments.lineMapping));
		}
		// OPTIMIZATION: Use minLine hint for sequential processing
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
	* OPTIMIZED: Streamlined overlap detection with character-based filtering
	* Major performance improvement over line-based approach
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
	 * OPTIMIZED: Character to line mapping with improved string processing
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

	/**
	 * Same as original - metadata parsing is already efficient
	 */
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

	/**
	 * OPTIMIZED: Calculate coverage stats with reduced overhead
	 */
	public struct function calculateCoverageStats( struct result ) {
		var startTime = getTickCount();
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
		
		// OPTIMIZATION: Pre-compute file paths array to avoid repeated key lookups
		var filePaths = structKeyArray(arguments.result.source.files);
		
		for (var i = 1; i <= arrayLen(filePaths); i++) {
			var filePath = filePaths[i];

			stats.files[ filePath ] = duplicate( statsTemplate );

			// Add linesCount (total lines in file, informational)
			var linesCount = structKeyExists(arguments.result.source.files[filePath], "linesCount") ? arguments.result.source.files[filePath].linesCount : 0;
			stats.files[filePath].linesCount = linesCount;

			stats.files[ filePath ].linesFound += arguments.result.source.files[ filePath ].linesFound;
			stats.totalLinesFound += arguments.result.source.files[ filePath ].linesFound;

			if ( structKeyExists( arguments.result.coverage, filePath ) ) {
				var filecoverage = arguments.result.coverage[ filePath ];
				var fileLinesHit = structCount( filecoverage );
				stats.totalLinesHit += fileLinesHit;
				stats.files[ filePath ].linesHit += fileLinesHit;

				// OPTIMIZATION: Process line data in batch
				var lineNumbers = structKeyArray(filecoverage);
				for ( var j = 1; j <= arrayLen(lineNumbers); j++ ) {
					var lineNum = lineNumbers[j];
					var lineData = filecoverage[ lineNum ];
					stats.totalExecutions += lineData[ 1 ];
					stats.totalExecutionTime += lineData[ 2 ];
					stats.files[ filePath ].totalExecutions += lineData[ 1 ];
					stats.files[ filePath ].totalExecutionTime += lineData[ 2 ];
				}
				// No warning here; test should assert linesHit/linesFound <= linesCount
			}
		}
		
		var totalTime = getTickCount() - startTime;
		//logger("Calculated coverage stats for " & arrayLen(filePaths) & " files in " & totalTime & "ms");
		return stats;
	}

	/**
	 * OPTIMIZED: Calculate detailed statistics with performance improvements
	 */
	public struct function calculateDetailedStats(required struct results, numeric processingTimeMs = 0) {
		var startTime = getTickCount();
		var executedFiles = 0;
		var fileStats = {};
		var totalResults = structCount(arguments.results);

		logger("Calculating detailed stats for " & totalResults & " result files");

		// OPTIMIZATION: Pre-build file path mappings to avoid repeated lookups
		var filePathMappings = {};
		for (var resultFile in arguments.results) {
			var result = arguments.results[resultFile];
			if (structKeyExists(result, "source") && structKeyExists(result.source, "files")) {
				filePathMappings[resultFile] = {};
				for (var fileIndex in result.source.files) {
					filePathMappings[resultFile][fileIndex] = result.source.files[fileIndex].path;
				}
			}
		}

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
						
						// OPTIMIZATION: Process line coverage in batch
						var lineNumbers = structKeyArray(fileCoverage);
						for (var i = 1; i <= arrayLen(lineNumbers); i++) {
							var line = lineNumbers[i];
							if (val(fileCoverage[line][1]) > 0) {
								fileStats[filePath].coveredLineNumbers[line] = true;
								hasExecutedCode = true;
							}
						}
					}
				}
			}

			if (hasExecutedCode) {
				executedFiles++;
			}
		}

		// OPTIMIZATION: Calculate totals in single pass
		var globalTotalLines = 0;
		var globalCoveredLines = 0;
		var filePathsArray = structKeyArray(fileStats);
		
		for (var i = 1; i <= arrayLen(filePathsArray); i++) {
			var filePath = filePathsArray[i];
			var fileStatData = fileStats[filePath];
			
			globalTotalLines += fileStatData.totalLines;
			
			// Update covered lines count based on unique line numbers
			fileStatData.coveredLines = structCount(fileStatData.coveredLineNumbers);
			globalCoveredLines += fileStatData.coveredLines;
			
			// Calculate percentage
			if (fileStatData.totalLines > 0) {
				fileStatData.coveragePercentage = 
					(fileStatData.coveredLines / fileStatData.totalLines) * 100;
			}
			
			// Clean up temporary tracking data
			structDelete(fileStatData, "coveredLineNumbers");
		}
		
		var coveragePercentage = globalTotalLines > 0 ? (globalCoveredLines / globalTotalLines) * 100 : 0;
		var totalTime = getTickCount() - startTime;
		
		logger("Detailed stats completed in " & totalTime & "ms: " & globalCoveredLines & "/" & globalTotalLines & " lines");

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
	 * Same as original - directory operations are already efficient
	 */
	public void function ensureDirectoryExists(required string directoryPath) {
		if (!directoryExists(arguments.directoryPath)) {
			directoryCreate(arguments.directoryPath, true);
		}
	}

}