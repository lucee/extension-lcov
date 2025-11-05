<cfscript>
// Test artifact for parallel thread execution logging

function processItem( item ) {
	sleep( 5 );
	return item * 2;
}

// Execute parallel arrayMap to spawn child threads
items = [ 1, 2, 3, 4, 5 ];
results = arrayMap( items, processItem, true ); // parallel=true

writeOutput( "Processed: " & arrayToList( results ) );
</cfscript>
