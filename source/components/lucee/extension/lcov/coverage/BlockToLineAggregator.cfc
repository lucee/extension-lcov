/**
 * BlockToLineAggregator.cfc
 *
 * Handles STAGE 2 & 2.5 of coverage processing:
 * - Aggregates blocks to line coverage
 * - Adds zero-count entries for unexecuted executable lines
 * - Cleans up temporary fields from file entries
 */
component {

	property name="logger" type="any";

	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Aggregates blocks to line coverage and adds zero-count entries.
	 * @coverageData Result object
	 * @blocks Blocks struct
	 * @files Files struct
	 * @lineMappingsCache Line mappings cache
	 * @return struct Coverage data keyed by file index
	 */
	public struct function aggregateBlocksToLines(
		required any coverageData,
		required struct blocks,
		required struct files,
		required struct lineMappingsCache
	) localmode=true {
		var event = variables.logger.beginEvent( "BlockToLineAggregation" );
		var blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		var coverage = structNew( "regular" );

		cfloop( collection=arguments.files, key="local.fileIdx", value="local.fileInfo" ) {

			// Aggregate blocks for this file
			if (structKeyExists(arguments.blocks, fileIdx) && structCount(arguments.blocks[fileIdx]) > 0) {
				// Ensure line mapping exists for this file
				if (!structKeyExists(arguments.lineMappingsCache, fileInfo.path)) {
					throw(message="Line mapping not found for file: " & fileInfo.path & " (fileIdx: " & fileIdx & ")");
				}

				coverage[fileIdx] = blockAggregator.aggregateBlocksToLines(
					arguments.coverageData,
					fileIdx,
					arguments.lineMappingsCache[fileInfo.path]
				);
			} else {
				coverage[fileIdx] = {};
			}

			// STAGE 2.5: Add zero-count entries for unexecuted executable lines
			if (structKeyExists(fileInfo, "executableLines")) {
				cfloop( collection=fileInfo.executableLines, key="local.lineNum" ) {
					if (!structKeyExists(coverage[fileIdx], lineNum)) {
						coverage[fileIdx][lineNum] = [0, 0, 0, 0]; // [hitCount, ownTime, childTime, blockTime]
					}
				}
			}

			// Remove temporary fields now that coverage has been populated
			structDelete(fileInfo, "executableLines");
			structDelete(fileInfo, "ast");
			structDelete(fileInfo, "lineMapping");
			structDelete(fileInfo, "mappingLen");
		}

		variables.logger.commitEvent( event=event, minThresholdMs=100, logLevel="debug" );

		return coverage;
	}

}
