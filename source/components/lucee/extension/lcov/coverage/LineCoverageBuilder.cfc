/**
 * Phase 3: Build Line Coverage from aggregated blocks.
 *
 * Converts character-position-based aggregated blocks to line-based coverage.
 * This phase is LAZY - only runs if flags.hasCoverage is false.
 *
 * Does NOT need CallTree data - just converts positions to lines.
 * LCOV format only needs this phase, not Phase 4 (CallTree annotation).
 */
component {

	property name="logger";
	property name="blockAggregator";
	property name="blockToLineAggregator";
	property name="blockProcessor";

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
	 * @return Array of processed JSON file paths
	 */
	public array function buildCoverage(required array jsonFilePaths, required string astMetadataPath) localmode="modern" {
		var startTime = getTickCount();
		var totalFiles = arrayLen(arguments.jsonFilePaths);
		variables.logger.info( "Phase 3: Building line coverage for #totalFiles# files" );

		// Phase 3 doesn't actually need AST metadata - it just converts blocks to lines
		// AST metadata is only needed in Phase 4 for CallTree annotation

		// Load AST index once for all files (shared across parallel processing)
		var astLoader = new lucee.extension.lcov.parser.AstMetadataLoader( logger=variables.logger );
		var astIndex = astLoader.loadIndex( arguments.astMetadataPath );

		// Cache for closure access
		var self = this;
		var astMetadataPath = arguments.astMetadataPath;

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
			self.buildCoverageForResult( result, astMetadataPath, astLoader, astIndex );

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
		variables.logger.info( "Phase 3: Processed #processedCount# files, skipped #skippedCount# in #elapsedTime#ms" );

		return arguments.jsonFilePaths;
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
	public any function buildCoverageForResult(required any result, string astMetadataPath, any astLoader, struct astIndex) localmode="modern" {
		// Check if already done
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCoverage" ) && flags.hasCoverage ) {
			variables.logger.debug( "Skipping coverage build - already done (hasCoverage=true)" );
			return arguments.result;
		}

		var startTime = getTickCount();
		variables.logger.trace( "Building line coverage from aggregated blocks" );

		// Get aggregated blocks and files
		var aggregated = arguments.result.getAggregated();
		var files = arguments.result.getFiles();

		// Convert aggregated to blocks (WITHOUT CallTree - that's Phase 4)
		// This just splits the aggregated entries into block format
		var blocks = variables.blockAggregator.convertAggregatedToBlocks( aggregated );

		// Store blocks in result
		arguments.result.setBlocks( blocks );

		// Build line mappings cache from AST JSON files (calculated once in Phase 2)
		// This eliminates 53,080 redundant file reads!
		var lineMappingsCache = {};
		for (var fileIdx in files) {
			var fileInfo = files[fileIdx];
			if ( !structKeyExists( fileInfo, "path" ) ) {
				continue;
			}

			// Check if lineMapping already exists
			if ( structKeyExists( fileInfo, "lineMapping" ) ) {
				lineMappingsCache[fileInfo.path] = fileInfo.lineMapping;
			} else {
				// Load from AST JSON - fail fast if not available!
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
				fileInfo.lineMapping = astData.lineMapping;
				lineMappingsCache[fileInfo.path] = astData.lineMapping;
			}
		}

		// Convert blocks to line-based coverage
		var coverage = variables.blockToLineAggregator.aggregateBlocksToLines(
			arguments.result,
			blocks,
			files,
			lineMappingsCache
		);

		// Store coverage in result
		arguments.result.setCoverage( coverage );

		// Update flags
		arguments.result.setFlags({
			"hasCallTree": false, // Still no CallTree
			"hasBlocks": true,
			"hasCoverage": true
		});

		var elapsedTime = getTickCount() - startTime;
		// Only log if it took more than 100ms to avoid log spam with thousands of files
		if ( elapsedTime > 100 ) {
			variables.logger.debug( "Built line coverage in #elapsedTime#ms" );
		}

		return arguments.result;
	}

}
