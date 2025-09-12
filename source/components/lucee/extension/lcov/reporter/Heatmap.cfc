/**
 * Main heatmap orchestrator for code coverage visualization
 * Coordinates between specialized components for modular functionality
 */
component output="false" {

	// Default number of heatmap buckets (can be reduced if insufficient data)
	variables.defaultBucketCount = 10;
	
	// Component dependencies
	variables.colorGenerator = new heatmap.colorGenerator();
	variables.bucketCalculator = new heatmap.bucketCalculator();
	variables.cssGenerator = new heatmap.cssGenerator();

	/**
	 * Calculates heatmap styles and generates scoped CSS for execution count and time visualization
	 * @param executedLines Struct containing execution data for each line
	 * @param fileLines Array of file lines for reference
	 * @param tableClass Unique CSS class for scoping styles to this file's table
	 * @param bucketCount Number of heatmap buckets to use (optional, defaults to 10)
	 * @return struct containing cssRules array and lineClasses struct
	 */
	public struct function calculateHeatmapStyles(struct executedLines, array fileLines, string tableClass, numeric bucketCount = 10) {
		// PASS 1: Extract execution values from data
		var executionData = extractExecutionValues(arguments.executedLines, arguments.fileLines);
		
		// PASS 2: Calculate optimal bucket counts
		var bucketCounts = variables.bucketCalculator.calculateOptimalBucketCounts(executionData.countValues, executionData.timeValues, arguments.bucketCount);
		
		// PASS 3: Generate CSS rules
		var cssRules = [];
		arrayAppend(cssRules, variables.cssGenerator.generateCountCssRules(executionData.countValues, bucketCounts.countBucketCount, arguments.tableClass), true);
		arrayAppend(cssRules, variables.cssGenerator.generateTimeCssRules(executionData.timeValues, bucketCounts.timeBucketCount, arguments.tableClass), true);
		
		// PASS 4: Assign line classes
		var countRanges = variables.bucketCalculator.calculateRanges(executionData.countValues, bucketCounts.countBucketCount);
		var timeRanges = variables.bucketCalculator.calculateRanges(executionData.timeValues, bucketCounts.timeBucketCount);
		var lineClasses = assignLineClasses(arguments.executedLines, arguments.fileLines, countRanges, timeRanges);
		
		return {
			"cssRules": cssRules,
			"lineClasses": lineClasses
		};
	}

	/**
	 * Extracts execution count and time values from line data
	 * @param executedLines Struct containing execution data for each line
	 * @param fileLines Array of file lines for reference
	 * @return struct containing countValues and timeValues arrays
	 */
	public struct function extractExecutionValues(struct executedLines, array fileLines) {
		var countValues = [];
		var timeValues = [];
		
		for (var i = 1; i <= arrayLen(arguments.fileLines); i++) {
			var lineKey = toString(i);
			var lineData = structKeyExists(arguments.executedLines, lineKey) ? arguments.executedLines[lineKey] : [];
			var len = arrayLen(lineData);
			
			if (len > 0) {
				// Fail fast if data structure is incorrect
				if (len != 2) {
					throw(type="InvalidDataStructure", message="Line execution data must contain exactly 2 elements [count, time]", detail="Line #i# has #len# elements: #serializeJSON(lineData)#");
				}
				
				var countVal = lineData[1] ?: 0;
				var timeVal = lineData[2] ?: 0;
				if (countVal > 0) arrayAppend(countValues, countVal);
				// Include zero execution times in heatmap range calculation
				if (isNumeric(lineData[2])) arrayAppend(timeValues, timeVal);
			}
		}
		
		return {
			"countValues": countValues,
			"timeValues": timeValues
		};
	}

	/**
	 * Assigns CSS classes to individual lines based on execution data
	 * @param executedLines Struct containing execution data for each line
	 * @param fileLines Array of file lines for reference
	 * @param countRanges Array of threshold values for count buckets
	 * @param timeRanges Array of threshold values for time buckets
	 * @return struct mapping line keys to CSS class information
	 */
	public struct function assignLineClasses(struct executedLines, array fileLines, array countRanges, array timeRanges) {
		var lineClasses = {};
		
		for (var i = 1; i <= arrayLen(arguments.fileLines); i++) {
			var lineKey = toString(i);
			var lineData = structKeyExists(arguments.executedLines, lineKey) ? arguments.executedLines[lineKey] : [];
			var len = arrayLen(lineData);
			
			// Generate CSS classes for this line
			var countClass = "";
			var timeClass = "";
			
			if (len > 0) {
				var countVal = lineData[1] ?: 0;
				var timeVal = lineData[2] ?: 0;

				if (countVal > 0) {
					var countLevel = variables.bucketCalculator.getValueLevel(countVal, arguments.countRanges);
					countClass = "count-level-" & countLevel;
				}

				// Include zero execution times in heatmap (assign to lowest level)
				if (len >= 2 && isNumeric(lineData[2]) && arrayLen(arguments.timeRanges) > 0) {
					var timeLevel = variables.bucketCalculator.getValueLevel(timeVal, arguments.timeRanges);
					timeClass = "time-level-" & timeLevel;
				}
			}
			
			lineClasses[lineKey] = {
				"countClass": countClass,
				"timeClass": timeClass
			};
		}
		
		return lineClasses;
	}


}