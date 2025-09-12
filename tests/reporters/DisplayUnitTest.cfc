component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function testReporterUnitConversion() {
		// Test creating reporter with different display units
		var utils = new lucee.extension.lcov.reporter.HtmlUtils();
		var units = utils.getUnits();
		for (var unit in units) {
			var unitInfo = utils.getUnitInfo(unit);
			var htmlWriter = new lucee.extension.lcov.reporter.HtmlWriter( {displayUnit: unitInfo} );
			var exe = utils.convertTimeUnit( 1024, "ms", unitInfo );
			var n = lsparseNumber( exe.time );
			expect( n ).toBeNumeric( "Converted time should be numeric" );
			expect( n ).toBeGT(0, "Converted time should be greater than 0" );
		}
	}
}