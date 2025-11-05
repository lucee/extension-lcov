<cfscript>
	// Test cross-file UDF calls through template includes
	// Template → includes template with function → calls that function

	// Include the template that defines the function
	include "included-template.cfm";

	// Now call the function that was defined in the included template
	for ( i = 1; i <= 5; i++ ) {
		result = processTemplate( "test data " & i );
		writeOutput( "Template result " & i & ": " & result & "<br>" );
	}

	writeOutput( "Template include test completed" );
</cfscript>
