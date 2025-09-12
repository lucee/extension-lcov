component {
	/**
	 *  Merge coverage results by file path from multiple .exl parsing results
	 * Uses pre-computed file mappings to avoid redundant lookups
	 * @results Struct of parsed results from multiple .exl files
	 * @return Struct with mergedCoverage and sorted files array
	 */
	public struct function mergeResultsByFile(required struct results) {
		var startTime = getTickCount();

		var merged = {
			files: {},
			coverage: {}
		};

		// OPTIMIZATION: Pre-build all file mappings to avoid repeated lookups
		var fileMappings = {};
		var totalSourceFiles = 0;

		for (var src in arguments.results) {
			var files = arguments.results[src].source.files;
			fileMappings[src] = {};

			for (var f in files) {
				if (!structKeyExists(merged.files, files[f].path)) {
					merged.files[files[f].path] = files[f];
					totalSourceFiles++;
				}
				fileMappings[src][f] = files[f].path;
			}
		}

		// OPTIMIZATION: Process coverage with pre-computed mappings
		var totalCoverageLines = 0;
		for (var src in arguments.results) {
			var coverage = arguments.results[src].coverage;
			var mapping = fileMappings[src];

			for (var f in coverage) {
				var realFile = mapping[f];
				if (!structKeyExists(merged.coverage, realFile)) {
					merged.coverage[realFile] = {};
				}

				// OPTIMIZATION: Process line coverage in batch
				var sourceLines = structKeyArray(coverage[f]);
				// Get the max line for this file if available
				var maxLine = 0;
				if (structKeyExists(merged.files, realFile) && structKeyExists(merged.files[realFile], "lineCount")) {
					maxLine = merged.files[realFile].lineCount;
				}
				for (var i = 1; i <= arrayLen(sourceLines); i++) {
					var l = sourceLines[i];
					if (maxLine > 0 && (l < 1 || l > maxLine)) {
						throw(
							"Invalid coverage data: line " & l & " is out of range for file " & realFile & " (max line: " & maxLine & ") in mergeResultsByFile. All lines: " & serializeJSON(sourceLines),
							"CoverageDataError"
						);
					}
					if (!structKeyExists(merged.coverage[realFile], l)) {
						merged.coverage[realFile][l] = [0, 0];
					}
					var lineData = merged.coverage[realFile][l];
					var srcLineData = coverage[f][l];
					lineData[1] += srcLineData[1];
					lineData[2] += srcLineData[2];
					totalCoverageLines++;
				}
			}
		}

		var files = structKeyArray(merged.files);
		arraySort(files, "textnocase");

		return {
			"mergedCoverage": merged,
			"files": files
		};
	}

	/**
	 * Merge execution results by source file instead of by execution run
	 * When separateFiles: true, this combines coverage data from multiple .exl runs
	 * that executed the same source files, creating one result per source file
	 * @results Struct of results keyed by .exl file path
	 * @verbose Boolean flag for verbose logging
	 * @return Struct of merged results keyed by source file path
	 */
	public struct function mergeResultsBySourceFile(required struct results, boolean verbose = false) {
		var mergeStart = getTickCount();
		var mergedResults = {};
		var sourceFileStats = {};
		var totalFilesProcessed = 0;
		var totalSourceFilesFound = 0;
		var validResults = {};
		for (var exlPath in arguments.results) {
			var result = arguments.results[exlPath];
			if (!structKeyExists(result, "coverage") || structIsEmpty(result.coverage)) {
				continue;
			}
			validResults[exlPath] = result;
			totalFilesProcessed++;
		}
		for (var exlPath in validResults) {
			var result = validResults[exlPath];
			for (var fileIndex in result.coverage) {
				var sourceFilePath = resolveSourceFilePath(result, fileIndex);
				if (!structKeyExists(mergedResults, sourceFilePath)) {
					mergedResults[sourceFilePath] = initializeSourceFileEntry(sourceFilePath, result, fileIndex);
					totalSourceFilesFound++;
				}
				if (!structKeyExists(sourceFileStats, sourceFilePath)) {
					sourceFileStats[sourceFilePath] = {"exlFiles": [], "totalLines": 0};
				}
				arrayAppend(sourceFileStats[sourceFilePath].exlFiles, listLast(exlPath, "/\\"));
			}
		}
		var totalMergeOperations = 0;
		for (var exlPath in validResults) {
			var result = validResults[exlPath];
			var exlFileName = listLast(exlPath, "/\\");
			for (var fileIndex in result.coverage) {
				var sourceFilePath = resolveSourceFilePath(result, fileIndex);
				var sourceFileCoverage = result.coverage[fileIndex];
				var mergedLines = mergeCoverageData(mergedResults[sourceFilePath], sourceFileCoverage, sourceFilePath);
				totalMergeOperations += mergedLines;
				mergeFileCoverageArray(mergedResults[sourceFilePath], result, fileIndex);
			}
		}
		for (var sourceFilePath in mergedResults) {
			var startTime = getTickCount();
			mergedResults[sourceFilePath].stats = new lucee.extension.lcov.CoverageStats().calculateCoverageStats(mergedResults[sourceFilePath]);
			var calcTime = getTickCount() - startTime;
			if (structKeyExists(mergedResults[sourceFilePath].stats, "totalExecutionTime")) {
				mergedResults[sourceFilePath].metadata["execution-time"] = mergedResults[sourceFilePath].stats.totalExecutionTime;
			}
		}
		return mergedResults;
	}

	private string function resolveSourceFilePath(required struct result, required string fileIndex) {
		if (structKeyExists(arguments.result, "source") && 
			structKeyExists(arguments.result.source, "files") && 
			structKeyExists(arguments.result.source.files, arguments.fileIndex)) {
			return arguments.result.source.files[arguments.fileIndex].path ?: arguments.fileIndex;
		}
		return arguments.fileIndex;
	}

	private struct function initializeSourceFileEntry(required string sourceFilePath, required struct sourceResult, required string fileIndex) {
		var entry = {
			"exeLog": arguments.sourceFilePath,
			"metadata": {
				"script-name": contractPath(arguments.sourceFilePath),
				"execution-time": "0",
				"unit": arguments.sourceResult.metadata.unit ?: "μs"
			},
			"files": {},
			"fileCoverage": [],
			"coverage": {},
			"source": { "files": {} },
			"stats": {
				"totalLinesFound": 0,
				"totalLinesHit": 0,
				"totalExecutions": 0,
				"totalExecutionTime": 0
			}
		};
		entry.coverage[arguments.sourceFilePath] = {};
		if (structKeyExists(arguments.sourceResult, "source") && 
			structKeyExists(arguments.sourceResult.source, "files") && 
			structKeyExists(arguments.sourceResult.source.files, arguments.fileIndex)) {
			entry.source.files[arguments.sourceFilePath] = arguments.sourceResult.source.files[arguments.fileIndex];
		}
		if (structKeyExists(arguments.sourceResult, "files") && 
			structKeyExists(arguments.sourceResult.files, arguments.fileIndex)) {
			entry.files[arguments.sourceFilePath] = arguments.sourceResult.files[arguments.fileIndex];
		}
		return entry;
	}

	private numeric function mergeCoverageData(required struct targetResult, required struct sourceFileCoverage, required string sourceFilePath) {
		var targetCoverage = arguments.targetResult.coverage[arguments.sourceFilePath];
		var linesMerged = 0;
		if ( structIsEmpty( targetCoverage ) ) {
			arguments.targetResult.coverage[ arguments.sourceFilePath ]  
				= duplicate( arguments.sourceFileCoverage );
			return structCount( arguments.sourceFileCoverage );
		}
		for (var lineNumber in arguments.sourceFileCoverage) {
			var sourceLine = arguments.sourceFileCoverage[lineNumber];
			if ( !structKeyExists( targetCoverage, lineNumber ) ) {
				targetCoverage[ lineNumber ] = duplicate( sourceLine );
			} else {
				var targetLine = targetCoverage[ lineNumber ];
				for (var key in sourceLine) {
					targetLine[ key ] += sourceLine[ key ];
				}
			}
			linesMerged++;
		}
		return linesMerged;
	}

	private void function mergeFileCoverageArray(required struct targetResult, required struct sourceResult, required string fileIndex) {
		if (!structKeyExists(arguments.sourceResult, "fileCoverage") || !isArray(arguments.sourceResult.fileCoverage)) {
			return;
		}
		for (var coverageLine in arguments.sourceResult.fileCoverage) {
			var parts = listToArray(coverageLine, chr(9), false, false);
			if (arrayLen(parts) >= 2 && parts[1] == arguments.fileIndex) {
				arrayAppend(arguments.targetResult.fileCoverage, coverageLine);
			}
		}
	}
}
