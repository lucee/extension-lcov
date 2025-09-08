<cfscript>
	// Function coverage test
	
	function add(a, b) {
		return a + b;
	}
	
	function divide(a, b) {
		if (b == 0) {
			throw(type="DivisionByZero", message="Cannot divide by zero");
		}
		return a / b;
	}
	
	function processArray(arr) {
		if (!isArray(arr)) {
			return [];
		}
		
		result = [];
		for (item in arr) {
			if (isNumeric(item)) {
				arrayAppend(result, item * 2);
			} else {
				arrayAppend(result, item);
			}
		}
		return result;
	}
	
	// Test function calls
	sum = add(5, 3);
	systemOutput("Sum: " & sum, true);
	
	try {
		quotient = divide(10, 2);
		systemOutput("Division: " & quotient, true);
	} catch (any e) {
		systemOutput("Error: " & e.message, true);
	}
	
	testArray = [1, "hello", 3, "world"];
	processed = processArray(testArray);
	systemOutput("Processed array: " & serializeJSON(processed), true);
</cfscript>