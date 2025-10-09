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
		var unit = arguments.displayUnit ?: variables.displayUnit;
		if (unit == "auto") {
			return "Execution Time";
		} else {
			var unitSymbol = getUnitInfo(unit).symbol;
			return "Execution Time (" & unitSymbol & ")";
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

		// OPTIMIZATION: Skip numberFormat for small integers (0-999)
		// These don't need formatting and toString is 86% faster
		var formattedValue;
		if (value < 1000 && value == int(value)) {
			formattedValue = toString(int(value));
		} else {
			// Only get mask when we actually need it for numberFormat
			var _mask = arguments.mask ?: "";
			if (_mask == "") {
				// Only seconds needs decimal places
				_mask = (unit == "s") ? "0.00," : ",";
			}
			formattedValue = numberFormat(value, _mask);
		}

		// When including units, use the symbol (e.g., "ms") not the name (e.g., "milli")
		if (arguments.includeUnits) {
			var unitSymbol = getUnitInfo(unit).symbol;
			return formattedValue & " " & unitSymbol;
		}
		return formattedValue;
	}

	
	/**
	 * Convert time between units with consistent parameters and no precision loss
	 * OPTIMIZED: Using integer math and simple switch for performance
	 * @value Numeric time value to convert
	 * @fromUnit String unit to convert from (ns, μs, ms, s)
	 * @toUnit String unit to convert to (ns, μs, ms, s)
	 * @return Numeric converted time value
	 */
	public numeric function convertTime(required numeric value, required string fromUnit, required string toUnit) {
		// Fast path for zero
		if (arguments.value == 0) {
			return 0;
		}

		// Fast path for same unit
		if (arguments.fromUnit == arguments.toUnit) {
			return arguments.value;
		}

		// Convert to microseconds (base unit) using integer operations
		var valueInMicroseconds = arguments.value;

		switch(arguments.fromUnit) {
			case "ns": valueInMicroseconds = arguments.value / 1000; break;
			case "μs": valueInMicroseconds = arguments.value; break;
			case "ms": valueInMicroseconds = arguments.value * 1000; break;
			case "s": valueInMicroseconds = arguments.value * 1000000; break;
		}

		// Convert from microseconds to target unit
		switch(arguments.toUnit) {
			case "ns": return valueInMicroseconds * 1000;
			case "μs": return valueInMicroseconds;
			case "ms": return valueInMicroseconds / 1000;
			case "s": return valueInMicroseconds / 1000000;
		}

		// Should never reach here with valid units
		return valueInMicroseconds;
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
