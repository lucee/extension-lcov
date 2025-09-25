component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.utils = new lucee.extension.lcov.reporter.HtmlUtils();
	}

	function run() {
		describe("HtmlUtils Clean Execution Time API", function() {

			it("supports all required time units", function() {
				var supportedUnits = variables.utils.getSupportedTimeUnits();
				expect(arrayContains(supportedUnits, "ns")).toBeTrue();
				expect(arrayContains(supportedUnits, "μs")).toBeTrue();
				expect(arrayContains(supportedUnits, "ms")).toBeTrue();
				expect(arrayContains(supportedUnits, "s")).toBeTrue();
				expect(arrayLen(supportedUnits)).toBe(4);
			});

			it("validates time units correctly", function() {
				expect(variables.utils.isValidTimeUnit("ns")).toBeTrue();
				expect(variables.utils.isValidTimeUnit("μs")).toBeTrue();
				expect(variables.utils.isValidTimeUnit("ms")).toBeTrue();
				expect(variables.utils.isValidTimeUnit("s")).toBeTrue();

				expect(variables.utils.isValidTimeUnit("minutes")).toBeFalse();
				expect(variables.utils.isValidTimeUnit("hours")).toBeFalse();
				expect(variables.utils.isValidTimeUnit("xyz")).toBeFalse();
				expect(variables.utils.isValidTimeUnit("")).toBeFalse();
			});

			describe("convertTime function", function() {

				it("converts microseconds to milliseconds", function() {
					var result = variables.utils.convertTime(1500, "μs", "ms");
					expect(result).toBe(1.5);
				});

				it("converts milliseconds to seconds", function() {
					var result = variables.utils.convertTime(2500, "ms", "s");
					expect(result).toBe(2.5);
				});

				it("converts nanoseconds to microseconds", function() {
					var result = variables.utils.convertTime(5000, "ns", "μs");
					expect(result).toBe(5);
				});

				it("handles same unit conversion", function() {
					var result = variables.utils.convertTime(1000, "μs", "μs");
					expect(result).toBe(1000);
				});

				it("handles zero values", function() {
					var result = variables.utils.convertTime(0, "μs", "ms");
					expect(result).toBe(0);
				});

				it("throws error for negative values", function() {
					expect(function() {
						variables.utils.convertTime(-100, "μs", "ms");
					}).toThrow("InvalidTimeValueError");
				});

				it("throws error for invalid fromUnit", function() {
					expect(function() {
						variables.utils.convertTime(100, "invalid", "ms");
					}).toThrow("InvalidTimeUnitError");
				});

				it("throws error for invalid toUnit", function() {
					expect(function() {
						variables.utils.convertTime(100, "μs", "invalid");
					}).toThrow("InvalidTimeUnitError");
				});

			});

			describe("formatTime function", function() {

				it("auto-formats microseconds", function() {
					var result = variables.utils.formatTime(500, "auto", 2);
					expect(result).toBe("500.00 μs");
				});

				it("auto-formats milliseconds", function() {
					var result = variables.utils.formatTime(1500, "auto", 2);
					expect(result).toBe("1.50 ms");
				});

				it("auto-formats seconds", function() {
					var result = variables.utils.formatTime(2500000, "auto", 2);
					expect(result).toBe("2.50 s");
				});

				it("auto-formats small microseconds as nanoseconds", function() {
					var result = variables.utils.formatTime(0.5, "auto", 2);
					expect(result).toBe("500.00 ns");
				});

				it("auto-formats nanoseconds", function() {
					var result = variables.utils.formatTime(0.0005, "auto", 2);
					expect(result).toBe("1.00 ns"); // 0.0005 * 1000 = 0.5, rounds to 1
				});

				it("formats with specific unit", function() {
					var result = variables.utils.formatTime(1500, "ms", 1);
					expect(result).toBe("1.5 ms");
				});

				it("handles zero values", function() {
					var result = variables.utils.formatTime(0);
					expect(result).toBe("0 μs");
				});

				it("handles negative values gracefully", function() {
					var result = variables.utils.formatTime(-100);
					expect(result).toBe("0 μs");
				});

			});

			describe("precision and accuracy", function() {

				it("maintains precision in conversions", function() {
					// Test round-trip conversion with units that don't round
					var original = 2500.0; // Exact value
					var toMs = variables.utils.convertTime(original, "μs", "ms");
					var backToUs = variables.utils.convertTime(toMs, "ms", "μs");
					expect(backToUs).toBe(original); // Should be exact since it rounds to an integer
				});

				it("returns integers for nanoseconds and microseconds", function() {
					var nsResult = variables.utils.convertTime(1500.7, "ns", "μs");
					expect(nsResult).toBe(2); // 1500.7 * 0.001 = 1.5007, rounds to 2
					expect(isNumeric(nsResult) && nsResult == int(nsResult)).toBeTrue("μs result should be integer");

					var usResult = variables.utils.convertTime(2.8, "μs", "ns");
					expect(usResult).toBe(2800); // 2.8 * 1000 = 2800
					expect(isNumeric(usResult) && usResult == int(usResult)).toBeTrue("ns result should be integer");
				});

				it("returns numeric for milliseconds and seconds", function() {
					var msResult = variables.utils.convertTime(1234.567, "μs", "ms");
					expect(msResult).toBe(1.234567);
					expect(isNumeric(msResult)).toBeTrue("ms result should be numeric");

					var sResult = variables.utils.convertTime(2500000.123, "μs", "s");
					expect(sResult).toBe(2.500000123);
					expect(isNumeric(sResult)).toBeTrue("s result should be numeric");
				});

				it("handles very small values", function() {
					var result = variables.utils.convertTime(0.001, "μs", "ns");
					expect(result).toBe(1);  // 0.001 * 1000 = 1.0
				});

				it("handles very large values", function() {
					var result = variables.utils.convertTime(3600000000, "μs", "s");
					expect(result).toBe(3600);
				});

			});

		});
	}

	// Leave test artifacts for inspection - no cleanup in afterAll
}