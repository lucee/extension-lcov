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
	echo("Sum: " & sum);
	
	try {
		quotient = divide(10, 2);
		echo("Division: " & quotient);
	} catch (any e) {
		echo("Error: " & e.message);
	}

	function sleeps(){
		sleep(10);
		sleep(25);
		sleep(50);
	}

	sleeps();
	
	testArray = [1, "hello", 3, "world"];
	processed = processArray(testArray);
	echo("Processed array: " & serializeJSON(processed));
</cfscript>