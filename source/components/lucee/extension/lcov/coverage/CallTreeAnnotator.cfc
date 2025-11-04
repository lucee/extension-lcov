/**
 * annotateCallTree: Annotate CallTree (mark blocks with blockType values).
 *
 * Marks blocks with CallTree metadata (blockType, isBuiltIn flags).
 * This phase is OPTIONAL - only needed for detailed HTML reports.
 *
 * LCOV format does NOT need this phase - it can skip straight to generateReports.
 * HTML format DOES need this phase to display child time information.
 */
component {

	property name="logger";
	property name="callTreeAnalyzer";

	/**
	 * Initialize call tree annotator with dependencies
	 * @logger Logger instance for debugging and tracing
	 * @return This instance
	 */
	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( logLevel="ERROR" );
		variables.callTreeAnalyzer = new lucee.extension.lcov.ast.CallTreeAnalyzer( logger=variables.logger );
		variables.blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		variables.coverageStats = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
		variables.astMetadataLoader = new lucee.extension.lcov.parser.AstMetadataLoader( logger=variables.logger );
		return this;
	}

	
	/**
	 * Annotate CallTree for multiple JSON files.
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json
	 * @return Array of processed JSON file paths
	 */
	public array function annotate(required array jsonFilePaths, required string astMetadataPath) localmode=true {
		var startTime = getTickCount();
		variables.logger.info( "Phase annotateCallTree: Annotating CallTree for #arrayLen(arguments.jsonFilePaths)# files" );

		// Load index once and share across all threads
		var index = variables.astMetadataLoader.loadIndex( arguments.astMetadataPath );

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
			var result = new lucee.extension.lcov.model.result().fromJson( jsonContent, false );

			// Check flags - skip if already done
			var flags = result.getFlags();
			if ( structKeyExists( flags, "hasCallTree" ) && flags.hasCallTree ) {
				variables.logger.trace( "Skipping #jsonPath# - hasCallTree=true" );
				return {processed: false, skipped: true};
			}

			// Build callTreeMap: nested struct keyed by fileIdx, then position
			var callTreeMap = structNew( "regular" );
			var files = result.getFiles();
			for ( var fileIdx in files ) {
				callTreeMap[fileIdx] = variables.astMetadataLoader.loadMetadataForFileWithIndex( metadataPath, index, files[fileIdx].path ).callTree;
			}

			// Annotate CallTree - pass AST index for lineMapping
			self.annotateResult( result, callTreeMap, metadataPath, index );

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

	/**
	 * Annotate CallTree for a single result.
	 *
	 * @result The result object with aggregated data
	 * @callTreeMap Map of call positions from ast-metadata.json
	 * @astMetadataPath Path to ast-metadata.json (for loading lineMapping)
	 * @astIndex Loaded AST index (shared across parallel processing)
	 * @return The result object with CallTree annotations
	 */
	private any function annotateResult(result, callTreeMap, astMetadataPath, astIndex) localmode=true {
		// Check if already done
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCallTree" ) && flags.hasCallTree ) {
			variables.logger.debug( "Skipping CallTree annotation - already done (hasCallTree=true)" );
			return arguments.result;
		}

		var event = variables.logger.beginEvent( "AnnotateCallTree" );;

		var blocks = arguments.result.getBlocks();
		var aggregated = arguments.result.getAggregated();
		var markedBlocks = variables.callTreeAnalyzer.markChildTimeBlocks( aggregated, arguments.callTreeMap );

		// Update existing blocks with blockType from markedBlocks
		// markedBlocks has flat structure: {fileIdx\tstartPos\tendPos: {fileIdx, startPos, endPos, isChildTime, isBuiltIn}}
		// blocks has nested structure: {fileIdx: {startPos-endPos: {hitCount, execTime, blockType, isOverlapping (optional)}}}
		for (var flatKey in markedBlocks) {
			var markedBlock = markedBlocks[flatKey];
			var fileIdx = markedBlock.fileIdx;
			var blockKey = markedBlock.startPos & "-" & markedBlock.endPos;

			if (structKeyExists(blocks, fileIdx) && structKeyExists(blocks[fileIdx], blockKey)) {
				var block = blocks[fileIdx][blockKey];
				// Base blockType: 1 if child time, 0 if own time
				var baseType = (markedBlock.isChildTime ?: false) ? 1 : 0;
				// Add 2 if overlapping (Phase 2): blockType 2 = own+overlap, 3 = child+overlap
				var isOverlapping = structKeyExists(block, "isOverlapping") && block.isOverlapping;
				block.blockType = baseType + (isOverlapping ? 2 : 0);
			}
		}

		arguments.result.setCallTree( arguments.callTreeMap );
		arguments.result.setCallTreeMetrics( variables.callTreeAnalyzer.calculateChildTimeMetrics( markedBlocks ) );

		var files = arguments.result.getFiles();

		// Ensure each file has lineMapping from AST JSON (calculated once in extractAstMetadata)
		// This eliminates 53,080 redundant file reads!
		cfloop( collection=files, key="local.fileIdx", value="local.fileInfo" ) {
			if (!structKeyExists(fileInfo, "lineMapping")) {
				// Load from AST JSON - fail fast if not available!
				var astData = variables.astMetadataLoader.loadMetadataForFileWithIndex(
					arguments.astMetadataPath,
					arguments.astIndex,
					fileInfo.path
				);
				fileInfo.lineMapping = astData.lineMapping; // Fail fast if lineMapping missing
			}
		}

		arguments.result.setCoverage( variables.blockAggregator.aggregateAllBlocksToLines( arguments.result, files ) );

		// Recalculate stats from the rebuilt coverage to pick up childTime values
		// This is critical - stats were calculated in buildLineCoverage before blocks had blockType set
		variables.coverageStats.calculateCoverageStats( arguments.result );

		// Update flags
		arguments.result.setFlags({
			"hasCallTree": true,
			"hasBlocks": true,
			"hasCoverage": true // Coverage has been rebuilt with proper child time
		});

		variables.logger.commitEvent( event=event, minThresholdMs=100, logLevel="debug" );

		return arguments.result;
	}


}
