<cfscript>
	// Include kitchen-sink 5 times in a single request
	loop times=5 {
		include "../kitchen-sink-example.cfm";
	}	
</cfscript>
