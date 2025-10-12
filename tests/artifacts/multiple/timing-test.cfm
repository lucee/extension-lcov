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

	// Do some work directly - this should show as ownTime
	echo("Direct work");
</cfscript>
