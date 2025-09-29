component {

	// Component C - called by ComponentB

	function init() {
		echo("        ComponentC: init" & chr(10));
		return this;
	}

	function calculateMetrics(data) {
		echo("      ComponentC.calculateMetrics: running" & chr(10));
		sleep(6); // Simulate metric calculation

		// Call internal helpers
		var stats = computeStatistics(data);
		var score = computeScore(stats);

		echo("      ComponentC.calculateMetrics: completed" & chr(10));
		return "Metrics: stats=" & stats & ", score=" & score;
	}

	function processDeep(data) {
		echo("      ComponentC.processDeep: starting" & chr(10));
		sleep(4); // Own processing time

		// Do multiple internal operations
		var step1 = firstPass(data);
		var step2 = secondPass(step1);
		var final = finalPass(step2);

		echo("      ComponentC.processDeep: completed" & chr(10));
		return final;
	}

	private function computeStatistics(data) {
		echo("        ComponentC.computeStatistics: running" & chr(10));
		sleep(2); // Simulate computation
		return "stats[" & len(data) & "]";
	}

	private function computeScore(stats) {
		echo("        ComponentC.computeScore: running" & chr(10));
		sleep(1); // Simulate scoring
		return randRange(70, 100);
	}

	private function firstPass(data) {
		echo("        ComponentC.firstPass: running" & chr(10));
		sleep(1); // First pass processing
		return data & " [pass1]";
	}

	private function secondPass(data) {
		echo("        ComponentC.secondPass: running" & chr(10));
		sleep(1); // Second pass processing
		return data & " [pass2]";
	}

	private function finalPass(data) {
		echo("        ComponentC.finalPass: running" & chr(10));
		sleep(1); // Final pass processing
		return data & " [final]";
	}
}