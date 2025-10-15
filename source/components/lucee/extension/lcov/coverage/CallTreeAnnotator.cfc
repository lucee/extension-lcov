/**
 * annotateCallTree: Annotate CallTree (mark blocks with isChildTime flags).
 *
 * Marks blocks with CallTree metadata (isChildTime, isBuiltIn flags).
 * This phase is OPTIONAL - only needed for detailed HTML reports.
 *
 * LCOV format does NOT need this phase - it can skip straight to generateReports.
 * HTML format DOES need this phase to display child time information.
 */
component {

	property name="logger";
	property name="callTreeAnalyzer";

	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( logLevel="ERROR" );
		variables.callTreeAnalyzer = new lucee.extension.lcov.ast.CallTreeAnalyzer( logger=variables.logger );
		return this;
	}

	/**
	 * Annotate CallTree for a single result.
	 *
	 * @result The result object with aggregated data
	 * @callTreeMap Map of call positions from ast-metadata.json
	 * @astMetadataPath Path to ast-metadata.json (for loading lineMapping)
	 * @astLoader AstMetadataLoader instance (shared across parallel processing)
	 * @astIndex Loaded AST index (shared across parallel processing)
	 * @return The result object with CallTree annotations
	 */
	public any function annotateResult(required any result, required struct callTreeMap, string astMetadataPath, any astLoader, struct astIndex) localmode="modern" {
		// Check if already done
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCallTree" ) && flags.hasCallTree ) {
			variables.logger.debug( "Skipping CallTree annotation - already done (hasCallTree=true)" );
			return arguments.result;
		}

		var startTime = getTickCount();
		// Comment out to avoid log spam - only the summary at the end is useful
		// variables.logger.debug( "Annotating blocks with CallTree metadata" );

		// Get existing blocks (from buildLineCoverage)
		var blocks = arguments.result.getBlocks();

		// Get aggregated to build call map
		var aggregated = arguments.result.getAggregated();

		// Mark blocks with CallTree flags using CallTreeAnalyzer
		var markedBlocks = variables.callTreeAnalyzer.markChildTimeBlocks( aggregated, arguments.callTreeMap );

		// Update existing blocks with isChild flags from markedBlocks
		// markedBlocks has flat structure: {fileIdx\tstartPos\tendPos: {fileIdx, startPos, endPos, isChildTime, isBuiltIn}}
		// blocks has nested structure: {fileIdx: {startPos-endPos: {hitCount, execTime, isChild}}}
		for (var flatKey in markedBlocks) {
			var markedBlock = markedBlocks[flatKey];
			var fileIdx = markedBlock.fileIdx;
			var blockKey = markedBlock.startPos & "-" & markedBlock.endPos;

			if (structKeyExists(blocks, fileIdx) && structKeyExists(blocks[fileIdx], blockKey)) {
				// Update isChild flag in the existing block
				blocks[fileIdx][blockKey].isChild = markedBlock.isChildTime ?: false;
			}
		}

		// Calculate metrics
		var metrics = variables.callTreeAnalyzer.calculateChildTimeMetrics( markedBlocks );

		// Store CallTree data and metrics
		arguments.result.setCallTree( arguments.callTreeMap );
		arguments.result.setCallTreeMetrics( metrics );

		// Rebuild coverage from blocks now that they have isChild flags
		// This is essential - coverage was built in buildLineCoverage before blocks had isChild flags
		// Now we need to rebuild it so child time is properly separated from own time
		var blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		var files = arguments.result.getFiles();

		// Ensure each file has lineMapping from AST JSON (calculated once in extractAstMetadata)
		// This eliminates 53,080 redundant file reads!
		for (var fileIdx in files) {
			var fileInfo = files[fileIdx];
			if (!structKeyExists(fileInfo, "lineMapping")) {
				// Load from AST JSON - fail fast if not available!
				var astData = arguments.astLoader.loadMetadataForFileWithIndex(
					arguments.astMetadataPath,
					arguments.astIndex,
					fileInfo.path
				);
				fileInfo.lineMapping = astData.lineMapping; // Fail fast if lineMapping missing
			}
		}

		var newCoverage = blockAggregator.aggregateAllBlocksToLines( arguments.result, files );
		arguments.result.setCoverage( newCoverage );

		// Recalculate stats from the rebuilt coverage to pick up childTime values
		// This is critical - stats were calculated in buildLineCoverage before blocks had isChild flags
		var coverageStats = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
		coverageStats.calculateCoverageStats( arguments.result );

		// Update flags
		arguments.result.setFlags({
			"hasCallTree": true,
			"hasBlocks": true,
			"hasCoverage": true // Coverage has been rebuilt with proper child time
		});

		var elapsedTime = getTickCount() - startTime;
		// Only log if it took more than 100ms to avoid log spam with thousands of files
		if ( elapsedTime > 100 ) {
			variables.logger.debug( "Annotated CallTree in #elapsedTime#ms: #metrics.totalBlocks# blocks, #metrics.childTimeBlocks# child time blocks" );
		}

		return arguments.result;
	}

	/**
	 * Annotate CallTree for multiple JSON files.
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json
	 * @return Array of processed JSON file paths
	 */
	public array function annotate(required array jsonFilePaths, required string astMetadataPath) localmode="modern" {
		var startTime = getTickCount();
		variables.logger.info( "Phase annotateCallTree: Annotating CallTree for #arrayLen(arguments.jsonFilePaths)# files" );

		// Load index once and share across all threads
		var loader = new lucee.extension.lcov.parser.AstMetadataLoader( logger=variables.logger );
		var index = loader.loadIndex( arguments.astMetadataPath );

		// Store references for closure
		var self = this;
		var metadataPath = arguments.astMetadataPath;

		var results = arrayMap( arguments.jsonFilePaths, function( jsonPath ) {
			if ( !fileExists( jsonPath ) ) {
				variables.logger.warn( "Skipping missing JSON file: #jsonPath#" );
				return {processed: false, skipped: false};
			}

			// Load result
			var jsonContent = fileRead( jsonPath );
			var data = deserializeJSON( jsonContent );

			// Check flags - skip if already done
			if ( structKeyExists( data, "flags" ) && structKeyExists( data.flags, "hasCallTree" ) && data.flags.hasCallTree ) {
				variables.logger.trace( "Skipping #jsonPath# - hasCallTree=true" );
				return {processed: false, skipped: true};
			}

			// Convert to result object
			var result = new lucee.extension.lcov.model.result();
			for ( var key in data ) {
				var setter = "set" & key;
				if ( structKeyExists( result, setter ) ) {
					result[setter]( data[key] );
				}
			}

			// Build callTreeMap: nested struct keyed by fileIdx, then position
			var callTreeMap = structNew( "regular" );
			var files = result.getFiles();
			for ( var fileIdx in files ) {
				callTreeMap[fileIdx] = loader.loadMetadataForFileWithIndex( metadataPath, index, files[fileIdx].path ).callTree;
			}

			// Annotate CallTree - pass AST loader for lineMapping
			self.annotateResult( result, callTreeMap, metadataPath, loader, index );

			// Write back to JSON
			fileWrite( jsonPath, result.toJson( pretty=false ) );
			return {processed: true, skipped: false};
		}, true ); // true = parallel processing

		// Count results
		var processedCount = 0;
		var skippedCount = 0;
		for ( var r in results ) {
			if ( r.processed ) processedCount++;
			if ( r.skipped ) skippedCount++;
		}

		var elapsedTime = getTickCount() - startTime;
		variables.logger.info( "Phase annotateCallTree: Processed #processedCount# files, skipped #skippedCount# in #elapsedTime#ms" );

		return arguments.jsonFilePaths;
	}

}
