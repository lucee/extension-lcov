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
		
		// For LIGHT MODE: Use brightness range that works with pure red (max ~0.299)
		var lightMinBrightness = 0.15; // Very dark (highest level) - accessibility minimum  
		var lightMaxBrightness = 0.299; // Maximum brightness possible with pure red
		var targetLightBrightness = lightMaxBrightness - (intensity * (lightMaxBrightness - lightMinBrightness));
		
		// For DARK MODE: Use wider brightness range for better differentiation  
		var darkMinBrightness = 0.35; // Medium-dark (highest level)
		var darkMaxBrightness = 0.85; // Light (level 1) - readable on dark
		var targetDarkBrightness = darkMaxBrightness - (intensity * (darkMaxBrightness - darkMinBrightness));
		
		// Generate light mode colors using direct brightness calculation
		// Use the luminance formula: 0.299*R + 0.587*G + 0.114*B = target brightness
		var lightColors = generateRGBFromBrightness(arguments.baseColor, targetLightBrightness);
		var darkColors = generateRGBFromBrightness(arguments.baseColor, targetDarkBrightness);
		
		// Use CSS light-dark() function for automatic mode switching
		return "light-dark(rgb(" & lightColors.r & ", " & lightColors.g & ", " & lightColors.b & "), rgb(" & darkColors.r & ", " & darkColors.g & ", " & darkColors.b & "))";
	}
	
	/**
	 * Generate RGB values that produce a specific brightness level
	 * @param baseColor Base color struct with r, g, b values (0-255)
	 * @param targetBrightness Target brightness (0-1)
	 * @return struct with r, g, b values that produce the target brightness
	 */
	private struct function generateRGBFromBrightness(struct baseColor, numeric targetBrightness) {
		// Calculate luminance weights: 0.299*R + 0.587*G + 0.114*B = brightness
		var rWeight = 0.299;
		var gWeight = 0.587;
		var bWeight = 0.114;

		// Normalize the base color to get the color ratios
		var totalBase = arguments.baseColor.r + arguments.baseColor.g + arguments.baseColor.b;
		if (totalBase == 0) {
			// If base color is black, default to equal distribution
			return {r: 0, g: 0, b: 0};
		}

		var rRatio = arguments.baseColor.r / totalBase;
		var gRatio = arguments.baseColor.g / totalBase;
		var bRatio = arguments.baseColor.b / totalBase;

		// Scale the color to achieve target brightness
		// We need to solve: brightness = (rWeight*r + gWeight*g + bWeight*b) / 255
		// Where r, g, b maintain the same ratios as the base color
		var scaleFactor = arguments.targetBrightness * 255 / (rWeight * rRatio + gWeight * gRatio + bWeight * bRatio);

		var r = max(0, min(255, int(rRatio * scaleFactor)));
		var g = max(0, min(255, int(gRatio * scaleFactor)));
		var b = max(0, min(255, int(bRatio * scaleFactor)));

		return {r: r, g: g, b: b};
	}

	/**
	 * Generates a gradient color between two colors for a specific level
	 * @param minColor Struct with r, g, b values for minimum color (level 1)
	 * @param maxColor Struct with r, g, b values for maximum color (highest level)
	 * @param level The current level (1 to bucketCount)
	 * @param bucketCount Total number of buckets
	 * @return string CSS light-dark() function for the interpolated color
	 */
	public string function generateGradientBetweenColors(struct minColor, struct maxColor, numeric level, numeric bucketCount) {
		// Calculate interpolation factor: level 1 = 0 (minColor), highest level = 1 (maxColor)
		var factor = arguments.bucketCount > 1 ? (arguments.level - 1) / (arguments.bucketCount - 1) : 0;

		// Interpolate between min and max colors for light mode
		var lightR = int(arguments.minColor.r + factor * (arguments.maxColor.r - arguments.minColor.r));
		var lightG = int(arguments.minColor.g + factor * (arguments.maxColor.g - arguments.minColor.g));
		var lightB = int(arguments.minColor.b + factor * (arguments.maxColor.b - arguments.minColor.b));

		// For dark mode, generate darker variants that work well on dark backgrounds
		// Apply a darkening factor to make colors suitable for dark themes
		var darkenFactor = 0.6; // Make colors 60% darker for dark mode
		var darkR = int(lightR * darkenFactor);
		var darkG = int(lightG * darkenFactor);
		var darkB = int(lightB * darkenFactor);

		return "light-dark(rgb(" & lightR & ", " & lightG & ", " & lightB & "), rgb(" & darkR & ", " & darkG & ", " & darkB & "))";
	}
}