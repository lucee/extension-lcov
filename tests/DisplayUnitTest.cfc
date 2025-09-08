component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function testReporterUnitConversion() {
		// Test creating reporter with different display units
		var htmlWriter = new lucee.extension.lcov.codeCoverageHtmlWriter();
		
		var units = htmlWriter.getUnits();

		for (var unit in units) {
			var htmlWriter = new lucee.extension.lcov.codeCoverageHtmlWriter( displayUnit: unit );
			var type = htmlWriter.getUnitInfo( unit );
			var exe = htmlWriter.convertTimeUnit( 1024, "ms", type );
			var n = lsparseNumber( exe.time );
			expect( n ).toBeNumeric( "Converted time should be numeric" );
			expect( n ).toBeGT(0, "Converted time should be greater than 0" );
		}
	}
}