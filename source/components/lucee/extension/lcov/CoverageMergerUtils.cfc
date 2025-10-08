/**
 * CoverageMergerUtils.cfc
 *
 * Contains private utility functions for CoverageMerger.cfc, extracted for clarity and testability.
 * All functions are private and intended for internal use only.
 */
component accessors=false {

	/**
	 * Filter out results that have no coverage data
	 * @results Struct of results keyed by .exl file path
	 * @return Struct of valid results with coverage data
	 */
	public static struct function filterValidResults(required struct results) {
		var validResults = {};
		for (var exlPath in arguments.results) {
			var result = arguments.results[exlPath];
			var coverageData = result.getCoverage();
			if (!isStruct(coverageData) || structIsEmpty(coverageData)) {
				continue;
			}
			validResults[exlPath] = result;
		}
		return validResults;
	}

	/**
	 * Build mappings from source file paths to canonical indices and vice versa
	 * @validResults Struct of valid results with coverage data
	 * @return Struct with filePathToIndex and indexToFilePath mappings
	 */
	public static struct function buildFileIndexMappings(required struct validResults) {
		var filePathToIndex = {};
		var indexToFilePath = {};
		var nextIndex = 0;
		for (var exlPath in arguments.validResults) {
			var result = arguments.validResults[exlPath];
			var files = result.getFiles();
			for (var fileIndex in files) {
				var sourceFilePath = result.getFileItem(fileIndex).path;
				if (!len(sourceFilePath)) {
					throw(message="BUG: Encountered fileIndex with empty or missing path during buildFileIndexMappings. exlPath=" & exlPath & ", fileIndex=" & fileIndex & ", result=" & serializeJSON(result));
				}
				if (!structKeyExists(filePathToIndex, sourceFilePath)) {
					filePathToIndex[sourceFilePath] = nextIndex;
					indexToFilePath[nextIndex] = sourceFilePath;
					nextIndex++;
				}
			}
		}
		return { filePathToIndex: filePathToIndex, indexToFilePath: indexToFilePath };
	}

	/**
	 * Initialize a source file entry in the merged results
	 * @sourceFilePath The real path of the source file
	 * @result The result object containing coverage data
	 * @fileIndex The file index in the result object
	 * @canonicalIndex The canonical index to use in merged results
	 * @return A new source file entry struct
	 */
	public static struct function initializeMergedResults(required struct validResults,
			required struct filePathToIndex, required struct indexToFilePath) {
		var mergedResults = {};
		for (var canonicalIndex in indexToFilePath) {
			var sourceFilePath = indexToFilePath[canonicalIndex];
			var found = false;
			for (var exlPath in validResults) {
				var result = validResults[exlPath];
				var files = result.getFiles();
				for (var fileIndex in files) {
					if (files[fileIndex].path == sourceFilePath) {
						mergedResults[canonicalIndex] = lucee.extension.lcov.CoverageMergerUtils::initializeSourceFileEntry(sourceFilePath, result, fileIndex, canonicalIndex);
						found = true;
						break;
					}
				}
				if (found) break;
			}
		}
		return mergedResults;
	}

	/**
	 * Creates and returns a new result model object representing a single source file's merged coverage data, keyed by a canonical (merged) file index.
	 *
	 * - Fails fast if the provided fileIndex does not map to a real file with a valid path.
	 * - Instantiates a new result model and initializes its stats and metadata.
	 * - Remaps and sets the source file data (source.files) to be keyed by the canonical merged file index, ensuring the path property is always the canonical file path.
	 * - Sets the coverage data for the file, keyed by the canonical index.
	 * - Sets the file stats struct (linesFound, linesSource, linesHit, path) for the file, also keyed by the canonical index.
	 * - Remaps and sets the fileCoverage array if present, ensuring all file path references are canonical.
	 * - Validates the result model before returning it.
	 *
	 * This ensures all per-file data in the merged results is consistently keyed by the canonical, consecutive numeric fileIndex, with all paths and stats normalized for downstream consumers and reporting.
	 */
	public static result function initializeSourceFileEntry(required string sourceFilePath, required result sourceResult,
			required string fileIndex, numeric mergedFileIndex = 0, boolean separateFiles = true) {
		if (!len(arguments.sourceFilePath)) {
			throw(message="BUG: initializeSourceFileEntry called with empty sourceFilePath. fileIndex=" & arguments.fileIndex & ", sourceResult=" & serializeJSON(arguments.sourceResult));
		}
		var path = arguments.sourceResult.getFileItem(arguments.fileIndex).path;
		var filesData = arguments.sourceResult.getFiles();
		var entry = new lucee.extension.lcov.model.result();
		entry.setIsFile(true); // Mark this as a file-level result
		entry.initStats();
		var metadataData = arguments.sourceResult.getMetadata();
		var fileUtils = new lucee.extension.lcov.reporter.FileUtils();
		entry.setMetadata("metadata": {
			"script-name": fileUtils.safeContractPath(arguments.sourceFilePath),
			"execution-time": structKeyExists(metadataData, "execution-time") ? metadataData["execution-time"] : "0",
			"unit": metadataData.unit ?: "μs"
		});
		entry.setExelog(arguments.sourceFilePath);
		var files = entry.getFiles();
		// Always use index 0 for separated files - each file gets its own result model
		var idx = 0;
		var filesStruct = {};
		if (structKeyExists(filesData, arguments.fileIndex)) {
			var fileStruct = duplicate(filesData[arguments.fileIndex]);
			fileStruct.path = arguments.sourceFilePath;
			filesStruct[idx] = fileStruct;
		} else {
			filesStruct[idx] = { path = arguments.sourceFilePath };
		}
		entry.setFiles(filesStruct);
		var coverageData = {};
		var sourceCoverage = arguments.sourceResult.getCoverage();
		if (structKeyExists(sourceCoverage, arguments.fileIndex)) {
			coverageData[idx] = duplicate(sourceCoverage[arguments.fileIndex]);
		} else {
			coverageData[idx] = {};
		}
		entry.setCoverage(coverageData);
		// Always build fileItem as a duplicate of the canonical file struct, then add/override computed fields
		var fileItem = structKeyExists(filesStruct, idx) ? duplicate(filesStruct[idx]) : { path = arguments.sourceFilePath };
		// Always preserve linesSource and any other present fields from the input file struct
		// Recalculate linesFound and linesHit from coverage, but do not remove linesSource
		var mergedCoverage = entry.getCoverage();
		var foundLines = [];
		var hitLines = [];
		if (structKeyExists(mergedCoverage, idx) && !structIsEmpty(mergedCoverage[idx])) {
			var coverageStruct = mergedCoverage[idx];
			for (var lineNum in coverageStruct) {
				if (isNumeric(lineNum) && lineNum >= 1) {
					arrayAppend(foundLines, lineNum);
					var hitCount = 0;
					var arr = coverageStruct[lineNum];
					if (isArray(arr) && arrayLen(arr) >= 2) {
						hitCount = arr[2];
					}
					if (hitCount > 0) {
						arrayAppend(hitLines, lineNum);
					}
				}
			}
			fileItem["linesFound"] = arrayLen(foundLines);
			fileItem["linesHit"] = arrayLen(hitLines);
		} else {
			// No coverage: preserve linesFound and linesHit from input file struct if present, else default to 0
			if (!structKeyExists(fileItem, "linesFound")) fileItem["linesFound"] = 0;
			if (!structKeyExists(fileItem, "linesHit")) fileItem["linesHit"] = 0;
		}
		entry.setFileItem(idx, fileItem);

		// Calculate stats from coverage to match validation requirements
		var totalExecutions = 0;
		var totalExecutionTime = 0;
		if (structKeyExists(mergedCoverage, idx)) {
			var coverageStruct = mergedCoverage[idx];
			for (var lineNum in coverageStruct) {
				var lineData = coverageStruct[lineNum];
				if (isArray(lineData) && arrayLen(lineData) >= 2) {
					totalExecutions += lineData[1];  // Hit count is at index 1
					totalExecutionTime += lineData[2];  // Execution time is at index 2
				}
			}
		}

		// Update stats to match the coverage data
		var stats = entry.getStats();
		stats.totalExecutions = totalExecutions;
		stats.totalExecutionTime = totalExecutionTime;
		stats.totalLinesFound = fileItem["linesFound"];
		stats.totalLinesHit = fileItem["linesHit"];
		stats.totalLinesSource = fileItem["linesSource"] ?: 0;
		entry.setStats(stats);

		entry.validate();
		return entry;
	}

}