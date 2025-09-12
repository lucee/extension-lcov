component accessors="true" {
	/**
	* Calculate LCOV-style statistics from merged coverage data
	* Uses batch processing and reduced function calls
	* @fileCoverage Struct containing files and coverage data (merged format)
	* @return Struct with stats per file path
	*/
	public struct function calculateLcovStats(required struct fileCoverage) {
		var startTime = getTickCount();
		var fileCount = structCount(arguments.fileCoverage.files);

		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;
		var stats = {};

		// OPTIMIZATION: Process all files in batch with minimal function calls
		for (var file in files) {
			var data = coverage[file];
			var lineNumbers = structKeyArray(data);

			// OPTIMIZATION: Count hits in single pass
			var linesHit = 0;
			for (var i = 1; i <= arrayLen(lineNumbers); i++) {
				if (data[lineNumbers[i]][1] > 0) {
					linesHit++;
				}
			}

			var linesFoundValue = structKeyExists(files[file], "linesFound") ? files[file].linesFound : arrayLen(lineNumbers);
			stats[files[file].path] = {
				"linesFound": linesFoundValue,
				"linesHit": linesHit,
				"lineCount": structKeyExists(files[file], "lineCount") ? files[file].lineCount : 0
			};
		}

		var totalTime = getTickCount() - startTime;
		return stats;
	}

	/**
	* Calculate overall coverage stats from a result struct
	*/
	public struct function calculateCoverageStats(struct result) {
		var startTime = getTickCount();
		var stats = {
			"totalLinesFound": 0,
			"totalLinesHit": 0,
			"totalExecutions": 0,
			"totalExecutionTime": 0,
			"files": {}
		};
		var statsTemplate = {
			"linesFound": 0,
			"linesHit": 0,
			"totalExecutions": 0,
			"totalExecutionTime": 0,
			"executedLines": {}
		};

		var filePaths = structKeyArray(arguments.result.source.files);

		for (var i = 1; i <= arrayLen(filePaths); i++) {
			var filePath = filePaths[i];
			stats.files[filePath] = duplicate(statsTemplate);
			var linesCount = structKeyExists(arguments.result.source.files[filePath], "linesCount") ? arguments.result.source.files[filePath].linesCount : 0;
			stats.files[filePath].linesCount = linesCount;
			stats.files[filePath].linesFound += arguments.result.source.files[filePath].linesFound;
			stats.totalLinesFound += arguments.result.source.files[filePath].linesFound;
			if (structKeyExists(arguments.result.coverage, filePath)) {
				var filecoverage = arguments.result.coverage[filePath];
				var fileLinesHit = structCount(filecoverage);
				stats.totalLinesHit += fileLinesHit;
				stats.files[filePath].linesHit += fileLinesHit;
				var lineNumbers = structKeyArray(filecoverage);
				for (var j = 1; j <= arrayLen(lineNumbers); j++) {
					var lineNum = lineNumbers[j];
					var lineData = filecoverage[lineNum];
					stats.totalExecutions += lineData[1];
					stats.totalExecutionTime += lineData[2];
					stats.files[filePath].totalExecutions += lineData[1];
					stats.files[filePath].totalExecutionTime += lineData[2];
				}
			}
		}
		var totalTime = getTickCount() - startTime;
		return stats;
	}

	/**
	* Calculate detailed stats for multiple result files
	*/
	public struct function calculateDetailedStats(required struct results, numeric processingTimeMs = 0) {
		var startTime = getTickCount();
		var executedFiles = 0;
		var fileStats = {};
		var totalResults = structCount(arguments.results);

		var filePathMappings = {};
		for (var resultFile in arguments.results) {
			var result = arguments.results[resultFile];
			if (structKeyExists(result, "source") && structKeyExists(result.source, "files")) {
				filePathMappings[resultFile] = {};
				for (var fileIndex in result.source.files) {
					filePathMappings[resultFile][fileIndex] = result.source.files[fileIndex].path;
				}
			}
		}

		for (var resultFile in arguments.results) {
			var result = arguments.results[resultFile];
			var hasExecutedCode = false;
			if (structKeyExists(result, "source") && structKeyExists(result.source, "files")) {
				for (var fileIndex in result.source.files) {
					var fileInfo = result.source.files[fileIndex];
					var filePath = fileInfo.path;
					if (!structKeyExists(fileStats, filePath)) {
						fileStats[filePath] = {
							"totalLines": fileInfo.linesFound,
							"coveredLines": 0,
							"coveragePercentage": 0,
							"coveredLineNumbers": {}
						};
					} else {
						var newTotalLines = fileInfo.linesFound;
						if (newTotalLines > fileStats[filePath].totalLines) {
							fileStats[filePath].totalLines = newTotalLines;
						}
					}
					if (structKeyExists(result, "coverage") && structKeyExists(result.coverage, fileIndex)) {
						var fileCoverage = result.coverage[fileIndex];
						var lineNumbers = structKeyArray(fileCoverage);
						for (var i = 1; i <= arrayLen(lineNumbers); i++) {
							var line = lineNumbers[i];
							if (isNumeric(fileCoverage[line][1]) && fileCoverage[line][1] > 0) {
								fileStats[filePath].coveredLineNumbers[line] = true;
								hasExecutedCode = true;
							}
						}
					}
				}
			}
			if (hasExecutedCode) {
				executedFiles++;
			}
		}

		var globalTotalLines = 0;
		var globalCoveredLines = 0;
		var uniqueFiles = {};
		var filePathsArray = structKeyArray(fileStats);
		for (var i = 1; i <= arrayLen(filePathsArray); i++) {
			var filePath = filePathsArray[i];
			if (!structKeyExists(uniqueFiles, filePath)) {
				uniqueFiles[filePath] = true;
				var fileStatData = fileStats[filePath];
				globalTotalLines += fileStatData.totalLines;
				fileStatData.coveredLines = structCount(fileStatData.coveredLineNumbers);
				if (fileStatData.coveredLines > fileStatData.totalLines) {
					throw(
						"Data inconsistency: coveredLines (" & fileStatData.coveredLines & ") exceeds totalLines (" & fileStatData.totalLines & ") for file " & filePath & ". Covered lines: " & serializeJSON(structKeyArray(fileStatData.coveredLineNumbers)),
						"CoverageDataError"
					);
				}
				globalCoveredLines += fileStatData.coveredLines;
				if (fileStatData.totalLines > 0) {
					fileStatData.coveragePercentage =
						(fileStatData.coveredLines / fileStatData.totalLines) * 100;
				}
				structDelete(fileStatData, "coveredLineNumbers");
			}
		}
		var coveragePercentage = globalTotalLines > 0 ? (globalCoveredLines / globalTotalLines) * 100 : 0;
		var totalTime = getTickCount() - startTime;
		return {
			"totalLines": globalTotalLines,
			"coveredLines": globalCoveredLines,
			"coveragePercentage": coveragePercentage,
			"totalFiles": structCount(uniqueFiles),
			"executedFiles": executedFiles,
			"processingTimeMs": arguments.processingTimeMs,
			"fileStats": fileStats
		};
	}
}
