/**
 * CoverageMerger.cfc
 *
 * Responsible for merging code coverage data from multiple execution log files (.exl files)
 * and producing consolidated, per-file coverage reports.
 *
 * Responsibilities:
 * - Parses and combines coverage data from multiple sources, mapping file indices to real file paths.
 * - Merges line-by-line execution counts for each source file across all runs.
 * - Builds a unified result model for each file, including statistics and metadata.
 * - Writes per-file JSON result files, each containing coverage data and the file path as a property.
 * - Ensures only valid files (with a real path) are included in the output, skipping or erroring on bogus indices.
 *
 * File Index Handling:
 * - File indices are assigned based on the order or mapping of files in the parsed data.
 * - Only indices that exist in source.files or filesData and have a valid path are considered valid.
 * - If an index does not map to a real file, it is skipped to prevent bogus entries in the output.
 *
 * Single File Case:
 * - If only one source file is processed, the only valid file index is 0.
 * - All coverage data, file stats, and JSON output will be keyed by 0, and the file mapping will associate index 0 with the real file path.
 * - There are no other indices to map or merge in this case.
 */
component {

	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		variables.coverageStats = new CoverageStats( logger=variables.logger );
		return this;
	}

	/**
	 * Merge execution results by source file and write them directly to JSON files
	 * When separateFiles: true, this combines coverage data from multiple .exl runs
	 * that executed the same source files, creating one JSON file per source file
	 * @results Struct of results keyed by .exl file path
	 * @outputDir Directory to write the file-*.json files to
	 * @logLevel Log level for verbose logging
	 * @return Array of written file paths
	 */
	public struct function mergeResults(required array jsonFilePaths, required string outputDir, string logLevel="none") localmode=true {
		// Progressive loading - process one file at a time to minimize memory usage
		var resultFactory = new lucee.extension.lcov.model.result();
		var mergedResults = structNew( "regular" );
		var fileMappings = structNew( "regular" );
		var isFirstFile = true;

		cfloop( array=arguments.jsonFilePaths, index="local.i", item="local.filePath" ) {
			variables.logger.debug( "Processing file " & i & " of " & arrayLen(arguments.jsonFilePaths) & ": " & filePath );

			if (!fileExists(filePath)) {
				throw(type="FileNotFound", message="JSON file not found: " & filePath);
			}

			try {
				// Load current result
				var jsonContent = fileRead(filePath);
				var currentResult = resultFactory.fromJson(jsonContent, false);

				// Initialize merged structure with first file
				if (isFirstFile) {
					mergedResults = initializeMergedStructure(currentResult);
					fileMappings = buildFileIndexMappingsForResult(currentResult);
					isFirstFile = false;
				}

				// Merge current result into accumulated results
				mergeCurrentResultProgressive(mergedResults, currentResult, fileMappings);

				// Clear reference to current result to free memory
				currentResult = nullValue();
				jsonContent = nullValue();

			} catch (any e) {
				variables.logger.info( "Error processing " & filePath & ": " & e.message );
				rethrow;
			}
		}

		// Recalculate and synchronize all per-file stats
		variables.coverageStats.calculateStatsForMergedResults( mergedResults );
		//variables.logger.trace( "Merged Results: " & serializeJSON(var=mergedResults, compact=false) );
		return mergedResults;
	}

	/**
	* Public: Merges all coverage data from validResults into mergedResults using mappings and sourceFileStats.
	* Used by ReportGenerator for generating separate file reports.
	* Also aggregates childTime from blocks during the merge (eliminates need for separate reload).
	* @validResults Struct of filtered valid results keyed by exlPath
	* @mergedResults Struct of initialized merged results (by canonical index)
	* @mappings Struct with filePathToIndex and indexToFilePath
	* @sourceFileStats Struct for tracking exlFiles per canonical index
	* @totalMergeOperations Numeric, running total of merge operations (will be updated)
	* @return mergedResults struct
	*/
	public struct function mergeAllCoverageDataFromResults(
		required struct validResults,
		required struct mergedResults,
		required struct mappings,
		required struct sourceFileStats,
		numeric totalMergeOperations = 0
	) {
		// Track which exlPath was used to initialize each merged entry (by filePath, not fileIndex)
		var initializedBy = structNew( "regular" );
		// Track childTime per canonical index
		var childTimeByFile = structNew( "regular" );

		cfloop( collection=arguments.mergedResults, key="local.canonicalIndex", value="local.mergedEntry" ) {
			var files = mergedEntry.getFiles();
			cfloop( collection=files, key="local.fileIndex" ) {
				var filePath = files[fileIndex].path;
				// Find the result that was used to initialize this merged entry
				// Match by filePath since fileIndex can differ between .exl files
				cfloop( collection=arguments.validResults, key="local.exlPath" ) {
					var result = arguments.validResults[exlPath];
					var resultFiles = result.getFiles();
					cfloop( collection=resultFiles, key="local.resultFileIndex" ) {
						if (resultFiles[resultFileIndex].path == filePath) {
							initializedBy[canonicalIndex] = { exlPath: exlPath, filePath: filePath };
							break;
						}
					}
					if (structKeyExists(initializedBy, canonicalIndex)) {
						break;
					}
				}
			}
		}

		cfloop( collection=arguments.validResults, key="local.exlPath" ) {
			var result = arguments.validResults[exlPath];
			var exlFileName = listLast(exlPath, "/\\");
			var coverageData = result.getCoverage();
			var blocks = result.getBlocks();

			cfloop( collection=coverageData, key="local.fileIndex" ) {
				var sourceFilePath = result.getFileItem(fileIndex).path;
				var canonicalIndex = arguments.mappings.filePathToIndex[sourceFilePath];
				var sourceFileCoverage = coverageData[fileIndex];

				// Only merge if this exlPath was NOT used to initialize the merged entry
				// Compare by exlPath only since the same file can have different fileIndex values
				if (!(structKeyExists(initializedBy, canonicalIndex) && initializedBy[canonicalIndex].exlPath == exlPath)) {
					var mergedLines = mergeCoverageData(arguments.mergedResults[canonicalIndex], sourceFileCoverage, sourceFilePath, 0);
					arguments.totalMergeOperations += mergedLines;
				}

				// Accumulate childTime from blocks while we have them in memory
				if (structKeyExists(blocks, fileIndex)) {
					if (!structKeyExists(childTimeByFile, canonicalIndex)) {
						childTimeByFile[canonicalIndex] = 0;
					}

					var fileBlocks = blocks[fileIndex];
					cfloop( collection=fileBlocks, key="local.blockKey" ) {
						var block = fileBlocks[blockKey];
						if (structKeyExists(block, "isChild") && block.isChild) {
							childTimeByFile[canonicalIndex] += block.execTime;
						}
					}
				}

				arrayAppend(arguments.sourceFileStats[canonicalIndex].exlFiles, exlFileName);
			}
		}

		// Set aggregated childTime on merged results
		cfloop( collection=childTimeByFile, key="local.canonicalIndex" ) {
			var mergedResult = arguments.mergedResults[canonicalIndex];
			mergedResult.setCallTreeMetrics({ totalChildTime: childTimeByFile[canonicalIndex] });

			// Also set in stats so HTML reporter can display it
			var stats = mergedResult.getStats();
			stats.totalChildTime = childTimeByFile[canonicalIndex];
			mergedResult.setStats(stats);
		}

		return arguments.mergedResults;
	}

	/**
	 * Build merged.json structure from already-merged results in memory
	 * This is much faster than reloading and re-merging all JSONs
	 * @mergedResults Struct of merged result objects keyed by canonical index
	 * @return Struct with mergedCoverage and files (same format as mergeResultsByFile)
	 */
	public struct function buildMergedJsonFromMergedResults(required struct mergedResults) localmode=true {
		var merged = {
			"files": structNew( "regular" ),
			"coverage": structNew( "regular" ),
			"blocks": structNew( "regular" )
		};

		cfloop( collection=arguments.mergedResults, key="local.canonicalIndex" ) {
			var mergedResult = arguments.mergedResults[canonicalIndex];
			var files = mergedResult.getFiles();
			var coverage = mergedResult.getCoverage();
			var blocks = mergedResult.getBlocks();

			// Each merged result has exactly one file (at index 0)
			var fileInfo = files[0];
			var filePath = fileInfo.path;

			// Copy file metadata
			merged.files[filePath] = fileInfo;

			// Copy coverage data (keyed by file path instead of index)
			if (structKeyExists(coverage, 0)) {
				merged.coverage[filePath] = coverage[0];
			}

			// Copy block data (keyed by file path instead of index)
			if (structKeyExists(blocks, 0)) {
				merged.blocks[filePath] = blocks[0];
			}
		}

		return {
			"mergedCoverage": merged,
			"files": merged.files
		};
	}

	/**
	 *  Merge coverage results by file path from multiple .exl parsing results
	 * Uses pre-computed file mappings to avoid redundant lookups
	 * @jsonFilePaths Array of JSON file paths to load and merge
	 * @logLevel Log level for verbose logging
	 * @return Struct with mergedCoverage and sorted files array
	 */
	public struct function mergeResultsByFile(required array jsonFilePaths, string logLevel="none") localmode=true {
		// Progressive loading - process one file at a time to minimize memory usage
		var resultFactory = new lucee.extension.lcov.model.result();
		var merged = { "files": structNew( "regular" ), "coverage": structNew( "regular" ), "blocks": structNew( "regular" ) };
		var fileMappings = structNew( "regular" );
		var isFirstFile = true;

		cfloop( array=arguments.jsonFilePaths, index="local.i", item="local.filePath" ) {
			variables.logger.trace( "mergeResultsByFile: Processing file " & i & " of " & arrayLen(arguments.jsonFilePaths) & ": " & filePath );

			if (!fileExists(filePath)) {
				throw(type="FileNotFound", message="mergeResultsByFile: JSON file not found: " & filePath);
			}
			// Load current result
			var jsonContent = fileRead(filePath);
			var currentResult = resultFactory.fromJson(jsonContent, false);

			// Initialize merged structure with files from the first file
			if (isFirstFile) {
				initializeMergedByFileStructure(merged, currentResult);
				isFirstFile = false;
			}

			// Merge current result into accumulated results
			mergeCurrentResultByFile(merged, currentResult, fileMappings);

			// Clear reference to current result to free memory
			currentResult = nullValue();
			jsonContent = nullValue();
		}

		//systemOutput("mergeResultsByFile: Coverage (#len(merged.coverage)#): " & serializeJSON(var=structKeyArray(merged.coverage)), true);
		//systemOutput("mergeResultsByFile: Files: (#len(merged.files)#)" & serializeJSON(var=structKeyArray(merged.files)), true);

		// Stats calculation moved to CoverageStats component
		return {
			"mergedCoverage": merged,
			"files": duplicate(merged.files)
		};
	}

	public struct function buildFileMappingsAndInitMerged(required struct results) localmode=true {
		var merged = { files: structNew( "regular" ), coverage: structNew( "regular" ) };
		var fileMappings = structNew( "regular" );
		cfloop( collection=arguments.results, key="local.src" ) {
			var files = arguments.results[src].getFiles();
			fileMappings[src] = structNew( "regular" );
			cfloop( collection=files, key="local.fKey" ) {
				if (!structKeyExists(merged.files, files[fKey].path)) {
					merged.files[files[fKey].path] = files[fKey];
				}
				// Note: executableLines merging removed - coverage now contains all executable lines
				fileMappings[src][fKey] = files[fKey].path;
			}
		}
		return { merged: merged, fileMappings: fileMappings };
	}


	public struct function createSourceFileStats(required struct indexToFilePath) localmode=true {
		var sourceFileStats = structNew( "regular" );
		cfloop( collection=indexToFilePath, key="local.canonicalIndex" ) {
			sourceFileStats[canonicalIndex] = {"exlFiles": [], "totalLines": 0};
		}
		return sourceFileStats;
	}

	/**
	 * @deprecated This function is no longer needed - CallTree metrics are aggregated during merge.
	 * Kept for backward compatibility only.
	 *
	 * Aggregate call tree metrics from source results into merged results
	 * This is needed when creating file-level results from request-level results
	 * @mergedResults Struct of merged result objects keyed by canonical index
	 * @sourceResults Struct of source result objects keyed by json path
	 * @return void (modifies mergedResults in place)
	 */
	public void function aggregateCallTreeMetricsForMergedResults(
		required struct mergedResults,
		required struct sourceResults
	) {
		// No-op - aggregation now happens in mergeAllCoverageDataFromResults()
		variables.logger.debug("aggregateCallTreeMetricsForMergedResults: Skipped (aggregation now done during merge)");
	}

	/**
	 * mergedFileIndex: The canonical file index for the merged result model. In the current design, this should always be 0,
	 * as all per-file data in the merged result is keyed by 0. This argument is retained for compatibility with previous logic
	 * and for possible future multi-file support, but all access and writes should use 0 as the file index.
	 */
	public numeric function mergeCoverageData(required struct targetResult, required struct sourceFileCoverage,
			required string sourceFilePath, numeric mergedFileIndex = 0) {
		var coverageData = arguments.targetResult.getCoverage();
		// Ensure coverageData is a struct, not an array
		if (!isStruct(coverageData)) coverageData = structNew( "regular" );
		var fileIndex = toString(arguments.mergedFileIndex);
		var targetCoverage = structKeyExists(coverageData, fileIndex) ? coverageData[fileIndex] : structNew( "regular" );
		var linesMerged = 0;
		if ( structIsEmpty( targetCoverage ) ) {
			coverageData[fileIndex] = duplicate( arguments.sourceFileCoverage );
			arguments.targetResult.setCoverage(coverageData);
			return structCount( arguments.sourceFileCoverage );
		}
		cfloop( collection=arguments.sourceFileCoverage, key="local.lineNumber" ) {
			var sourceLine = arguments.sourceFileCoverage[lineNumber];
			if ( !structKeyExists( targetCoverage, lineNumber ) ) {
				targetCoverage[ lineNumber ] = duplicate( sourceLine );
			} else {
				var targetLine = targetCoverage[ lineNumber ];
				// Fail-fast: ensure both arrays are the same length and valid
				if (!isArray(targetLine) || !isArray(sourceLine)) {
					throw("mergeCoverageData: Coverage line data is not an array at line " & lineNumber & ". targetLine=" & serializeJSON(targetLine) & ", sourceLine=" & serializeJSON(sourceLine), "CoverageDataError");
				}
				if (arrayLen(targetLine) != arrayLen(sourceLine)) {
					throw("mergeCoverageData: Coverage line array length mismatch at line " & lineNumber & ". targetLine=" & serializeJSON(targetLine) & ", sourceLine=" & serializeJSON(sourceLine), "CoverageDataError");
				}
				// NEW FORMAT: Sum all three values [hitCount, ownTime, childTime]
				targetLine[1] += sourceLine[1]; // hitCount
				targetLine[2] += sourceLine[2]; // ownTime
				targetLine[3] += sourceLine[3]; // childTime
			}
			linesMerged++;
		}
		coverageData[fileIndex] = targetCoverage;
		arguments.targetResult.setCoverage(coverageData);
		return linesMerged;
	}


	private struct function initializeMergedStructure(required any firstResult) localmode=true {
		var merged = structNew( "regular" );
		var files = arguments.firstResult.getFiles();

		// Create the first merged result based on the first file
		cfloop( collection=files, key="local.fileIndex" ) {
			if (!structKeyExists(merged, fileIndex)) {
				var resultCopy = duplicate(arguments.firstResult);
				resultCopy.setCoverage({});
				merged[fileIndex] = resultCopy;
			}
		}

		return merged;
	}

	private struct function buildFileIndexMappingsForResult(required any result) localmode=true {
		var mappings = structNew( "regular" );
		var files = arguments.result.getFiles();

		cfloop( collection=files, key="local.fileIndex" ) {
			var filePath = files[fileIndex].path;
			if (!structKeyExists(mappings, filePath)) {
				mappings[filePath] = fileIndex;
			}
		}

		return mappings;
	}

	private void function mergeCurrentResultProgressive(required struct mergedResults, required any currentResult, required struct fileMappings) localmode=true {
		var currentFiles = arguments.currentResult.getFiles();
		var currentCoverage = arguments.currentResult.getCoverage();

		// For each file in the current result
		cfloop( collection=currentFiles, key="local.fileIndex" ) {
			var filePath = currentFiles[fileIndex].path;

			// Find or assign target index for this file path
			var targetIndex = fileIndex;
			if (structKeyExists(arguments.fileMappings, filePath)) {
				targetIndex = arguments.fileMappings[filePath];
			} else {
				// First time seeing this file, use its current index as target
				arguments.fileMappings[filePath] = fileIndex;
				targetIndex = fileIndex;
			}

			if (structKeyExists(arguments.mergedResults, targetIndex)) {
				// Merge coverage data
				if (structKeyExists(currentCoverage, fileIndex)) {
					var targetResult = arguments.mergedResults[targetIndex];
					var sourceCoverage = currentCoverage[fileIndex];
					mergeCoverageData(targetResult, sourceCoverage, filePath, targetIndex);
				}
			} else {
				// First time seeing this file, create entry in merged results
				var resultCopy = duplicate(arguments.currentResult);
				resultCopy.setCoverage({});
				resultCopy.setIsFile(true); // Mark this as a file-level merged result
				arguments.mergedResults[targetIndex] = resultCopy;

				// Now merge the data
				if (structKeyExists(currentCoverage, fileIndex)) {
					var sourceCoverage = currentCoverage[fileIndex];
					mergeCoverageData(arguments.mergedResults[targetIndex], sourceCoverage, filePath, targetIndex);
				}
			}
		}
	}

	private void function initializeMergedByFileStructure(required struct merged, required any firstResult) localmode=true {
		var files = arguments.firstResult.getFiles();
		var coverage = arguments.firstResult.getCoverage();

		// Initialize merged structure based on first file - only include files that have coverage data
		cfloop( collection=files, key="local.fileIndex" ) {
			var filePath = files[fileIndex].path;
			// Only add file if it has coverage data
			if (structKeyExists(coverage, fileIndex)) {
				if (!structKeyExists(arguments.merged.files, filePath)) {
					arguments.merged.files[filePath] = files[fileIndex];
				}
			} else {
				// Skip files without coverage data (e.g., files that were tracked but never executed)
				variables.logger.debug( "initializeMergedByFileStructure: Skipping file index " & fileIndex & " (path: " & filePath & ") - no coverage data in first result" );
			}
		}
	}

	private void function mergeCurrentResultByFile(required struct merged, required any currentResult, required struct fileMappings) localmode=true {
		var currentFiles = arguments.currentResult.getFiles();
		var currentCoverage = arguments.currentResult.getCoverage();
		var currentBlocks = arguments.currentResult.getBlocks();

		//systemOutput("Coverage keys for current result: " & serializeJSON(var=structKeyArray(currentCoverage)), true);
		//systemOutput("Coverage Files for current result: " & serializeJSON(var=structKeyArray(currentFiles)), true);

		// Process each file in current result
		cfloop( collection=currentFiles, key="local.fileIndex" ) {
			var filePath = currentFiles[fileIndex].path;
			var hasCoverage = structKeyExists(currentCoverage, fileIndex);

			if (!hasCoverage) {
				// Skip files without coverage data (e.g., files that were tracked but never executed)
				variables.logger.debug( "mergeCurrentResultByFile: Skipping file index " & fileIndex & " (path: " & filePath & ") - no coverage data" );
				continue;
			}

			variables.logger.trace( "mergeCurrentResultByFile: Merging coverage for file [#fileIndex#]: " & filePath );

			// Merge file metadata
			if (!structKeyExists(arguments.merged.files, filePath)) {
				arguments.merged.files[filePath] = currentFiles[fileIndex];
			}
			// Note: executableLines merging removed - coverage now contains all executable lines

			// Merge coverage data
			if (!structKeyExists(arguments.merged.coverage, filePath)) {
				arguments.merged.coverage[filePath] = structNew( "regular" );
			}

			var sourceCoverage = currentCoverage[fileIndex];
			var targetCoverage = arguments.merged.coverage[filePath];

			// Merge line coverage
			cfloop( collection=sourceCoverage, key="local.lineNum" ) {
				if (!structKeyExists(targetCoverage, lineNum)) {
					targetCoverage[lineNum] = duplicate(sourceCoverage[lineNum]);
				} else {
					// Add hit counts, execution times, and child times together
					targetCoverage[lineNum][1] += sourceCoverage[lineNum][1];
					targetCoverage[lineNum][2] += sourceCoverage[lineNum][2];
					targetCoverage[lineNum][3] += sourceCoverage[lineNum][3]; // childTime
				}
			}

			// Merge block coverage
			var hasBlocks = structKeyExists(currentBlocks, fileIndex);
			if (hasBlocks) {
				if (!structKeyExists(arguments.merged.blocks, filePath)) {
					arguments.merged.blocks[filePath] = structNew( "regular" );
				}

				var sourceBlocks = currentBlocks[fileIndex];
				var targetBlocks = arguments.merged.blocks[filePath];

				// Merge each block
				cfloop( collection=sourceBlocks, key="local.blockKey" ) {
					var sourceBlock = sourceBlocks[blockKey];
					if (!structKeyExists(targetBlocks, blockKey)) {
						targetBlocks[blockKey] = duplicate(sourceBlock);
					} else {
						// Add hit counts and execution times together
						targetBlocks[blockKey].hitCount += sourceBlock.hitCount;
						targetBlocks[blockKey].execTime += sourceBlock.execTime;
						// isChild flag should be consistent across runs - keep first value
					}
				}
			}
		}
	}

}
