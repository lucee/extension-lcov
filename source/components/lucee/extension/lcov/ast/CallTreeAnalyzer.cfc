/**
 * CallTreeAnalyzer - Analyzes execution blocks to identify child time
 *
 * This component:
 * - Identifies which execution blocks represent child time (time in called functions)
 * - Marks blocks that are function calls, especially built-in functions
 * - Provides simplified metrics focused on child time identification
 * - Works with position-based data from execution logs, not line numbers
 */
component {

	// Cache for per-file call extraction to avoid repeated AST analysis across .exl files
	variables.fileCallCache = {};

	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		variables.astCallAnalyzer = new AstCallAnalyzer( logger=variables.logger );
		variables.parallelHelper = new CallTreeParallelHelpers();
		return this;
	}

	/**
	 * Extract all function calls from AST data across all files
	 * @files File information including AST
	 * @astCallAnalyzer The AST call analyzer component
	 * @return Struct mapping call positions to call info
	 */
	private struct function extractAllCalls(required struct files, required any astCallAnalyzer) localmode=true {
		var callsMap = structNew( "regular" );
		var totalFiles = structCount( arguments.files );
		var cacheHits = 0;
		var cacheMisses = 0;

		variables.logger.trace( "extractAllCalls: Processing " & totalFiles & " files" );

		// Build array of file data for parallel processing: [fileIdx, file, filePath, cached, fileCallCache]
		var fileArray = [];
		cfloop( collection=arguments.files, key="local.fileIdx", value="local.file" ) {

			// Fail fast if no AST available
			if ( !structKeyExists( file, "ast" ) || !isStruct( file.ast ) ) {
				var filePath = file.path ?: "unknown file (fileIdx: " & fileIdx & ")";
				throw( type="MissingAST", message="No AST available for file: " & filePath );
			}

			var filePath = file.path ?: fileIdx;

			// Check cache
			var cached = false;
			var fileCalls = [];
			if ( structKeyExists( file, "path" ) && structKeyExists( variables.fileCallCache, filePath ) ) {
				fileCalls = variables.fileCallCache[ filePath ];
				cached = true;
				cacheHits++;
			} else {
				cacheMisses++;
			}

			arrayAppend( fileArray, [ fileIdx, file, filePath, cached, fileCalls, arguments.astCallAnalyzer ] );
		}

		// Add helper to each file info array
		cfloop( array=fileArray, item="local.fileInfo" ) {
			arrayAppend( fileInfo, variables.parallelHelper );
		}

		// Process files in parallel
		var fileResults = arrayMap( fileArray, variables.parallelHelper.processFileForCalls, true );  // parallel=true

		// Merge results and update cache
		cfloop( array=fileResults, item="local.fileResult" ) {
			var fileIdx = fileResult.fileIdx;
			var filePath = fileResult.filePath;
			var fileCalls = fileResult.calls;

			// Update cache if not already cached
			if ( !fileResult.wasCached && fileResult.hasPath ) {
				variables.fileCallCache[ filePath ] = fileCalls;
			}

			// Add file calls to callsMap (nested struct: {fileIdx: {position: callInfo}})
			if ( !structKeyExists( callsMap, fileIdx ) ) {
				callsMap[fileIdx] = {};
			}
			cfloop( array=fileCalls, item="local.call" ) {
				callsMap[fileIdx][call.position] = {
					isChildTime: true,
					isBuiltIn: call.isBuiltIn,
					functionName: call.name
				};
			}
		}

		variables.logger.trace( "extractAllCalls: Cache hits=" & cacheHits & ", misses=" & cacheMisses );

		return callsMap;
	}

	/**
	 * Mark execution blocks that represent child time (function calls)
	 */
	public struct function markChildTimeBlocks(required struct blocks, required struct callsMap, required struct astNodesMap, required struct files) localmode=true {
		var markedBlocks = structNew( "regular" );

		// callsMap is now nested: {fileIdx: {position: {isChildTime, isBuiltIn, functionName}}}
		// No need to rebuild callsByFile - it's already indexed by fileIdx!

		// Convert blocks struct to array for chunking
		// blocks format: {fileIdx: {"startPos-endPos": {hitCount, execTime, isOverlapping, blockType}}}
		var blockArray = [];
		cfloop( collection=arguments.blocks, key="local.fileIdx", value="local.fileBlocks" ) {
			if ( !isStruct( fileBlocks ) ) {
				throw(
					type = "CallTreeAnalyzer.InvalidBlocksStructure",
					message = "Expected blocks[fileIdx] to be a struct, got: #getMetadata( fileBlocks ).name#",
					detail = "fileIdx: #fileIdx#, blocks type: #getMetadata( arguments.blocks ).name#, fileBlocks: #serializeJSON( fileBlocks )#"
				);
			}
			cfloop( collection=fileBlocks, key="local.blockKey", value="local.blockData" ) {
				// blockKey is "startPos-endPos", parse it
				var parts = listToArray( blockKey, "-" );
				if ( arrayLen( parts ) != 2 ) {
					throw(
						type = "CallTreeAnalyzer.InvalidBlockKey",
						message = "Expected blockKey format 'startPos-endPos', got: '#blockKey#'",
						detail = "Parts array length: #arrayLen( parts )#, Parts: #serializeJSON( parts )#, fileIdx: #fileIdx#, fileBlocks type: #getMetadata( fileBlocks ).name#"
					);
				}
				var startPos = parts[1];
				var endPos = parts[2];
				arrayAppend( blockArray, [ fileIdx, startPos, endPos, blockData ] );
			}
		}

		// Use fixed chunk size - arrayMap's thread pool handles optimal parallelism
		var totalBlocks = arrayLen( blockArray );
		var chunkSize = 500;

		// Split into chunks using arraySlice
		var chunks = [];
		for ( var i = 1; i <= totalBlocks; i += chunkSize ) {
			var length = min( chunkSize, totalBlocks - i + 1 );
			var chunk = arraySlice( blockArray, i, length );
			arrayAppend( chunks, [ chunk, arguments.callsMap, arguments.astNodesMap, arguments.files ] );
		}

		// Process chunks in parallel
		var chunkResults = arrayMap( chunks, variables.parallelHelper.processBlockChunk, true );

		// Merge results
		cfloop( array=chunkResults, item="local.chunkResult" ) {
			structAppend( markedBlocks, chunkResult, true );
		}

		return markedBlocks;
	}

	/**
	 * Calculate metrics based on child time blocks
	 */
	public struct function calculateChildTimeMetrics(required struct markedBlocks) localmode=true {
		var metrics = {
			"totalBlocks": structCount(arguments.markedBlocks),
			"childTimeBlocks": 0,
			"builtInBlocks": 0
		};

		cfloop( collection=arguments.markedBlocks, key="local.blockKey", value="local.block" ) {

			if (block.isChildTime) {
				metrics.childTimeBlocks++;

				if (block.isBuiltIn) {
					metrics.builtInBlocks++;
				}
			}
		}

		return metrics;
	}

	/**
	 * Get summary metrics for marked blocks
	 */
	public struct function getCallTreeMetrics(required struct result) localmode=true {
		if (!structKeyExists(arguments.result, "blocks") ||
			!structKeyExists(arguments.result, "metrics")) {
			return {
				"totalBlocks": 0,
				"childTimeBlocks": 0,
				"builtInBlocks": 0
			};
		}

		return arguments.result.metrics;
	}
}