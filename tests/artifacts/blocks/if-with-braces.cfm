<cfscript>
// Test if statement with explicit braces
// This should NOT double-count time for the if statement and its body

function expensiveCheck() {
	sleep(10); // 10ms
	return true;
}

function expensiveWork() {
	sleep(20); // 20ms
	return "done";
}

// The if statement with braces
if ( expensiveCheck() ) {
	result = expensiveWork();
}

writeOutput(result);
</cfscript>
