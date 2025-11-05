<cfscript>
// Test: if statement without braces
// Expected: No container block, just the body statement

function expensiveCheck() {
	sleep(10); // 10ms
	return true;
}

function expensiveWork() {
	sleep(20); // 20ms
	return "done";
}

// Line 15: The if statement without braces - should NOT create a container
if ( expensiveCheck() )
	result = expensiveWork();

writeOutput(result);
</cfscript>
