/**
 * BlockAnnotator - Annotates execution blocks with AST metadata
 *
 * Matches execution blocks (from .exl files) with AST nodes by position
 * and adds astNodeType, isBlock, and tagName information.
 */
component {

	property name="logger";

	/**
	 * Initialize BlockEnricher
	 * @logger Logger instance
	 */
	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Enrich blocks with AST metadata by matching positions.
	 *
	 * @aggregatedBlocks Struct of aggregated blocks (after overlap filtering)
	 * @files Struct of file info {fileIdx: {path: "..."}}
	 * @astMetadataCache Struct of AST metadata by file path {filePath: {astNodes: {...}}}
	 * @return Enriched blocks with AST data added
	 */
	public struct function enrichBlocks(
		required struct aggregatedBlocks,
		required struct files,
		required struct astMetadataCache
	) localmode=true {
		var enrichedBlocks = structNew( "regular" );
		var enrichedCount = 0;
		var totalBlocks = 0;

		// Process each block
		cfloop( collection=arguments.aggregatedBlocks, key="local.blockKey" ) {
			totalBlocks++;
			var block = arguments.aggregatedBlocks[blockKey];

			// Block format: [fileIdx, startPos, endPos, count, totalTime, isOverlapping]
			var fileIdx = toString( block[1] );
			var startPos = block[2];
			var endPos = block[3];

			// Get file path
			var filePath = "";
			if ( structKeyExists( arguments.files, fileIdx ) &&
			     structKeyExists( arguments.files[fileIdx], "path" ) ) {
				filePath = arguments.files[fileIdx].path;
			}

			// Try to enrich with AST data
			var astData = findAstNodeForBlock( filePath, startPos, endPos, arguments.astMetadataCache );

			// Create enriched block - keep original data plus AST info
			var enrichedBlock = duplicate( block );

			if ( structCount( astData ) > 0 ) {
				// Add AST data as additional elements in array
				// Format: [fileIdx, startPos, endPos, count, totalTime, isOverlapping, astNodeType, isBlock, tagName]
				arrayAppend( enrichedBlock, astData.astNodeType );
				arrayAppend( enrichedBlock, astData.isBlock );
				arrayAppend( enrichedBlock, astData.tagName );

				// VALIDATION: If overlap says it's a block container, AST MUST agree
				// (Overlap is never wrong when it detects a container via runtime heuristic)
				// But if AST says it's a block and overlap doesn't, that's OK
				// (Overlap can miss single-statement blocks with no child execution blocks)
				// isOverlapping is at index 6, isBlock is at index 8 (just appended)
				var overlapSaysBlock = enrichedBlock[6]; // isOverlapping from overlap detection
				var astSaysBlock = enrichedBlock[8];     // isBlock from AST

				// Only throw if overlap detected a container but AST didn't
				if ( overlapSaysBlock && !astSaysBlock ) {
					throw(
						type = "BlockAnnotator.BlockMismatch",
						message = "Overlap detection found block container but AST disagrees for block #blockKey# in #filePath#",
						detail = "Overlap detection: isOverlapping=#overlapSaysBlock#, AST: isBlock=#astSaysBlock#, astNodeType=#astData.astNodeType#"
					);
				}

				enrichedCount++;
			} else {
				// No AST match - add empty values to maintain consistent array length
				arrayAppend( enrichedBlock, "" );      // astNodeType
				arrayAppend( enrichedBlock, false );   // isBlock
				arrayAppend( enrichedBlock, "" );      // tagName
			}

			enrichedBlocks[blockKey] = enrichedBlock;
		}

		variables.logger.debug( "Enriched #enrichedCount# of #totalBlocks# blocks with AST metadata" );

		return enrichedBlocks;
	}

	/**
	 * Find matching AST node for a block by position.
	 *
	 * @filePath File path to look up AST metadata
	 * @startPos Block start position
	 * @endPos Block end position
	 * @astMetadataCache AST metadata cache
	 * @return Struct with {astNodeType, isBlock, tagName} or empty struct if no match
	 */
	private struct function findAstNodeForBlock(
		required string filePath,
		required numeric startPos,
		required numeric endPos,
		required struct astMetadataCache
	) localmode=true {
		// Check if we have AST metadata for this file
		if ( !structKeyExists( arguments.astMetadataCache, arguments.filePath ) ) {
			return {};
		}

		var metadata = arguments.astMetadataCache[arguments.filePath];
		if ( !structKeyExists( metadata, "astNodes" ) ) {
			return {};
		}

		// Look for exact match by position
		var astNodes = metadata.astNodes;
		var lookupKey = arguments.startPos & "-" & arguments.endPos;

		if ( structKeyExists( astNodes, lookupKey ) ) {
			var node = astNodes[lookupKey];
			return {
				"astNodeType": node.astNodeType ?: "",
				"isBlock": node.isBlock ?: false,
				"tagName": node.tagName ?: ""
			};
		}

		// No exact match - could do fuzzy matching here if needed
		return {};
	}

}
