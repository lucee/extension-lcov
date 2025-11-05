<cfscript>
// Test: if statement with braces creates container block
// Expected: Container block time should NOT be added to line totals (would double-count)

function expensiveCheck() {
	sleep(10); // 10ms
	return true;
}

function expensiveWork() {
	sleep(20); // 20ms
	return "done";
}

// Line 15: The if statement with braces - this creates a CONTAINER block
if ( expensiveCheck() ) {
	// Line 17: The body - this creates a CHILD block  
	result = expensiveWork();
}

writeOutput(result);
</cfscript>
