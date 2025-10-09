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
		return this;
	}

	/**
	 * Analyzes execution blocks to identify which represent child time
	 * @aggregated The aggregated execution blocks (position-based format)
	 * @files File information including AST data
	 * @return Struct containing blocks marked as child time
	 */
	public struct function analyzeCallTree(required struct aggregated, required struct files) {
		var startTime = getTickCount();

		variables.logger.trace( "CallTreeAnalyzer: Starting analysis with " & structCount( arguments.aggregated ) & " blocks and " & structCount( arguments.files ) & " files" );

		// Create AST call analyzer instance
		var astCallAnalyzer = new AstCallAnalyzer( logger=variables.logger );
		var astStart = getTickCount();

		// Extract all function calls from AST for all files
		var callsMap = extractAllCalls( arguments.files, astCallAnalyzer );

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
	private struct function extractAllCalls(required struct files, required any astCallAnalyzer) localmode="modern" {
		var callsMap = {};
		var totalFiles = structCount( arguments.files );
		var cacheHits = 0;
		var cacheMisses = 0;

		variables.logger.trace( "extractAllCalls: Processing " & totalFiles & " files" );

		// Build array of file data for parallel processing: [fileIdx, file, filePath, cached, fileCallCache]
		var fileArray = [];
		for ( var fileIdx in arguments.files ) {
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

		var helper = new CallTreeParallelHelpers();

		// Add helper to each file info array
		for ( var fileInfo in fileArray ) {
			arrayAppend( fileInfo, helper );
		}

		// Process files in parallel
		var fileResults = arrayMap( fileArray, helper.processFileForCalls, true );  // parallel=true

		// Merge results and update cache
		for ( var fileResult in fileResults ) {
			var fileIdx = fileResult.fileIdx;
			var filePath = fileResult.filePath;
			var fileCalls = fileResult.calls;

			// Update cache if not already cached
			if ( !fileResult.wasCached && fileResult.hasPath ) {
				variables.fileCallCache[ filePath ] = fileCalls;
			}

			// Add file calls to callsMap
			for ( var call in fileCalls ) {
				var key = arrayToList( [ fileIdx, call.position ], chr(9) );
				callsMap[ key ] = {
					fileIdx: fileIdx,
					position: call.position,
					type: call.type,
					name: call.name,
					isBuiltIn: call.isBuiltIn
				};
			}
		}

		variables.logger.trace( "extractAllCalls: Cache hits=" & cacheHits & ", misses=" & cacheMisses );

		return callsMap;
	}

	/**
	 * Mark execution blocks that represent child time (function calls)
	 */
	private struct function markChildTimeBlocks(required struct aggregated, required struct callsMap) localmode="modern" {
		var markedBlocks = {};

		// Build index of calls by fileIdx to avoid O(n²) nested loop
		var callsByFile = {};
		for ( var callKey in arguments.callsMap ) {
			var call = arguments.callsMap[ callKey ];
			if ( !structKeyExists( callsByFile, call.fileIdx ) ) {
				callsByFile[ call.fileIdx ] = [];
			}
			arrayAppend( callsByFile[ call.fileIdx ], call );
		}

		// Convert aggregated struct to array for chunking
		var blockArray = [];
		for ( var blockKey in arguments.aggregated ) {
			arrayAppend( blockArray, [ blockKey, arguments.aggregated[ blockKey ] ] );
		}

		// Use fixed chunk size - arrayMap's thread pool handles optimal parallelism
		var totalBlocks = arrayLen( blockArray );
		var chunkSize = 500;  // Balance between thread overhead and parallelism

		// Split into chunks using arraySlice
		var chunks = [];
		for ( var i = 1; i <= totalBlocks; i += chunkSize ) {
			var length = min( chunkSize, totalBlocks - i + 1 );
			var chunk = arraySlice( blockArray, i, length );
			arrayAppend( chunks, [ chunk, callsByFile ] );
		}

		// Process chunks in parallel
		var chunkResults = arrayMap( chunks, new CallTreeParallelHelpers().processBlockChunk, true );  // parallel=true

		// Merge results
		for ( var chunkResult in chunkResults ) {
			structAppend( markedBlocks, chunkResult, true );
		}

		return markedBlocks;
	}

	/**
	 * Calculate metrics based on child time blocks
	 */
	private struct function calculateChildTimeMetrics(required struct markedBlocks) localmode="modern" {
		var metrics = {
			"totalBlocks": structCount(arguments.markedBlocks),
			"childTimeBlocks": 0,
			"builtInBlocks": 0
		};

		for (var blockKey in arguments.markedBlocks) {
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
	public struct function getCallTreeMetrics(required struct result) {
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