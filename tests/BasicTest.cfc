component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function testComponentInstantiation() {
		var logger = new lucee.extension.lcov.Logger( level="none" );
		var parser = new lucee.extension.lcov.ExecutionLogParser();
		var utils = new lucee.extension.lcov.coverage.CoverageBlockProcessor();
		var htmlReporter = new lucee.extension.lcov.reporter.HtmlReporter( logger=logger );
		var exeLogger = new lucee.extension.lcov.exeLogger( request.SERVERADMINPASSWORD );
		
		expect(parser).toBeInstanceOf("ExecutionLogParser");
		expect(utils).toBeInstanceOf("CoverageBlockProcessor");
		expect(htmlReporter).toBeInstanceOf("HtmlReporter");
		expect(exeLogger).toBeInstanceOf("exeLogger");
	}
}