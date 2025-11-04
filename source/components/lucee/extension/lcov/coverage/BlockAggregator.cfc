/**
 * BlockAggregator - Aggregates block-level coverage data to line-level coverage.
 *
 * LINE COVERAGE FORMAT:
 *
 * CURRENT FORMAT (used throughout the system):
 *   [hitCount, ownTime, childTime]
 *   - hitCount: Number of times the line was executed (integer)
 *   - ownTime: Time spent in the line's own code in nanoseconds (blocks with blockType==0)
 *   - childTime: Time spent in function calls in nanoseconds (blocks with blockType==1)
 *   - totalTime = ownTime + childTime
 *
 * LEGACY FORMAT (deprecated - no longer used):
 *   [hitCount, execTime, isChildTime]
 *   - execTime: Total execution time
 *   - isChildTime: Boolean flag indicating if line contains function calls
 *   Note: This format is no longer used. All code has been migrated to use numeric childTime values.
 */
component {

	/**
	 * Initialize the block aggregator with cached utilities
	 * @return This instance
	 */
	public function init() {
		// Cache LinePositionUtils instance for 14.55% performance gain vs static :: syntax
		variables.linePositionUtils = new lucee.extension.lcov.LinePositionUtils();
		return this;
	}

	/**
	 * Convert aggregated blocks (tab-delimited format) to storage format.
	 * This is a format conversion utility - takes blocks from CoverageAggregator.
	 * Note: blockType is NOT set here - it's added later in annotateCallTree if needed.
	 * @aggregatedBlocks Struct with tab-delimited keys: "fileIdx\tstartPos\tendPos", values: [fileIdx, startPos, endPos, hitCount, execTime, isOverlapping (optional)]
	 * @return Struct keyed by fileIdx, containing blocks keyed by "startPos-endPos": {hitCount, execTime, isOverlapping (if present)}
	 */
	public struct function convertAggregatedToBlocks( required struct aggregatedBlocks ) localmode=true {
		var blocks = structNew('regular');

		cfloop( collection=arguments.aggregatedBlocks, key="local.key", value="local.blockData" ) {
			var parts = listToArray( key, "	", false, false );
			var fileIdx = parts[ 1 ];
			var startPos = parts[ 2 ];
			var endPos = parts[ 3 ];
			// blockData is [fileIdx, startPos, endPos, hitCount, execTime, isOverlapping (optional)]

			if ( !structKeyExists( blocks, fileIdx ) ) {
				blocks[ fileIdx ] = structNew('regular');
			}

			var blockKey = startPos & "-" & endPos;
			var blockStruct = {
				"hitCount": blockData[ 4 ],
				"execTime": blockData[ 5 ]
			};

			// Preserve isOverlapping flag if present (Phase 2)
			if ( arrayLen( blockData ) >= 6 ) {
				blockStruct.isOverlapping = blockData[ 6 ];
			}

			blocks[ fileIdx ][ blockKey ] = blockStruct;
		}

		return blocks;
	}

	/**
	 * Aggregates blocks to line-based coverage for a specific file.
	 * Requires line mappings to convert block positions to line numbers.
	 * @result The result model containing blocks
	 * @fileIndex The file index (numeric)
	 * @lineMapping Array where index = character position, value = line number
	 * @return Struct of line-based coverage: {lineNum: [hitCount, ownTime, childTime]}
	 */
	public struct function aggregateBlocksToLines( required any result, required numeric fileIndex, required array lineMapping ) localmode=true {
		var lineCoverage = structNew('regular');
		var fileBlocks = arguments.result.getBlocksForFile( arguments.fileIndex );

		var lineMappingLen = arrayLen( arguments.lineMapping );

		// Check once if blocks have blockType (set in annotateCallTree, missing in buildLineCoverage)
		var hasBlockType = 0;

		cfloop( collection=fileBlocks, key="local.blockKey", value="local.block" ) {
			var parts = listToArray( blockKey, "-" );
			var startPos = parts[ 1 ];
			var originalStartPos = startPos;

			// Check once if blocks have blockType (set in annotateCallTree, missing in buildLineCoverage)
			if (hasBlockType == 0){
				hasBlockType = structKeyExists( block, "blockType" ) ? 1 : -1;
			}

			// Get line number from position using binary search
			// lineMapping is an array of line START positions: [1, 50, 100, ...] not a direct index lookup
			// Handle startPos=0 (treat as position 1, first character)
			if ( startPos == 0 ) {
				startPos = 1;
			}

			// Use LinePositionUtils for binary search to find which line this position belongs to
			var lineNum = variables.linePositionUtils.getLineFromCharacterPosition(
				startPos,
				arguments.lineMapping,
				lineMappingLen,
				1  // minLine
			);

			// LinePositionUtils returns 0 for invalid positions - skip those blocks
			if ( lineNum == 0 ) {
				continue;
			}

			// Initialize line if not exists: [hitCount, ownTime, childTime]
			if ( !structKeyExists( lineCoverage, lineNum ) ) {
				lineCoverage[ lineNum ] = [ 0, 0, 0 ];
			}

			var lineData = lineCoverage[ lineNum ];
			// Aggregate hit counts
			lineData[ 1 ] += block.hitCount;

			// Separate own time vs child time based on blockType
			// blockType may not exist if annotateCallTree hasn't run yet
			// blockType: 0=own, 1=child, 2=own+overlap, 3=child+overlap
			if ( hasBlockType === 1 && (block.blockType == 1 || block.blockType == 3) ) {
				lineData[ 3 ] += block.execTime;  // Child time (blockType == 1 or 3)
			} else {
				lineData[ 2 ] += block.execTime;  // Own time (blockType == 0, 2, or not set)
			}
		}

		return lineCoverage;
	}

	/**
	 * Aggregates all blocks in a result to line-based coverage for all files.
	 * @result The result model containing blocks
	 * @files The files struct with line mappings
	 * @return Struct of coverage data: {fileIdx: {lineNum: [hitCount, ownTime, childTime]}}
	 */
	public struct function aggregateAllBlocksToLines( required any result, required struct files ) localmode=true {
		var coverage = structNew('regular');
		var blocks = arguments.result.getBlocks();

		cfloop( collection=blocks, key="local.fileIdx" ) {
			var fileInfo = arguments.files[ fileIdx ];
			coverage[ fileIdx ] = aggregateBlocksToLines( arguments.result, fileIdx, fileInfo.lineMapping );
		}

		return coverage;
	}

	/**
	 * Aggregates merged blocks (from CoverageMerger) to line-based coverage.
	 * Works with the merged structure where keys are file paths, not indices.
	 * @mergedBlocks Struct of blocks keyed by file path: {"/path": {"startPos-endPos": {hitCount, execTime, blockType}}}
	 * @mergedFiles Struct of file info keyed by file path: {"/path": {path, lines, content, ...}}
	 * @return Struct of coverage data keyed by file path: {"/path": {lineNum: [hitCount, ownTime, childTime]}}
	 */
	public struct function aggregateMergedBlocksToLines( required struct mergedBlocks, required struct mergedFiles ) localmode=true {
		var coverage = {};

		cfloop( collection=arguments.mergedBlocks, key="local.filePath", value="local.fileBlocks" ) {
			var fileInfo = arguments.mergedFiles[ filePath ];

			// Build line mapping if not exists (need full content)
			var lineMapping = [];
			if ( structKeyExists( fileInfo, "content" ) ) {
				lineMapping = buildCharacterToLineMapping( fileInfo.content );
			} else if ( structKeyExists( fileInfo, "path" ) && fileExists( fileInfo.path ) ) {
				// Load content from disk if not present (minimal cache mode)
				var fileContent = fileRead( fileInfo.path );
				lineMapping = buildCharacterToLineMapping( fileContent );
			} else {
				throw(
					type = "BlockAggregationError",
					message = "Cannot aggregate blocks to lines: missing file content and path for file [" & filePath & "]",
					detail = "File info must contain either 'content' or 'path' to build line mappings for block aggregation"
				);
			}

			var hasBlockType = 0;

			// Aggregate blocks to lines for this file
			var lineCoverage = structNew('regular');
			cfloop( collection=fileBlocks, key="local.blockKey", value="local.block" ) {
				var parts = listToArray( blockKey, "-" );
				var startPos = parts[ 1 ];
				// Check once if blocks have blockType (set in annotateCallTree, missing in buildLineCoverage)
				if (hasBlockType == 0){
					hasBlockType = structKeyExists( block, "blockType" ) ? 1 : -1;
				}

				// Get line number from position
				// Handle startPos=0 (treat as position 1, first character)
				if ( startPos == 0 ) {
					startPos = 1;
				}
				if ( startPos > arrayLen( lineMapping ) ) {
					throw( message="Invalid startPos " & startPos & " for block " & blockKey & " in file " & filePath );
				}
				var lineNum = lineMapping[ startPos ];

				// Initialize line if not exists: [hitCount, ownTime, childTime]
				if ( !structKeyExists( lineCoverage, lineNum ) ) {
					lineCoverage[ lineNum ] = [ 0, 0, 0 ];
				}

				var lineData = lineCoverage[ lineNum ];
				// Aggregate hit counts
				lineData[ 1 ] += block.hitCount;

				// Separate own time vs child time based on blockType
				// blockType: 0=own, 1=child, 2=own+overlap, 3=child+overlap
				if ( hasBlockType === 1 && (block.blockType == 1 || block.blockType == 3) ) {
					lineData[ 3 ] += block.execTime;  // Child time (blockType == 1 or 3)
				} else {
					lineData[ 2 ] += block.execTime;  // Own time (blockType == 0, 2, or not set)
				}
			}

			coverage[ filePath ] = lineCoverage;
		}

		return coverage;
	}

	/**
	 * Builds a character-to-line mapping array from file content.
	 * @content The full file content as a string
	 * @return Array where index = character position, value = line number
	 */
	private array function buildCharacterToLineMapping( required string content ) {
		var mapping = [];
		arrayResize( mapping, len( arguments.content ) + 1 ); // +1 for 1-based indexing
		var lineNum = 1;
		var contentLen = len( arguments.content );

		for ( var i = 1; i <= contentLen; i++ ) {
			mapping[ i ] = lineNum;
			if ( mid( arguments.content, i, 1 ) == chr( 10 ) ) {
				lineNum++;
			}
		}

		return mapping;
	}
}
