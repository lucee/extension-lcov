component displayname="OverlapFilterPosition" accessors="true" {

	/**
	 * Initialize the position-based overlap filter
	 * @options Configuration options struct (optional)
	 * @return This instance
	 */
	public function init(struct options = {}) {
		variables.options = arguments.options;
		var logLevel = variables.options.logLevel ?: "none";
		variables.logger = new lucee.extension.lcov.Logger(level=logLevel);
		return this;
	}


	/**
	 * Filter overlapping position-based blocks
	 * Returns filtered blocks still in character position format
	 */
	public struct function filter(aggregatedOrBlocksByFile, files, lineMappingsCache) localmode=true {
		var event = variables.logger.beginEvent("OverlapFilterPosition");
		event["inputEntries"] = structCount(arguments.aggregatedOrBlocksByFile);
		var startTime = getTickCount();
		var result = structNew( "regular" );
		var blocksByFile = structNew( "regular" );

		// Detect input format and convert if needed
		var isAggregatedFormat = false;

		// Check if this is aggregated format (has tab-delimited keys) or blocks format (numeric keys with array values)
		cfloop( collection=arguments.aggregatedOrBlocksByFile, key="local.key", value="local.value" ) {
			if (isArray(value) && arrayLen(value) > 0) {
				if (isArray(value[1])) {
					// This is blocksByFile format (array of arrays)
					blocksByFile = arguments.aggregatedOrBlocksByFile;
					break;
				} else {
					// This is aggregated format (single array with fileIdx as first element)
					isAggregatedFormat = true;
					break;
				}
			}
		}

		if (isAggregatedFormat) {
			// Convert aggregated structure to blocks by file
			cfloop( collection=arguments.aggregatedOrBlocksByFile, key="local.key", value="local.block" ) {
				// Block format from aggregator: [fileIdx, startPos, endPos, count, totalTime]
				var fileIdx = toString(block[1]);
				if (!structKeyExists(blocksByFile, fileIdx)) {
					blocksByFile[fileIdx] = [];
				}
				// Convert to overlap filter format: [fileIdx, startPos, endPos, execTime]
				// Use totalTime as execTime for filtering purposes
				arrayAppend(blocksByFile[fileIdx], [fileIdx, block[2], block[3], block[5]]);
			}
		}

		// Process each file's blocks
		var fileProcessingStart = getTickCount();
		var filesProcessed = 0;
		var filesWithChanges = 0;

		cfloop( collection=blocksByFile, key="local.fileIdx", value="local.blocks" ) {
			var fileStart = getTickCount();
			var blockCountBefore = arrayLen( blocks );

			// Filter overlapping blocks based on character positions
			var filteredBlocks = filterOverlappingBlocks( blocks );
			var blockCountAfter = arrayLen( filteredBlocks );
			filesProcessed++;

			if ( blockCountBefore != blockCountAfter ) {
				filesWithChanges++;
			}

			var fileTime = getTickCount() - fileStart;
			if ( fileTime > 100 ) {
				var filePath = structKeyExists( arguments.files, fileIdx ) && structKeyExists( arguments.files[ fileIdx ], "path" )
					? arguments.files[ fileIdx ].path
					: "file index " & fileIdx;
				variables.logger.trace( "  OverlapFilter: File [" & filePath & "] took " & fileTime & "ms (" & blockCountBefore & " -> " & blockCountAfter & " blocks)" );
			}

			// VALIDATION: Since Phase 2, we keep ALL blocks (just mark overlaps), count should never change
			if (blockCountBefore > 0 && blockCountAfter != blockCountBefore) {
				// Get file path for better error message
				var filePath = "unknown";
				if (structKeyExists(arguments.files, fileIdx) && structKeyExists(arguments.files[fileIdx], "path")) {
					filePath = arguments.files[fileIdx].path;
				}
				throw(
					type = "OverlapFilterPosition.InvalidResult",
					message = "Overlap marking changed block count for file index " & fileIdx,
					detail = "File: " & filePath & ", Blocks before: " & blockCountBefore & ", Blocks after: " & blockCountAfter & ". This should never happen - overlap marking should preserve all blocks."
				);
			}

			if (isAggregatedFormat) {
				// Convert back to aggregated format for each filtered block (including overlapping ones)
				cfloop( array=filteredBlocks, item="local.fBlock" ) {
					// Create key in same format as aggregator (fileIdx\tstartPos\tendPos)
					var key = "#fileIdx#	#fBlock[2]#	#fBlock[3]#";
					// Find original aggregated entry to preserve count information
					if (structKeyExists(arguments.aggregatedOrBlocksByFile, key)) {
						var originalBlock = arguments.aggregatedOrBlocksByFile[key];
						// Add overlap flag as 6th element: [fileIdx, startPos, endPos, hitCount, execTime, isOverlapping]
						var isOverlapping = arrayLen(fBlock) >= 5 ? fBlock[5] : false;
						result[key] = [originalBlock[1], originalBlock[2], originalBlock[3], originalBlock[4], originalBlock[5], isOverlapping];
					} else {
						// Fallback: reconstruct entry (shouldn't happen normally)
						var isOverlapping = arrayLen(fBlock) >= 5 ? fBlock[5] : false;
						result[key] = [fileIdx, fBlock[2], fBlock[3], 1, fBlock[4], isOverlapping];
					}
				}
			} else {
				// Keep blocksByFile format for tests
				result[fileIdx] = filteredBlocks;
			}

			// Count how many blocks are marked as overlapping (for logging)
			var overlappingCount = 0;
			cfloop( array=filteredBlocks, item="local.fBlock" ) {
				if (arrayLen(fBlock) >= 5 && fBlock[5]) {
					overlappingCount++;
				}
			}

			// Log per-file overlap marking details
			if (overlappingCount > 0) {
				var filePath = structKeyExists(arguments.files, fileIdx) && structKeyExists(arguments.files[fileIdx], "path")
					? arguments.files[fileIdx].path
					: "file index " & fileIdx;
				variables.logger.debug("  Marked overlaps in file [" & filePath & "]: " & blockCountAfter & " blocks total (" & overlappingCount & " marked as overlapping)");
			}
		}

		var totalTime = getTickCount() - startTime;
		event["outputEntries"] = structCount( result );
		event["markedEntries"] = 0; // Count of blocks marked as overlapping
		event["filesProcessed"] = filesProcessed;
		event["filesWithOverlaps"] = filesWithChanges;

		// Count total marked overlaps
		cfloop( collection=result, key="local.key", value="local.entry" ) {
			if (isAggregatedFormat && isArray(entry) && arrayLen(entry) >= 6 && entry[6]) {
				event["markedEntries"]++;
			}
		}

		variables.logger.commitEvent( event );

		variables.logger.trace( "OverlapFilterPosition: Processed " & filesProcessed & " files (" & filesWithChanges & " with overlaps) in " & totalTime & "ms" );

		if ( isAggregatedFormat ) {
			variables.logger.debug( "OverlapFilterPosition: Marked overlaps in " & structCount( arguments.aggregatedOrBlocksByFile )
				& " entries (" & event["markedEntries"] & " marked as overlapping) in " & totalTime & "ms" );
		} else {
			variables.logger.debug( "OverlapFilterPosition: Processed " & structCount( result )
				& " files in " & totalTime & "ms" );
		}
		return result;
	}

	/**
	 * Detect overlapping blocks for position-based (character offset) data
	 * Blocks are defined by character positions [fileIdx, startPos, endPos, execTime]
	 * Returns ALL blocks with overlap information marked
	 */
	private array function filterOverlappingBlocks(blocks) localmode=true {
		var allBlocks = [];

		// Sort blocks by span size (smallest first)
		var blockRanges = [];
		cfloop( array=blocks, index="local.i", item="local.block" ) {
			blockRanges.append({
				index: i,
				startPos: block[2],
				endPos: block[3],
				span: block[3] - block[2],
				block: block,
				isOverlapping: false
			});
		}

		// Sort by span size (smallest first)
		arraySort(blockRanges, function(a, b) {
			return a.span - b.span;
		});

		// Mark overlapping blocks (contained within or containing other blocks)
		var nonOverlappingBlocks = [];
		var blockRangesLen = arrayLen(blockRanges);

		cfloop( array=blockRanges, item="local.current" ) {
			var currentStart = current.startPos;
			var currentEnd = current.endPos;
			var isOverlapping = false;

			// Check both containment conditions in single loop
			var nonOverlappingLen = arrayLen(nonOverlappingBlocks);
			cfloop( from=1, to=nonOverlappingLen, index="local.j" ) {
				var nonOverlapping = nonOverlappingBlocks[j];
				var nonOverlappingStart = nonOverlapping.startPos;
				var nonOverlappingEnd = nonOverlapping.endPos;

				// If an existing block fully contains this block, mark as overlapping
				if (nonOverlappingStart <= currentStart && nonOverlappingEnd >= currentEnd) {
					isOverlapping = true;
					break;
				}
				// If this block would fully contain an existing block, mark as overlapping
				if (currentStart <= nonOverlappingStart && currentEnd >= nonOverlappingEnd) {
					isOverlapping = true;
					break;
				}
			}

			current.isOverlapping = isOverlapping;
			if (!isOverlapping) {
				nonOverlappingBlocks.append(current);
			}
		}

		// Return ALL blocks with overlap information
		// Add isOverlapping flag as 5th element: [fileIdx, startPos, endPos, execTime, isOverlapping]
		cfloop( array=blockRanges, item="local.blockRange" ) {
			var markedBlock = duplicate(blockRange.block);
			// Append overlap flag to the block array
			arrayAppend(markedBlock, blockRange.isOverlapping);
			allBlocks.append(markedBlock);
		}

		return allBlocks;
	}

}