component {
	// Shared helpers for encoding, formatting, etc. (if needed)

	/**
	 * Returns unit information for display
	 */
	public struct function getUnitInfo(string unit) {
		var units = getUnits();
		return structKeyExists(units, arguments.unit) ? units[arguments.unit] : units["micro"];
	}

	public struct function getUnits() {
		return {
			"seconds": { symbol: "s", name: "seconds" },
			"milli": { symbol: "ms", name: "milliseconds" },
			"micro": { symbol: "μs", name: "microseconds" },
			"nano": { symbol: "ns", name: "nanoseconds" }
		};
	}

	/**
	 * CLEAN NEW API - Convert time between units with consistent parameters and no precision loss
	 * @value Numeric time value to convert
	 * @fromUnit String unit to convert from (ns, μs, ms, s)
	 * @toUnit String unit to convert to (ns, μs, ms, s)
	 * @return Numeric converted time value (integers for ns/μs, numeric for ms/s)
	 */
	public numeric function convertTime(required numeric value, required string fromUnit, required string toUnit) {
		if (!isNumeric(arguments.value) || arguments.value < 0) {
			throw("Invalid time value: " & arguments.value, "InvalidTimeValueError");
		}
		if (arguments.value == 0) {
			return 0;
		}
		if (!isValidTimeUnit(arguments.fromUnit)) {
			throw("Invalid fromUnit: " & arguments.fromUnit & ". Supported units: " & arrayToList(getSupportedTimeUnits()), "InvalidTimeUnitError");
		}
		if (!isValidTimeUnit(arguments.toUnit)) {
			throw("Invalid toUnit: " & arguments.toUnit & ". Supported units: " & arrayToList(getSupportedTimeUnits()), "InvalidTimeUnitError");
		}

		// Convert to canonical microseconds first, then to target unit
		var conversionFactors = getConversionFactors();
		var valueInMicroseconds = arguments.value * conversionFactors[arguments.fromUnit];
		var result = valueInMicroseconds / conversionFactors[arguments.toUnit];

		// Return integers for nanoseconds and microseconds (discrete units)
		if (arguments.toUnit == "ns" || arguments.toUnit == "μs") {
			return round(result);
		}

		return result;
	}

	/**
	 * Format time value with appropriate unit selection and precision
	 * @microseconds Numeric time in microseconds (canonical internal unit)
	 * @targetUnit String target unit for display ("auto" for automatic selection)
	 * @precision Numeric decimal places for formatting
	 * @return String formatted time with unit
	 */
	public string function formatTime(required numeric microseconds, string targetUnit = "auto", numeric precision = 2) {
		if (!isNumeric(arguments.microseconds) || arguments.microseconds < 0) {
			return "0 μs";
		}
		if (arguments.microseconds == 0) {
			// For zero values, respect the requested target unit
			if (arguments.targetUnit != "auto") {
				return "0 " & arguments.targetUnit;
			}
			return "0 μs";
		}

		var unit = arguments.targetUnit;
		var value = arguments.microseconds;

		// Auto-select appropriate unit based on magnitude
		if (arguments.targetUnit == "auto") {
			if (arguments.microseconds >= 1000000) {
				unit = "s";
				value = convertTime(arguments.microseconds, "μs", "s");
			} else if (arguments.microseconds >= 1000) {
				unit = "ms";
				value = convertTime(arguments.microseconds, "μs", "ms");
			} else if (arguments.microseconds >= 1) {
				unit = "μs";
				value = arguments.microseconds;
			} else {
				unit = "ns";
				value = convertTime(arguments.microseconds, "μs", "ns");
			}
		} else {
			value = convertTime(arguments.microseconds, "μs", arguments.targetUnit);
		}

		return numberFormat(value, "0." & repeatString("0", arguments.precision)) & " " & unit;
	}

	/**
	 * Validate if a unit string is supported
	 * @unit String unit to validate
	 * @return Boolean true if supported
	 */
	public boolean function isValidTimeUnit(required string unit) {
		return arrayContains(getSupportedTimeUnits(), arguments.unit);
	}

	/**
	 * Get array of supported time unit strings
	 * @return Array of supported unit strings
	 */
	public array function getSupportedTimeUnits() {
		return ["ns", "μs", "ms", "s"];
	}

	/**
	 * Get conversion factors to microseconds (canonical internal unit)
	 * Simple, clean mapping with no duplicate keys
	 * @return Struct with conversion factors
	 */
	private struct function getConversionFactors() {
		return {
			"ns": 0.001,      // nanoseconds to microseconds
			"μs": 1.0,        // microseconds (canonical)
			"ms": 1000.0,     // milliseconds to microseconds
			"s": 1000000.0    // seconds to microseconds
		};
	}


	/**
	 * Safely contracts a file path , falling back to original path if contraction fails
	 */
	public string function safeContractPath(required string filePath) {
		try {
			var contractedPath = contractPath(arguments.filePath);
			return (isNull(contractedPath) || contractedPath == "null" || contractedPath contains "null") 
				? arguments.filePath : contractedPath;
		} catch (any e) {
			return arguments.filePath;
		}
	}
}
