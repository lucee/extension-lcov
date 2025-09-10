component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function testBasicExtensionLoading() {
		var reporter = new lucee.extension.lcov.codeCoverageReporter();
		expect(reporter).toBeInstanceOf("codeCoverageReporter");
	}

	function testComponentInstantiation() {
		var parser = new lucee.extension.lcov.ExecutionLogParser();
		var utils = new lucee.extension.lcov.codeCoverageUtils();
		var htmlReporter = new lucee.extension.lcov.reporter.HtmlReporter();
		var exeLogger = new lucee.extension.lcov.exeLogger(request.SERVERADMINPASSWORD);
		
		expect(parser).toBeInstanceOf("ExecutionLogParser");
		expect(utils).toBeInstanceOf("codeCoverageUtils");
		expect(htmlReporter).toBeInstanceOf("HtmlReporter");
		expect(exeLogger).toBeInstanceOf("exeLogger");
	}
}