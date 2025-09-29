<cfscript>
// Built-in function calls
var result1 = len("test");
var result2 = ucase("hello");
var result3 = now();

// User-defined function call
function myFunction(x) {
	return x * 2;
}
var result4 = myFunction(5);
</cfscript>