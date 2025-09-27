/**
 * Agnostic heatmap generator - handles a single dataset with configurable colors
 * Completely generic - has no knowledge of what data it's visualizing
 */
component output="false" {

	// Component dependencies
	variables.colorGenerator = new heatmap.colorGenerator();
	variables.bucketCalculator = new heatmap.bucketCalculator();
	variables.cssGenerator = new heatmap.cssGenerator();

	/**
	 * Generates CSS rules and value classifier for a single heatmap
	 * @param values Array of numeric values to create heatmap from
	 * @param bucketCount Number of buckets to create
	 * @param tableClass CSS class for scoping
	 * @param cssClass CSS class name for the heatmap (e.g., "exec-count.count-level")
	 * @param minColor Struct with r, g, b values for minimum value color
	 * @param maxColor Struct with r, g, b values for maximum value color
	 * @param sortDirection "asc" or "desc" for value-to-level mapping
	 * @param unit Optional unit string for comments (e.g., "μs", "%")
	 * @param comment Optional comment for the CSS block
	 * @return struct containing cssRules array and getValueClass function
	 */
	public struct function generate(array values, numeric bucketCount, string tableClass, string cssClass, struct minColor, struct maxColor, string sortDirection = "asc", string unit = "", string comment = "Heatmap") {

		if (arrayLen(arguments.values) == 0) {
			return {
				"cssRules": [],
				"ranges": [],
				"getValueClass": function(value) { return ""; }
			};
		}

		// Generate CSS rules
		var cssRules = variables.cssGenerator.generateCssRules(
			arguments.values,
			arguments.bucketCount,
			arguments.tableClass,
			arguments.cssClass,
			arguments.minColor,
			arguments.maxColor,
			arguments.sortDirection,
			arguments.unit,
			arguments.comment
		);

		// Calculate value ranges for classification
		var ranges = variables.bucketCalculator.calculateRanges(arguments.values, arguments.bucketCount);

		// Capture values for closure
		var sortDir = arguments.sortDirection;
		var cssClassName = arguments.cssClass;

		// Extract the last part of cssClass for the level class prefix
		var classParts = listToArray(cssClassName, ".");
		var classPrefix = classParts[arrayLen(classParts)];

		// Pre-compute lookup array for common values (0-1000)
		// This covers 99% of real-world coverage execution counts
		var lookupArray = [];
		for (var i = 0; i <= 1000; i++) {
			if (i == 0) {
				lookupArray[i + 1] = "";
			} else {
				var level = variables.bucketCalculator.getValueLevel(i, ranges, sortDir);
				lookupArray[i + 1] = classPrefix & "-" & level;
			}
		}

		// Pre-compute class for values > 1000 (they all map to highest bucket)
		var maxLevel = arrayLen(ranges);
		if (sortDir == "desc") {
			maxLevel = 1;
		}
		var highValueClass = classPrefix & "-" & maxLevel;

		// Return optimized function to classify values
		var getValueClass = function(value) {
			if (!isNumeric(value) || value < 0) return "";

			// Ultra-fast lookup for common values (0-1000)
			if (value <= 1000) {
				return lookupArray[value + 1];
			}

			// Rare case: values > 1000 go to highest bucket
			return highValueClass;
		};

		return {
			"cssRules": cssRules,
			"ranges": ranges,
			"getValueClass": getValueClass
		};
	}

}