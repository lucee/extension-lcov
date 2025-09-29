<!--- Custom tag invocations in tag syntax --->
<cf_mytag attribute="value">

<!--- CFModule is a built-in tag but invokes user-defined templates --->
<cfmodule template="mymodule.cfm" param="test">

<!--- Import custom tag library (path doesn't need to exist for AST parsing) --->
<cfimport taglib="../customtags" prefix="ct">
<ct:customtag />

<!--- Test some more built-in tags --->
<cfinclude template="test-include.cfm">
<cfset x = 1>

<cfscript>
// Custom tag invocation from script - these become function calls
cf_anothertag(name="test");

// cfmodule as a function - built-in function but invokes user code
cfmodule(template="another.cfm");

// cfsavecontent as a function - built-in function with block syntax
cfsavecontent(variable="myContent") {
	writeOutput("Some content here");
}

// Another built-in tag as function
cfloop(from=1, to=5, index="i") {
	// loop body
}
</cfscript>