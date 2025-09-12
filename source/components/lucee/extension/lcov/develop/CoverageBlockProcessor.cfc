component extends="lucee.extension.lcov.CoverageBlockProcessor" {

	/*
		* Override: Calculate coverage stats, only count hits for executable lines
	*/
	public struct function zzzzcalculateCoverageStats(struct result) {
		var startTime = getTickCount();
		var stats = {
			"linesFound": 0,
			"linesHit": 0,
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

		var filesStruct = arguments.result.getFiles();
		var filePaths = structKeyArray(filesStruct);
		for (var i = 1; i <= arrayLen(filePaths); i++) {
			var filePath = filePaths[i];
			stats.files[filePath] = duplicate(statsTemplate);
			   var fileStruct = arguments.result.getFileItem(filePath);
			var totalLinesSource = fileStruct.linesSource;
			stats.files[filePath].totalLinesSource = totalLinesSource;
			var executableLines = fileStruct.executableLines ?: [];
			stats.files[filePath].linesFound = arrayLen(executableLines);
			stats.linesFound += stats.files[filePath].linesFound;

			var uniqueHitLines = {};
			var coverageData = arguments.result.getCoverage();
			if (structKeyExists(coverageData, filePath)) {
				var filecoverage = coverageData[filePath];
				for (var k = 1; k <= arrayLen(executableLines); k++) {
					var execLine = executableLines[k];
					if (!structKeyExists(filecoverage, execLine)) {
						systemOutput(
							"\n[FAIL-FAST] execLine " & execLine & " missing in filecoverage for file " & filePath &
							".\nfilecoverage keys: " & serializeJSON(structKeyArray(filecoverage)) &
							"\nexecutableLines: " & serializeJSON(executableLines), true);
						throw(
							message = "execLine " & execLine & " missing in filecoverage for file " & filePath,
							detail = "filecoverage keys: " & serializeJSON(structKeyArray(filecoverage)) &
								", executableLines: " & serializeJSON(executableLines)
						);
					}
					if (
						isArray(filecoverage[execLine])
						&& arrayLen(filecoverage[execLine]) >= 2
						&& filecoverage[execLine][1] > 0
					) {
						uniqueHitLines[execLine] = true;
						stats.files[filePath].executedLines[execLine] = filecoverage[execLine][1];
						stats.totalExecutions += filecoverage[execLine][1];
						stats.totalExecutionTime += filecoverage[execLine][2];
						stats.files[filePath].totalExecutions += filecoverage[execLine][1];
						stats.files[filePath].totalExecutionTime += filecoverage[execLine][2];
					}
				}
				stats.files[filePath].linesHit = structCount(uniqueHitLines);
				stats.linesHit += stats.files[filePath].linesHit;
			}
		}
		var totalTime = getTickCount() - startTime;
		return stats;
	}

}
