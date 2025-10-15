/**
 * LcovReportGenerator.cfc
 *
 * LCOV-specific report generation operations.
 * Extends ReportGenerator with LCOV-focused methods.
 */
component extends="ReportGenerator" {

	/**
	 * Build LCOV format content from JSON file paths
	 * @jsonFilePaths Array of JSON file paths
	 * @options Options struct containing logLevel and useRelativePath
	 * @return String containing LCOV format content
	 */
	public string function buildLcovContent( required array jsonFilePaths, required struct options ) {
		var merger = new lucee.extension.lcov.CoverageMerger( logger=variables.logger );
		var merged = merger.mergeResultsByFile( arguments.jsonFilePaths );

		var blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		var lineCoverage = {};

		if ( structKeyExists( merged.mergedCoverage, "blocks" ) && structCount( merged.mergedCoverage.blocks ) > 0 ) {
			logger.debug( "Using block-based aggregation for LCOV generation" );
			lineCoverage = blockAggregator.aggregateMergedBlocksToLines(
				merged.mergedCoverage.blocks,
				merged.mergedCoverage.files
			);
		} else {
			logger.debug( "No blocks found, using existing line coverage" );
			lineCoverage = merged.mergedCoverage.coverage;
		}

		var mergedForLcov = {
			"files": merged.mergedCoverage.files,
			"coverage": lineCoverage
		};

		var lcovWriter = new lucee.extension.lcov.reporter.LcovWriter( logger=variables.logger, options=arguments.options );
		return lcovWriter.buildLCOV( mergedForLcov, arguments.options.useRelativePath ?: false );
	}

}
