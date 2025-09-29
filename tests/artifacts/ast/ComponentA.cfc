component {

	// Component A - calls ComponentB methods

	function init() {
		echo("    ComponentA: init" & chr(10));
		return this;
	}

	function processWithB(data) {
		echo("  ComponentA.processWithB: starting" & chr(10));
		sleep(2); // Own time for this method

		// Create instance of ComponentB and call its methods
		var compB = new ComponentB();
		var transformed = compB.transform(data);
		var validated = compB.validate(transformed);

		echo("  ComponentA.processWithB: completed" & chr(10));
		return validated;
	}

	function analyzeWithB(data) {
		echo("  ComponentA.analyzeWithB: starting" & chr(10));
		sleep(3); // Own time for this method

		// Call ComponentB's analyze method
		var compB = new ComponentB();
		var result = compB.analyze(data);

		// Do some local processing
		result = enhanceResult(result);

		echo("  ComponentA.analyzeWithB: completed" & chr(10));
		return result;
	}

	private function enhanceResult(result) {
		echo("    ComponentA.enhanceResult: running" & chr(10));
		sleep(1); // Own time
		return result & " [enhanced by A]";
	}

	function callChain(data) {
		echo("  ComponentA.callChain: starting" & chr(10));
		sleep(2); // Own time

		// This will create a chain: A -> B -> C
		var compB = new ComponentB();
		var result = compB.callC(data);

		echo("  ComponentA.callChain: completed" & chr(10));
		return result;
	}
}