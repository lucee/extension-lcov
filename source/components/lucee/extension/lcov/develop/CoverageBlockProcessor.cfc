component extends="lucee.extension.lcov.CoverageBlockProcessor" {

	/*
	* Override: Calculate coverage stats, only count hits for executable lines
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
			var executableLines = arguments.result.source.files[filePath].executableLines ?: [];
			stats.files[filePath].linesFound = arrayLen(executableLines);
			stats.totalLinesFound += stats.files[filePath].linesFound;

			var uniqueHitLines = {};
			if (structKeyExists(arguments.result.coverage, filePath)) {
				var filecoverage = arguments.result.coverage[filePath];
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
				stats.totalLinesHit += stats.files[filePath].linesHit;
			}
		}
		var totalTime = getTickCount() - startTime;
		return stats;
	}

}
