component {
	
	// Public method
	public string function getName() {
		return "SimpleComponent";
	}
	
	// Private method
	private numeric function calculate(required numeric a, required numeric b) {
		return a * b;
	}
	
	// Method with conditional logic
	public any function processValue(required any value) {
		if (isNumeric(value)) {
			return value * 2;
		} else if (isSimpleValue(value)) {
			return uCase(value);
		} else {
			return "";
		}
	}
	
	// Method that calls other methods
	public struct function getInfo() {
		var result = {};
		result.name = getName();
		result.calculation = calculate(5, 10);
		result.processed = processValue("test");
		return result;
	}
}