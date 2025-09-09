/**
 * Color generation component for heatmap visualization
 * Handles RGB color generation with light/dark mode support
 */
component output="false" {

	/**
	 * Generates appropriate text color for contrast based on heatmap level
	 * @param level The current level (1 to bucketCount)
	 * @param bucketCount Total number of buckets
	 * @return string CSS light-dark() function for text color
	 */
	public string function getContrastTextColor(numeric level, numeric bucketCount) {
		// Our generated colors are quite dark even at the "lightest" levels
		// Always use white text in light mode for all heatmap levels to ensure readability
		// The gradient algorithm produces colors that are too dark for black text
		
		// Always use white text for all heatmap levels
		return "light-dark(white, white)";
	}

	/**
	 * Generates a gradient color for a specific level with good contrast for both light and dark modes
	 * @param baseColor Struct with r, g, b values for the base color
	 * @param level The current level (1 to bucketCount)
	 * @param bucketCount Total number of buckets
	 * @return string CSS color-mix() that adapts to both light and dark modes
	 */
	public string function generateGradientColor(struct baseColor, numeric level, numeric bucketCount) {
		// Calculate intensity: level 1 = lightest, highest level = darkest
		// Handle edge case where bucketCount is 1 to avoid division by zero
		var intensity = arguments.bucketCount > 1 ? (arguments.level - 1) / (arguments.bucketCount - 1) : 0; // 0 to 1
		
		// For LIGHT MODE: Use wider brightness range for better differentiation
		// Map intensity from medium-light to very dark
		var lightMinBrightness = 0.15; // Very dark (highest level)
		var lightMaxBrightness = 0.65; // Medium-light (level 1) - readable on white
		var lightBrightness = lightMaxBrightness - (intensity * (lightMaxBrightness - lightMinBrightness));
		
		// For DARK MODE: Use wider brightness range for better differentiation
		// Map intensity from light to medium-dark
		var darkMinBrightness = 0.35; // Medium-dark (highest level)
		var darkMaxBrightness = 0.85; // Light (level 1) - readable on dark
		var darkBrightness = darkMaxBrightness - (intensity * (darkMaxBrightness - darkMinBrightness));
		
		// Use more moderate saturation for better color distinction
		var minSaturation = 0.4;
		var maxSaturation = 0.8;
		var saturation = minSaturation + (intensity * (maxSaturation - minSaturation));
		
		// Generate light mode colors
		var lightR = int(255 * (arguments.baseColor.r / 255.0) * saturation * lightBrightness + 255 * (1 - saturation) * lightBrightness);
		var lightG = int(255 * (arguments.baseColor.g / 255.0) * saturation * lightBrightness + 255 * (1 - saturation) * lightBrightness);
		var lightB = int(255 * (arguments.baseColor.b / 255.0) * saturation * lightBrightness + 255 * (1 - saturation) * lightBrightness);
		
		// Generate dark mode colors
		var darkR = int(255 * (arguments.baseColor.r / 255.0) * saturation * darkBrightness + 255 * (1 - saturation) * darkBrightness);
		var darkG = int(255 * (arguments.baseColor.g / 255.0) * saturation * darkBrightness + 255 * (1 - saturation) * darkBrightness);
		var darkB = int(255 * (arguments.baseColor.b / 255.0) * saturation * darkBrightness + 255 * (1 - saturation) * darkBrightness);
		
		// Clamp values
		lightR = max(0, min(255, lightR));
		lightG = max(0, min(255, lightG));
		lightB = max(0, min(255, lightB));
		darkR = max(0, min(255, darkR));
		darkG = max(0, min(255, darkG));
		darkB = max(0, min(255, darkB));
		
		// Use CSS light-dark() function for automatic mode switching
		return "light-dark(rgb(" & lightR & ", " & lightG & ", " & lightB & "), rgb(" & darkR & ", " & darkG & ", " & darkB & "))";
	}
}