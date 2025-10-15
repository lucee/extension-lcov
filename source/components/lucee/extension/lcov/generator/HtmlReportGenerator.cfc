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
		arguments.logger.commitEvent( fileEvent, 0, "info" );
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
		arguments.logger.commitEvent( reqEvent, 0, "info" );
	}

	/**
	 * Render HTML reports from in-memory results (Stage 2 optimization)
	 * NEW: Works with merged in-memory results instead of loading from disk
	 * @results with Struct of result objects keyed by canonical index
	 * @htmlReporter HtmlReporter instance
	 * @logger Logger instance
	 */
	public void function renderHtmlReportsFromResults(
		required struct resultsWithCoverage,
		required any htmlReporter,
		required any logger
	) {
		var fileEvent = arguments.logger.beginEvent( "Render HTML Reports from in-memory results" );

		// Generate HTML report for each result
		cfloop(collection=arguments.resultsWithCoverage, item="local.canonicalIndex") {
			var result = arguments.resultsWithCoverage[canonicalIndex];
			arguments.htmlReporter.generateHtmlReport( result );
		}

		arguments.logger.commitEvent( fileEvent, 0, "info" );
	}

	/**
	 * Write JSON files from in-memory results
	 * @resultsWithCoverage Struct of result objects keyed by canonical index
	 * @outputDir Output directory for JSON files
	 * @logger Logger instance
	 * @return Array of written JSON file paths
	 */
	public array function writeJsonFilesFromResults(
		required struct resultsWithCoverage,
		required string outputDir,
		required any logger
	) {
		var writeEvent = arguments.logger.beginEvent( "Write #structCount(arguments.resultsWithCoverage)# JSON files" );
		var jsonFiles = [];

		cfloop(collection=arguments.resultsWithCoverage, item="local.canonicalIndex") {
			var result = arguments.resultsWithCoverage[canonicalIndex];
			var outputFilename = result.getOutputFilename();
			var jsonPath = arguments.outputDir & "/" & outputFilename & ".json";

			fileWrite( jsonPath, serializeJSON( var=result, compact=false ) );
			arrayAppend( jsonFiles, jsonPath );
		}

		arguments.logger.commitEvent( writeEvent, 0, "info" );
		return jsonFiles;
	}

	/**
	 * Generate index.json file from results
	 * @resultsWithCoverage Struct of result objects keyed by canonical index
	 * @outputDir Output directory for index.json
	 * @logger Logger instance
	 * @return Path to written index.json file
	 */
	public string function writeIndexJson(
		required struct resultsWithCoverage,
		required string outputDir,
		required any logger
	) {
		var indexData = [];

		cfloop(collection=arguments.resultsWithCoverage, item="local.canonicalIndex") {
			var result = arguments.resultsWithCoverage[canonicalIndex];
			var files = result.getFiles();

			// Each merged result should have exactly one file
			for ( var fileIdx in files ) {
				var fileInfo = files[fileIdx];
				var coverage = result.getCoverage();
				var fileCoverage = structKeyExists( coverage, fileIdx ) ? coverage[fileIdx] : {};

				var totalLinesFound = 0;
				var totalLinesHit = 0;

				if ( structKeyExists( fileCoverage, "totalLinesFound" ) ) {
					totalLinesFound = fileCoverage.totalLinesFound;
				}
				if ( structKeyExists( fileCoverage, "totalLinesHit" ) ) {
					totalLinesHit = fileCoverage.totalLinesHit;
				}

				arrayAppend( indexData, {
					"scriptName": fileInfo.path,
					"htmlFile": result.getOutputFilename() & ".html",
					"totalLinesFound": totalLinesFound,
					"totalLinesHit": totalLinesHit
				});
			}
		}

		var indexJsonPath = arguments.outputDir & "/index.json";
		fileWrite( indexJsonPath, serializeJSON( var=indexData, compact=false ) );
		arguments.logger.debug( "Wrote index.json with " & arrayLen(indexData) & " entries" );

		return indexJsonPath;
	}

}
