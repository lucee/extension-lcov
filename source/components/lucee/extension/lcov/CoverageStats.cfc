component accessors="true" {

	/**
	 * Initialize CoverageStats
	 * @logLevel Log level for debugging stats calculations
	 */
	public function init(string logLevel="none") {
		variables.logger = new lucee.extension.lcov.Logger(level=arguments.logLevel);
		return this;
	}

	/**
	* Calculate LCOV-style statistics from merged coverage data
	* Uses batch processing and reduced function calls
	* @fileCoverage Struct containing files and coverage data (merged format)
	* @return Struct with stats keyed per file path
	*/
	public struct function calculateLcovStats(required struct fileCoverage) {
		var startTime = getTickCount();
		var fileCount = structCount(arguments.fileCoverage.files);

		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;
		var stats = {};

		// OPTIMIZATION: Process all files in batch with minimal function calls
		for (var file in files) {
			var filePath = files[file].path;
			var data = coverage[file];
			var lineNumbers = structKeyArray(data);

			// Count hits in single pass
			var linesHit = 0;
			for (var i = 1; i <= arrayLen(lineNumbers); i++) {
				if (data[lineNumbers[i]][1] > 0) {
					linesHit++;
				}
			}

			// Aggregate duplicate file entries: use max linesFound, sum linesHit, keep linesSource from any (should be same)
			if (!structKeyExists(stats, filePath)) {
				stats[filePath] = {
					"linesFound": files[file].linesFound,
					"linesHit": linesHit,
					"linesSource": files[file].linesSource
				};
			} else {
				// Use max linesFound
				if (files[file].linesFound > stats[filePath].linesFound) {
					stats[filePath].linesFound = files[file].linesFound;
				}
				// Sum linesHit (union of covered lines)
				stats[filePath].linesHit += linesHit;
			}

			// Fail fast if linesFound > linesSource
			if (files[file].linesFound > files[file].linesSource) {
				throw(message="linesFound (" & files[file].linesFound & ") exceeds linesSource (" & files[file].linesSource & ") for file " & filePath);
			}

			// Fail fast if linesHit > linesFound (after aggregation)
			if (structKeyExists(stats, filePath) && stats[filePath].linesHit > stats[filePath].linesFound) {
				throw(message="linesHit (" & stats[filePath].linesHit & ") exceeds linesFound (" & stats[filePath].linesFound & ") for file " & filePath);
			}
		}

		var totalTime = getTickCount() - startTime;
		return stats;
	}

	/**
	* Calculate overall coverage stats from a result struct
	*/
	public any function calculateCoverageStats(result result) {
		var event = variables.logger.beginEvent("CoverageStats");
		var totalStats = {
			"totalLinesFound": 0,  // total executable lines
			"totalLinesHit": 0, // total lines executed
			"totalLinesSource": 0, // total lines in source file
			"totalExecutions": 0, // total function executions
			"totalExecutionTime": 0, // total time spent executing
			"totalChildTime": 0 // total child time from call tree
		};
		var fileStats = {
			"linesFound": 0, // number of executable lines
			"linesHit": 0, // number of lines executed
			"linesSource": 0, // total lines in source file
			"totalExecutions": 0, // total function executions for this file
			"totalExecutionTime": 0, // total time spent executing for this file
			"totalChildTime": 0 // child time from call tree for this file
		};

		var filesData = arguments.result.getFiles();
		if (structIsEmpty(filesData)) {
			// Always return required canonical keys, even if no files present
		arguments.result.setStats(totalStats);
			arguments.result.validate();
			return arguments.result;
		}

		var coverageData = result.getCoverage();

		structEach(filesData, function(fileIdx, _fileInfo) {
			var fileInfo = arguments._fileInfo;
			// Always set all canonical keys for each file, using a duplicate of fileStats as the base
			structAppend(fileInfo, duplicate(fileStats), false);

			// Reset stats that will be recalculated to avoid double counting
			fileInfo.linesHit = 0;
			fileInfo.totalExecutions = 0;
			fileInfo.totalExecutionTime = 0;
			fileInfo.totalChildTime = 0;

			// linesHit, totalExecutions, totalExecutionTime remain 0 until coverage is processed
			var originalLinesFound = fileInfo.linesFound;
			totalStats.totalLinesFound += fileInfo.linesFound;

			if (structKeyExists(coverageData, fileIdx)) {
				var filecoverage = coverageData[fileIdx];
				var lineNumbers = structKeyArray(filecoverage);

				// Coverage now contains all executable lines (both executed and unexecuted as zero-counts)
				// Update linesFound from coverage which is the single source of truth
				var coverageLineCount = arrayLen(lineNumbers);
				if (coverageLineCount >= fileInfo.linesFound) {
					// Coverage has been populated with zero-counts, use it as source of truth
					var delta = coverageLineCount - fileInfo.linesFound;
					fileInfo.linesFound = coverageLineCount;
					// Update totalStats to reflect the new linesFound
					totalStats.totalLinesFound += delta;
				}

				for (var j = 1; j <= arrayLen(lineNumbers); j++) {
					var lineNum = lineNumbers[j];
					var lineData = filecoverage[lineNum];

					// lineData[1] is hit count, lineData[2] is execution time, lineData[3] is isChildTime (optional)
					// Count lines with hitCount > 0 as executed
					if (isNumeric(lineData[1]) && lineData[1] > 0) {
						totalStats.totalLinesHit++;
						fileInfo.linesHit++;
					}

					totalStats.totalExecutions += lineData[1];
					totalStats.totalExecutionTime += lineData[2];
					fileInfo.totalExecutions += lineData[1];
					fileInfo.totalExecutionTime += lineData[2];

					// If this line has child time flag and it's true, add execution time to child time
					if (arrayLen(lineData) >= 3 && lineData[3] == true) {
						totalStats.totalChildTime += lineData[2];
						fileInfo.totalChildTime += lineData[2];
					}
				}
			}
			// fileinfo is passed by reference and updated in place
		});

		// Child time is now calculated from coverage data in the loop above
		// where we check lineData[3] for the isChildTime flag

		arguments.result.setStats(totalStats);

		var validationError = arguments.result.validate(throw=false);
		if (len(validationError)) {
			variables.logger.debug("Result before validation: " & serializeJSON(var=arguments.result, compact=false));
			variables.logger.debug("Validation errors: " & serializeJSON(var=validationError, compact=false));
			// Extract actual file paths for concise error message
			var filePaths = arguments.result.getAllFilePaths();
			var filePathList = arrayLen(filePaths) ? arrayToList(filePaths, ", ") : "unknown";
			throw "Result validation failed for file(s): [" & filePathList & "], validation errors: " & serializeJSON(var=validationError, compact=false);
		}

		event["filesProcessed"] = structCount(filesData);
		event["totalLinesFound"] = totalStats.totalLinesFound;
		event["totalLinesHit"] = totalStats.totalLinesHit;
		variables.logger.commitEvent(event);

		return arguments.result;
	}

	/**
	 * Progressive aggregateCoverageStats method - only supports array of JSON file paths
	 * @jsonFilePaths Array of JSON file paths to process
	 * @processingTimeMs Processing time in milliseconds for timing calculations
	 * @return Detailed stats struct
	 */
	public struct function aggregateCoverageStats(required array jsonFilePaths, numeric processingTimeMs = 0) {
		var startTime = getTickCount();
		var executedFiles = 0;
		var fileStats = {};
		var totalResults = arrayLen(arguments.jsonFilePaths);
		var resultFactory = new lucee.extension.lcov.model.result();

		// First pass: collect all executable lines for each file across all results
		// Use coverage as source of truth (contains all executable lines with zero-counts)
		// Fall back to executableLines field for backward compatibility with old cached JSON files
		var allExecutableLines = {};
		for (var jsonPath in arguments.jsonFilePaths) {
			if (!fileExists(jsonPath)) {
				throw(message="JSON file [jsonPath] does not exist: [" & jsonPath & "]");
			}

			var result = resultFactory.fromJson(fileRead(jsonPath), false);
			var filesData = result.getFiles();
			var coverageData = result.getCoverage();

			for (var filePath in filesData) {
				var fileInfo = filesData[filePath];

				// Get executable lines from coverage first (preferred), fall back to executableLines field
				var executableLinesForFile = {};
				var fileIdx = structKeyExists(fileInfo, "fileIdx") ? fileInfo.fileIdx : "";

				// Try to get from coverage (which should have all lines including zero-counts)
				if (len(fileIdx) && structKeyExists(coverageData, fileIdx)) {
					var fileCoverage = coverageData[fileIdx];
					for (var lineNum in fileCoverage) {
						executableLinesForFile[lineNum] = true;
					}
				}

				// Fall back to executableLines field if coverage was empty or not found
				if (structIsEmpty(executableLinesForFile) && structKeyExists(fileInfo, "executableLines")) {
					executableLinesForFile = duplicate(fileInfo.executableLines);
				}

				// Merge with allExecutableLines
				if (!structKeyExists(allExecutableLines, filePath)) {
					allExecutableLines[filePath] = executableLinesForFile;
				} else {
					// Merge executable lines (union of all executable lines across runs)
					for (var lineNum in executableLinesForFile) {
						allExecutableLines[filePath][lineNum] = true;
					}
				}
			}
			// Clear result from memory
			result = nullValue();
		}

		// Second pass: calculate coverage stats using merged executable lines
		for (var jsonPath in arguments.jsonFilePaths) {
			var result = resultFactory.fromJson(fileRead(jsonPath), false);
			var coverage = result.getCoverage();
			var filesData = result.getFiles();

			for (var filePath in filesData) {
				if (!structKeyExists(fileStats, filePath)) {
					fileStats[filePath] = {
						"linesFound": structCount(allExecutableLines[filePath]),
						"linesHit": 0,
						"linesSource": filesData[filePath].linesSource ?: 0,
						"hitCounts": {},
						"path": filesData[filePath].path
					};
				}

				// Count coverage for this file using the proper file key mapping
				for (var fKey in filesData) {
					var fileInfo = filesData[fKey];
					if (fileInfo.path == filePath && structKeyExists(coverage, fKey)) {
						var fileCoverage = coverage[fKey];
						for (var lineNum in fileCoverage) {
							if (structKeyExists(allExecutableLines[filePath], lineNum)) {
								var hitCount = int(fileCoverage[lineNum][1]);
								if (!structKeyExists(fileStats[filePath].hitCounts, lineNum)) {
									fileStats[filePath].hitCounts[lineNum] = 0;
									// Only count as hit if this line has actual hits > 0
									if (hitCount > 0) {
										fileStats[filePath].linesHit++;
									}
								}
								fileStats[filePath].hitCounts[lineNum] += hitCount;
							}
						}
						break; // Found the matching file, no need to continue loop
					}
				}
			}
			executedFiles++;
			// Clear result from memory
			result = nullValue();
		}

		// Calculate totals and per-file coverage percentages
		var totalLinesFound = 0;
		var totalLinesHit = 0;
		var totalLinesSource = 0;
		for (var filePath in fileStats) {
			totalLinesFound += fileStats[filePath].linesFound;
			totalLinesHit += fileStats[filePath].linesHit;
			totalLinesSource += fileStats[filePath].linesSource;

			// Calculate coverage percentage for each file
			var fileCoveragePercentage = fileStats[filePath].linesFound > 0
				? (fileStats[filePath].linesHit / fileStats[filePath].linesFound) * 100
				: 0;
			fileStats[filePath]["coveragePercentage"] = numberFormat(fileCoveragePercentage, "0.0");
		}

		var coveragePercentage = totalLinesFound > 0 ? (totalLinesHit / totalLinesFound) * 100 : 0;
		var calculationTime = getTickCount() - startTime;

		return {
			"totalFiles": structCount(fileStats),
			"totalLinesFound": totalLinesFound,
			"totalLinesHit": totalLinesHit,
			"totalLinesSource": totalLinesSource,
			"coveragePercentage": numberFormat(coveragePercentage, "0.0"),
			"fileStats": fileStats,
			"executedFiles": executedFiles,
			"totalResults": totalResults,
			"calculationTimeMs": calculationTime,
			"processingTimeMs": arguments.processingTimeMs
		};
	}

	/**
	* Calculate stats for all merged result objects (moved from CoverageMerger)
	* @mergedResults Struct of result objects keyed by file index
	*/
	public static void function calculateStatsForMergedResults(required struct mergedResults) {
		var statsCalculator = new CoverageStats();

		// Calculate stats for each file
		for (var fileIndex in arguments.mergedResults) {
			var startTime = getTickCount();
			var result = statsCalculator.calculateCoverageStats(arguments.mergedResults[fileIndex]);
			// calculateCoverageStats returns the result with updated stats, so we don't need to set .stats manually
		}
	}
}
