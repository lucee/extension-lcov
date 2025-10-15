/**
 * StreamingMerger.cfc
 *
 * Streams through request-level JSON files and merges them into source-level results.
 * Never loads all JSONs into memory at once - processes in chunks for memory efficiency.
 *
 * Key Features:
 * - Streaming merge: Load one JSON, merge it, discard it (minimal memory)
 * - Parallel processing: Process chunks of JSONs in parallel for speed
 * - Single pass: Merges coverage + aggregates childTime in one pass
 * - In-memory results: Returns merged results in memory (no disk write)
 */
component {

	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Stream merge request-level JSONs into source-level results
	 * Processes files in parallel chunks for speed and memory efficiency
	 *
	 * @jsonFilePaths Array of JSON file paths to merge
	 * @parallel Whether to process in parallel chunks (default true)
	 * @chunkSize Number of files to process per parallel thread (default 100)
	 * @return Struct of merged result objects keyed by canonical index
	 */
	public struct function streamMergeToSourceFiles(
		required array jsonFilePaths,
		boolean parallel = true,
		numeric chunkSize = 100
	) localmode=true {
		var startTime = getTickCount();
		var totalFiles = arrayLen(arguments.jsonFilePaths);

		variables.logger.info("Phase earlyMergeToSourceFiles: Streaming merge of #totalFiles# JSON files");

		// Step 1: Build file mappings without loading all JSONs
		var mappingStartTime = getTickCount();
		var mappings = buildFileMappingsWithoutLoading(arguments.jsonFilePaths);
		var uniqueFiles = structCount(mappings.filePathToIndex);
		variables.logger.info("Phase earlyMergeToSourceFiles: Found #uniqueFiles# unique source files in #getTickCount() - mappingStartTime#ms");

		// Step 2: Initialize empty merged results
		var mergedResults = initializeEmptyMergedResults(mappings);

		// Step 3: Stream merge in parallel chunks
		var mergeStartTime = getTickCount();
		if (arguments.parallel) {
			streamMergeParallel(arguments.jsonFilePaths, mergedResults, mappings, arguments.chunkSize);
		} else {
			streamMergeSequential(arguments.jsonFilePaths, mergedResults, mappings);
		}
		var mergeTime = getTickCount() - mergeStartTime;

		// Note: Stats calculation skipped - will be done after buildLineCoverageFromResults converts aggregated → coverage

		var totalTime = getTickCount() - startTime;
		variables.logger.info("Phase earlyMergeToSourceFiles: Completed streaming merge of #totalFiles# → #uniqueFiles# files in #totalTime#ms (merge: #mergeTime#ms)");

		return mergedResults;
	}

	/**
	 * Build file path mappings by reading file lists from JSONs without loading full data
	 * This is fast and memory-efficient - only reads the "files" section
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @return Struct with filePathToIndex and indexToFilePath mappings
	 */
	private struct function buildFileMappingsWithoutLoading(required array jsonFilePaths) localmode=true {
		var filePathToIndex = structNew("regular");
		var indexToFilePath = structNew("regular");
		var canonicalIndex = 0;
		var resultFactory = new lucee.extension.lcov.model.result();

		// Quick pass: just read files section from each JSON
		for (var jsonPath in arguments.jsonFilePaths) {
			var jsonContent = fileRead(jsonPath);
			var result = resultFactory.fromJson(jsonContent, false);
			var files = result.getFiles();

			// Map each unique file path to a canonical index
			cfloop(collection=files, item="local.fileIndex") {
				var filePath = files[fileIndex].path;
				if (!structKeyExists(filePathToIndex, filePath)) {
					filePathToIndex[filePath] = canonicalIndex;
					indexToFilePath[canonicalIndex] = {
						"path": filePath,
						"fileInfo": files[fileIndex]
					};
					canonicalIndex++;
				}
			}

			// Free memory
			result = nullValue();
			jsonContent = nullValue();
		}

		return {
			"filePathToIndex": filePathToIndex,
			"indexToFilePath": indexToFilePath
		};
	}

	/**
	 * Initialize empty merged result objects for each unique source file
	 * These will be populated during streaming merge
	 *
	 * @mappings Struct with filePathToIndex and indexToFilePath
	 * @return Struct of empty result objects keyed by canonical index
	 */
	private struct function initializeEmptyMergedResults(required struct mappings) localmode=true {
		var mergedResults = structNew("regular");

		cfloop(collection=arguments.mappings.indexToFilePath, item="local.canonicalIndex") {
			var fileInfo = arguments.mappings.indexToFilePath[canonicalIndex];

			// Create empty result with just file metadata
			var emptyResult = new lucee.extension.lcov.model.result();
			emptyResult.setFiles({
				"0": fileInfo.fileInfo  // Always use index 0 for merged results
			});
			emptyResult.setAggregated({});  // Will be populated during merge
			emptyResult.setCoverage({});    // Will be built from aggregated later
			emptyResult.setBlocks({});      // Will be built from aggregated later
			emptyResult.setIsFile(true);
			emptyResult.setCallTreeMetrics({"totalChildTime": 0});
			emptyResult.setFlags({
				"hasCallTree": false,
				"hasBlocks": false,
				"hasCoverage": false
			});

			// Set metadata with required properties (script-name, execution-time, unit)
			emptyResult.setMetadata({
				"script-name": fileInfo.path,
				"exeLog": fileInfo.path,
				"execution-time": "0",
				"unit": "μs"
			});

			// Generate outputFilename from path (same logic as CoverageMergerWriter)
			var sourceDir = getDirectoryFromPath( fileInfo.path );
			var sourceFileName = getFileFromPath( fileInfo.path );
			var dirHash = left( hash( sourceDir, "MD5" ), 7 );
			var baseName = "file-" & dirHash & "-" & reReplace( sourceFileName, "\\.(cfm|cfc)$", "" );
			emptyResult.setOutputFilename( baseName );

			mergedResults[canonicalIndex] = emptyResult;
		}

		return mergedResults;
	}

	/**
	 * Stream merge JSONs in parallel chunks
	 * Splits JSONs into chunks and processes each chunk in parallel
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @mergedResults Struct of merged results (modified in place)
	 * @mappings File path mappings
	 * @chunkSize Number of files per chunk
	 */
	private void function streamMergeParallel(
		required array jsonFilePaths,
		required struct mergedResults,
		required struct mappings,
		required numeric chunkSize
	) localmode=true {
		var chunks = [];
		var totalFiles = arrayLen(arguments.jsonFilePaths);

		// Split into chunks
		for (var i = 1; i <= totalFiles; i += arguments.chunkSize) {
			var chunk = [];
			for (var j = i; j < i + arguments.chunkSize && j <= totalFiles; j++) {
				arrayAppend(chunk, arguments.jsonFilePaths[j]);
			}
			arrayAppend(chunks, chunk);
		}

		variables.logger.info("Phase earlyMergeToSourceFiles: Processing #totalFiles# files in #arrayLen(chunks)# parallel chunks of ~#arguments.chunkSize# files");

		// Cache references for closure
		var self = this;
		var mergedResults = arguments.mergedResults;
		var mappings = arguments.mappings;

		// Process chunks in parallel
		arrayMap(chunks, function(chunk) {
			self.processChunk(chunk, mergedResults, mappings);
			return true;
		}, true);  // parallel=true
	}

	/**
	 * Stream merge JSONs sequentially (for debugging or single-threaded environments)
	 *
	 * @jsonFilePaths Array of JSON file paths
	 * @mergedResults Struct of merged results (modified in place)
	 * @mappings File path mappings
	 */
	private void function streamMergeSequential(
		required array jsonFilePaths,
		required struct mergedResults,
		required struct mappings
	) localmode=true {
		processChunk(arguments.jsonFilePaths, arguments.mergedResults, arguments.mappings);
	}

	/**
	 * Process a chunk of JSON files
	 * Loads each JSON, merges it into merged results, then discards it
	 *
	 * @jsonPaths Array of JSON file paths in this chunk
	 * @mergedResults Struct of merged results (modified in place)
	 * @mappings File path mappings
	 */
	public void function processChunk(
		required array jsonPaths,
		required struct mergedResults,
		required struct mappings
	) localmode=true {
		var resultFactory = new lucee.extension.lcov.model.result();
		var merger = new lucee.extension.lcov.CoverageMerger(logger=variables.logger);

		// Process each JSON in this chunk
		for (var jsonPath in arguments.jsonPaths) {
			var result = resultFactory.fromJson(fileRead(jsonPath), false);

			// Merge this result into appropriate merged results
			mergeResultIntoMergedResults(result, arguments.mergedResults, arguments.mappings, merger);

			// Free memory immediately
			result = nullValue();
		}
	}

	/**
	 * Merge a single result into the merged results
	 * Merges aggregated data (block-based) - coverage/CallTree built later with AST metadata
	 *
	 * @result The result object to merge
	 * @mergedResults Struct of merged results (modified in place)
	 * @mappings File path mappings
	 * @merger CoverageMerger instance (not used for aggregated merge)
	 */
	private void function mergeResultIntoMergedResults(
		required any result,
		required struct mergedResults,
		required struct mappings,
		required any merger
	) localmode=true {
		var aggregatedData = arguments.result.getAggregated();
		var files = arguments.result.getFiles();

		// For each block in aggregated data: "fileIdx\tstartPos\tendPos" = [fileIdx, startPos, endPos, hitCount, execTime]
		cfloop(collection=aggregatedData, item="local.blockKey") {
			var blockData = aggregatedData[blockKey];

			var fileIndex = blockData[1];  // First element is file index
			var filePath = files[fileIndex].path;
			var canonicalIndex = arguments.mappings.filePathToIndex[filePath];
			var mergedResult = arguments.mergedResults[canonicalIndex];

			// Get or initialize aggregated struct for merged result
			var mergedAggregated = mergedResult.getAggregated();
			if (!isStruct(mergedAggregated)) {
				mergedAggregated = structNew("regular");
			}

			// Build key with canonical index (always 0 for merged results)
			var mergedBlockKey = "0	#blockData[2]#	#blockData[3]#";  // "0\tstartPos\tendPos" using chr(9) for TAB

			// Merge block: accumulate hitCount and execTime
			if (structKeyExists(mergedAggregated, mergedBlockKey)) {
				var existingBlock = mergedAggregated[mergedBlockKey];
				existingBlock[4] += blockData[4];  // hitCount
				existingBlock[5] += blockData[5];  // execTime
			} else {
				// New block: copy with canonical index 0
				mergedAggregated[mergedBlockKey] = ["0", blockData[2], blockData[3], blockData[4], blockData[5]];
			}

			mergedResult.setAggregated(mergedAggregated);
		}
	}

}
