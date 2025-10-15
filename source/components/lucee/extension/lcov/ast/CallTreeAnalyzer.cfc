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
	 * Analyzes execution blocks to identify which represent child time
	 * @aggregated The aggregated execution blocks (position-based format)
	 * @files File information including AST data
	 * @return Struct containing blocks marked as child time
	 */
	public struct function analyzeCallTree(required struct aggregated, required struct files) localmode=true {
		var startTime = getTickCount();

		variables.logger.trace( "CallTreeAnalyzer: Starting analysis with " & structCount( arguments.aggregated ) & " blocks and " & structCount( arguments.files ) & " files" );

		var astStart = getTickCount();

		// Extract all function calls from AST for all files
		var callsMap = extractAllCalls( arguments.files, variables.astCallAnalyzer );

		variables.logger.debug( "CallTreeAnalyzer: extractAllCalls completed in " & ( getTickCount() - astStart ) & "ms, found " & structCount( callsMap ) & " call positions" );

		// Mark blocks that represent child time (function calls)
		var markStart = getTickCount();
		var markedBlocks = markChildTimeBlocks( arguments.aggregated, callsMap );

		variables.logger.debug( "CallTreeAnalyzer: markChildTimeBlocks completed in " & ( getTickCount() - markStart ) & "ms" );

		var metricsStart = getTickCount();
		var metrics = calculateChildTimeMetrics( markedBlocks );

		variables.logger.trace( "CallTreeAnalyzer: calculateChildTimeMetrics completed in " & ( getTickCount() - metricsStart ) & "ms" );
		variables.logger.debug( "CallTreeAnalyzer: Total analysis time: " & ( getTickCount() - startTime ) & "ms" );

		return {
			blocks: markedBlocks,
			metrics: metrics
		};
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
		cfloop( collection=arguments.files, key="local.fileIdx" ) {
			var file = arguments.files[ fileIdx ];

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
	public struct function markChildTimeBlocks(required struct aggregated, required struct callsMap) localmode=true {
		var markedBlocks = structNew( "regular" );

		// callsMap is now nested: {fileIdx: {position: {isChildTime, isBuiltIn, functionName}}}
		// No need to rebuild callsByFile - it's already indexed by fileIdx!

		// Convert aggregated struct to array for chunking
		var blockArray = [];
		cfloop( collection=arguments.aggregated, key="local.blockKey" ) {
			arrayAppend( blockArray, [ blockKey, arguments.aggregated[ blockKey ] ] );
		}

		// Use fixed chunk size - arrayMap's thread pool handles optimal parallelism
		var totalBlocks = arrayLen( blockArray );
		var chunkSize = 500;

		// Split into chunks using arraySlice
		var chunks = [];
		for ( var i = 1; i <= totalBlocks; i += chunkSize ) {
			var length = min( chunkSize, totalBlocks - i + 1 );
			var chunk = arraySlice( blockArray, i, length );
			arrayAppend( chunks, [ chunk, arguments.callsMap ] );
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

		cfloop( collection=arguments.markedBlocks, key="local.blockKey" ) {
			var block = arguments.markedBlocks[blockKey];

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