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
		if (!directoryExists(arguments.executionLogDir)) {
			throw(message="Execution log directory does not exist: " & arguments.executionLogDir);
		}

		logger("Processing execution logs from: " & arguments.executionLogDir);

		// Create parser with options for verbose logging
		var exlParser = new ExecutionLogParser(arguments.options);

		var files = directoryList(arguments.executionLogDir, false, "query", "*.exl", "datecreated");
		var results = {};

		logger("Found " & files.recordCount & " .exl files to process");

		for (var file in files) {
			var exlPath = file.directory & "/" & file.name;
			try {
				logger("Processing .exl file: " & exlPath);
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
		logger("Starting mergeResultsBySourceFile - processing " & structCount(arguments.results) & " results");
		
		var mergedResults = {};
		
		// Iterate through each .exl result
		for (var exlPath in arguments.results) {
			var result = arguments.results[exlPath];
			
			// Skip if no coverage data
			if (!structKeyExists(result, "coverage") || structIsEmpty(result.coverage)) {
				logger("Skipping " & exlPath & " - no coverage data");
				continue;
			}
			
			// Process each source file in this result's coverage data
			for (var fileIndex in result.coverage) {
				var sourceFileCoverage = result.coverage[fileIndex];
				
				// Get the actual file path from the file index
				var sourceFilePath = "";
				if (structKeyExists(result, "source") && structKeyExists(result.source, "files") && structKeyExists(result.source.files, fileIndex)) {
					sourceFilePath = result.source.files[fileIndex].path ?: fileIndex;
				} else {
					sourceFilePath = fileIndex; // Fallback to index if path not found
				}
				
				// Initialize merged result for this source file if it doesn't exist
				if (!structKeyExists(mergedResults, sourceFilePath)) {
					mergedResults[sourceFilePath] = {
						"exeLog": sourceFilePath, // Use source file path instead of .exl path
						"metadata": {
							"script-name": contractPath(sourceFilePath),
							"execution-time": "0", // Will be accumulated from individual results
							"unit": result.metadata.unit ?: "μs"
						},
						"files": {}, // This should remain at the top level, not nested
						"fileCoverage": [], // fileCoverage is an array, not a struct
						"coverage": {},
						"source": { 
							"files": {} // This is what calculateCoverageStats expects
						},
						"stats": {
							"totalLinesFound": 0,
							"totalLinesHit": 0,
							"totalExecutions": 0,
							"totalExecutionTime": 0
						}
					};
					
					// Copy the source file structure to the correct locations
					mergedResults[sourceFilePath].coverage[sourceFilePath] = {};
					if (structKeyExists(result, "source") && structKeyExists(result.source, "files") && structKeyExists(result.source.files, fileIndex)) {
						mergedResults[sourceFilePath].source.files[sourceFilePath] = result.source.files[fileIndex];
					}
					if (structKeyExists(result, "files") && structKeyExists(result.files, fileIndex)) {
						mergedResults[sourceFilePath].files[sourceFilePath] = result.files[fileIndex];
					}
					// Note: fileCoverage is an array that contains raw coverage data lines
					// We'll merge the relevant coverage data from the array later
				}
				
				// Merge coverage data for this source file
				var targetCoverage = mergedResults[sourceFilePath].coverage[sourceFilePath];
				
				// If target coverage is empty, initialize it
				if (structIsEmpty(targetCoverage)) {
					mergedResults[sourceFilePath].coverage[sourceFilePath] = duplicate(sourceFileCoverage);
				} else {
					// Merge line-by-line coverage data
					for (var lineNumber in sourceFileCoverage) {
						var sourceLine = sourceFileCoverage[lineNumber];
						
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
							
							// Merge any other execution data
							for (var key in sourceLine) {
								if (key != "count" && key != "time") {
									if (isNumeric(sourceLine[key]) && isNumeric(targetLine[key] ?: 0)) {
										targetLine[key] = val(targetLine[key] ?: 0) + val(sourceLine[key]);
									}
								}
							}
						}
					}
				}
				
				// Also merge fileCoverage array data for this source file
				if (structKeyExists(result, "fileCoverage") && isArray(result.fileCoverage)) {
					// We already have the fileIndex from the loop variable
					// Add relevant coverage lines from fileCoverage array
					for (var coverageLine in result.fileCoverage) {
						// Parse the tab-separated coverage line: fileIdx, lineNum, count, time
						var parts = listToArray(coverageLine, chr(9), false, false);
						if (arrayLen(parts) >= 2 && parts[1] == fileIndex) {
							// This coverage line is for our current source file
							arrayAppend(mergedResults[sourceFilePath].fileCoverage, coverageLine);
						}
					}
				}
				
				// Note: execution-time will be set later based on calculated stats
				
				logger("Merged coverage data for source file: " & sourceFilePath);
			}
		}
		
		// Recalculate stats for each merged result and update execution time
		for (var sourceFile in mergedResults) {
			mergedResults[sourceFile].stats = variables.codeCoverageUtils.calculateCoverageStats(mergedResults[sourceFile]);
			
			// Set the execution time based on the calculated per-file stats
			if (structKeyExists(mergedResults[sourceFile].stats, "totalExecutionTime")) {
				mergedResults[sourceFile].metadata["execution-time"] = mergedResults[sourceFile].stats.totalExecutionTime;
			}
		}
		
		logger("Completed mergeResultsBySourceFile - created " & structCount(mergedResults) & " merged results");
		return mergedResults;
	}
}