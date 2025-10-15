/**
 * BlockAggregator - Aggregates block-level coverage data to line-level coverage.
 *
 * LINE COVERAGE FORMAT:
 *
 * CURRENT FORMAT (used throughout the system):
 *   [hitCount, ownTime, childTime]
 *   - hitCount: Number of times the line was executed (integer)
 *   - ownTime: Time spent in the line's own code in nanoseconds (blocks with isChild=false)
 *   - childTime: Time spent in function calls in nanoseconds (blocks with isChild=true)
 *   - totalTime = ownTime + childTime
 *
 * LEGACY FORMAT (deprecated - no longer used):
 *   [hitCount, execTime, isChildTime]
 *   - execTime: Total execution time
 *   - isChildTime: Boolean flag indicating if line contains function calls
 *   Note: This format is no longer used. All code has been migrated to use numeric childTime values.
 */
component {

	public function init() {
		// Cache LinePositionUtils instance for 14.55% performance gain vs static :: syntax
		variables.linePositionUtils = new lucee.extension.lcov.LinePositionUtils();
		return this;
	}

	/**
	 * Convert aggregated blocks (tab-delimited format) to storage format.
	 * This is a format conversion utility - takes blocks from CoverageAggregator.
	 * Note: isChild flags are NOT set here - they are added later in Phase 4 (CallTreeAnnotator) if needed.
	 * @aggregatedBlocks Struct with tab-delimited keys: "fileIdx\tstartPos\tendPos", values: [fileIdx, startPos, endPos, hitCount, execTime]
	 * @return Struct keyed by fileIdx, containing blocks keyed by "startPos-endPos": {hitCount, execTime}
	 */
	public struct function convertAggregatedToBlocks( required struct aggregatedBlocks ) localmode="modern" {
		var blocks = structNew('regular');

		for ( var key in arguments.aggregatedBlocks ) {
			var parts = listToArray( key, "	", false, false );
			var fileIdx = parts[ 1 ];
			var startPos = parts[ 2 ];
			var endPos = parts[ 3 ];
			var blockData = arguments.aggregatedBlocks[ key ];
			// blockData is [fileIdx, startPos, endPos, hitCount, execTime]

			if ( !structKeyExists( blocks, fileIdx ) ) {
				blocks[ fileIdx ] = {};
			}

			var blockKey = startPos & "-" & endPos;
			blocks[ fileIdx ][ blockKey ] = {
				"hitCount": blockData[ 4 ],
				"execTime": blockData[ 5 ]
			};
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
	public struct function aggregateBlocksToLines( required any result, required numeric fileIndex, required array lineMapping ) localmode="modern" {
		var lineCoverage = structNew('regular');
		var fileBlocks = arguments.result.getBlocksForFile( arguments.fileIndex );

		var lineMappingLen = arrayLen( arguments.lineMapping );

		// Check once if blocks have isChild flag (set in Phase 4, missing in Phase 3)
		var hasIsChildFlag = 0;

		for ( var blockKey in fileBlocks ) {
			var block = fileBlocks[ blockKey ];
			var parts = listToArray( blockKey, "-" );
			var startPos = parts[ 1 ];
			var originalStartPos = startPos;

			// Check once if blocks have isChild flag (set in Phase 4, missing in Phase 3)
			if (hasIsChildFlag == 0){
				hasIsChildFlag = structKeyExists( block, "isChild" ) ? 1 : -1;
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

			// Separate own time vs child time based on isChild flag
			// isChild may not exist if Phase 4 (CallTreeAnnotator) hasn't run yet
			if ( hasIsChildFlag === 1 && block.isChild ) {
				lineData[ 3 ] += block.execTime;  // Child time
			} else {
				lineData[ 2 ] += block.execTime;  // Own time
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
	public struct function aggregateAllBlocksToLines( required any result, required struct files ) localmode="modern" {
		var coverage = structNew('regular');
		var blocks = arguments.result.getBlocks();

		for ( var fileIdx in blocks ) {
			if ( !structKeyExists( arguments.files, fileIdx ) ) {
				continue; // Skip files not in files struct
			}

			var fileInfo = arguments.files[ fileIdx ];
			if ( !structKeyExists( fileInfo, "lineMapping" ) ) {
				continue; // Skip files without line mappings
			}

			coverage[ fileIdx ] = aggregateBlocksToLines( arguments.result, fileIdx, fileInfo.lineMapping );
		}

		return coverage;
	}

	/**
	 * Aggregates merged blocks (from CoverageMerger) to line-based coverage.
	 * Works with the merged structure where keys are file paths, not indices.
	 * @mergedBlocks Struct of blocks keyed by file path: {"/path": {"startPos-endPos": {hitCount, execTime, isChild}}}
	 * @mergedFiles Struct of file info keyed by file path: {"/path": {path, lines, content, ...}}
	 * @return Struct of coverage data keyed by file path: {"/path": {lineNum: [hitCount, ownTime, childTime]}}
	 */
	public struct function aggregateMergedBlocksToLines( required struct mergedBlocks, required struct mergedFiles ) localmode="modern" {
		var coverage = {};

		for ( var filePath in arguments.mergedBlocks ) {
			if ( !structKeyExists( arguments.mergedFiles, filePath ) ) {
				continue; // Skip blocks for files not in files struct
			}

			var fileInfo = arguments.mergedFiles[ filePath ];
			var fileBlocks = arguments.mergedBlocks[ filePath ];

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

			var hasIsChildFlag = 0;

			// Aggregate blocks to lines for this file
			var lineCoverage = structNew('regular');
			for ( var blockKey in fileBlocks ) {
				
				var block = fileBlocks[ blockKey ];
				var parts = listToArray( blockKey, "-" );
				var startPos = parts[ 1 ];
				// Check once if blocks have isChild flag (set in Phase 4, missing in Phase 3)
				if (hasIsChildFlag == 0){
					hasIsChildFlag = structKeyExists( block, "isChild" ) ? 1 : -1;
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

				// Separate own time vs child time based on isChild flag
				if ( hasIsChildFlag === 1 && block.isChild ) {
					lineData[ 3 ] += block.execTime;  // Child time
				} else {
					lineData[ 2 ] += block.execTime;  // Own time
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
