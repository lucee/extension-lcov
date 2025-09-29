<cfscript>
// This file is included by test-include-calls.cfm
echo("This is the included file executing");

function includedFunction() {
	return "from included file";
}

includedResult = includedFunction();
echo("Included file result: " & includedResult);
</cfscript>