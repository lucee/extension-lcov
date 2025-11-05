<cfscript>
	// Function defined in included template
	function processTemplate( required string data ) {
		// BIF - should show as own time
		sleep( 3 );

		// Some processing
		var result = "";
		for ( var i = 1; i <= 5; i++ ) {
			result &= arguments.data & " ";
		}

		return trim( result );
	}
</cfscript>
