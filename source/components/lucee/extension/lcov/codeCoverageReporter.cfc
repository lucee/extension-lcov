component {

	public function init() {
		variables.utils = new codeCoverageUtils();
		return this;
	}

	/**
	* Reads all .exl files in artifacts/codecoverage, parses them, and produces an LCOV file.
	* @outputFile The path to write the LCOV file to.
	* @generateHtml Optional boolean flag to control HTML report generation (default: true)
	*/
	public struct function generateCodeCoverage( string coverageDir, string outputFile,
			boolean generateHtml = true, array allowList=[], array blocklist=[], displayUnit="milli" ) {

		var htmlReporter = new reporter.HtmlReporter( displayUnit );
		var exlParser = new ExecutionLogParser();

		var files = directoryList(coverageDir, false, "query", "*.exl", "datecreated");

		systemOutput("Processing " & files.recordCount & " .exl files...", true);

		var results = {};

		for (var file in files) {
			var exlPath = file.directory & "/" & file.name;
			var result = exlParser.parseExlFile( exlPath, arguments.generateHtml,
					arguments.allowList, arguments.blocklist );
			if ( len( result ) eq 0) continue;
			result["stats"] = variables.utils.calculateCoverageStats( result );
			results[ exlPath ] = result;
		}

		if ( arguments.generateHtml ) {
			for (var file in results ) {
				try {
					htmlReporter.generateHtmlReport( results[ file ] );
				} catch (any e) {
					throw(message="Error generating HTML report for " & file, detail=e.message, cause=e);
				}
			}
			var htmlReportIndex = htmlReporter.generateIndexHtml( coverageDir & "/" );
		}

		// for LCVOV we need to merge all the fileCoverage structs
		var lcovStart = getTickCount();
		var resultsFile = replace(outputFile, "lcov.info", "results.json");
		fileWrite(resultsFile, serializeJson(var=results, compact=false));

		var fullCoverage = variables.utils.mergeResultsByFile( results );
		var mergedReportFile = replace(outputFile, "lcov.info", "mergedCoverage.json");
		fileWrite(mergedReportFile, serializeJson(var=fullCoverage, compact=false));
		systemOutput( "Calculating LCOV coverage, merge took " & (getTickCount() - lcovStart) & "ms, " & mergedReportFile, true );
		var lcovParsingStart = getTickCount();
		// Use new LcovWriter component
		var lcovWriter = new reporter.LcovWriter();
		var lcovContent = lcovWriter.buildLCOV(fullCoverage.mergedCoverage);
		fileWrite(outputFile, lcovContent);
		
		// Calculate and write stats separately
		var stats = variables.utils.calculateLcovStats(fullCoverage.mergedCoverage);
		var lcovStatsFile = replace(outputFile, "lcov.info", "lcov-stats.json");
		fileWrite(lcovStatsFile, serializeJson(var=stats, compact=false));

		systemOutput("Generated LCOV file: " & outputFile & ", parsing took " & (getTickCount() - lcovParsingStart) & "ms", true);
		systemOutput("Generated LCOV stats file: " & lcovStatsFile, true);

		systemOutput("Cache stats - File contents: " & structCount(exlParser.getFileContentsCache()) &
		", Line mappings: " & structCount(exlParser.getLineMappingsCache()) &
		", File exists: " & structCount(exlParser.getFileExistsCache()), true);

		systemOutput( "--- reported files-----", true );
		systemOutput( serializeJson( var=exlParser.getFileExistsCache(), compact=false ), true );

		var output = {
			"lcovFile": outputFile,
			"lcovStatsFile": lcovStatsFile,
			"resultsFile": resultsFile,
			"mergedReportFile": mergedReportFile
		};
		if (arguments.generateHtml) {
			output["htmlReportIndex"] = htmlReportIndex;
		}
		return output;
	}


}