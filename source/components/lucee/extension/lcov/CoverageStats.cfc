component accessors="true" {

	variables.debug = false;

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
		var totalStats = {
			"totalLinesFound": 0,  // total executable lines
			"totalLinesHit": 0, // total lines executed
			"totalLinesSource": 0, // total lines in source file
			"totalExecutions": 0, // total function executions
			"totalExecutionTime": 0 // total time spent executing
		};
		var fileStats = {
			"linesFound": 0, // number of executable lines
			"linesHit": 0, // number of lines executed
			"linesSource": 0, // total lines in source file
			"totalExecutions": 0, // total function executions for this file
			"totalExecutionTime": 0 // total time spent executing for this file
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

			// linesHit, totalExecutions, totalExecutionTime remain 0 until coverage is processed
			totalStats.totalLinesFound += fileInfo.linesFound;

			// Validate data integrity - fail fast on inconsistent state
			if (fileInfo.linesHit > fileInfo.linesFound) {
				var filePath = structKeyExists(fileInfo, "path") ? fileInfo.path : "fileIdx[" & fileIdx & "]";
				throw(type="DataIntegrityError", message="Invalid coverage data: linesHit [" & fileInfo.linesHit
					  & "] exceeds linesFound [" & fileInfo.linesFound & "] for file: [" & filePath & "]");
			}

			if (structKeyExists(coverageData, fileIdx)) {
				var filecoverage = coverageData[fileIdx];
				var lineNumbers = structKeyArray(filecoverage);
				if (!structKeyExists(fileInfo, "executableLines")) {
					throw(
						type="CoverageStatsError",
						message="Missing executableLines data for file: " & fileInfo.path & ". executableLines is required for accurate coverage calculation."
					);
				}
				var executableLines = fileInfo.executableLines;
				for (var j = 1; j <= arrayLen(lineNumbers); j++) {
					var lineNum = lineNumbers[j];
					var lineData = filecoverage[lineNum];
					// lineData[1] is hit count, lineData[2] is execution time
					if (isNumeric(lineData[1]) && lineData[1] > 0 && structKeyExists(executableLines, lineNum)) {
						totalStats.totalLinesHit++;
						fileInfo.linesHit++;
					}
					totalStats.totalExecutions += lineData[1];
					totalStats.totalExecutionTime += lineData[2];
					fileInfo.totalExecutions += lineData[1];
					fileInfo.totalExecutionTime += lineData[2];
				}
			}
			// fileinfo is passed by reference and updated in place
		});
		arguments.result.setStats(totalStats);

		var validationError = arguments.result.validate(throw=false);
		if (len(validationError)) {
			if (variables.debug) {
				systemOutput("Result before validation: " & serializeJSON(var=arguments.result, compact=false), true);
				systemOutput("Validation errors: " & serializeJSON(var=validationError, compact=false), true);
			}
			// Extract actual file paths for concise error message
			var filePaths = arguments.result.getAllFilePaths();
			var filePathList = arrayLen(filePaths) ? arrayToList(filePaths, ", ") : "unknown";
			throw "Result validation failed for file(s): [" & filePathList & "], validation errors: " & serializeJSON(var=validationError, compact=false);
		}
		return arguments.result;
	}

	/**
	* Calculate detailed stats for multiple result files.
	* Aggregates per-file and global coverage statistics from a struct of result objects.
	* Returns a struct with global totals (linesFound, linesHit, linesSource, coveragePercentage, etc.) and a fileStats struct keyed by file path, each containing per-file stats.
	*/
	public struct function calculateDetailedStats(required struct results, numeric processingTimeMs = 0) {
		var startTime = getTickCount();
		var executedFiles = 0;
		var fileStats = {};
		var totalResults = structCount(arguments.results);

		// First pass: collect all executableLines for each file across all results
		var allExecutableLines = {};
		for (var resultFile in arguments.results) {
			var result = arguments.results[resultFile];
			var filesData = result.getFiles();
			for (var filePath in filesData) {
				var fileInfo = filesData[filePath];
				if (!structKeyExists(fileInfo, "executableLines")) {
					throw(
						type="CoverageStatsError",
						message="Missing executableLines data for file: " & filePath & ". executableLines is required for accurate coverage calculation."
					);
				}

				if (!structKeyExists(allExecutableLines, filePath)) {
					allExecutableLines[filePath] = {};
				}

				// Merge executableLines from this result into the union
				var executableLines = fileInfo.executableLines;
				for (var lineNum in executableLines) {
					allExecutableLines[filePath][lineNum] = true;
				}
			}
		}

		// Second pass: process coverage data with correct linesFound
		for (var resultFile in arguments.results) {
			var result = arguments.results[resultFile];
			var hasExecutedCode = false;
			var filesData = result.getFiles();
			for (var filePath in filesData) {
				var fileInfo = filesData[filePath];
				if (!structKeyExists(fileStats, filePath)) {
					// Use the union of executableLines to calculate correct linesFound
					var correctLinesFound = structCount(allExecutableLines[filePath]);
					fileStats[filePath] = {
						"linesFound": correctLinesFound, // number of executable lines from union of all results
						"linesHit": 0, // number of executable lines actually executed (will be computed from coverage); must be <= linesFound
						"linesSource": fileInfo.linesSource, // total lines in source file (including whitespace/comments); always the largest
						"coveragePercentage": 0, // percentage of executable lines covered
						"coveredLineNumbers": {}
					};
				} else {
					// Update linesSource if this result has a larger value
					if (fileInfo.linesSource > fileStats[filePath].linesSource) {
						fileStats[filePath].linesSource = fileInfo.linesSource;
					}
				}
				var coverageData = result.getCoverage();
				if (structKeyExists(coverageData, filePath)) {
					var fileCoverage = coverageData[filePath];
					var executableLines = fileInfo.executableLines;
					var lineNumbers = structKeyArray(fileCoverage);
					for (var i = 1; i <= arrayLen(lineNumbers); i++) {
						var line = lineNumbers[i];
						// Only count as hit if the line is covered AND is executable
						if (isNumeric(fileCoverage[line][1]) && fileCoverage[line][1] > 0 && structKeyExists(executableLines, line)) {
							fileStats[filePath].coveredLineNumbers[line] = true;
							hasExecutedCode = true;
						}
					}
				}
			}
			if (hasExecutedCode) {
				executedFiles++;
			}
		}

		var globalLinesFound = 0;
		var globalLinesSource = 0;
		var globalLinesHit = 0;
		var uniqueFiles = {};
		var filePathsArray = structKeyArray(fileStats);
		for (var i = 1; i <= arrayLen(filePathsArray); i++) {
			var filePath = filePathsArray[i];
			if (!structKeyExists(uniqueFiles, filePath)) {
				uniqueFiles[filePath] = true;
				var fileStatData = fileStats[filePath];
				   // Do not reassign linesSource here; it was set correctly in the first loop
				   fileStatData.linesHit = structCount(fileStatData.coveredLineNumbers);

				// DEBUG: Check for the specific case we're investigating
				if (fileStatData.linesHit > fileStatData.linesFound) {
					// Find the executableLines count for this file from the original results
					var executableLinesCount = "unknown";
					for (var resultFile in arguments.results) {
						var result = arguments.results[resultFile];
						var filesData = result.getFiles();
						for (var fIdx in filesData) {
							if (filesData[fIdx].path == filePath) {
								if (structKeyExists(filesData[fIdx], "executableLines")) {
									executableLinesCount = structCount(filesData[fIdx].executableLines);
								}
								break;
							}
						}
					}
					systemOutput("[LCOV DEBUG] linesHit > linesFound for file: " & filePath, true);
					systemOutput("[LCOV DEBUG] linesHit: " & fileStatData.linesHit, true);
					systemOutput("[LCOV DEBUG] linesFound: " & fileStatData.linesFound, true);
					systemOutput("[LCOV DEBUG] linesSource: " & fileStatData.linesSource, true);
					systemOutput("[LCOV DEBUG] coveredLineNumbers count: " & structCount(fileStatData.coveredLineNumbers), true);
					systemOutput("[LCOV DEBUG] executableLines count: " & executableLinesCount, true);
					systemOutput("[LCOV DEBUG] This suggests linesFound != executableLines count, indicating a data inconsistency", true);
				}

				// If found lines exceed source lines, this means a bug in executable line detection logic
				// TODO temp disabled
				if (fileStatData.linesFound > fileStatData.linesSource) {
					systemOutput("[LCOV] linesFound > linesSource for file: " & filePath, true);
					systemOutput("[LCOV] raw results: " & serializeJSON(results, true), true);
					systemOutput("[LCOV] linesFound: " & fileStatData.linesFound, true);
					systemOutput("[LCOV] linesSource: " & fileStatData.linesSource, true);
					systemOutput("[LCOV] fileStatData: " & serializeJSON(fileStatData), true);
					throw(message="linesFound (" & fileStatData.linesFound & ") exceeds linesSource (" & fileStatData.linesSource & ") for file " & filePath);
				}
				globalLinesFound += fileStatData.linesFound;
				globalLinesHit += fileStatData.linesHit;
				globalLinesSource += fileStatData.linesSource;
				if (fileStatData.linesFound > 0) {
					fileStatData.coveragePercentage = (fileStatData.linesHit / fileStatData.linesFound) * 100;
				}
				structDelete(fileStatData, "coveredLineNumbers");
			}
		}
		var coveragePercentage = globalLinesFound > 0 ? (globalLinesHit / globalLinesFound) * 100 : 0;
		var totalTime = getTickCount() - startTime;
		return {
			"totalLinesFound": globalLinesFound, // total executable lines across all results
			"totalLinesSource": globalLinesSource, // total source lines covered across all results
			"totalLinesHit": globalLinesHit, // total lines executed across all results
			"coveragePercentage": coveragePercentage, // overall coverage percentage
			"totalFiles": structCount(uniqueFiles), // total unique source files
			"executedFiles": executedFiles, // number of files with executed code
			"processingTimeMs": arguments.processingTimeMs, // time taken to process all results
			"fileStats": fileStats // detailed stats per file
		};
	}

	/**
	* Calculate stats for all merged result objects (moved from CoverageMerger)
	* @mergedResults Struct of result objects keyed by file index
	*/
	public static void function calculateStatsForMergedResults(required struct mergedResults) {
		var statsCalculator = new CoverageStats();
		for (var fileIndex in arguments.mergedResults) {
			var startTime = getTickCount();
			var result = statsCalculator.calculateCoverageStats(arguments.mergedResults[fileIndex]);
			// calculateCoverageStats returns the result with updated stats, so we don't need to set .stats manually
			if (structKeyExists(result.getStats(), "totalExecutionTime")) {
				var metadata = result.getMetadata();
				metadata["execution-time"] = result.getStats().totalExecutionTime;
				result.setMetadata(metadata);
			}
		}
	}
}
