<cfscript>
	// This file tests child time calculation with predictable timing
	// Using sleep() makes timing consistent across runs (no JIT variance)

	// Create component instance
	helper = new TimingHelper();

	// Call method that sleeps - this should show as childTime
	helper.sleepFor5Ms();

	// Call a method that calls another method (nested calls)
	// This tests if childTime is double-counted in nested scenarios
	helper.callsAnotherMethod();

	// Test same-file nested calls (should also show double-counting)
	localFunctionA();

	// Call localFunctionB directly as well
	localFunctionB();

	// Do some work directly - this should show as ownTime
	echo("Direct work");

	// Local function that calls another local function
	function localFunctionA() {
		// This function calls localFunctionB
		// The child time here should be ~3ms (from localFunctionB)
		localFunctionB();
	}

	function localFunctionB() {
		// Sleep for 3 milliseconds - predictable timing
		sleep(3);
	}
</cfscript>
