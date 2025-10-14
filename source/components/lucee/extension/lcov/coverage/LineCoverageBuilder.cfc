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

	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( logLevel="ERROR" );
		variables.blockAggregator = new lucee.extension.lcov.coverage.BlockAggregator( logger=variables.logger );
		variables.blockToLineAggregator = new lucee.extension.lcov.coverage.BlockToLineAggregator( logger=variables.logger );
		return this;
	}

	/**
	 * Build line coverage for a single result.
	 *
	 * @result The result object with aggregated data
	 * @astMetadata Optional AST metadata (for executable line counts). If not provided, will use coverage keys.
	 * @return The result object with coverage added
	 */
	public any function buildCoverageForResult(required any result, struct astMetadata) {
		// Check if already done
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCoverage" ) && flags.hasCoverage ) {
			variables.logger.debug( "Skipping coverage build - already done (hasCoverage=true)" );
			return arguments.result;
		}

		var startTime = getTickCount();
		variables.logger.debug( "Building line coverage from aggregated blocks" );

		// Get aggregated blocks and files
		var aggregated = arguments.result.getAggregated();
		var files = arguments.result.getFiles();

		// Convert aggregated to blocks (WITHOUT CallTree - that's Phase 4)
		// This just splits the aggregated entries into block format
		var blocks = variables.blockAggregator.convertAggregatedToBlocks( aggregated );

		// Store blocks in result
		arguments.result.setBlocks( blocks );

		// Build line mappings cache from files struct
		// If lineMapping is missing, rebuild it from file content or disk
		var lineMappingsCache = {};
		var blockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=variables.logger );
		for (var fileIdx in files) {
			var fileInfo = files[fileIdx];
			if ( !structKeyExists( fileInfo, "path" ) ) {
				continue;
			}

			// Check if lineMapping already exists
			if ( structKeyExists( fileInfo, "lineMapping" ) ) {
				lineMappingsCache[fileInfo.path] = fileInfo.lineMapping;
			} else {
				// Rebuild lineMapping from content or disk
				var fileContent = "";
				if ( structKeyExists( fileInfo, "content" ) ) {
					fileContent = fileInfo.content;
				} else if ( fileExists( fileInfo.path ) ) {
					fileContent = fileRead( fileInfo.path );
				} else {
					throw( message="Cannot build line mapping: file not found and no content cached for [#fileInfo.path#]" );
				}

				// Build line mapping from content using CoverageBlockProcessor
				var lineMapping = blockProcessor.buildCharacterToLineMapping( fileContent );
				lineMappingsCache[fileInfo.path] = lineMapping;
				// Cache it back in fileInfo for future use
				fileInfo.lineMapping = lineMapping;
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
		variables.logger.debug( "Built line coverage in #elapsedTime#ms" );

		return arguments.result;
	}

	/**
	 * Build line coverage for multiple JSON files.
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @astMetadataPath Path to ast-metadata.json (optional)
	 * @return Array of processed JSON file paths
	 */
	public array function buildCoverage(required array jsonFilePaths, string astMetadataPath) {
		var startTime = getTickCount();
		variables.logger.debug( "Phase 3: Building line coverage for #arrayLen(arguments.jsonFilePaths)# files" );

		// Load AST metadata if provided
		var astMetadata = {};
		if ( structKeyExists( arguments, "astMetadataPath" ) && fileExists( arguments.astMetadataPath ) ) {
			var metadataJson = fileRead( arguments.astMetadataPath );
			astMetadata = deserializeJSON( metadataJson );
		}

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
			if ( structKeyExists( data, "flags" ) && structKeyExists( data.flags, "hasCoverage" ) && data.flags.hasCoverage ) {
				skippedCount++;
				variables.logger.trace( "Skipping #jsonPath# - hasCoverage=true" );
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

			// Build coverage
			buildCoverageForResult( result, astMetadata );

			// Write back to JSON
			fileWrite( jsonPath, result.toJson( pretty=false ) );
			processedCount++;
		}

		var elapsedTime = getTickCount() - startTime;
		variables.logger.debug( "Phase 3: Processed #processedCount# files, skipped #skippedCount# in #elapsedTime#ms" );

		return arguments.jsonFilePaths;
	}

}
