/**
 * buildLineCoverage: Build Line Coverage from aggregated blocks.
 *
 * Converts character-position-based aggregated blocks to line-based coverage.
 * This phase is LAZY - only runs if flags.hasCoverage is false.
 *
 * Does NOT need CallTree data - just converts positions to lines.
 * LCOV format only needs this phase, not annotateCallTree.
 */
component {

	property name="logger";
	property name="blockAggregator";
	property name="blockToLineAggregator";
	property name="blockProcessor";

	/**
	 * @logger Logger instance (optional)
	 */
	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( logLevel="ERROR" );
		variables.blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator( logger=variables.logger );
		variables.blockToLineAggregator = new lucee.extension.lcov.coverage.BlockToLineAggregator( logger=variables.logger );
		variables.blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=variables.logger );
		return this;
	}

		/**
	 * Build line coverage for multiple JSON files.
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json
	 * @buildWithCallTree If true, marks blocks with blockType before building coverage (combines buildLineCoverage+annotateCallTree)
	 * @return Array of processed JSON file paths
	 */
	public array function buildCoverage(required array jsonFilePaths, required string astMetadataPath, boolean buildWithCallTree = false) localmode=true {
		var startTime = getTickCount();
		var totalFiles = arrayLen(arguments.jsonFilePaths);
		variables.logger.info( "Phase buildLineCoverage: Building line coverage for #totalFiles# files" );

		// buildLineCoverage doesn't actually need AST metadata - it just converts blocks to lines
		// AST metadata is only needed in annotateCallTree for CallTree annotation

		// Load AST index once for all files (shared across parallel processing)
		var astLoader = new lucee.extension.lcov.parser.AstMetadataLoader( logger=variables.logger );
		var astIndex = astLoader.loadIndex( arguments.astMetadataPath );

		// Cache for closure access
		var self = this;
		var astMetadataPath = arguments.astMetadataPath;
		var buildWithCallTree = arguments.buildWithCallTree;

		var results = arrayMap( arguments.jsonFilePaths, function( jsonPath, index ) {
			if ( !fileExists( jsonPath ) ) {
				variables.logger.warn( "Skipping missing JSON file: #jsonPath#" );
				return {processed: false, skipped: false};
			}

			// Load result
			var jsonContent = fileRead( jsonPath );
			var data = deserializeJSON( jsonContent );

			// Check flags - skip if already done
			if ( structKeyExists( data, "flags" ) && structKeyExists( data.flags, "hasCoverage" ) && data.flags.hasCoverage ) {
				variables.logger.trace( "Skipping #jsonPath# - hasCoverage=true" );
				return {processed: false, skipped: true};
			}

			// Convert to result object
			var result = new lucee.extension.lcov.model.result();
			for (var key in data) {
				var setter = "set" & key;
				if ( structKeyExists( result, setter ) ) {
					result[setter]( data[key] );
				}
			}

			// Build coverage - pass AST loader for lineMapping
			self.buildCoverageForResult( result, astMetadataPath, astLoader, astIndex, buildWithCallTree );

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
		variables.logger.info( "Phase buildLineCoverage: Processed #processedCount# files, skipped #skippedCount# in #elapsedTime#ms" );

		return arguments.jsonFilePaths;
	}

	/**
	 * Build line coverage for in-memory results (Stage 2 optimization)
	 * Works with already-merged results instead of loading from disk
	 *
	 * @mergedResults Struct of merged result objects keyed by canonical index
	 * @astMetadataPath Path to ast-metadata.json
	 * @buildWithCallTree If true, marks blocks with blockType before building coverage
	 * @return Struct of result objects with coverage added
	 */
	public struct function buildCoverageFromResults(
		required struct mergedResults,
		required string astMetadataPath,
		boolean buildWithCallTree = false
	) localmode=true {
		var startTime = getTickCount();
		var totalFiles = structCount(arguments.mergedResults);
		variables.logger.info( "Phase buildLineCoverage: Building line coverage for #totalFiles# in-memory results" );

		// Load AST index once for all files (shared across parallel processing)
		var astLoader = new lucee.extension.lcov.parser.AstMetadataLoader( logger=variables.logger );
		var astIndex = astLoader.loadIndex( arguments.astMetadataPath );

		// Cache for closure access
		var self = this;
		var astMetadataPath = arguments.astMetadataPath;
		var buildWithCallTree = arguments.buildWithCallTree;

		// Convert struct to array of {canonicalIndex, result} for parallel processing
		var resultArray = [];
		cfloop(collection=arguments.mergedResults, key="local.canonicalIndex", value="local.result") {
			arrayAppend(resultArray, {
				"canonicalIndex": canonicalIndex,
				"result": result
			});
		}

		// Process in parallel
		var results = arrayMap(resultArray, function(item) {
			// Check flags - skip if already done
			var flags = item.result.getFlags();
			if (structKeyExists(flags, "hasCoverage") && flags.hasCoverage) {
				return {processed: false, skipped: true};
			}

			// Build coverage
			self.buildCoverageForResult(item.result, astMetadataPath, astLoader, astIndex, buildWithCallTree);
			return {processed: true, skipped: false};
		}, true); // true = parallel processing

		// Count results
		var processedCount = 0;
		var skippedCount = 0;
		for (var r in results) {
			if (r.processed) processedCount++;
			if (r.skipped) skippedCount++;
		}

		var elapsedTime = getTickCount() - startTime;
		variables.logger.info( "Phase buildLineCoverage: Processed #processedCount# in-memory results, skipped #skippedCount# in #elapsedTime#ms" );

		return arguments.mergedResults;
	}


	/**
	 * Build line coverage for a single result.
	 *
	 * @result The result object with aggregated data
	 * @astMetadataPath Path to ast-metadata.json (for loading lineMapping)
	 * @astLoader AstMetadataLoader instance (shared across parallel processing)
	 * @astIndex Loaded AST index (shared across parallel processing)
	 * @return The result object with coverage added
	 */
	public any function buildCoverageForResult(required any result, string astMetadataPath, any astLoader, struct astIndex, boolean buildWithCallTree = false) localmode=true {
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCoverage" ) && flags.hasCoverage ) {
			variables.logger.debug( "Skipping coverage build - already done (hasCoverage=true)" );
			return arguments.result;
		}

		var event = variables.logger.beginEvent( "BuildLineCoverage" );
		var aggregated = arguments.result.getAggregated();
		var files = arguments.result.getFiles();

		// If buildWithCallTree, build CallTree data and mark blocks with blockType
		// Convert aggregated to blocks FIRST (needed for markChildTimeBlocks)
		var blocks = variables.blockAggregator.convertAggregatedToBlocks( aggregated );

		// Clear aggregated from memory - no longer needed after blocks are created
		// Keeping it around only wastes memory and bloats JSON output files
		// Comment this out if you need aggregated for debugging
		arguments.result.setAggregated( structNew() );
		if ( arguments.buildWithCallTree ) {
			var callTreeMap = structNew( "regular" );
			var astNodesMap = structNew( "regular" );
			cfloop( collection=files, key="local.fileIdx", value="local.fileInfo" ) {
				var metadata = arguments.astLoader.loadMetadataForFileWithIndex(
					arguments.astMetadataPath,
					arguments.astIndex,
					fileInfo.path
				);
				callTreeMap[fileIdx] = metadata.callTree;
				// Load astNodes if available (backward compatible - old metadata won't have it)
				astNodesMap[fileInfo.path] = structKeyExists( metadata, "astNodes" ) ? metadata.astNodes : structNew();
			}

			var callTreeAnalyzer = new lucee.extension.lcov.ast.CallTreeAnalyzer( logger=variables.logger );
			var markedBlocks = callTreeAnalyzer.markChildTimeBlocks( blocks, callTreeMap, astNodesMap, files );

			arguments.result.setCallTree( callTreeMap );
			arguments.result.setCallTreeMetrics( callTreeAnalyzer.calculateChildTimeMetrics( markedBlocks ) );
		}


		if ( arguments.buildWithCallTree ) {
			applyIsChildFlags( blocks, markedBlocks );
		}

		arguments.result.setBlocks( blocks );

		// Build line mappings cache from AST JSON files (calculated once in extractAstMetadata)
		// IMPORTANT: lineMapping is REQUIRED for block-based markdown reports
		var lineMappingsCache = structNew( "regular" );
		cfloop( collection=files, key="local.fileIdx", value="local.fileInfo" ) {
			// Always load lineMapping from AST metadata (it's not persisted in result JSON)
			var astData = arguments.astLoader.loadMetadataForFileWithIndex(
				arguments.astMetadataPath,
				arguments.astIndex,
				fileInfo.path
			);
			if ( !structKeyExists( astData, "lineMapping" ) ) {
				throw(
					type = "LineMappingMissing",
					message = "lineMapping not found in AST metadata for file [#fileInfo.path#]. AST data keys: [#structKeyList(astData)#]. Index has #structCount(arguments.astIndex.files)# files."
				);
			}
			// Add lineMapping to the result's files struct so reporters can access it
			files[fileIdx].lineMapping = astData.lineMapping;
			lineMappingsCache[fileInfo.path] = astData.lineMapping;

			// Also update executable line info from AST if not already set
			if ( !structKeyExists( fileInfo, "linesFound" ) || fileInfo.linesFound == 0 ) {
				files[fileIdx].linesFound = astData.executableLineCount;
			}
			if ( !structKeyExists( fileInfo, "executableLines" ) ) {
				files[fileIdx].executableLines = astData.executableLines;
			}
		}

		// Write modified files struct back to result (ensures lineMapping persists)
		arguments.result.setFiles( files );

		var coverage = variables.blockToLineAggregator.aggregateBlocksToLines(
			arguments.result,
			blocks,
			files,
			lineMappingsCache
		);

		arguments.result.setCoverage( coverage );

		// Recalculate stats if we built with CallTree (to pick up childTime values)
		if ( arguments.buildWithCallTree ) {
			var coverageStats = new lucee.extension.lcov.CoverageStats( logger=variables.logger );
			coverageStats.calculateCoverageStats( arguments.result );
		}

		arguments.result.setFlags({
			"hasCallTree": arguments.buildWithCallTree, // Has CallTree if built with it
			"hasBlocks": true,
			"hasCoverage": true
		});

		variables.logger.commitEvent( event=event, minThresholdMs=100, logLevel="debug" );

		return arguments.result;
	}

	/**
	 * Apply blockType from markedBlocks to blocks struct.
	 * @blocks Blocks struct keyed by fileIdx -> blockKey
	 * @markedBlocks Flat struct of marked blocks from CallTreeAnalyzer
	 */
	private void function applyIsChildFlags( required struct blocks, required struct markedBlocks ) {
		cfloop( collection=arguments.markedBlocks, key="local.flatKey", value="local.markedBlock" ) {
			var fileIdx = markedBlock.fileIdx;
			var blockKey = markedBlock.startPos & "-" & markedBlock.endPos;

			arguments.blocks[fileIdx][blockKey]["blockType"] = (markedBlock.isChildTime ?: false) ? 1 : 0;
			arguments.blocks[fileIdx][blockKey]["isBlock"] = markedBlock.isBlock ?: false;
		}
	}

}
