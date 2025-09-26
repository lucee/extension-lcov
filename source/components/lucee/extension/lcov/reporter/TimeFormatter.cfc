component {

	/**
	 * Constructor to configure the TimeFormatter instance
	 * @displayUnit String display unit ("auto", "ms", "s", etc.)
	 * @return TimeFormatter instance
	 */
	public TimeFormatter function init(string displayUnit = "auto") {
		variables.displayUnit = arguments.displayUnit;
		variables.includeUnits = (arguments.displayUnit == "auto");
		return this;
	}

	/**
	 * Simple format method using instance configuration
	 * @microseconds Numeric time in microseconds (canonical internal unit)
	 * @return String formatted time with or without unit based on instance config
	 */
	public string function format(required numeric microseconds) {
		return formatTime(arguments.microseconds, variables.displayUnit, variables.includeUnits);
	}

	/**
	 * Get the appropriate header text for execution time columns
	 * Uses instance displayUnit if available, otherwise requires displayUnit parameter
	 * @displayUnit String display unit ("auto", "ms", "s", etc.) - optional if instance configured
	 * @return String header text
	 */
	public string function getExecutionTimeHeader(string displayUnit) {
		var unit = structKeyExists(arguments, "displayUnit") ? arguments.displayUnit : variables.displayUnit;
		if (unit == "auto") {
			return "Execution Time";
		} else {
			return "Execution Time (" & unit & ")";
		}
	}

	/**
	 * Format time value with appropriate unit selection and precision
	 * @microseconds Numeric time in microseconds (canonical internal unit)
	 * @targetUnit String target unit for display ("auto" for automatic selection)
	 * @precision Numeric decimal places for formatting
	 * @return String formatted time with unit
	 */
	public string function formatTime(required numeric microseconds, required string targetUnit, boolean includeUnits = true, string mask) {
		// Handle edge cases first
		if (!isNumeric(arguments.microseconds) || arguments.microseconds < 0) {
			throw("Invalid time value: " & arguments.microseconds, "InvalidTimeValueError");
		}
		if (arguments.microseconds == 0) {
			// For zero values, respect includeUnits parameter
			if (arguments.targetUnit != "auto") {
				var unitInfo = getUnitInfo(arguments.targetUnit);
				var _mask = arguments.mask ?: unitInfo.mask;
				return arguments.includeUnits ? "0 " & arguments.targetUnit : "0";
			}
			return arguments.includeUnits ? "0 μs" : "0";
		}

		var unit = arguments.targetUnit;
		var value = -1;

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

		var unitInfo = getUnitInfo(unit);
		var _mask = arguments.mask ?: unitInfo.mask;

		var formattedValue = numberFormat(value, _mask);
		return arguments.includeUnits ? formattedValue & " " & unit : formattedValue;
	}

	
	/**
	 * Convert time between units with consistent parameters and no precision loss
	 * @value Numeric time value to convert
	 * @fromUnit String unit to convert from (ns, μs, ms, s, nano, micro, milli, second)
	 * @toUnit String unit to convert to (ns, μs, ms, s, nano, micro, milli, second)
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
			var allUnits = getSupportedTimeUnits();
			for (var unitName in getUnits()) {
				arrayAppend(allUnits, unitName);
			}
			throw("Invalid fromUnit: " & arguments.fromUnit & ". Supported units: " & arrayToList(allUnits), "InvalidTimeUnitError");
		}
		if (!isValidTimeUnit(arguments.toUnit)) {
			var allUnits = getSupportedTimeUnits();
			for (var unitName in getUnits()) {
				arrayAppend(allUnits, unitName);
			}
			throw("Invalid toUnit: " & arguments.toUnit & ". Supported units: " & arrayToList(allUnits), "InvalidTimeUnitError");
		}

		// Normalize unit names to symbols
		var fromSymbol = normalizeUnit(arguments.fromUnit);
		var toSymbol = normalizeUnit(arguments.toUnit);

		// Convert to canonical microseconds first, then to target unit
		var conversionFactors = getConversionFactors();
		var valueInMicroseconds = arguments.value * conversionFactors[fromSymbol];
		var result = valueInMicroseconds / conversionFactors[toSymbol];

		return result;
	}

	/**
	 * Returns unit information for display
	 */
	public struct function getUnitInfo(required string unit) {
		var units = getUnits();

		// First try direct lookup by unit name
		if (structKeyExists(units, arguments.unit)) {
			return units[arguments.unit];
		}

		// Then try lookup by symbol
		for (var unitName in units) {
			if (units[unitName].symbol == arguments.unit) {
				return units[unitName];
			}
		}

		// If neither works, throw error
		var supportedUnits = [];
		for (var unitName in units) {
			arrayAppend(supportedUnits, unitName & " (" & units[unitName].symbol & ")");
		}
		throw("Invalid unit: " & arguments.unit & ". Supported units: " & arrayToList(supportedUnits), "InvalidUnitError");
	}

	public struct function getUnits() {
		return {
			"second": { symbol: "s", name: "seconds", mask: "0.00," },
			"milli": { symbol: "ms", name: "milliseconds", mask: "," },
			"micro": { symbol: "μs", name: "microseconds", mask: "," },
			"nano": { symbol: "ns", name: "nanoseconds", mask: "," }
		};
	}

	/**
	 * Validate if a unit string is supported
	 * @unit String unit to validate
	 * @return Boolean true if supported
	 */
	public boolean function isValidTimeUnit(required string unit) {
		// Check if it's a unit symbol
		if (arrayContains(getSupportedTimeUnits(), arguments.unit)) {
			return true;
		}
		// Check if it's a unit name from getUnits()
		var units = getUnits();
		return structKeyExists(units, arguments.unit);
	}

	/**
	 * Get array of supported time unit strings (symbols only)
	 * @return Array of supported unit symbols
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
	 * Normalize unit name or symbol to canonical symbol
	 * @unit String unit name or symbol
	 * @return String canonical symbol
	 */
	private string function normalizeUnit(required string unit) {
		// If it's already a symbol, return as-is
		if (arrayContains(getSupportedTimeUnits(), arguments.unit)) {
			return arguments.unit;
		}
		// If it's a unit name, convert to symbol
		var units = getUnits();
		if (structKeyExists(units, arguments.unit)) {
			return units[arguments.unit].symbol;
		}
		// This shouldn't happen if isValidTimeUnit passed, but just in case
		throw("Cannot normalize unit: " & arguments.unit);
	}

}
