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

		var htmlReporter = new codeCoverageHtmlReporter( displayUnit );
		var exlParser = new codeCoverageExlParser();

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

		var fullCoverage = mergeResultsByFile( results );
		var mergedReportFile = replace(outputFile, "lcov.info", "mergedCoverage.json");
		fileWrite(mergedReportFile, serializeJson(var=fullCoverage, compact=false));
		systemOutput( "Calculating LCOV coverage, merge took " & (getTickCount() - lcovStart) & "ms, " & mergedReportFile, true );
		var lcovParsingStart = getTickCount();
		var lcov = buildLCOV( fullCoverage.mergedCoverage );
		fileWrite(outputFile, lcov.lcov);
		// Write out LCOV stats as JSON
		var lcovStatsFile = replace(outputFile, "lcov.info", "lcov-stats.json");
		fileWrite(lcovStatsFile, serializeJson(var=lcov.stats, compact=false));

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

	/* this function takes all the results from multiple EXL files and merges them into a single fileCoverage struct */
	private function mergeResultsByFile( struct results ) {
		var merged = {
			files: {},
			coverage: {}
		};
		for ( var src in results ) {
			var coverage = results[ src ].coverage;
			var files = results[ src ].source.files;
			/*
			systemOutput( "", true );
			systemOutput( "--- source file: " & src & " -----", true );
			systemOutput( serializeJSON( var=files, compact=false ), true );
			*/
			// files index per result overlap
			var mapping = {};

			for ( var f in files ) {
				if ( !structKeyExists( merged.files, files[ f ].path ) ) {
					merged.files[ files[ f ].path ] = files[ f ];
				}
				mapping[ f ] = files[ f ].path; // only used for this src
			}
			for ( var f in coverage ) {
				var realFile = mapping[ f ];
				if ( !structKeyExists( merged.coverage, realFile ) ) {
					merged.coverage[ realFile ] = {};
				}
				for ( var l in coverage[ f ] ) {
					if ( !structKeyExists( merged.coverage[ realFile ], l ) ) {
						merged.coverage[ realFile ][ l ] = [ 0, 0 ];
					}
					var lineData = merged.coverage[ realFile ][ l ];
					var srcLineData = coverage[ f ][ l ];
					lineData[ 1 ] += srcLineData[ 1 ];
					lineData[ 2 ] += srcLineData[ 2 ];
				}
			}
		}
		var files = structKeyArray( merged.files );
		arraySort( files, "textnocase" );
		return {
			"mergedCoverage": merged,
			"files": files
		};
	}

	/**
	* Builds LCOV string from fileCoverage struct.
	* Uses array joining for better performance with large datasets.
	*/
	private struct function buildLCOV( struct fileCoverage ) {
		var lcovLines = [];
		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;
		var stats = {};

		for (var file in files) {
			arrayAppend( lcovLines, "SF:" & files[ file] .path );

			var data = coverage[ file ];

			// Get line numbers and sort them numerically
			var lineNumbers = structKeyArray(data);
			arraySort(lineNumbers, "numeric");

			// Count lines found and lines hit for summary
			var linesHit = 0;

			for (var line in lineNumbers) {
				arrayAppend( lcovLines, "DA:" & line & "," & data[ line ][ 1 ]);
				linesHit++;
			}

			// Add line summary records
			var linesFoundValue = structKeyExists(files[file], "linesFound") ? files[file].linesFound : linesHit;
			arrayAppend( lcovLines, "LF:" & linesFoundValue );
			arrayAppend( lcovLines, "LH:" & linesHit );
			arrayAppend( lcovLines, "end_of_record" );
			stats[ files[ file] .path ] = {
				"linesFound": linesFoundValue,
				"linesHit": linesHit,
				"lineCount": structKeyExists(files[file], "lineCount") ? files[file].lineCount : 0
			};
		}

		return {
			"stats": stats,
			"lcov": arrayToList( lcovLines, chr(10) )
		};
	}

}