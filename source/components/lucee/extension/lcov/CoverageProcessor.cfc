component {

	/**
	 * Initialize CoverageProcessor
	 * @logger Logger instance for debugging
	 */
	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Process aggregated coverage entries to line coverage
	 */
	public struct function processAggregatedToLineCoverage(
		struct aggregatedData,
		struct files,
		struct lineMappingsCache,
		any executionLogParser
	) {
		var event = variables.logger.beginEvent("CoverageProcessing");
		event["inputEntries"] = structCount(arguments.aggregatedData);
		var processingStart = getTickCount();
		var coverage = {};

		for (var key in arguments.aggregatedData) {
			var entry = arguments.aggregatedData[key];  // entry is now an array: [fileIdx, startPos, endPos, count, totalTime]
			var fileIdx = entry[1];
			var fpath = arguments.files[fileIdx].path;
			var lineMapping = arguments.lineMappingsCache[fpath];
			var mappingLen = arrayLen(lineMapping);

			// Convert character positions to line numbers
			var startLine = arguments.executionLogParser.getLineFromCharacterPosition(entry[2], fpath, lineMapping, mappingLen);
			var endLine = arguments.executionLogParser.getLineFromCharacterPosition(entry[3], fpath, lineMapping, mappingLen, startLine);

			// Skip invalid positions
			if (startLine == 0 || endLine == 0) {
				continue;
			}

			// Initialize file coverage if needed
			if (!structKeyExists(coverage, fileIdx)) {
				coverage[fileIdx] = {};
			}

			// Add aggregated coverage for each line in the range
			for (var lineNum = startLine; lineNum <= endLine; lineNum++) {
				var lineKey = toString(lineNum);
				if (!structKeyExists(coverage[fileIdx], lineKey)) {
					coverage[fileIdx][lineKey] = [0, 0, 0]; // [hitCount, ownTime, childTime]
				}
				coverage[fileIdx][lineKey][1] += entry[4]; // add aggregated hit count
				coverage[fileIdx][lineKey][2] += entry[5]; // add aggregated execution time
			}
		}

		var processingTime = getTickCount() - processingStart;
		event["outputFiles"] = structCount(coverage);
		variables.logger.commitEvent(event);

		return {
			"coverage": coverage,
			"processingTime": processingTime
		};
	}

}