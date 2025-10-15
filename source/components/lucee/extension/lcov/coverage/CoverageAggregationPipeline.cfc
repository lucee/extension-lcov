/**
 * CoverageAggregationPipeline.cfc
 *
 * Handles STAGE 1 & 1.5 of coverage processing:
 * - Aggregates identical coverage entries
 * - Filters overlapping blocks
 */
component {

	property name="logger" type="any";
	property name="blockProcessor" type="any";

	public function init(required any logger, required any blockProcessor) {
		variables.logger = arguments.logger;
		variables.blockProcessor = arguments.blockProcessor;
		return this;
	}

	/**
	 * Aggregates coverage data and filters overlapping blocks.
	 * @exlPath Path to .exl file
	 * @validFileIds Struct of valid file IDs
	 * @files Files struct from result object
	 * @lineMappingsCache Line mappings cache
	 * @return struct with {aggregated: struct, aggregatedEntries: numeric, duplicateCount: numeric, aggregationTime: numeric}
	 */
	public struct function aggregateAndFilter(
		required string exlPath,
		required struct validFileIds,
		required struct files,
		required struct lineMappingsCache
	) localmode=true {
		// STAGE 1: Pre-aggregate identical coverage entries
		var aggregator = new lucee.extension.lcov.coverage.CoverageAggregator( logger=variables.logger );
		var aggregationResult = aggregator.aggregate( arguments.exlPath, arguments.validFileIds );

		var exclusionStart = getTickCount();
		var beforeEntities = structCount(aggregationResult.aggregated);

		// STAGE 1.5: Exclude overlapping blocks
		var overlapFilter = new lucee.extension.lcov.coverage.OverlapFilterPosition( logger=variables.logger );
		aggregationResult.aggregated = overlapFilter.filter(
			aggregationResult.aggregated,
			arguments.files,
			arguments.lineMappingsCache
		);

		var remaining = structCount(aggregationResult.aggregated);
		variables.logger.debug("After excluding overlapping blocks, remaining aggregated entries: "
			& numberFormat(remaining) & " (took "
			& numberFormat(getTickCount() - exclusionStart) & "ms)");

		return aggregationResult;
	}

}
