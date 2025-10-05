component {

	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Enriches a result model with child time analysis data.
	 * This marks blocks that represent child time (function calls).
	 */
	public void function enrich(required any result, struct options = {}) {
		var callTreeAnalyzer = new CallTreeAnalyzer( logger=variables.logger );

		// Build aggregated data from the result's coverage
		var aggregated = buildAggregatedFromResult(arguments.result);

		// Get files with AST data from the result
		var files = arguments.result.getFiles();

		// Analyze blocks to identify child time
		var analysisResult = callTreeAnalyzer.analyzeCallTree(aggregated, files);

		// Add child time data to the result model
		arguments.result.setCallTree(analysisResult.blocks);
		arguments.result.setCallTreeMetrics(analysisResult.metrics);

		// Optionally update stats with child time insights
		if (structKeyExists(arguments.options, "updateStats") && arguments.options.updateStats) {
			updateStatsWithCallTree(arguments.result, analysisResult.metrics);
		}
	}

	/**
	 * Builds aggregated execution data from a result model's coverage data.
	 * Converts from per-line coverage format to position-based aggregated format.
	 */
	private struct function buildAggregatedFromResult(required any result) {
		var aggregated = {};
		var coverage = arguments.result.getCoverage();
		var files = arguments.result.getFiles();

		for (var fileIdx in coverage) {
			var fileCoverage = coverage[fileIdx];
			var fileData = files[fileIdx];

			// Validate file has lines data
			if (!structKeyExists(fileData, "lines")) {
				throw "File data missing 'lines' array for file index: " & fileIdx;
			}
			if (!isArray(fileData.lines)) {
				throw "File data 'lines' must be an array for file index: " & fileIdx & ", got: " & getMetadata(fileData.lines).getName();
			}

			var lines = fileData.lines;
			var currentPos = 0;

			// Process each line of coverage
			for (var lineNum in fileCoverage) {
				var lineData = fileCoverage[lineNum];

				if (isArray(lineData) && arrayLen(lineData) >= 2) {
					var hitCount = lineData[1];
					var execTime = lineData[2];

					// Only process lines that were executed
					if (hitCount > 0 && execTime > 0) {
						// Calculate character positions for this line
						var lineIdx = val(lineNum);
						var startPos = getCharacterPositionForLine(lines, lineIdx);
						var endPos = getCharacterPositionForLine(lines, lineIdx + 1) - 1;

						if (startPos >= 0 && endPos > startPos) {
							// Create aggregated key: fileIdx#TAB#startPos#TAB#endPos#TAB#hitCount
							var key = arrayToList([fileIdx, startPos, endPos, hitCount], chr(9));

							// Add or accumulate execution time
							if (structKeyExists(aggregated, key)) {
								aggregated[key] += execTime;
							} else {
								aggregated[key] = execTime;
							}
						}
					}
				}
			}
		}

		return aggregated;
	}

	/**
	 * Gets the character position for a given line number.
	 * Line 1 starts at position 0.
	 */
	private numeric function getCharacterPositionForLine(required array lines, required numeric lineNum) {
		if (arguments.lineNum <= 0 || arguments.lineNum > arrayLen(arguments.lines) + 1) {
			return -1;
		}

		var pos = 0;
		for (var i = 1; i < arguments.lineNum && i <= arrayLen(arguments.lines); i++) {
			pos += len(arguments.lines[i]) + 1; // +1 for newline character
		}
		return pos;
	}

	/**
	 * Updates result stats with child time metrics.
	 */
	private void function updateStatsWithCallTree(required any result, required struct metrics) {
		var stats = arguments.result.getStats();

		// Add child time summary to stats
		stats.childTimeBlocks = arguments.metrics.childTimeBlocks;
		stats.builtInBlocks = arguments.metrics.builtInBlocks;
		stats.totalTime = arguments.metrics.totalTime;
		stats.childTime = arguments.metrics.childTime;
		stats.builtInTime = arguments.metrics.builtInTime;
		stats.childTimePercentage = arguments.metrics.childTimePercentage;
		stats.builtInTimePercentage = arguments.metrics.builtInTimePercentage;

		arguments.result.setStats(stats);
	}
}