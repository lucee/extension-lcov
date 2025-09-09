/**
 * Heatmap calculation component for code coverage visualization
 * Handles the generation of CSS rules and styling classes for heatmap visualization
 */
component output="false" {

	/**
	 * Calculates heatmap styles and generates scoped CSS for execution count and time visualization
	 * @param executedLines Struct containing execution data for each line
	 * @param fileLines Array of file lines for reference
	 * @param maxCount Maximum execution count for normalization
	 * @param maxTime Maximum execution time for normalization
	 * @param tableClass Unique CSS class for scoping styles to this file's table
	 * @return struct containing cssRules array and lineClasses struct
	 */
	public struct function calculateHeatmapStyles(struct executedLines, array fileLines, numeric maxCount, numeric maxTime, string tableClass) {
		var cssRules = [];
		var lineClasses = {};
		
		for (var i = 1; i <= arrayLen(fileLines); i++) {
			var lineKey = toString(i);
			var lineData = structKeyExists(executedLines, lineKey) ? executedLines[lineKey] : [];
			var len = arrayLen(lineData);
			
			// Calculate color intensities (0-255) based on relative values
			var countIntensity = (len >= 1 && lineData[1] ?: 0) > 0 && maxCount > 0 ?
				int((lineData[1] / maxCount) * 255) : 0;
			var timeIntensity = (len >= 2 && lineData[2] ?: 0) > 0 && maxTime > 0 ?
				int((lineData[2] / maxTime) * 255) : 0;
			
			// Generate CSS classes for this line
			var countClass = "";
			var timeClass = "";
			
			if (countIntensity > 0) {
				// Convert to intensity level (low/medium/high)
				var countLevel = countIntensity <= 85 ? "low" : (countIntensity <= 170 ? "medium" : "high");
				countClass = "count-" & countLevel;
				arrayAppend(cssRules, "." & tableClass & " .exec-count." & countClass & " { background-color: var(--heatmap-count-" & countLevel & "); }");
			}
			
			if (timeIntensity > 0) {
				// Convert to intensity level (low/medium/high)  
				var timeLevel = timeIntensity <= 85 ? "low" : (timeIntensity <= 170 ? "medium" : "high");
				timeClass = "time-" & timeLevel;
				arrayAppend(cssRules, "." & tableClass & " .exec-time." & timeClass & " { background-color: var(--heatmap-time-" & timeLevel & "); }");
			}
			
			lineClasses[lineKey] = {
				"countClass": countClass,
				"timeClass": timeClass
			};
		}
		
		return {
			"cssRules": cssRules,
			"lineClasses": lineClasses
		};
	}

	/**
	 * Gets intensity level string based on numeric intensity
	 * @param intensity Numeric intensity value (0-255)
	 * @return string Intensity level: "low", "medium", or "high"
	 */
	public string function getIntensityLevel(numeric intensity) {
		return intensity <= 85 ? "low" : (intensity <= 170 ? "medium" : "high");
	}

	/**
	 * Calculates normalized intensity value for a given count/time relative to maximum
	 * @param value The actual count or time value
	 * @param maxValue The maximum value for normalization
	 * @return numeric Intensity value from 0-255
	 */
	public numeric function calculateIntensity(numeric value, numeric maxValue) {
		return value > 0 && maxValue > 0 ? int((value / maxValue) * 255) : 0;
	}
}