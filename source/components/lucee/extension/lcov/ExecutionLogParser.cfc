component accessors="true" {
	// Utility component for code coverage helpers
	// Cache structures for performance optimization
	property name="fileContentsCache" type="struct" default="#{}#";
	property name="fileBlockIgnoreCache" type="struct" default="#{}#";
	property name="lineMappingsCache" type="struct" default="#{}#";
	property name="positionMappingsCache" type="struct" default="#{}#";
	property name="fileExistsCache" type="struct" default="#{}#";
	property name="fileIgnoreCache" type="struct" default="#{}#"; // files not allowed due to allow/block lists


	/**
	* Initialize the parser with cache structures
	* @options Configuration options struct (optional)
	*/
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
		
		// Always instantiate the utility component for code coverage helpers
		variables.utils = new codeCoverageUtils(arguments.options);
		variables.ast = new ExecutableLineCounter(arguments.options);
		return this;
	}

	/**
	* Private logging function that respects verbose setting
	* @message The message to log
	*/
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	* Parse a single .exl file and extract sections and file coverage data
	* @exlPath Path to the .exl file to parse
	* @fileCoverage Reference to the cumulative file coverage structure (for LCOV generation)
	* @needSingleFileCoverage Whether to return isolated coverage data for this file (for HTML generation)
	* @allowList Array of allowed file patterns/paths
	* @blocklist Array of blocked file patterns/paths
	* @return Struct containing sections and fileCoverage data
	*/
	public struct function parseExlFile(string exlPath, boolean needSingleFileCoverage = false,
		array allowList=[], array blocklist=[], boolean useAstForLinesFound = true) {

		var lines = [];
		try {
			var fileContent = fileRead(arguments.exlPath);
			lines = listToArray(fileContent, chr(10), true, false);
		} catch (any e) {
			logger("Error reading file [" & arguments.exlPath & "]: " & e.message);
			return { "sections": {}, "fileCoverage": {} };
		}

		var section = 0; // 0=metadata, 1=files, 2=coverage
		var emptyLineCount = 0;
		var metadata = [];
		var files = [];
		var fileCoverage = [];

		for ( var i = 1; i <= arrayLen( lines ); i++ ) {
			var line = lines[i];
			if ( trim( line ) == "" ) {
				emptyLineCount++;
				if ( emptyLineCount == 1 ) {
					section = 1; // Start files section
				} else if ( emptyLineCount == 2 ) {
					section = 2; // Start coverage section
				}
			} else {
				if ( section == 0 ) {
					arrayAppend( metadata, line );
				} else if ( section == 1 ) {
					arrayAppend( files, line );
				} else {
					arrayAppend( fileCoverage, line );
				}
			}
		}

		var coverage = {
			"metadata": variables.utils.parseMetadata( metadata ),
			"source": parseFiles( files, exlPath, allowList, blocklist, arguments.useAstForLinesFound ),
			"fileCoverage": fileCoverage,
			"exeLog": exlPath
		};

		if ( structCount( coverage.source.files ) == 0 && arrayLen( coverage.fileCoverage ) == 0 ) {
			logger("Skipping file with empty files and fileCoverage: [" & exlPath & "]");
			return {};
		}

		coverage["coverage"] = parseCoverage( coverage );

		logger("parsed file: " & exlPath &
			", Metadata lines: " & structCount( coverage.metadata ) &
			", files lines: " & structCount( coverage.source.files ) &
			", skipped files: " & len( coverage.source.skipped ) & "] skipped" &
			", Coverage lines: " & arrayLen( coverage.fileCoverage ));

			// write out filecoverage as json using compact=false for debuggingg
		fileWrite( replace( arguments.exlPath, ".exl", "-fileCoverage.json" ), serializeJson( var=coverage, compact=false ) );
		logger( "" );

		return coverage;
	}

	/**
	* Parallel processing for large datasets using 3-stage approach
	*/
	private struct function parseCoverage( struct coverageData) {
		var chunkSize = 50000; // Default chunk size
		var totalLines = arrayLen(arguments.coverageData.fileCoverage);
		var files = arguments.coverageData.source.files;
		var fileCoverage = arguments.coverageData.fileCoverage;
		var exlPath = arguments.coverageData.exeLog;
		var start = getTickCount();
		var coverage = {};
		var chunks = [];

		for (var i = 1; i <= totalLines; i += chunkSize) {
			var endIdx = min(i + chunkSize - 1, totalLines);
			arrayAppend(chunks, {
				"startIdx": i,
				"endIdx": endIdx,
				"size": endIdx - i + 1
			});
		}
		if (arrayLen(chunks) > 1) {
			logger("  Split " & totalLines & " coverage lines into " & arrayLen(chunks) & " chunks of ~" & numberFormat(chunkSize) & " lines each");
		}
		var parallelStart = getTickCount();
		// Process job queue in parallel - arrayEach automatically handles thread allocation
		var chunkResults = [];
		// Build caches for all files once before chunk processing
		var lineMappingsCache = {};
		var mappingLens = {};
		for (var fileIdx in files) {
			var fpath = files[fileIdx].path;
			lineMappingsCache[fpath] = variables.lineMappingsCache[fpath];
			mappingLens[fpath] = arrayLen(lineMappingsCache[fpath]);
		}

		arrayEach(chunks, function(chunk, index) {
			var chunkBlocks = [];
			var chunkStart = getTickCount();

			// duplicate mapping caches for thread safety
			var _lineMappingsCache = duplicate(lineMappingsCache);
			var _mappingLens = duplicate(mappingLens);

			for (var j = chunk.startIdx; j <= chunk.endIdx; j++) {
				var line = fileCoverage[ j ];
				var p = listToArray(line, chr(9), false, false);
				var fileIdx = p[1];
				if (!structKeyExists(files, fileIdx)) {
					continue; // file is blocklistsed or not allowed
				}
				var fpath = files[fileIdx].path;
				var lineMapping = _lineMappingsCache[fpath];
				var mappingLen = _mappingLens[fpath];
				var r = processCoverageLine(line, files, exlPath, lineMapping, mappingLen);
				if (arrayLen(r)) {
					// r = [fileIdx, startLine, endLine, execTime]
					arrayAppend(chunkBlocks, r);
				}
			}

			var chunkTime = getTickCount() - chunkStart;
			logger("  Chunk " & index & " / " & arrayLen(chunks) & " completed in " & chunkTime & "ms");

			// Store result for merging
			arrayAppend(chunkResults, chunkBlocks);
		}, true); // parallel=true

		logger("  Parallel processing completed in " & (getTickCount() - parallelStart) & "ms");

		var mergeStart = getTickCount();

		// Merge all chunkResults into a single array of blocks
		var allBlocks = variables.utils.combineChunkResults( chunkResults );
		// Pass a flag to processBlocks to indicate blocks are already line-based
		var processStart = getTickCount();
		var coverage = variables.utils.processBlocks( allBlocks, files, lineMappingsCache, true );
		logger("  Processed blocks into line coverage in " & (getTickCount() - processStart) & "ms");

		var totalTime = mergeStart - start;
		logger("  Merge completed in " & (getTickCount() - mergeStart) & "ms");
		logger("  Total parallel processing time: " & totalTime & "ms (" & decimalFormat(totalTime/totalLines) & "ms per line)");

		return coverage;
	}


	/**
	* Process a single coverage line and return structured data with a valid flag
	*/
	private array function processCoverageLine(line, files, exlPath, lineMappings, lineMappingLen) {
		// Use listToArray with tab delimiter - more compatible than split()
		var result = [];
		var p = listToArray(arguments.line, chr(9), false, false);
		if (arrayLen(p) != 4) {
			throw "Malformed coverage data line in [" & arguments.exlPath & "]: [" & arguments.line & "]" &
				", Detail: Line does not have 4 tab-separated values.";
		}

		if (!structKeyExists(arguments.files, p[1])) {
			return {}; // file is not allowed due to allow / block list
		}

		var f = arguments.files[ p[ 1 ] ].path;

		var startLine = getLineFromCharacterPosition( p[ 2 ], f, lineMappings, lineMappingLen);
		var endLine = getLineFromCharacterPosition( p[ 3 ], f, lineMappings, lineMappingLen);

		// Skip invalid positions
		if ((startLine == 0 && endLine == 0) || endLine == 0) {
			throw "Malformed coverage data line in [" & arguments.exlPath & "]: [" & arguments.line & "]" &
				", Detail: Both start and end character positions map to line 0 in file: " & f;
		}

		// Get total line count for this file to detect entire-file ranges
		var fileTotalLines = arrayLen( variables.lineMappingsCache[ f ] );

		// Only exclude ranges that cover the entire file (likely overhead/instrumentation)
		if (startLine <= 1 && endLine >= fileTotalLines) {
			// log a warning for debugging
			// systemOutput("WARNING whole-file coverage for file: " & f & " (" & startLine & "-" & endLine & ")", true);
			// return result; // Skip whole-file coverage
		}
		// Return structured result: [fileIdx, startLine, endLine, executionTime]
		return [ p[ 1 ], startLine, endLine, p[ 4 ] ];
	}



	/**
	* Get the line number for a given character position in a file.
	* Uses cached line mappings for performance.
	*/
	public numeric function getLineFromCharacterPosition( charPos, path, lineMapping = 0, mappingLen = 0 ) {
		// Accept a pre-cached line mapping array and its length to avoid repeated struct lookups and arrayLen calls
		var lineStarts = isArray(lineMapping) ? lineMapping : variables.lineMappingsCache[ arguments.path ];
		var len = mappingLen > 0 ? mappingLen : arrayLen(lineStarts);

		// Binary search to find the line
		var low = 1;
		var high = len;

		while (low <= high) {
			var mid = int((low + high) / 2);

			if (mid == len) {
				// Last line - check if charPos is beyond the start of this line
				return lineStarts[mid] <= arguments.charPos ? mid : mid - 1;
			} else if (lineStarts[mid] <= arguments.charPos && arguments.charPos < lineStarts[mid + 1]) {
				return mid;
			} else if (lineStarts[mid] > arguments.charPos) {
				high = mid - 1;
			} else {
				low = mid + 1;
			}
		}

		return 0; // Not found
	}

	/**
	* Extracts file mappings from the .exl file lines.
	* The file format is: metadata, empty line, file mappings (num:Path), empty line, then coverage data.
	*/
	private struct function parseFiles(array filesLines, string exlPath,
			array allowList, array blocklist, boolean useAstForLinesFound = true) {
		var files = {};
		var skipped = {}
		for (var i = 1; i <= arrayLen(arguments.filesLines); i++) {
			var line = trim(arguments.filesLines[i]);
			if (line == "") break;
			var num = listFirst(line, ":");
			var path = listRest(line, ":");

			if ( !fileExists( path ) ) {
				if ( !structKeyExists( variables.fileExistsCache, path ) ) {
					variables.fileExistsCache[ path ] = false;
				}
				variables.fileIgnoreCache[ path ] = "file doesn't exist [" & num & "]";
				skipped[ path ] = "file doesn't exist";
				continue;
			} else {
				variables.fileExistsCache[ path ] = true;
			}

			var skip = false;
			if ( arrayLen( arguments.allowList ) > 0 ) {
				skip = true;
				for ( var pattern in arguments.allowList ) {
					var normalizedPath = replace(path, "/", server.separator.file, "all");
					normalizedPath = replace(normalizedPath, "\", server.separator.file, "all");
					var normalizedPattern = replace(pattern, "/", server.separator.file, "all");
					normalizedPattern = replace(normalizedPattern, "\", server.separator.file, "all");
					if ( find( normalizedPattern, normalizedPath ) > 0 ) {
						skip = false;
						break;
					}
				}
				if ( skip ) {
					variables.fileIgnoreCache[ path ] = "not in allowList [" & num & "]";
					skipped[ path ] = path & " not found in allowList";
					continue;
				}
			}

			for ( var pattern in arguments.blocklist ) {
				var normalizedPath = replace(path, "/", server.separator.file, "all");
				normalizedPath = replace(normalizedPath, "\", server.separator.file, "all");
				var normalizedPattern = replace(pattern, "/", server.separator.file, "all");
				normalizedPattern = replace(normalizedPattern, "\", server.separator.file, "all");
				if ( find( normalizedPattern, normalizedPath ) > 0 ) {
					variables.fileIgnoreCache[ path ] = "found in blocklist [" & num & "]";
					skip = true;
					skipped[ path ] = path & " found in blocklist";
					break;
				}
			}

			if ( !skip ) {
				if ( !structKeyExists( variables.fileContentsCache, path) ) {
					variables.fileContentsCache[ path] = fileRead( path );
					variables.lineMappingsCache[ path] = variables.utils.buildCharacterToLineMapping( variables.fileContentsCache[ path] );
				}
				var sourceLines = readFileAsArrayBylines( path );
				var lineInfo = {};
				
				if (arguments.useAstForLinesFound) {
					// Use AST-based approach
					var ast = astFromPath( path );
					lineInfo = variables.ast.countExecutableLinesFromAst( ast );
				} else {
					// Use simple line counting approach
					lineInfo = variables.ast.countExecutableLinesSimple( sourceLines );
				}
				
				files[ num ] = {
					"path": path,
					"lineCount": len( variables.lineMappingsCache[ path] ),
					"linesFound": lineInfo.count,
					"lines": sourceLines,
					"executableLines": lineInfo.executableLines
				};
			}
		}
		if (len(skipped) > 0) {
			logger("Skipped [" & len(skipped) & "] files due to allow/block lists in [" & listLast(arguments.exlPath, "\/") & "]");
		}
		return {
			"files": files,
			"skipped": skipped
		};
	}

	/**
	* Reads a file and returns its contents as an array of lines, using the parser's fileContentsCache.
	*/
	private array function readFileAsArrayBylines( string path ) {
		if ( !structKeyExists( variables.fileContentsCache, arguments.path ) ) {
			variables.fileContentsCache[ arguments.path ] = fileRead( arguments.path );
		}
		return listToArray( variables.fileContentsCache[ arguments.path ], chr(10), true, false );
	}

}