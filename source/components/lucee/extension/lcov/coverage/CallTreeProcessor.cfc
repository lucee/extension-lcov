/**
 * CallTreeProcessor.cfc
 *
 * Handles STAGE 1.6, 1.7, 1.8 of coverage processing:
 * - Analyzes call tree using AST
 * - Maps call tree data to lines
 * - Converts aggregated data to blocks with isChild flags
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
	 * Processes call tree analysis and converts to blocks.
	 * @aggregated Aggregated coverage data
	 * @files Files struct from result object
	 * @callTreeAnalyzer CallTreeAnalyzer instance
	 * @return struct with {callTreeData: struct, blocks: struct}
	 */
	public struct function processCallTree(
		required struct aggregated,
		required struct files,
		required any callTreeAnalyzer
	) localmode="modern" {
		// STAGE 1.6: Call tree analysis using AST
		var callTreeStart = getTickCount();
		var callTreeResult = arguments.callTreeAnalyzer.analyzeCallTree( arguments.aggregated, arguments.files );
		var callTreeMetrics = arguments.callTreeAnalyzer.getCallTreeMetrics( callTreeResult );

		var callTreeData = {
			"callTree": callTreeResult.blocks,
			"callTreeMetrics": callTreeMetrics
		};

		variables.logger.debug("Call tree analysis completed in " & numberFormat(getTickCount() - callTreeStart)
			& "ms. Blocks: " & callTreeMetrics.totalBlocks
			& ", Child time blocks: " & callTreeMetrics.childTimeBlocks
			& ", Built-in blocks: " & callTreeMetrics.builtInBlocks);

		// STAGE 1.7: Map call tree data to lines for display
		var lineMapperStart = getTickCount();
		var callTreeLineMapper = new lucee.extension.lcov.ast.CallTreeLineMapper();
		var lineCallTree = callTreeLineMapper.mapCallTreeToLines(callTreeResult, arguments.files, variables.blockProcessor);

		variables.logger.debug("Call tree line mapping completed in " & numberFormat(getTickCount() - lineMapperStart)
			& "ms. Lines with call tree data: " & structCount(lineCallTree));

		// STAGE 1.8: Store block-level data with isChild flag from call tree
		var blockStorageStart = getTickCount();
		var blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		var blocks = blockAggregator.convertAggregatedToBlocks(arguments.aggregated, callTreeResult.blocks);
		variables.logger.trace("Block storage completed in " & numberFormat(getTickCount() - blockStorageStart) & "ms");

		return {
			"callTreeData": callTreeData,
			"blocks": blocks
		};
	}

}
