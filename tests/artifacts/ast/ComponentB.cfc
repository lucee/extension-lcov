component {

	// Component B - called by ComponentA, calls ComponentC

	function init() {
		echo("      ComponentB: init" & chr(10));
		return this;
	}

	function transform(data) {
		echo("    ComponentB.transform: running" & chr(10));
		sleep(5); // Simulate transformation work

		// Do internal processing
		var cleaned = cleanData(data);

		echo("    ComponentB.transform: completed" & chr(10));
		return cleaned & " [transformed]";
	}

	function validate(data) {
		echo("    ComponentB.validate: running" & chr(10));
		sleep(3); // Simulate validation work

		// Call internal helper
		checkRules(data);

		echo("    ComponentB.validate: completed" & chr(10));
		return data & " [validated]";
	}

	function analyze(data) {
		echo("    ComponentB.analyze: running" & chr(10));
		sleep(4); // Simulate analysis

		// Create and use ComponentC
		var compC = new ComponentC();
		var metrics = compC.calculateMetrics(data);

		echo("    ComponentB.analyze: completed" & chr(10));
		return "Analysis: " & metrics;
	}

	private function cleanData(data) {
		echo("      ComponentB.cleanData: running" & chr(10));
		sleep(2); // Simulate cleaning
		return data & " [cleaned]";
	}

	private function checkRules(data) {
		echo("      ComponentB.checkRules: running" & chr(10));
		sleep(1); // Simulate rule checking
		return true;
	}

	function callC(data) {
		echo("    ComponentB.callC: starting" & chr(10));
		sleep(2); // Own time for B

		// Call ComponentC methods to create a call chain
		var compC = new ComponentC();
		var result = compC.processDeep(data);

		echo("    ComponentB.callC: completed" & chr(10));
		return result;
	}
}