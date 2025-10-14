/**
 * Phase 4: Annotate CallTree (mark blocks with isChildTime flags).
 *
 * Marks blocks with CallTree metadata (isChildTime, isBuiltIn flags).
 * This phase is OPTIONAL - only needed for detailed HTML reports.
 *
 * LCOV format does NOT need this phase - it can skip straight to Phase 5.
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
	 * @return The result object with CallTree annotations
	 */
	public any function annotateResult(required any result, required struct callTreeMap) {
		// Check if already done
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCallTree" ) && flags.hasCallTree ) {
			variables.logger.debug( "Skipping CallTree annotation - already done (hasCallTree=true)" );
			return arguments.result;
		}

		var startTime = getTickCount();
		variables.logger.debug( "Annotating blocks with CallTree metadata" );

		// Get existing blocks (from Phase 3)
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
		// This is essential - coverage was built in Phase 3 before blocks had isChild flags
		// Now we need to rebuild it so child time is properly separated from own time
		var blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator();
		var files = arguments.result.getFiles();

		// Ensure each file has lineMapping (needed for aggregation)
		// lineMapping is NOT stored in JSON, so we must load from disk
		var blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=variables.logger );
		for (var fileIdx in files) {
			var fileInfo = files[fileIdx];
			if (!structKeyExists(fileInfo, "lineMapping")) {
				// Load file content from disk and build lineMapping
				if (!structKeyExists(fileInfo, "path") || !fileExists(fileInfo.path)) {
					variables.logger.warn("Skipping file #fileIdx# - no path or file not found");
					continue;
				}
				var fileContent = fileRead(fileInfo.path);
				fileInfo.lineMapping = blockProcessor.buildCharacterToLineMapping(fileContent);
			}
		}

		var newCoverage = blockAggregator.aggregateAllBlocksToLines( arguments.result, files );
		arguments.result.setCoverage( newCoverage );

		// Recalculate stats from the rebuilt coverage to pick up childTime values
		// This is critical - stats were calculated in Phase 3 before blocks had isChild flags
		var coverageStats = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
		coverageStats.calculateCoverageStats( arguments.result );

		// Update flags
		arguments.result.setFlags({
			"hasCallTree": true,
			"hasBlocks": true,
			"hasCoverage": true // Coverage has been rebuilt with proper child time
		});

		var elapsedTime = getTickCount() - startTime;
		variables.logger.debug( "Annotated CallTree in #elapsedTime#ms: #metrics.totalBlocks# blocks, #metrics.childTimeBlocks# child time blocks" );

		return arguments.result;
	}

	/**
	 * Annotate CallTree for multiple JSON files.
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json
	 * @return Array of processed JSON file paths
	 */
	public array function annotate(required array jsonFilePaths, required string astMetadataPath) {
		var startTime = getTickCount();
		variables.logger.debug( "Phase 4: Annotating CallTree for #arrayLen(arguments.jsonFilePaths)# files" );

		// Load AST metadata
		if ( !fileExists( arguments.astMetadataPath ) ) {
			throw( type="CallTreeAnnotator.MissingMetadata", message="AST metadata file not found: #arguments.astMetadataPath#" );
		}

		var metadataJson = fileRead( arguments.astMetadataPath );
		var astMetadata = deserializeJSON( metadataJson );

		// ast-metadata.json has callTree keyed by position only (no fileIdx)
		// We need to transform it to fileIdx\tposition format for markChildTimeBlocks()
		// This will be done per-result, not globally here

		var processedCount = 0;
		var skippedCount = 0;

		for (var jsonPath in arguments.jsonFilePaths) {
			if ( !fileExists( jsonPath ) ) {
				variables.logger.warn( "Skipping missing JSON file: #jsonPath#" );
				continue;
			}

			// Load result
			var jsonContent = fileRead( jsonPath );
			var data = deserializeJSON( jsonContent );

			// Check flags - skip if already done
			if ( structKeyExists( data, "flags" ) && structKeyExists( data.flags, "hasCallTree" ) && data.flags.hasCallTree ) {
				skippedCount++;
				variables.logger.trace( "Skipping #jsonPath# - hasCallTree=true" );
				continue;
			}

			// Convert to result object
			var result = new lucee.extension.lcov.model.result();
			for (var key in data) {
				var setter = "set" & key;
				if ( structKeyExists( result, setter ) ) {
					result[setter]( data[key] );
				}
			}

			// Build callTreeMap for this result (transform position → fileIdx\tposition)
			var callTreeMap = {};
			var files = result.getFiles();
			for (var fileIdx in files) {
				var fileInfo = files[fileIdx];
				var filePath = fileInfo.path;

				// Look up this file's CallTree in ast-metadata
				if ( structKeyExists( astMetadata, "files" ) && structKeyExists( astMetadata.files, filePath ) ) {
					var fileMetadata = astMetadata.files[filePath];
					if ( structKeyExists( fileMetadata, "callTree" ) ) {
						// Transform keys from "position" to "fileIdx\tposition"
						// AND add fileIdx and position fields that markChildTimeBlocks() expects
						for (var position in fileMetadata.callTree) {
							var key = fileIdx & chr(9) & position;
							var callInfo = fileMetadata.callTree[position];

							// markChildTimeBlocks() expects: {fileIdx, position, type, name, isBuiltIn}
							callTreeMap[key] = {
								"fileIdx": fileIdx,
								"position": position,
								"type": callInfo.functionName ?: "unknown",
								"name": callInfo.functionName ?: "",
								"isBuiltIn": callInfo.isBuiltIn ?: false
							};
						}
					}
				}
			}

			variables.logger.trace( "Built callTreeMap with #structCount(callTreeMap)# entries for #jsonPath#" );

			// Annotate CallTree
			annotateResult( result, callTreeMap );

			// Write back to JSON
			fileWrite( jsonPath, result.toJson( pretty=false ) );
			processedCount++;
		}

		var elapsedTime = getTickCount() - startTime;
		variables.logger.debug( "Phase 4: Processed #processedCount# files, skipped #skippedCount# in #elapsedTime#ms" );

		return arguments.jsonFilePaths;
	}

}
