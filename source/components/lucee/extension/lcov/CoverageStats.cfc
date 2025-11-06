component accessors="true" {

	/**
	 * Initialize CoverageStats
	 * @logger Logger instance for debugging stats calculations
	 */
	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	* Calculate LCOV-style statistics from merged coverage data
	* Uses batch processing and reduced function calls
	* @fileCoverage Struct containing files and coverage data (merged format)
	* @return Struct with stats keyed per file path
	*/
	public struct function calculateLcovStats(required struct fileCoverage) localmode=true {
		var startTime = getTickCount();
		var fileCount = structCount(arguments.fileCoverage.files);

		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;
		var stats = {};

		// OPTIMIZATION: Process all files in batch with minimal function calls
		cfloop( collection=files, key="local.file", value="local.fileData" ) {
			var filePath = fileData.path;
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
					"linesFound": fileData.linesFound,
					"linesHit": linesHit,
					"linesSource": fileData.linesSource
				};
			} else {
				// Use max linesFound
				if (fileData.linesFound > stats[filePath].linesFound) {
					stats[filePath].linesFound = fileData.linesFound;
				}
				// Sum linesHit (union of covered lines)
				stats[filePath].linesHit += linesHit;
			}

			// Fail fast if linesFound > linesSource
			if (fileData.linesFound > fileData.linesSource) {
				throw(message="linesFound (" & fileData.linesFound & ") exceeds linesSource (" & fileData.linesSource & ") for file " & filePath);
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
	* Calculate stats for all merged result objects
	* @mergedResults Struct of result objects keyed by file index
	*/
	public static void function calculateStatsForMergedResults(required struct mergedResults) localmode=true {
		// Calculate stats for each file
		cfloop( collection=arguments.mergedResults, key="local.fileIndex", value="local.result" ) {
			calculateCoverageStats( result );
		}
	}

	/**
	* Calculate overall coverage stats from a result struct
	*/
	public any function calculateCoverageStats(result result) localmode=true {
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

					// lineData[1] is hitCount, lineData[2] is execTime, lineData[3] is blockType
					// Count lines with hitCount > 0 as executed
					if (isNumeric(lineData[1]) && lineData[1] > 0) {
						totalStats.totalLinesHit++;
						fileInfo.linesHit++;
					}

					totalStats.totalExecutions += lineData[1];
					fileInfo.totalExecutions += lineData[1];

					// Sum execTime based on blockType to avoid double-counting
					// blockType: 0=own, 1=child, 2=own+overlap, 3=child+overlap
					var blockType = lineData[3];
					var execTime = lineData[2];

					// totalExecutionTime: only count OWN time (blockType 0 or 2), not child time
					// This prevents double-counting since child time is already counted in the function where it executes
					if (blockType == 0 || blockType == 2) {
						totalStats.totalExecutionTime += execTime;
						fileInfo.totalExecutionTime += execTime;
					}

					// totalChildTime: accumulate execTime for child blockTypes (1 or 3)
					if (blockType == 1 || blockType == 3) {
						totalStats.totalChildTime += execTime;
						fileInfo.totalChildTime += execTime;
					}
				}
			}
			// fileinfo is passed by reference and updated in place
		});

		// Child time is now calculated from coverage data in the loop above
		// where we sum lineData[2] (execTime) for lines with child blockType (1 or 3)

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
	public struct function aggregateCoverageStats(required array jsonFilePaths, numeric processingTimeMs = 0) localmode=true {
		var startTime = getTickCount();
		var executedFiles = 0;
		var fileStats = {};
		var totalResults = arrayLen(arguments.jsonFilePaths);
		var resultFactory = new lucee.extension.lcov.model.result();

		// First pass: collect all executable lines for each file across all results
		// Use coverage as source of truth (contains all executable lines with zero-counts)
		// Fall back to executableLines field for backward compatibility with old cached JSON files
		var allExecutableLines = structNew('regular');
		cfloop( array=arguments.jsonFilePaths, item="local.jsonPath" ) {
			if (!fileExists(jsonPath)) {
				throw(message="JSON file [jsonPath] does not exist: [" & jsonPath & "]");
			}

			var result = resultFactory.fromJson(fileRead(jsonPath), false);
			var filesData = result.getFiles();
			var coverageData = result.getCoverage();

			cfloop( collection=filesData, key="local.filePath", value="local.fileInfo" ) {

				// Get executable lines from coverage first (preferred), fall back to executableLines field
				var executableLinesForFile = structNew('regular');
				var fileIdx = fileInfo.fileIdx ?: "";

				// Try to get from coverage (which should have all lines including zero-counts)
				if (len(fileIdx) && structKeyExists(coverageData, fileIdx)) {
					var fileCoverage = coverageData[fileIdx];
					cfloop( collection=fileCoverage, key="local.lineNum" ) {
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
					cfloop( collection=executableLinesForFile, key="local.lineNum" ) {
						allExecutableLines[filePath][lineNum] = true;
					}
				}
			}
			// Clear result from memory
			result = nullValue();
		}

		// Second pass: calculate coverage stats using merged executable lines
		cfloop( array=arguments.jsonFilePaths, item="local.jsonPath" ) {
			var result = resultFactory.fromJson(fileRead(jsonPath), false);
			var coverage = result.getCoverage();
			var filesData = result.getFiles();

			cfloop( collection=filesData, key="local.filePath", value="local.fileData" ) {
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
				cfloop( collection=filesData, key="local.fKey", value="local.fileInfo" ) {
					if (fileInfo.path == filePath && structKeyExists(coverage, fKey)) {
						processFileCoverage(
							fileStats = fileStats,
							filePath = filePath,
							fileCoverage = coverage[fKey],
							allExecutableLines = allExecutableLines
						);
						break; // Found the matching file, no need to continue loop
					}
				}
			}
			executedFiles++;
			// Clear result from memory
			result = nullValue();
		}

		return buildAggregatedStatsResult(
			fileStats = fileStats,
			executedFiles = executedFiles,
			totalResults = totalResults,
			startTime = startTime,
			processingTimeMs = arguments.processingTimeMs
		);
	}

	/**
	 * Process coverage data for all lines in a file and update file stats
	 * @fileStats Reference to the fileStats struct for all files
	 * @filePath The file path being processed
	 * @fileCoverage The coverage data struct keyed by line number
	 * @allExecutableLines All executable lines across all runs
	 */
	private void function processFileCoverage(
		required struct fileStats,
		required string filePath,
		required struct fileCoverage,
		required struct allExecutableLines
	) localmode=true {
		cfloop( collection=arguments.fileCoverage, key="local.lineNum", value="local.lineData" ) {
			if (!structKeyExists(allExecutableLines[filePath], lineNum)) {
				continue;
			}
			var hitCount = int(lineData[1]);
			if (!structKeyExists(fileStats[filePath].hitCounts, lineNum)) {
				fileStats[filePath].hitCounts[lineNum] = 0;
				// Only count as hit if this line has actual hits > 0
				if (hitCount > 0) {
					fileStats[filePath].linesHit++;
				}
			}
			fileStats[filePath].hitCounts[lineNum] += hitCount;

			// Track childTime: accumulate execTime for child blockTypes (1 or 3)
			if (!structKeyExists(fileStats[filePath], "totalChildTime")) {
				fileStats[filePath].totalChildTime = 0;
			}
			var blockType = lineData[3];
			if (blockType == 1 || blockType == 3) {
				fileStats[filePath].totalChildTime += lineData[2]; // execTime
			}
		}
	}

	/**
	 * Build the final aggregated stats result structure
	 * @fileStats The per-file stats struct
	 * @executedFiles Number of files executed
	 * @totalResults Total number of result files processed
	 * @startTime Start time in milliseconds
	 * @processingTimeMs Processing time in milliseconds
	 * @return Final stats struct
	 */
	private struct function buildAggregatedStatsResult(
		required struct fileStats,
		required numeric executedFiles,
		required numeric totalResults,
		required numeric startTime,
		required numeric processingTimeMs
	) localmode=true {
		var totalLinesFound = 0;
		var totalLinesHit = 0;
		var totalLinesSource = 0;
		var totalChildTime = 0;

		cfloop( collection=arguments.fileStats, key="local.filePath", value="local.stats" ) {
			totalLinesFound += stats.linesFound;
			totalLinesHit += stats.linesHit;
			totalLinesSource += stats.linesSource;
			totalChildTime += stats.totalChildTime ?: 0;

			// Calculate coverage percentage for each file
			var fileCoveragePercentage = stats.linesFound > 0
				? (stats.linesHit / stats.linesFound) * 100
				: 0;
			stats["coveragePercentage"] = numberFormat(fileCoveragePercentage, "0.0");
		}

		var coveragePercentage = totalLinesFound > 0 ? (totalLinesHit / totalLinesFound) * 100 : 0;
		var calculationTime = getTickCount() - arguments.startTime;

		return {
			"totalFiles": structCount(arguments.fileStats),
			"totalLinesFound": totalLinesFound,
			"totalLinesHit": totalLinesHit,
			"totalLinesSource": totalLinesSource,
			"totalChildTime": totalChildTime,
			"coveragePercentage": numberFormat(coveragePercentage, "0.0"),
			"fileStats": arguments.fileStats,
			"executedFiles": arguments.executedFiles,
			"totalResults": arguments.totalResults,
			"calculationTimeMs": calculationTime,
			"processingTimeMs": arguments.processingTimeMs
		};
	}

}
