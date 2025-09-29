<cfscript>
// This file is included by test-include-calls.cfm
systemOutput("This is the included file executing", true);

function includedFunction() {
	return "from included file";
}

includedResult = includedFunction();
systemOutput("Included file result: " & includedResult, true);
</cfscript>