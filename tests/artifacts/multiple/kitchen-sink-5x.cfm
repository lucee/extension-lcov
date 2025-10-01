<cfscript>
	// Include kitchen-sink 5 times in a single request
	echo( "Running kitchen-sink 5 times..." );
	i = 1;
	while ( i <= 5 ) {
		echo( "Iteration #i#" );
		include "../kitchen-sink-example.cfm";
		i++;
	}
	echo( "Completed 5 iterations" );
</cfscript>
