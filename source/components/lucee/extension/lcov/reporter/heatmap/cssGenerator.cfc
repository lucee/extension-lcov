/**
 * CSS generation component for heatmap visualization
 * Handles CSS rule creation and formatting - completely agnostic to data type
 */
component output="false" {

	variables.colorGenerator = new colorGenerator();
	variables.bucketCalculator = new bucketCalculator();

	/**
	 * Generates CSS rules for heatmap visualization
	 * @param values Array of values to create buckets from
	 * @param bucketCount Number of buckets to create
	 * @param tableClass CSS class for scoping
	 * @param cssClass CSS class name for the heatmap (e.g., "count-level", "time-level")
	 * @param minColor Struct with r, g, b values for minimum value color
	 * @param maxColor Struct with r, g, b values for maximum value color
	 * @param sortDirection "asc" or "desc" for value-to-level mapping
	 * @param unit Optional unit string for comments (e.g., "μs", "%")
	 * @param comment Optional comment for the CSS block
	 * @return array of CSS rule strings
	 */
	public array function generateCssRules(array values, numeric bucketCount, string tableClass, string cssClass, struct minColor, struct maxColor, string sortDirection = "asc", string unit = "", string comment = "Heatmap") {
		var cssRules = [];

		if (arrayLen(arguments.values) == 0) {
			return cssRules;
		}

		var ranges = variables.bucketCalculator.calculateRanges(arguments.values, arguments.bucketCount);

		arrayAppend(cssRules, "");
		arrayAppend(cssRules, "	/* " & arguments.comment & " - " & arguments.bucketCount & " levels */");

		// Extract base class from cssClass (e.g., "exec-count.count-level" -> "exec-count")
		var baseClass = listFirst(arguments.cssClass, ".");

		// Add base class rule for common properties
		arrayAppend(cssRules, "	." & baseClass & " { color: white; border-radius: 3px; padding: 2px 5px; }");

		var prevThreshold = 0;
		for (var level = 1; level <= arguments.bucketCount; level++) {
			var levelClass = arguments.cssClass & "-" & level;
			var levelColor = variables.colorGenerator.generateGradientBetweenColors(arguments.minColor, arguments.maxColor, level, arguments.bucketCount);

			// Build range comment for this level
			var threshold = ranges[level];
			var rangeComment = "/* " & (prevThreshold + 1);
			if (threshold != (prevThreshold + 1)) {
				rangeComment = rangeComment & "-" & threshold;
			}
			if (arguments.unit != "") {
				rangeComment = rangeComment & " " & arguments.unit;
			}
			rangeComment = rangeComment & " */";

			// Generate concise CSS rule - only background color since base class handles the rest
			var cssRule = "	." & arguments.tableClass & " ." & arguments.cssClass & "-" & level & " { background-color: " & levelColor & "; } " & rangeComment;
			arrayAppend(cssRules, cssRule);

			prevThreshold = threshold;
		}

		return cssRules;
	}
}