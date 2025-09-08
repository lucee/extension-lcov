component accessors="true" {
	
	property name="precision" type="numeric" default="2";
	
	// Constructor
	public MathUtils function init(numeric precision = 2) {
		setPrecision(precision);
		return this;
	}
	
	// Static-style method
	public numeric function add(required numeric a, required numeric b) {
		return round(a + b, getPrecision());
	}
	
	public numeric function subtract(required numeric a, required numeric b) {
		return round(a - b, getPrecision());
	}
	
	public numeric function multiply(required numeric a, required numeric b) {
		return round(a * b, getPrecision());
	}
	
	public numeric function divide(required numeric a, required numeric b) {
		if (b == 0) {
			throw(type="MathUtils.DivisionByZero", message="Cannot divide by zero");
		}
		return round(a / b, getPrecision());
	}
	
	// Method with loops
	public numeric function factorial(required numeric n) {
		if (n < 0) {
			throw(type="MathUtils.InvalidInput", message="Factorial is not defined for negative numbers");
		}
		
		if (n <= 1) {
			return 1;
		}
		
		var result = 1;
		for (var i = 2; i <= n; i++) {
			result *= i;
		}
		return result;
	}
	
	// Method with array processing
	public struct function arrayStats(required array numbers) {
		if (arrayLen(numbers) == 0) {
			return {
				sum: 0,
				average: 0,
				min: 0,
				max: 0,
				count: 0
			};
		}
		
		var sum = 0;
		var min = numbers[1];
		var max = numbers[1];
		
		for (var num in numbers) {
			if (!isNumeric(num)) {
				continue;
			}
			
			sum += num;
			if (num < min) min = num;
			if (num > max) max = num;
		}
		
		return {
			sum: round(sum, getPrecision()),
			average: round(sum / arrayLen(numbers), getPrecision()),
			min: min,
			max: max,
			count: arrayLen(numbers)
		};
	}
}