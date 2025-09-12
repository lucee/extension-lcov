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
	 * Converts time between different units
	 */
	public struct function convertTimeUnit(numeric value, string fromUnit, struct toUnit) {
		if (!isNumeric(arguments.value)) {
			return { time: -1, unit: toUnit.symbol };
		}
		if (arguments.value == 0) {
			return { time: 0, unit: toUnit.symbol };
		}
		var toMicros = {
			"s": 1000000,
			"ms": 1000,
			"μs": 1,
			"ns": 0.001,
			"seconds": 1000000,
			"milli": 1000,
			"micro": 1,
			"nano": 0.001
		};
		var micros = arguments.value * (structKeyExists(toMicros, arguments.fromUnit) ? toMicros[arguments.fromUnit] : 1);
		var targetFactor = structKeyExists(toMicros, arguments.toUnit.symbol) ? toMicros[arguments.toUnit.symbol] : 1;
		return {
			time: numberFormat( int( micros / targetFactor ) ),
			unit: arguments.toUnit.symbol
		};
	}
}
