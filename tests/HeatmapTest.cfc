component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe("Heatmap Business Rules", function() {
			
			beforeEach(function() {
				variables.colorGenerator = new lucee.extension.lcov.reporter.heatmap.colorGenerator();
				variables.bucketCalculator = new lucee.extension.lcov.reporter.heatmap.bucketCalculator();
				variables.cssGenerator = new lucee.extension.lcov.reporter.heatmap.cssGenerator();
			});

			// ========== COLOR GENERATION BUSINESS RULES ==========
			
			describe("Color Generation Rules", function() {
				
				it("should generate gradient from light to dark intensity", function() {
					var baseColor = {r: 255, g: 0, b: 0}; // Red base color
					var color1 = colorGenerator.generateGradientColor(baseColor, 1, 10); // Lightest (level 1)
					var color10 = colorGenerator.generateGradientColor(baseColor, 10, 10); // Darkest (level 10)
					
					var intensity1 = extractIntensityFromColor(color1);
					var intensity10 = extractIntensityFromColor(color10);
					
					expect(intensity1).toBeLT(intensity10, "Level 1 should be lighter than level 10");
					expect(intensity1).toBeGTE(0, "Intensity should be >= 0");
					expect(intensity10).toBeLTE(1, "Intensity should be <= 1");
				});

				it("should maintain brightness range 0.15-0.65", function() {
					var baseColor = {r: 255, g: 0, b: 0}; // Red base color
					for (var i = 1; i <= 10; i++) {
						var color = colorGenerator.generateGradientColor(baseColor, i, 10);
						var brightness = extractBrightnessFromColor(color);
						
						expect(round(brightness, 2)).toBeGTE(0.15, "Brightness should be >= 0.15 for bucket #i#");
						expect(round(brightness, 2)).toBeLTE(0.65, "Brightness should be <= 0.65 for bucket #i#");
					}
				});

				it("should return valid light-dark CSS format", function() {
					var baseColor = {r: 255, g: 0, b: 0}; // Red base color
					for (var i = 1; i <= 10; i++) {
						var color = colorGenerator.generateGradientColor(baseColor, i, 10);
						
						expect(color).toInclude("light-dark(", "Should use CSS light-dark function for level #i#");
						expect(color).toInclude("rgb(", "Should contain RGB color values for level #i#");
						expect(color).toMatch("light-dark\s*\(\s*rgb\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)", "Should match RGB pattern for level #i#");
					}
				});

				it("should always use white text regardless of background", function() {
					for (var i = 1; i <= 10; i++) {
						var textColor = colorGenerator.getContrastTextColor(i, 10);
						expect(textColor).toBe("light-dark(white, white)", "Text should always be white for bucket #i#");
					}
				});

				it("should distribute brightness evenly across buckets", function() {
					var colors = [];
					var totalBuckets = 5;
					var baseColor = {r: 255, g: 0, b: 0}; // Red base color
					
					for (var i = 1; i <= totalBuckets; i++) {
						arrayAppend(colors, colorGenerator.generateGradientColor(baseColor, i, totalBuckets));
					}
					
					var brightnesses = [];
					for (var color in colors) {
						arrayAppend(brightnesses, extractBrightnessFromColor(color));
					}
					
					// Check that brightness decreases from level 1 to max level
					for (var i = 2; i <= arrayLen(brightnesses); i++) {
						expect(brightnesses[i]).toBeLT(brightnesses[i-1], "Level #i# should be darker than level #(i-1)#");
					}
				});
			});

			// ========== BUCKET ASSIGNMENT BUSINESS RULES ==========
			
			describe("Bucket Assignment Logic", function() {
				
				it("should assign bucket 0 to fastest execution times", function() {
					var times = [100, 500, 1000, 2000];
					var buckets = bucketCalculator.calculateBuckets(times, 4);
					
					expect(buckets[100]).toBe(0, "Fastest time (100) should be in bucket 0");
				});

				it("should assign highest bucket to slowest execution times", function() {
					var times = [100, 500, 1000, 2000];
					var totalBuckets = 4;
					var buckets = bucketCalculator.calculateBuckets(times, totalBuckets);
					
					expect(buckets[2000]).toBe(totalBuckets - 1, "Slowest time (2000) should be in highest bucket");
				});

				it("should keep all bucket values within valid range", function() {
					var times = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
					var totalBuckets = 5;
					var buckets = bucketCalculator.calculateBuckets(times, totalBuckets);
					
					for (var time in structKeyArray(buckets)) {
						var bucket = buckets[time];
						expect(bucket).toBeGTE(0, "Bucket for time #time# should be >= 0");
						expect(bucket).toBeLT(totalBuckets, "Bucket for time #time# should be < #totalBuckets#");
					}
				});

				it("should exclude zero execution times from heatmap calculation", function() {
					var times = [0, 100, 200, 300];
					var buckets = bucketCalculator.calculateBuckets(times, 3);
					
					expect(buckets).notToHaveKey(0, "Zero execution times should not be in buckets");
					expect(structCount(buckets)).toBe(3, "Only non-zero times should be bucketed");
				});
			});

			// ========== VISUAL STYLING BUSINESS RULES ==========
			
			describe("Visual Styling Rules", function() {
				
				it("should right-align numeric cells (time/count)", function() {
					var cssContent = cssGenerator.generateCssRules();
					
					expect(cssContent).toInclude(".exec-count", "CSS should contain exec-count class");
					expect(cssContent).toInclude(".exec-time", "CSS should contain exec-time class");
					expect(cssContent).toInclude("text-align: right", "Numeric cells should be right-aligned");
				});

				it("should use light-dark CSS function for dual-mode theming", function() {
					var textColor = colorGenerator.getContrastTextColor(5, 10);
					expect(textColor).toInclude("light-dark(", "Should use CSS light-dark function");
				});

				it("should use separate styling for not-executed lines", function() {
					var cssContent = cssGenerator.generateCssRules();
					
					expect(cssContent).toInclude("non-executable", "Should have non-executable class");
					expect(cssContent).notToInclude("##heatmap-non-executable", "Non-executed lines should not use heatmap colors");
				});
			});

			// ========== ACCESSIBILITY BUSINESS RULES ==========
			
			describe("Accessibility Requirements", function() {
				
				it("should ensure WCAG contrast compliance with white text", function() {
					for (var i = 0; i < 10; i++) {
						var textColor = colorGenerator.getContrastTextColor(i, 10);
						expect(textColor).toBe("light-dark(white, white)", "White text ensures maximum contrast for bucket #i#");
					}
				});

				it("should provide dark mode support through CSS variables", function() {
					var cssContent = cssGenerator.generateCssRules();
					
					expect(cssContent).toInclude("--not-executed-bg", "Should define dark mode background variable");
					expect(cssContent).toInclude("--not-executed-text", "Should define dark mode text variable");
				});
			});

			// ========== EDGE CASES AND DATA VALIDATION ==========
			
			describe("Edge Cases and Data Validation", function() {
				
				it("should handle single bucket scenarios", function() {
					var times = [500];
					var buckets = bucketCalculator.calculateBuckets(times, 1);
					
					expect(structCount(buckets)).toBe(1, "Should handle single time value");
					expect(buckets[500]).toBe(0, "Single time should be in bucket 0");
				});

				it("should handle empty data gracefully", function() {
					var times = [];
					var buckets = bucketCalculator.calculateBuckets(times, 5);
					
					expect(structCount(buckets)).toBe(0, "Empty data should result in empty buckets");
				});

				it("should handle identical execution times", function() {
					var times = [100, 100, 100, 100];
					var buckets = bucketCalculator.calculateBuckets(times, 3);
					
					var firstBucket = buckets[100];
					for (var time in structKeyArray(buckets)) {
						expect(buckets[time]).toBe(firstBucket, "All identical times should be in same bucket");
					}
				});

				it("should handle large datasets efficiently", function() {
					var times = [];
					for (var i = 1; i <= 1000; i++) {
						arrayAppend(times, i * 10);
					}
					
					var startTime = getTickCount();
					var buckets = bucketCalculator.calculateBuckets(times, 50);
					var endTime = getTickCount();
					
					expect(endTime - startTime).toBeLT(1000, "Should process 1000 times in < 1 second");
					expect(structCount(buckets)).toBe(1000, "Should handle all 1000 data points");
				});

				it("should maintain performance with many buckets", function() {
					var times = [];
					for (var i = 1; i <= 500; i++) {
						arrayAppend(times, randRange(1, 10000));
					}
					
					var startTime = getTickCount();
					var buckets = bucketCalculator.calculateBuckets(times, 100);
					var endTime = getTickCount();
					
					expect(endTime - startTime).toBeLT(500, "Should handle 100 buckets efficiently");
					
					// Verify bucket range validity
					for (var time in structKeyArray(buckets)) {
						var bucket = buckets[time];
						expect(bucket).toBeGTE(0, "Bucket should be >= 0");
						expect(bucket).toBeLT(100, "Bucket should be < 100");
					}
				});
			});
		});
	}

	// ========== HELPER FUNCTIONS ==========
	
	private function extractBrightnessFromColor(required string color) {
		// Extract RGB values from light-dark() format and calculate relative brightness
		// Format: "light-dark(rgb(r, g, b), rgb(r, g, b))"
		var matches = reFind("light-dark\s*\(\s*rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)", arguments.color, 1, true);
		if (matches.pos[1] > 0 && arrayLen(matches.pos) > 3) {
			var r = mid(arguments.color, matches.pos[2], matches.len[2]) / 255.0;
			var g = mid(arguments.color, matches.pos[3], matches.len[3]) / 255.0;
			var b = mid(arguments.color, matches.pos[4], matches.len[4]) / 255.0;
			
			// Calculate relative luminance (brightness)
			return 0.299 * r + 0.587 * g + 0.114 * b;
		}
		return 0;
	}

	private function extractIntensityFromColor(required string color) {
		// Calculate color intensity based on how dark/light the RGB values are
		// Lower values = lighter (green end), higher values = darker (red end)
		var brightness = extractBrightnessFromColor(arguments.color);
		
		// Map brightness range (0.15-0.65) to intensity (0-1)
		var minBrightness = 0.15;
		var maxBrightness = 0.65;
		
		if (brightness <= minBrightness) return 1.0; // Darkest (red)
		if (brightness >= maxBrightness) return 0.0; // Lightest (green)
		
		// Linear interpolation between min and max
		return (maxBrightness - brightness) / (maxBrightness - minBrightness);
	}
}