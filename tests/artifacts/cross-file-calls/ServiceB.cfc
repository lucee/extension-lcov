component {

	function transform( required string input ) {
		// BIF - should show as own time
		sleep( 2 );

		// Some processing
		var processed = uCase( arguments.input );
		var reversed = reverse( processed );

		return reversed;
	}

}
