component {

	function init() {
		variables.serviceB = new ServiceB();
		return this;
	}

	function processData( required string data ) {
		// Call ServiceB multiple times
		var results = [];
		for ( var i = 1; i <= 3; i++ ) {
			var result = variables.serviceB.transform( arguments.data & " - pass " & i );
			arrayAppend( results, result );
		}
		return arrayToList( results, "; " );
	}

}
