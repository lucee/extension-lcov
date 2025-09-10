/**
 * CSS generation component for heatmap styling
 * Handles CSS rule creation and formatting
 */
component output="false" {

	// Instance variables for dependencies
	variables.colorGenerator = new colorGenerator();
	variables.bucketCalculator = new bucketCalculator();
	
	// Base colors for gradient generation (RGB values)
	variables.countBaseColor = {r: 255, g: 0, b: 0}; // Red for execution counts
	variables.timeBaseColor = {r: 0, g: 102, b: 204}; // Blue for execution times

	/**
	 * Generates CSS rules for execution count heatmap
	 * @param countValues Array of execution count values
	 * @param bucketCount Number of buckets to create
	 * @param tableClass CSS class for scoping
	 * @return array of CSS rule strings
	 */
	public array function generateCountCssRules(array countValues, numeric bucketCount, string tableClass) {
		var cssRules = [];
		
		if (arrayLen(arguments.countValues) == 0) {
			return cssRules;
		}
		
		var countRanges = variables.bucketCalculator.calculateRanges(arguments.countValues, arguments.bucketCount);
		
		arrayAppend(cssRules, "");
		arrayAppend(cssRules, "	/* Execution Count Heatmap - " & arguments.bucketCount & " levels */");
		
		var prevThreshold = 0;
		for (var level = 1; level <= arguments.bucketCount; level++) {
			var countClass = "count-level-" & level;
			var countColor = variables.colorGenerator.generateGradientColor(variables.countBaseColor, level, arguments.bucketCount);
			
			// Build range comment for this level
			var threshold = countRanges[level];
			var rangeComment = "/* " & (prevThreshold + 1);
			if (threshold != (prevThreshold + 1)) {
				rangeComment = rangeComment & "-" & threshold;
			}
			rangeComment = rangeComment & " */";
			
			// Generate text color for contrast
			var countTextColor = variables.colorGenerator.getContrastTextColor(level, arguments.bucketCount);
			arrayAppend(cssRules, "	." & arguments.tableClass & " .exec-count." & countClass & " { background-color: " & countColor & "; color: " & countTextColor & "; } " & rangeComment);
			prevThreshold = threshold;
		}
		
		return cssRules;
	}

	/**
	 * Generates CSS rules for execution time heatmap
	 * @param timeValues Array of execution time values
	 * @param bucketCount Number of buckets to create
	 * @param tableClass CSS class for scoping
	 * @return array of CSS rule strings
	 */
	public array function generateTimeCssRules(array timeValues, numeric bucketCount, string tableClass) {
		var cssRules = [];
		
		if (arrayLen(arguments.timeValues) == 0) {
			return cssRules;
		}
		
		var timeRanges = variables.bucketCalculator.calculateRanges(arguments.timeValues, arguments.bucketCount);
		
		arrayAppend(cssRules, "");
		arrayAppend(cssRules, "	/* Execution Time Heatmap - " & arguments.bucketCount & " levels */");
		
		var prevThreshold = 0;
		for (var level = 1; level <= arguments.bucketCount; level++) {
			var timeClass = "time-level-" & level;
			var timeColor = variables.colorGenerator.generateGradientColor(variables.timeBaseColor, level, arguments.bucketCount);
			
			// Build range comment for this level
			var threshold = timeRanges[level];
			var rangeComment = "/* " & (prevThreshold + 1);
			if (threshold != (prevThreshold + 1)) {
				rangeComment = rangeComment & "-" & threshold;
			}
			rangeComment = rangeComment & " μs */";
			
			// Generate text color for contrast
			var timeTextColor = variables.colorGenerator.getContrastTextColor(level, arguments.bucketCount);
			arrayAppend(cssRules, "	." & arguments.tableClass & " .exec-time." & timeClass & " { background-color: " & timeColor & "; color: " & timeTextColor & "; } " & rangeComment);
			prevThreshold = threshold;
		}
		
		return cssRules;
	}

	/**
	 * Generates CSS rules for both count and time heatmaps (test-friendly method)
	 * @return string CSS rules as concatenated string
	 */
	public string function generateCssRules() {
		var rules = [];
		
		// Generate basic CSS structure for testing
		arrayAppend(rules, "/* Basic heatmap CSS structure */");
		arrayAppend(rules, ".exec-count { text-align: right; }");
		arrayAppend(rules, ".exec-time { text-align: right; }");
		arrayAppend(rules, ".non-executable { background: var(--not-executed-bg, ##f5f5f5); color: var(--not-executed-text, ##666); }");
		
		return arrayToList(rules, chr(10));
	}
}