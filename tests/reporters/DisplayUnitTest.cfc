component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function testReporterUnitConversion() {
		// Test creating reporter with different display units
		var logger = new lucee.extension.lcov.Logger( level="none" );
		var timeFormatter = new lucee.extension.lcov.reporter.TimeFormatter();
		var units = timeFormatter.getUnits();
		for (var unit in units) {
			var unitInfo = timeFormatter.getUnitInfo( unit );
			var htmlWriter = new lucee.extension.lcov.reporter.HtmlWriter( logger=logger, displayUnit=unitInfo.symbol );
			var convertedTime = timeFormatter.convertTime( 1024, "ms", unitInfo.symbol );
			var n = lsparseNumber( convertedTime );
			expect( n ).toBeNumeric( "Converted time should be numeric" );
			expect( n ).toBeGT(0, "Converted time should be greater than 0" );
		}
	}
}