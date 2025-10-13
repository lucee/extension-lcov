/**
 * HtmlReportGenerator.cfc
 *
 * HTML-specific report generation operations.
 * Extends ReportGenerator with HTML-focused methods.
 */
component extends="ReportGenerator" {

	/**
	 * Render HTML reports for separate files mode
	 * @sourceFileJsons Array of source file JSON paths
	 * @htmlReporter HtmlReporter instance
	 * @logger Logger instance
	 */
	public void function renderSeparateFileHtmlReports(
		required array sourceFileJsons,
		required any htmlReporter,
		required any logger
	) {
		var fileEvent = arguments.logger.beginEvent( "Render Per-File HTML Reports" );
		var resultFactory = new lucee.extension.lcov.model.result();
		for ( var jsonFile in arguments.sourceFileJsons ) {
			var sourceResult = resultFactory.fromJson( fileRead( jsonFile ), true );
			sourceResult.validate();

			var sourceFilePath = getFileFromPath( jsonFile );
			sourceFilePath = reReplace( sourceFilePath, "^file-[^-]+-", "" );
			sourceFilePath = reReplace( sourceFilePath, "\.json$", "" );
			sourceResult.setExeLog( sourceFilePath );

			arguments.htmlReporter.generateHtmlReport( sourceResult );
		}
		arguments.logger.commitEvent( fileEvent );
	}

	/**
	 * Render HTML reports for request-based mode
	 * @jsonFilePaths Array of JSON file paths
	 * @results Struct of results
	 * @htmlReporter HtmlReporter instance
	 * @outputDir Output directory
	 * @logger Logger instance
	 */
	public void function renderRequestHtmlReports(
		required array jsonFilePaths,
		required struct results,
		required any htmlReporter,
		required string outputDir,
		required any logger
	) {
		var reqEvent = arguments.logger.beginEvent( "Render Per-Request HTML Reports" );
		for ( var jsonPath in arguments.jsonFilePaths ) {
			var result = arguments.results[ jsonPath ];
			var coverage = result.getCoverage();
			if ( structKeyExists( coverage, "0" ) && !structIsEmpty( coverage[ "0" ] ) ) {
				var jsonFileName = result.getOutputFilename() & ".json";
				fileWrite( arguments.outputDir & "/" & jsonFileName, serializeJSON( var=result, compact=false ) );
				arguments.htmlReporter.generateHtmlReport( result );
			}
		}
		arguments.logger.commitEvent( reqEvent );
	}

}
