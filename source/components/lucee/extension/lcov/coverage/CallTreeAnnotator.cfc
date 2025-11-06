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
		variables.blockAnnotator = new lucee.extension.lcov.coverage.BlockAnnotator( logger=variables.logger );
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
			var astNodesMap = structNew( "regular" );
			var files = result.getFiles();
			for ( var fileIdx in files ) {
				var metadata = variables.astMetadataLoader.loadMetadataForFileWithIndex( metadataPath, index, files[fileIdx].path );
				callTreeMap[fileIdx] = metadata.callTree;
				// Load astNodes if available (backward compatible - old metadata won't have it)
				astNodesMap[files[fileIdx].path] = structKeyExists( metadata, "astNodes" ) ? metadata.astNodes : structNew();
			}

			// Annotate CallTree - pass AST index for lineMapping
			self.annotateResult( result, callTreeMap, astNodesMap, metadataPath, index );

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
	 * @astNodesMap Map of AST nodes by file path from ast-metadata.json
	 * @astMetadataPath Path to ast-metadata.json (for loading lineMapping)
	 * @astIndex Loaded AST index (shared across parallel processing)
	 * @return The result object with CallTree annotations
	 */
	private any function annotateResult(result, callTreeMap, astNodesMap, astMetadataPath, astIndex) localmode=true {
		// Check if already done
		var flags = arguments.result.getFlags();
		if ( structKeyExists( flags, "hasCallTree" ) && flags.hasCallTree ) {
			variables.logger.debug( "Skipping CallTree annotation - already done (hasCallTree=true)" );
			return arguments.result;
		}

		var event = variables.logger.beginEvent( "AnnotateCallTree" );;

		var blocks = arguments.result.getBlocks();
		var files = arguments.result.getFiles();
		var markedBlocks = variables.callTreeAnalyzer.markChildTimeBlocks( blocks, arguments.callTreeMap, arguments.astNodesMap, files );


		// Update existing blocks with blockType and isBlock from markedBlocks
		// markedBlocks has flat structure: {fileIdx\tstartPos\tendPos: {fileIdx, startPos, endPos, isChildTime, isBuiltIn, isBlock}}
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
				// isOverlapping is optional - only set after overlap filtering phase
				var isOverlapping = block.isOverlapping ?: false;
				block[ "blockType" ] = baseType + (isOverlapping ? 2 : 0);
				// Set isBlock flag from AST analysis
				block[ "isBlock" ] = markedBlock.isBlock ?: false;
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
		// Enrich blocks with AST node type information (MUST be after blocks are rebuilt from aggregated!)
		enrichBlocksWithAst( arguments.result.getBlocks(), files, arguments.astNodesMap );

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

	/**
	 * Enrich blocks with AST node type information.
	 *
	 * @blocks Nested struct {fileIdx: {startPos-endPos: {hitCount, execTime, ...}}}
	 * @files Files struct {fileIdx: {path: "..."}}
	 * @astNodesMap AST nodes by file path {filePath: {startPos-endPos: {astNodeType, isBlock, tagName}}}
	 */
	private void function enrichBlocksWithAst(
		required struct blocks,
		required struct files,
		required struct astNodesMap
	) localmode=true {
		var enrichedCount = 0;
		var totalBlocks = 0;

		// Iterate over each file's blocks
		cfloop( collection=arguments.blocks, key="local.fileIdx", value="local.fileBlocks" ) {
			// Get file path
			var filePath = "";
			if ( structKeyExists( arguments.files, fileIdx ) &&
			     structKeyExists( arguments.files[fileIdx], "path" ) ) {
				filePath = arguments.files[fileIdx].path;
			}

			// Get AST nodes for this file
			var astNodes = structKeyExists( arguments.astNodesMap, filePath ) ?
				arguments.astNodesMap[filePath] :
				structNew();

			// Skip if no AST nodes for this file
			if ( structCount( astNodes ) == 0 ) {
				continue;
			}
			cfloop( collection=fileBlocks, key="local.blockKey", value="local.block" ) {
				totalBlocks++;

				// blockKey format: "startPos-endPos"
				// Look up AST node with same key
				if ( structKeyExists( astNodes, blockKey ) ) {
					var astNode = astNodes[blockKey];

					// VALIDATION: If overlap says it's a block container, AST MUST agree
					// (Overlap is never wrong when it detects a container via runtime heuristic)
					// But if AST says it's a block and overlap doesn't, that's OK
					// (Overlap can miss single-statement blocks with no child execution blocks)
					if ( structKeyExists( block, "isOverlapping" ) ) {
						var overlapSaysBlock = block.isOverlapping;
						var astSaysBlock = astNode.isBlock ?: false;

						// Only throw if overlap detected a container but AST didn't
						if ( overlapSaysBlock && !astSaysBlock ) {
							throw(
								type = "CallTreeAnnotator.BlockMismatch",
								message = "Overlap detection found block container but AST disagrees for block #blockKey# in #filePath#",
								detail = "Overlap detection: isOverlapping=#overlapSaysBlock#, AST: isBlock=#astSaysBlock#, astNodeType=#astNode.astNodeType#, tagName=#astNode.tagName ?: ''#" & chr(10) &
									"Block data: hitCount=#block.hitCount#, execTime=#block.execTime#" & chr(10) &
									"Full block struct: #serializeJSON(block)#" & chr(10) &
									"Full AST node: #serializeJSON(astNode)#"
							);
						}
					}

					// Add AST data to block
					block.astNodeType = astNode.astNodeType ?: "";
					block.isBlock = astNode.isBlock ?: false;
					block.tagName = astNode.tagName ?: "";
					enrichedCount++;
				}
			}
		}
		variables.logger.debug( "Enriched #enrichedCount# of #totalBlocks# blocks with AST metadata" );
	}


}
