component extends="SimpleComponent" {
	
	// Override parent method
	public string function getName() {
		return "DataProcessor extends " & super.getName();
	}
	
	// Method with complex conditional logic
	public any function validateInput(required any input, string type = "string") {
		switch (type) {
			case "string":
				if (!isSimpleValue(input)) {
					throw(type="ValidationError", message="Expected string input");
				}
				return len(trim(input)) > 0;
				
			case "numeric":
				if (!isNumeric(input)) {
					throw(type="ValidationError", message="Expected numeric input");
				}
				return input >= 0;
				
			case "array":
				if (!isArray(input)) {
					throw(type="ValidationError", message="Expected array input");
				}
				return arrayLen(input) > 0;
				
			case "struct":
				if (!isStruct(input)) {
					throw(type="ValidationError", message="Expected struct input");
				}
				return structCount(input) > 0;
				
			default:
				return true;
		}
	}
	
	// Method with nested loops and conditions
	public array function processMatrix(required array matrix) {
		var result = [];
		
		for (var rowIndex = 1; rowIndex <= arrayLen(matrix); rowIndex++) {
			var row = matrix[rowIndex];
			var processedRow = [];
			
			if (!isArray(row)) {
				continue;
			}
			
			for (var colIndex = 1; colIndex <= arrayLen(row); colIndex++) {
				var cell = row[colIndex];
				
				if (isNumeric(cell)) {
					if (cell > 0) {
						arrayAppend(processedRow, cell * 2);
					} else if (cell < 0) {
						arrayAppend(processedRow, abs(cell));
					} else {
						arrayAppend(processedRow, 1);
					}
				} else {
					arrayAppend(processedRow, 0);
				}
			}
			
			arrayAppend(result, processedRow);
		}
		
		return result;
	}
	
	// Method with exception handling
	public struct function safeProcess(required any data) {
		var result = {
			success: false,
			data: "",
			error: ""
		};
		try {
			try {
				if (validateInput(data, "string")) {
					result.data = processValue(data);
					result.success = true;
				} else {
					result.error = "Validation failed";
				}
			} catch (ValidationError e) {
				result.error = "Validation error: " & e.message;
				rethrow;
			} catch (any e) {
				result.error = "Unexpected error: " & e.message;
				throw(type="ProcessingError", message="Failed to process data", cause=e);
			}
		} catch (any outer) {
			return outer;
		}

		return result;
	}
}