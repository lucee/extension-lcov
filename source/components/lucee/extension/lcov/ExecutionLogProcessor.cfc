/**
 * Component responsible for processing execution log (.exl) files
 */
component {

	/**
	 * Initialize the execution log processor with options
	 * @options Configuration options struct (optional)
	 */
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
		variables.codeCoverageUtils = new codeCoverageUtils(arguments.options);
		variables.useOptimized = true;
		return this;
	}

	/**
	 * Private logging function that respects verbose setting
	 * @message The message to log
	 */
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	 * Parse execution logs from a directory and return processed results
	 * @executionLogDir Directory containing .exl files
	 * @options Processing options including allowList and blocklist
	 * @return Struct of parsed results keyed by .exl file path
	 */

	public struct function parseExecutionLogs(required string executionLogDir, struct options = {}) {
		// add an exclusive cflock here
		cflock(name="lcov-parse:#arguments.executionLogDir#", timeout=0, type="exclusive", throwOnTimeout=true) {
			return _parseExecutionLogs(arguments.executionLogDir, arguments.options);
		}
	}

	private struct function _parseExecutionLogs(required string executionLogDir, struct options = {}) {
		if (!directoryExists(arguments.executionLogDir)) {
			throw(message="Execution log directory does not exist: " & arguments.executionLogDir);
		}

		logger("Processing execution logs from: " & arguments.executionLogDir);

		if (useOptimized) {
			// Create parser with options for verbose logging
			var exlParser = new ExecutionLogParserOptimized(arguments.options);
		} else {
			var exlParser = new ExecutionLogParser(arguments.options);
		}

		var files = directoryList(arguments.executionLogDir, false, "query", "*.exl", "datecreated");
		var results = {};

		logger("Found " & files.recordCount & " .exl files to process");

		for (var file in files) {
			var exlPath = file.directory & "/" & file.name;
			try {
				var info = getFileInfo( exlPath );
				logger("Processing .exl file: " & exlPath 
					& " (" & decimalFormat( info.size/1024 ) & " Kb)");
				var result = exlParser.parseExlFile(
					exlPath, 
					false, // generateHtml
					arguments.options.allowList ?: [], 
					arguments.options.blocklist ?: []
				);
				if (len(result)) {
					result["stats"] = variables.codeCoverageUtils.calculateCoverageStats(result);
					results[exlPath] = result;
					logger("Successfully processed: " & exlPath);
				} else {
					logger("Skipped empty result for: " & exlPath);
				}
			} catch (any e) {
				logger("Warning: Failed to parse " & exlPath & " - " & e.message);
				// Continue processing other files
			}
		}

		logger("Completed processing " & structCount(results) & " valid .exl files");
		return results;
	}

	/**
	 * Validate that an execution log directory exists and contains .exl files
	 * @executionLogDir Directory to validate
	 * @return Boolean indicating if directory is valid
	 */
	public boolean function validateExecutionLogDirectory(required string executionLogDir) {
		if (!directoryExists(arguments.executionLogDir)) {
			return false;
		}

		var files = directoryList(arguments.executionLogDir, false, "query", "*.exl");
		return files.recordCount > 0;
	}

	/**
	 * Get summary information about an execution log directory
	 * @executionLogDir Directory to analyze
	 * @return Struct with directory summary info
	 */
	public struct function getExecutionLogDirectoryInfo(required string executionLogDir) {
		var info = {
			"exists": directoryExists(arguments.executionLogDir),
			"exlFileCount": 0,
			"totalSizeBytes": 0,
			"files": []
		};

		if (info.exists) {
			var files = directoryList(arguments.executionLogDir, false, "query", "*.exl", "datecreated");
			info.exlFileCount = files.recordCount;
			
			for (var file in files) {
				var fileInfo = {
					"name": file.name,
					"size": file.size,
					"dateModified": file.dateLastModified
				};
				info.files.append(fileInfo);
				info.totalSizeBytes += file.size;
			}
		}

		return info;
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
		//logger("=== MERGE BY SOURCE FILE: Starting merge process ===");
		//logger("Processing " & structCount(arguments.results) & " .exl results");
		
		var mergedResults = {};
		var sourceFileStats = {};
		var totalFilesProcessed = 0;
		var totalSourceFilesFound = 0;
		
		// PASS 1: Discovery and Validation
		//logger("--- PASS 1: Discovery and Validation ---");
		var validResults = {};
		for (var exlPath in arguments.results) {
			var result = arguments.results[exlPath];
			
			if (!structKeyExists(result, "coverage") || structIsEmpty(result.coverage)) {
				logger("SKIP: " & listLast(exlPath, "/\\") & " - no coverage data");
				continue;
			}
			
			validResults[exlPath] = result;
			totalFilesProcessed++;
			logger("VALID: " & listLast(exlPath, "/\\") & " contains " & structCount(result.coverage) & " source files");
		}
		//logger("Pass 1 complete: " & totalFilesProcessed & " valid .exl files found");
		
		// PASS 2: Source File Discovery and Structure Initialization
		//logger("--- PASS 2: Source File Discovery ---");
		for (var exlPath in validResults) {
			var result = validResults[exlPath];
			
			for (var fileIndex in result.coverage) {
				// Resolve source file path
				var sourceFilePath = resolveSourceFilePath(result, fileIndex);
				
				if (!structKeyExists(mergedResults, sourceFilePath)) {
					// Initialize new source file entry
					mergedResults[sourceFilePath] = initializeSourceFileEntry(sourceFilePath, result, fileIndex);
					totalSourceFilesFound++;
					//logger("INIT: " & contractPath(sourceFilePath) & " (from " & listLast(exlPath, "/\\") & ")");
				}
				
				// Track statistics
				if (!structKeyExists(sourceFileStats, sourceFilePath)) {
					sourceFileStats[sourceFilePath] = {"exlFiles": [], "totalLines": 0};
				}
				arrayAppend(sourceFileStats[sourceFilePath].exlFiles, listLast(exlPath, "/\\"));
			}
		}
		//logger("Pass 2 complete: " & totalSourceFilesFound & " unique source files discovered");
		
		// PASS 3: Coverage Data Merging
		//logger("--- PASS 3: Coverage Data Merging ---");
		var totalMergeOperations = 0;
		for (var exlPath in validResults) {
			var result = validResults[exlPath];
			var exlFileName = listLast(exlPath, "/\\");
			
			for (var fileIndex in result.coverage) {
				var sourceFilePath = resolveSourceFilePath(result, fileIndex);
				var sourceFileCoverage = result.coverage[fileIndex];
				
				// Merge coverage data
				var mergedLines = mergeCoverageData(mergedResults[sourceFilePath], sourceFileCoverage, sourceFilePath);
				totalMergeOperations += mergedLines;
				
				// Merge fileCoverage array data
				mergeFileCoverageArray(mergedResults[sourceFilePath], result, fileIndex);
				
				//logger("MERGE: " & contractPath(sourceFilePath) & " + " & exlFileName & " (" & mergedLines & " lines)");
			}
		}
		//logger("Pass 3 complete: " & totalMergeOperations & " total line merges performed");
		
		// PASS 4: Statistics Recalculation and Finalization
		//logger("--- PASS 4: Statistics and Finalization ---");
		for (var sourceFilePath in mergedResults) {
			var startTime = getTickCount();
			mergedResults[sourceFilePath].stats = variables.codeCoverageUtils.calculateCoverageStats(mergedResults[sourceFilePath]);
			var calcTime = getTickCount() - startTime;
			
			// Update execution time metadata
			if (structKeyExists(mergedResults[sourceFilePath].stats, "totalExecutionTime")) {
				mergedResults[sourceFilePath].metadata["execution-time"] = mergedResults[sourceFilePath].stats.totalExecutionTime;
			}
			
			var stats = mergedResults[sourceFilePath].stats;
			var coverage = stats.totalLinesFound > 0 ? numberFormat(100.0 * stats.totalLinesHit / stats.totalLinesFound, "0.0") : "0.0";
			//logger("STATS: " & contractPath(sourceFilePath) & " - " & stats.totalLinesHit & "/" & stats.totalLinesFound & " (" & coverage & "%) in " & calcTime & "ms");
		}
		
		//logger("=== MERGE COMPLETE: " & structCount(mergedResults) & " source files ready ===");
		return mergedResults;
	}
	
	/**
	 * Resolves the actual source file path from a file index
	 */
	private string function resolveSourceFilePath(required struct result, required string fileIndex) {
		if (structKeyExists(arguments.result, "source") && 
			structKeyExists(arguments.result.source, "files") && 
			structKeyExists(arguments.result.source.files, arguments.fileIndex)) {
			return arguments.result.source.files[arguments.fileIndex].path ?: arguments.fileIndex;
		}
		return arguments.fileIndex; // Fallback to index if path not found
	}
	
	/**
	 * Initializes a new source file entry in the merged results
	 */
	private struct function initializeSourceFileEntry(required string sourceFilePath, required struct sourceResult, required string fileIndex) {
		var entry = {
			"exeLog": arguments.sourceFilePath, // Use source file path instead of .exl path
			"metadata": {
				"script-name": contractPath(arguments.sourceFilePath),
				"execution-time": "0", // Will be accumulated from individual results
				"unit": arguments.sourceResult.metadata.unit ?: "μs"
			},
			"files": {}, // Top-level files mapping
			"fileCoverage": [], // Raw coverage data array
			"coverage": {},
			"source": { 
				"files": {} // Expected by calculateCoverageStats
			},
			"stats": {
				"totalLinesFound": 0,
				"totalLinesHit": 0,
				"totalExecutions": 0,
				"totalExecutionTime": 0
			}
		};
		
		// Initialize coverage structure
		entry.coverage[arguments.sourceFilePath] = {};
		
		// Copy the source file structure to the correct locations
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
	
	/**
	 * Merges coverage data from source into target
	 * @return Number of lines merged
	 */
	private numeric function mergeCoverageData(required struct targetResult, required struct sourceFileCoverage, required string sourceFilePath) {
		var targetCoverage = arguments.targetResult.coverage[arguments.sourceFilePath];
		var linesMerged = 0;
		
		// If target coverage is empty, initialize it
		if (structIsEmpty(targetCoverage)) {
			arguments.targetResult.coverage[arguments.sourceFilePath] = duplicate(arguments.sourceFileCoverage);
			return structCount(arguments.sourceFileCoverage);
		}
		
		// Merge line-by-line coverage data
		for (var lineNumber in arguments.sourceFileCoverage) {
			var sourceLine = arguments.sourceFileCoverage[lineNumber];
			
			if (!structKeyExists(targetCoverage, lineNumber)) {
				// First time seeing this line
				targetCoverage[lineNumber] = duplicate(sourceLine);
			} else {
				// Merge execution data for this line
				var targetLine = targetCoverage[lineNumber];
				
				// Add execution counts
				if (structKeyExists(sourceLine, "count")) {
					targetLine.count = val(targetLine.count ?: 0) + val(sourceLine.count ?: 0);
				}
				
				// Merge execution times if present
				if (structKeyExists(sourceLine, "time")) {
					targetLine.time = val(targetLine.time ?: 0) + val(sourceLine.time ?: 0);
				}
				
				// Merge any other numeric execution data
				for (var key in sourceLine) {
					if (key != "count" && key != "time") {
						if (isNumeric(sourceLine[key]) && isNumeric(targetLine[key] ?: 0)) {
							targetLine[key] = val(targetLine[key] ?: 0) + val(sourceLine[key]);
						}
					}
				}
			}
			linesMerged++;
		}
		
		return linesMerged;
	}
	
	/**
	 * Merges fileCoverage array data for a specific file
	 */
	private void function mergeFileCoverageArray(required struct targetResult, required struct sourceResult, required string fileIndex) {
		if (!structKeyExists(arguments.sourceResult, "fileCoverage") || !isArray(arguments.sourceResult.fileCoverage)) {
			return;
		}
		
		// Add relevant coverage lines from fileCoverage array
		for (var coverageLine in arguments.sourceResult.fileCoverage) {
			// Parse the tab-separated coverage line: fileIdx, lineNum, count, time
			var parts = listToArray(coverageLine, chr(9), false, false);
			if (arrayLen(parts) >= 2 && parts[1] == arguments.fileIndex) {
				// This coverage line is for our current source file
				arrayAppend(arguments.targetResult.fileCoverage, coverageLine);
			}
		}
	}
}