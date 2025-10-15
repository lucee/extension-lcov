component displayname="OverlapFilterPosition" accessors="true" {

	/**
	 * Initialize the position-based overlap filter
	 * @options Configuration options struct (optional)
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
	public struct function filter(aggregatedOrBlocksByFile, files, lineMappingsCache) localmode="modern" {
		var event = variables.logger.beginEvent("OverlapFilterPosition");
		event["inputEntries"] = structCount(arguments.aggregatedOrBlocksByFile);
		var startTime = getTickCount();
		var result = structNew( "regular" );
		var blocksByFile = structNew( "regular" );

		// Detect input format and convert if needed
		var isAggregatedFormat = false;

		// Check if this is aggregated format (has tab-delimited keys) or blocks format (numeric keys with array values)
		cfloop( collection=arguments.aggregatedOrBlocksByFile, item="local.key" ) {
			var value = arguments.aggregatedOrBlocksByFile[key];
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
			cfloop( collection=arguments.aggregatedOrBlocksByFile, item="local.key" ) {
				var block = arguments.aggregatedOrBlocksByFile[key];
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

		cfloop( collection=blocksByFile, item="local.fileIdx" ) {
			var fileStart = getTickCount();
			var blocks = blocksByFile[ fileIdx ];
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

			// VALIDATION: Overlap filtering must not result in zero coverage for a file
			if (blockCountBefore > 0 && blockCountAfter == 0) {
				// Get file path for better error message
				var filePath = "unknown";
				if (structKeyExists(arguments.files, fileIdx) && structKeyExists(arguments.files[fileIdx], "path")) {
					filePath = arguments.files[fileIdx].path;
				}
				throw(
					type = "OverlapFilterPosition.InvalidResult",
					message = "Overlap filtering removed ALL coverage blocks for file index " & fileIdx,
					detail = "File: " & filePath & ", Blocks before: " & blockCountBefore & ", Blocks after: " & blockCountAfter & ". This should never happen - overlap filtering should only remove nested/duplicate blocks, not all blocks."
				);
			}

			if (isAggregatedFormat) {
				// Convert back to aggregated format for each filtered block
				cfloop( array=filteredBlocks, item="local.fBlock" ) {
					// Create key in same format as aggregator (fileIdx\tstartPos\tendPos)
					var key = "#fileIdx#	#fBlock[2]#	#fBlock[3]#";
					// Find original aggregated entry to preserve count information
					if (structKeyExists(arguments.aggregatedOrBlocksByFile, key)) {
						result[key] = arguments.aggregatedOrBlocksByFile[key];
					} else {
						// Fallback: reconstruct entry (shouldn't happen normally)
						result[key] = [fileIdx, fBlock[2], fBlock[3], 1, fBlock[4]];
					}
				}
			} else {
				// Keep blocksByFile format for tests
				result[fileIdx] = filteredBlocks;
			}

			// Log per-file filtering details
			if (blockCountBefore != blockCountAfter) {
				var filePath = structKeyExists(arguments.files, fileIdx) && structKeyExists(arguments.files[fileIdx], "path")
					? arguments.files[fileIdx].path
					: "file index " & fileIdx;
				variables.logger.debug("  Filtered file [" & filePath & "]: " & blockCountBefore & " blocks -> " & blockCountAfter & " blocks (removed " & (blockCountBefore - blockCountAfter) & ")");
			}
		}

		var totalTime = getTickCount() - startTime;
		event["outputEntries"] = structCount( result );
		event["removedEntries"] = event["inputEntries"] - event["outputEntries"];
		event["filesProcessed"] = filesProcessed;
		event["filesWithChanges"] = filesWithChanges;
		variables.logger.commitEvent( event );

		variables.logger.trace( "OverlapFilterPosition: Processed " & filesProcessed & " files (" & filesWithChanges & " with changes) in " & totalTime & "ms" );

		if ( isAggregatedFormat ) {
			variables.logger.debug( "OverlapFilterPosition: Filtered " & structCount( arguments.aggregatedOrBlocksByFile )
				& " entries to " & structCount( result ) & " entries in " & totalTime & "ms" );
		} else {
			variables.logger.debug( "OverlapFilterPosition: Filtered " & structCount( result )
				& " files in " & totalTime & "ms" );
		}
		return result;
	}

	/**
	 * Filter overlapping blocks for position-based (character offset) data
	 * Blocks are defined by character positions [fileIdx, startPos, endPos, execTime]
	 */
	private array function filterOverlappingBlocks(blocks) localmode="modern" {
		var filteredBlocks = [];

		// Sort blocks by span size (smallest first)
		var blockRanges = [];
		cfloop( array=blocks, index="local.i", item="local.block" ) {
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
		var blockRangesLen = arrayLen(blockRanges);

		cfloop( array=blockRanges, item="local.current" ) {
			var currentStart = current.startPos;
			var currentEnd = current.endPos;
			var shouldKeep = true;

			// Check both containment conditions in single loop
			var keptLen = arrayLen(keptBlocks);
			cfloop( from=1, to=keptLen, index="local.j" ) {
				var kept = keptBlocks[j];
				var keptStart = kept.startPos;
				var keptEnd = kept.endPos;

				// If an existing block fully contains this block, skip it
				if (keptStart <= currentStart && keptEnd >= currentEnd) {
					shouldKeep = false;
					break;
				}
				// If this block would fully contain an existing block, skip it
				if (currentStart <= keptStart && currentEnd >= keptEnd) {
					shouldKeep = false;
					break;
				}
			}

			if (shouldKeep) {
				keptBlocks.append(current);
			}
		}

		// Convert back to blocks array
		cfloop( array=keptBlocks, item="local.kept" ) {
			filteredBlocks.append(kept.block);
		}

		return filteredBlocks;
	}

}