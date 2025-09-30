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

	// CoverageMergerUtils functions now called as static methods for better performance
	variables.debug = false;


	/**
	 * Merge execution results by source file and write them directly to JSON files
	 * When separateFiles: true, this combines coverage data from multiple .exl runs
	 * that executed the same source files, creating one JSON file per source file
	 * @results Struct of results keyed by .exl file path
	 * @outputDir Directory to write the file-*.json files to
	 * @verbose Boolean flag for verbose logging
	 * @return Array of written file paths
	 */
	public struct function mergeResults(required array jsonFilePaths, required string outputDir, boolean verbose=false) {
		// Progressive loading - process one file at a time to minimize memory usage
		var resultFactory = new lucee.extension.lcov.model.result();
		var mergedResults = {};
		var fileMappings = {};
		var isFirstFile = true;

		for (var i = 1; i <= arrayLen(arguments.jsonFilePaths); i++) {
			var filePath = arguments.jsonFilePaths[i];
			if (arguments.verbose) {
				systemOutput("Processing file " & i & " of " & arrayLen(arguments.jsonFilePaths) & ": " & filePath, true);
			}

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
				if (arguments.verbose) {
					systemOutput("Error processing " & filePath & ": " & e.message, true);
				}
				rethrow;
			}
		}


		// Recalculate and synchronize all per-file stats
		new CoverageStats().calculateStatsForMergedResults(mergedResults);
		if (variables.debug) {
			systemOutput("Merged Results: " & serializeJSON(var=mergedResults, compact=false), true);
		}
		return mergedResults;
	}

	/**
	 * Private: Merges all result structs into a single mergedResults struct
	 * @results Struct of results keyed by .exl file path
	 * @verbose Boolean flag for verbose logging
	 * @return mergedResults struct
	 */
	public struct function mergeResultStructs(required struct results, required boolean verbose) {
		var validResults = lucee.extension.lcov.CoverageMergerUtils::filterValidResults(arguments.results);
		var mappings = lucee.extension.lcov.CoverageMergerUtils::buildFileIndexMappings(validResults);
		if (variables.debug) {
			systemOutput("File Mappings: " & serializeJSON(var=mappings, compact=false), true);
			systemOutput("Source Results: " & serializeJSON(var=validResults, compact=false), true);
		}
		var mergedResults = lucee.extension.lcov.CoverageMergerUtils::initializeMergedResults(validResults, mappings.filePathToIndex, mappings.indexToFilePath);
		var sourceFileStats = createSourceFileStats(mappings.indexToFilePath);
		var totalMergeOperations = 0;
		mergedResults = mergeAllCoverageDataFromResults(validResults, mergedResults, mappings, sourceFileStats, totalMergeOperations);

		if (variables.debug) {
			systemOutput("Total merge operations: " & totalMergeOperations, true);
			systemOutput("Merged Results before calc Stats: " & serializeJSON(var=mergedResults, compact=false), true);
		}
		return mergedResults;
	}

	/**
	* Public: Merges all coverage data from validResults into mergedResults using mappings and sourceFileStats.
	* Extracted from mergeResultStructs for clarity and testability.
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
		// Track which exlPath/fileIndex was used to initialize each merged entry
		var initializedBy = {};
		for (var canonicalIndex in arguments.mergedResults) {
			var mergedEntry = arguments.mergedResults[canonicalIndex];
			var files = mergedEntry.getFiles();
			for (var fileIndex in files) {
				var filePath = files[fileIndex].path;
				// Find the result and fileIndex that was used to initialize this merged entry
				for (var exlPath in arguments.validResults) {
					var result = arguments.validResults[exlPath];
					var resultFiles = result.getFiles();
					if (structKeyExists(resultFiles, fileIndex) && resultFiles[fileIndex].path == filePath) {
						initializedBy[canonicalIndex] = { exlPath: exlPath, fileIndex: fileIndex };
						break;
					}
				}
			}
		}

		for (var exlPath in arguments.validResults) {
			var result = arguments.validResults[exlPath];
			var exlFileName = listLast(exlPath, "/\\");
			var coverageData = result.getCoverage();
			for (var fileIndex in coverageData) {
				var sourceFilePath = result.getFileItem(fileIndex).path;
				var canonicalIndex = arguments.mappings.filePathToIndex[sourceFilePath];
				var sourceFileCoverage = coverageData[fileIndex];
				// Only merge if this exlPath/fileIndex was NOT used to initialize the merged entry
				if (!(structKeyExists(initializedBy, canonicalIndex) && initializedBy[canonicalIndex].exlPath == exlPath
						&& initializedBy[canonicalIndex].fileIndex == fileIndex)) {
					var mergedLines = mergeCoverageData(arguments.mergedResults[canonicalIndex], sourceFileCoverage, sourceFilePath, 0);
					arguments.totalMergeOperations += mergedLines;
				}
				// NOTE: Eliminated mergeFileCoverageArray call - no longer needed since we use processed coverage data
				arrayAppend(arguments.sourceFileStats[canonicalIndex].exlFiles, exlFileName);
			}
		}
		return arguments.mergedResults;
	}

	/**
	 *  Merge coverage results by file path from multiple .exl parsing results
	 * Uses pre-computed file mappings to avoid redundant lookups
	 * @jsonFilePaths Array of JSON file paths to load and merge
	 * @verbose Whether to output verbose logging (default false)
	 * @return Struct with mergedCoverage and sorted files array
	 */
	public struct function mergeResultsByFile(required array jsonFilePaths, boolean verbose=false) {
		// Progressive loading - process one file at a time to minimize memory usage
		var resultFactory = new lucee.extension.lcov.model.result();
		var merged = { "files": {}, "coverage": {} };
		var fileMappings = {};
		var isFirstFile = true;

		for (var i = 1; i <= arrayLen(arguments.jsonFilePaths); i++) {
			var filePath = arguments.jsonFilePaths[i];
			if (arguments.verbose) {
				systemOutput("mergeResultsByFile: Processing file " & i & " of " & arrayLen(arguments.jsonFilePaths) & ": " & filePath, true);
			}

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

	public struct function buildFileMappingsAndInitMerged(required struct results) {
		var merged = { files: {}, coverage: {} };
		var fileMappings = {};
		for (var src in arguments.results) {
			var files = arguments.results[src].getFiles();
			fileMappings[src] = {};
			for (var fKey in files) {
				if (!structKeyExists(merged.files, files[fKey].path)) {
					merged.files[files[fKey].path] = files[fKey];
				}
				// Note: executableLines merging removed - coverage now contains all executable lines
				fileMappings[src][fKey] = files[fKey].path;
			}
		}
		return { merged: merged, fileMappings: fileMappings };
	}

	public void function mergeCoverageLines(required struct merged, required struct fileMappings, required struct results) {
		var totalCoverageLines = 0;
		for (var src in arguments.results) {
			var coverage = arguments.results[src].getCoverage();
			var mapping = arguments.fileMappings[src];
			for (var fKey in coverage) {
				var realFile = mapping[fKey];
				if (!structKeyExists(arguments.merged.coverage, realFile)) {
					arguments.merged.coverage[realFile] = {};
				}
				var sourceLines = structKeyArray(coverage[fKey]);
				var maxLine = 0;
				if (structKeyExists(arguments.merged.files, realFile) && structKeyExists(arguments.merged.files[realFile], "linesSource")) {
					maxLine = arguments.merged.files[realFile].linesSource;
				}
				for (var l in coverage[fKey]) {
					if (maxLine > 0 && (l < 1 || l > maxLine)) {
						throw(
							"mergeCoverageLines: Invalid coverage data: line " & l & " is out of range for file " & realFile & " (max line: " & maxLine & ") in mergeResultsByFile. All lines: " & serializeJSON(sourceLines),
							"CoverageDataError"
						);
					}
					if (!structKeyExists(arguments.merged.coverage[realFile], l)) {
						arguments.merged.coverage[realFile][l] = [0, 0];
					}
					var lineData = arguments.merged.coverage[realFile][l];
					var srcLineData = coverage[fKey][l];
					lineData[1] += srcLineData[1];
					lineData[2] += srcLineData[2];
					totalCoverageLines++;
				}
			}
		}
		if(variables.debug) {
			systemOutput("Merged " & totalCoverageLines & " coverage lines. merged: " & serializeJSON(arguments.merged), true);
		}
	}


	public struct function createSourceFileStats(required struct indexToFilePath) {
		var sourceFileStats = {};
		for (var canonicalIndex in indexToFilePath) {
			sourceFileStats[canonicalIndex] = {"exlFiles": [], "totalLines": 0};
		}
		return sourceFileStats;
	}

	/**
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
		for (var canonicalIndex in arguments.mergedResults) {
			var mergedResult = arguments.mergedResults[canonicalIndex];
			var filePath = mergedResult.getFileItem(0).path;
			var totalChildTime = 0;

			// Sum up call tree metrics from source results that contain this file
			for (var sourcePath in arguments.sourceResults) {
				var sourceResult = arguments.sourceResults[sourcePath];
				var resultFiles = sourceResult.getFiles();

				// Check if this result contains the file we're merging
				var containsFile = false;
				var targetFileIdx = "";
				for (var fileIdx in resultFiles) {
					if (resultFiles[fileIdx].path == filePath) {
						containsFile = true;
						targetFileIdx = fileIdx;
						break;
					}
				}

				if (containsFile) {
					var callTree = sourceResult.getCallTree();
					// Sum up child times for blocks in this file
					for (var blockKey in callTree) {
						var block = callTree[blockKey];
						// Check if this block belongs to the file we're processing
						if (block.fileIdx == targetFileIdx && block.isChildTime) {
							totalChildTime += block.executionTime;
						}
					}
				}
			}

			// Set aggregated metrics on the merged result
			var mergedMetrics = {
				totalChildTime: totalChildTime
			};
			mergedResult.setCallTreeMetrics(mergedMetrics);
		}
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
		if (!isStruct(coverageData)) coverageData = {};
		var fileIndex = toString(arguments.mergedFileIndex);
		var targetCoverage = structKeyExists(coverageData, fileIndex) ? coverageData[fileIndex] : {};
		var linesMerged = 0;
		if ( structIsEmpty( targetCoverage ) ) {
			coverageData[fileIndex] = duplicate( arguments.sourceFileCoverage );
			arguments.targetResult.setCoverage(coverageData);
			return structCount( arguments.sourceFileCoverage );
		}
		for (var lineNumber in arguments.sourceFileCoverage) {
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
				for (var key=1; key <= arrayLen(sourceLine); key++) {
					if (key > arrayLen(targetLine)) {
						throw("mergeCoverageData: Array index [" & key & "] out of range for targetLine (size=" & arrayLen(targetLine) & ") at line " & lineNumber & ". targetLine=" & serializeJSON(targetLine) & ", sourceLine=" & serializeJSON(sourceLine), "CoverageDataError");
					}
					targetLine[ key ] += sourceLine[ key ];
				}
			}
			linesMerged++;
		}
		coverageData[fileIndex] = targetCoverage;
		arguments.targetResult.setCoverage(coverageData);
		return linesMerged;
	}

	/**
	 * DEPRECATED: No longer used - replaced by processing structured coverage data directly.
	 * This function was causing performance bottlenecks due to arrayAppend() operations on large datasets.
	 *
	 * Remap fileCoverage array lines to canonical file path for downstream consumers.
	 * Only lines matching the canonical fileIndex (always 0 internally) are allowed.
	 * Fails fast if any line has an unexpected fileIndex value.
	 */
	public void function mergeFileCoverageArray(required result targetResult, required result sourceResult,
			required string fileIndex, numeric mergedFileIndex = 0, string sourceFilePath = "") {
		if (!isArray(sourceResult.getFileCoverage())) {
			return;
		}

		var sourceArray = sourceResult.getFileCoverage();
		var tempArray = [];

		// Build temporary array with optimized string replacement (much faster than listToArray/arrayToList)
		for (var i = 1; i <= arrayLen(sourceArray); i++) {
			var coverageLine = sourceArray[i];
			var tabPos = find(chr(9), coverageLine);
			if (tabPos == 0) {
				throw(
					"mergeFileCoverageArray: Malformed fileCoverage line: [" & coverageLine & "]. " &
					"Expected format: <fileIndex>\\t<startLine>\\t<endLine>\\t<hitCount> (4 tab-separated columns). " &
					"No tab separator found.",
					"CoverageDataError"
				);
			}
			// Replace first column (fileIndex) with "0" using fast string operations
			arrayAppend(tempArray, "0" & mid(coverageLine, tabPos, len(coverageLine)));
		}

		// Single bulk append operation - much faster than individual appends
		var targetArray = targetResult.getFileCoverage();
		arrayAppend(targetArray, tempArray, true);
		targetResult.setFileCoverage(targetArray);
	}

	private struct function initializeMergedStructure(required any firstResult) {
		var merged = {};
		var files = arguments.firstResult.getFiles();

		// Create the first merged result based on the first file
		for (var fileIndex in files) {
			if (!structKeyExists(merged, fileIndex)) {
				var resultCopy = duplicate(arguments.firstResult);
				resultCopy.setCoverage({});
				resultCopy.setFileCoverage([]);
				merged[fileIndex] = resultCopy;
			}
		}

		return merged;
	}

	private struct function buildFileIndexMappingsForResult(required any result) {
		var mappings = {};
		var files = arguments.result.getFiles();

		for (var fileIndex in files) {
			var filePath = files[fileIndex].path;
			if (!structKeyExists(mappings, filePath)) {
				mappings[filePath] = fileIndex;
			}
		}

		return mappings;
	}

	private void function mergeCurrentResultProgressive(required struct mergedResults, required any currentResult, required struct fileMappings) {
		var currentFiles = arguments.currentResult.getFiles();
		var currentCoverage = arguments.currentResult.getCoverage();

		// For each file in the current result
		for (var fileIndex in currentFiles) {
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

				// Merge fileCoverage array
				var targetResult = arguments.mergedResults[targetIndex];
				mergeFileCoverageArray(targetResult, arguments.currentResult, fileIndex, targetIndex, filePath);
			} else {
				// First time seeing this file, create entry in merged results
				var resultCopy = duplicate(arguments.currentResult);
				resultCopy.setCoverage({});
				resultCopy.setFileCoverage([]);
				resultCopy.setIsFile(true); // Mark this as a file-level merged result
				arguments.mergedResults[targetIndex] = resultCopy;

				// Now merge the data
				if (structKeyExists(currentCoverage, fileIndex)) {
					var sourceCoverage = currentCoverage[fileIndex];
					mergeCoverageData(arguments.mergedResults[targetIndex], sourceCoverage, filePath, targetIndex);
				}
				mergeFileCoverageArray(arguments.mergedResults[targetIndex], arguments.currentResult, fileIndex, targetIndex, filePath);
			}
		}
	}

	private void function initializeMergedByFileStructure(required struct merged, required any firstResult) {
		var files = arguments.firstResult.getFiles();
		var coverage = arguments.firstResult.getCoverage();

		// Initialize merged structure based on first file - only include files that have coverage data
		for (var fileIndex in files) {
			var filePath = files[fileIndex].path;
			// Only add file if it has coverage data
			if (structKeyExists(coverage, fileIndex)) {
				if (!structKeyExists(arguments.merged.files, filePath)) {
					arguments.merged.files[filePath] = files[fileIndex];
				}
			} else {
				// Skip files without coverage data (e.g., files that were tracked but never executed)
				if (variables.debug) {
					systemOutput("initializeMergedByFileStructure: Skipping file index " & fileIndex & " (path: " & filePath & ") - no coverage data in first result", true);
				}
			}
		}
	}

	private void function mergeCurrentResultByFile(required struct merged, required any currentResult, required struct fileMappings) {
		var currentFiles = arguments.currentResult.getFiles();
		var currentCoverage = arguments.currentResult.getCoverage();

		//systemOutput("Coverage keys for current result: " & serializeJSON(var=structKeyArray(currentCoverage)), true);
		//systemOutput("Coverage Files for current result: " & serializeJSON(var=structKeyArray(currentFiles)), true);

		// Process each file in current result
		for (var fileIndex in currentFiles) {
			var filePath = currentFiles[fileIndex].path;
			var hasCoverage = structKeyExists(currentCoverage, fileIndex);

			if (!hasCoverage) {
				// Skip files without coverage data (e.g., files that were tracked but never executed)
				if (variables.debug) {
					systemOutput("mergeCurrentResultByFile: Skipping file index " & fileIndex & " (path: " & filePath & ") - no coverage data", true);
				}
				continue;
			}

			if (variables.debug) {
				systemOutput("mergeCurrentResultByFile: Merging coverage for file [#fileIndex#]: " & filePath, true);
			}

			// Merge file metadata
			if (!structKeyExists(arguments.merged.files, filePath)) {
				arguments.merged.files[filePath] = currentFiles[fileIndex];
			}
			// Note: executableLines merging removed - coverage now contains all executable lines

			// Merge coverage data
			if (!structKeyExists(arguments.merged.coverage, filePath)) {
				arguments.merged.coverage[filePath] = {};
			}

			var sourceCoverage = currentCoverage[fileIndex];
			var targetCoverage = arguments.merged.coverage[filePath];

			// Merge line coverage
			for (var lineNum in sourceCoverage) {
				if (!structKeyExists(targetCoverage, lineNum)) {
					targetCoverage[lineNum] = sourceCoverage[lineNum];
				} else {
					// Add hit counts together
					targetCoverage[lineNum][2] += sourceCoverage[lineNum][2];
				}
			}
		}
	}

}
