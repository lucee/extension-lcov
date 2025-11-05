component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.adminPassword = request.SERVERADMINPASSWORD;
		variables.testDataGenerator = new GenerateTestData( testName="CrossFileCallsTest" );
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
			adminPassword: variables.adminPassword,
			fileFilter: "cross-file-calls/test-cfc-chain.cfm"
		);
	}

	function testCfcChainReports() {
		var outputDir = variables.testDataGenerator.getOutputDir( "reports" );

		lcovGenerateHtml(
			executionLogDir: variables.testData.coverageDir,
			outputDir: outputDir,
			options: {
				includeSourceCode: true,
				logLevel: "INFO"
			}
		);

		var reportFiles = directoryList( outputDir, false, "array", "*.md" );
		expect( arrayLen( reportFiles ) ).toBeGT( 0 );
	}

}
