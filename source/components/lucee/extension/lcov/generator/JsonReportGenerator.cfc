/**
 * JsonReportGenerator.cfc
 *
 * JSON-specific report generation operations.
 * Extends ReportGenerator with JSON-focused methods.
 */
component extends="ReportGenerator" {

	/**
	 * Write core JSON files (results, merged, stats)
	 * @results Struct of results
	 * @jsonFilePaths Array of JSON file paths
	 * @outputDir Output directory
	 * @compact Whether to use compact JSON format
	 * @logger Logger instance
	 * @processingTimeMs Processing time in milliseconds
	 * @return Struct with paths to generated JSON files
	 */
	public struct function writeCoreJsonFiles(
		required struct results,
		required array jsonFilePaths,
		required string outputDir,
		required boolean compact,
		required any logger,
		required numeric processingTimeMs
	) {
		var jsonFiles = {};

		var resultsFile = arguments.outputDir & "/results.json";
		fileWrite( resultsFile, serializeJSON( var=arguments.results, compact=arguments.compact ) );
		jsonFiles.results = resultsFile;

		var merged = new lucee.extension.lcov.CoverageMerger( logger=arguments.logger ).mergeResultsByFile( arguments.jsonFilePaths );
		var mergedFile = arguments.outputDir & "/merged.json";
		fileWrite( mergedFile, serializeJSON( var=merged, compact=arguments.compact ) );
		jsonFiles.merged = mergedFile;

		var totalStats = aggregateCoverageStats( arguments.jsonFilePaths, arguments.processingTimeMs );
		var statsFile = arguments.outputDir & "/summary-stats.json";
		fileWrite( statsFile, serializeJSON( var=totalStats, compact=arguments.compact ) );
		jsonFiles.stats = statsFile;

		return jsonFiles;
	}

	/**
	 * Write request-based JSON files
	 * @results Struct of results
	 * @outputDir Output directory
	 * @compact Whether to use compact JSON format
	 * @return Struct with paths to generated JSON files (keyed by filename)
	 */
	public struct function writeRequestJsonFiles(
		required struct results,
		required string outputDir,
		required boolean compact
	) {
		var jsonFiles = {};
		for ( var resultKey in arguments.results ) {
			var result = arguments.results[ resultKey ];
			var coverage = result.getCoverage();
			if ( isStruct(coverage) && !structIsEmpty( coverage ) ) {
				var jsonFileName = result.getOutputFilename() & ".json";
				var jsonFilePath = arguments.outputDir & "/" & jsonFileName;
				fileWrite( jsonFilePath, serializeJSON( var=result, compact=arguments.compact ) );
				jsonFiles[ jsonFileName ] = jsonFilePath;
			}
		}
		return jsonFiles;
	}

}
