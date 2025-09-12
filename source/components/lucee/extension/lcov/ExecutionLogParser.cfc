component accessors="true" {
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
		variables.utils = new lucee.extension.lcov.CoverageBlockProcessor(arguments.options);
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

		var startTime = getTickCount();

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
			   "metadata": parseMetadata( metadata ),
			   "source": parseFiles( files, exlPath, allowList, blocklist, arguments.useAstForLinesFound ),
			   "fileCoverage": fileCoverage,
			   "exeLog": exlPath
		   };

		if ( structCount( coverage.source.files ) == 0 && arrayLen( coverage.fileCoverage ) == 0 ) {
			logger("Skipping file with empty files and fileCoverage: [" & exlPath & "]");
			return {};
		}

		// OPTIMIZATION: Pre-aggregate coverage data before expensive processing
		coverage["coverage"] = parseCoverage( coverage );

		// Add performance metrics from the optimization processing
		if (structKeyExists(variables, "performanceData")) {
			coverage["parserPerformance"] = variables.performanceData;
		}

		var totalTime = getTickCount() - startTime;
		logger("Files: " & structCount( coverage.source.files ) &
		//	", skipped files: " & len( coverage.source.skipped ) & "] skipped" &
			", raw rows: " & numberFormat(arrayLen( coverage.fileCoverage )) &
			", in " & numberFormat(totalTime ) & "ms");

		// Write out filecoverage as json using compact=false for debugging
		fileWrite( replace( arguments.exlPath, ".exl", ".json" ), serializeJson( var=coverage, compact=false ) );
		logger( "" );

		return coverage;
	}

	/**
	* Combine identical coverage entries before line processing
	*/
	private struct function parseCoverage( struct coverageData) {
		var totalLines = arrayLen(arguments.coverageData.fileCoverage);
		var files = arguments.coverageData.source.files;
		var fileCoverage = arguments.coverageData.fileCoverage;
		var exlPath = arguments.coverageData.exeLog;
		var start = getTickCount();

		// Build line mappings cache for all files
		var lineMappingsCache = {};
		for (var fileIdx in files) {
			var fpath = files[fileIdx].path;
			lineMappingsCache[fpath] = variables.lineMappingsCache[fpath];
		}

		// STAGE 1: Pre-aggregate identical coverage entries
		var aggregationStart = getTickCount();
		var aggregated = {};
		var duplicateCount = 0;

		for (var i = 1; i <= totalLines; i++) {
			var line = fileCoverage[i];
			var p = listToArray(line, chr(9), false, false);
			var fileIdx = p[1];
			var startPos = p[2];
			var endPos = p[3];
			var execTime = p[4];

			if (!structKeyExists(files, fileIdx)) {
				continue; // file is blocklisted or not allowed
			}

			// Create unique key for this position range
			var key = fileIdx & ":" & startPos & ":" & endPos;

			if (!structKeyExists(aggregated, key)) {
				aggregated[key] = {
					"fileIdx": fileIdx,
					"startPos": startPos,
					"endPos": endPos,
					"count": 1,
					"totalTime": execTime
				};
			} else {
				// Aggregate identical entries
				aggregated[key].count += 1;
				aggregated[key].totalTime += execTime;
				duplicateCount++;
			}
		}

		var aggregatedEntries = structCount(aggregated);
		var reductionPercent = totalLines > 0 ?
				numberFormat(((totalLines - aggregatedEntries) 	/ totalLines) * 100, "0.0") : "0";
		var aggregationTime = getTickCount() - aggregationStart;

		logger("Post merging: " & numberFormat(aggregatedEntries)
			& " unique (" & reductionPercent & "% reduction)"
		    & " in " & numberFormat(aggregationTime) & "ms");
		// logger("Found " & duplicateCount & " duplicate entries to combine");

		/*
		var exclusionStart = getTickCount();
		if (variables.verbose) {
			var beforeEntities = 0;
			for (var key in aggregated) {
				beforeEntities += structCount(aggregated[key]);
			}
			logger("Total aggregated entries before exclusion: " & numberFormat(beforeEntities));
		}

		// STAGE 1.5: Exclude overlapping blocks
		aggregated =  utils.excludeOverlappingBlocks(aggregated, files, lineMappingsCache);
		if (variables.verbose) {
			var remaining = 0;
			for (var key in aggregated) {
				remaining += structCount(aggregated[key]);
			}
			logger("After excluding overlapping blocks, remaining aggregated entries: "
				& numberFormat(remaining) & " (took "
				& numberFormat(getTickCount() - exclusionStart) & "ms)");
		}
		*/

		// STAGE 2: Process aggregated entries to line coverage
		var processingStart = getTickCount();
		var coverage = {};

		for (var key in aggregated) {
			var entry = aggregated[key];
			var fileIdx = entry.fileIdx;
			var fpath = files[fileIdx].path;
			var lineMapping = lineMappingsCache[fpath];
			var mappingLen = arrayLen(lineMapping);

			// Convert character positions to line numbers
			var startLine = getLineFromCharacterPosition(entry.startPos, fpath, lineMapping, mappingLen);
			var endLine = getLineFromCharacterPosition(entry.endPos, fpath, lineMapping, mappingLen, startLine);

			// Skip invalid positions
			if (startLine == 0 || endLine == 0) {
				continue;
			}

			// Initialize file coverage if needed
			if (!structKeyExists(coverage, fileIdx)) {
				coverage[fileIdx] = {};
			}

			// Add aggregated coverage for each line in the range
			for (var lineNum = startLine; lineNum <= endLine; lineNum++) {
				var lineKey = toString(lineNum);
				if (!structKeyExists(coverage[fileIdx], lineKey)) {
					coverage[fileIdx][lineKey] = [0, 0]; // [count, totalTime]
				}
				coverage[fileIdx][lineKey][1] += entry.count; // add aggregated hit count
				coverage[fileIdx][lineKey][2] += entry.totalTime; // add aggregated execution time
			}
		}

		var processingTime = getTickCount() - processingStart;
		var totalTime = getTickCount() - start;
		var timePerOriginalLine = totalLines > 0 ? numberFormat((totalTime / totalLines), "0.00") : "0";
		var timePerAggregatedEntry = aggregatedEntries > 0 ? numberFormat((processingTime / aggregatedEntries), "0.00") : "0";

		/*
		logger("Processing " & numberFormat(aggregatedEntries)
			& " aggregated entries completed in " & numberFormat(processingTime)
			& "ms (" & timePerAggregatedEntry & "ms per entry), "
			& "Total time:" & numberFormat(totalTime) & "ms, (" & timePerOriginalLine
			& "ms per original line)");
		*/

		// Store performance data to be added at main level
		variables.performanceData = {
			"processingTime": totalTime,
			"timePerLine": timePerOriginalLine,
			"totalLines": totalLines,
			"optimizationsApplied": ["pre-aggregation"],
			"preAggregation": {
				"originalEntries": totalLines,
				"aggregatedEntries": aggregatedEntries,
				"duplicatesFound": duplicateCount,
				"reductionPercent": reductionPercent,
				"aggregationTime": aggregationTime,
				"processingTime": processingTime,
				"timePerAggregatedEntry": timePerAggregatedEntry
			},
			"memoryOptimizations": true,
			"parallelProcessing": false
		};

		return coverage;
	}

	/**
	* Process pre-aggregated coverage data
	*/
	private struct function processAggregatedCoverage(struct aggregatedCoverage, struct files, string exlPath) {
		var coverage = {};

		// Process each unique position once with aggregated data
		for (var key in arguments.aggregatedCoverage) {
			var pos = arguments.aggregatedCoverage[key];
			var fileIdx = pos.fileIdx;

			if (!structKeyExists(arguments.files, fileIdx)) continue;
			var fpath = arguments.files[fileIdx].path;

			// Get line mappings once per file
			if (!structKeyExists(variables.lineMappingsCache, fpath)) {
				variables.lineMappingsCache[fpath] = variables.utils.buildCharacterToLineMapping(
					variables.fileContentsCache[fpath]
				);
			}

			var lineMapping = variables.lineMappingsCache[fpath];
			var mappingLen = arrayLen(lineMapping);

			// Convert to lines once per unique position
			var startLine = getLineFromCharacterPosition(pos.startPos, fpath, lineMapping, mappingLen);
			var endLine = getLineFromCharacterPosition(pos.endPos, fpath, lineMapping, mappingLen, startLine);

			// Initialize file coverage if needed
			if (!structKeyExists(coverage, fileIdx)) {
				coverage[fileIdx] = {};
			}

			// Aggregate line coverage
			for (var lineNum = startLine; lineNum <= endLine; lineNum++) {
				var lineKey = toString(lineNum);
				if (!structKeyExists(coverage[fileIdx], lineKey)) {
					coverage[fileIdx][lineKey] = [0, 0]; // [count, time]
				}
				coverage[fileIdx][lineKey][1] += pos.count;
				coverage[fileIdx][lineKey][2] += pos.totalTime;
			}
		}

		return coverage;
	}

	/**
	* File parsing with early validation
	*/
	private struct function parseFiles(array filesLines, string exlPath,
			array allowList, array blocklist, boolean useAstForLinesFound = true) {

		var files = {};
		var skipped = {};
		var startFiles = getTickCount();

		//logger("Filtering " & arrayLen(arguments.filesLines) & " files");

		for (var i = 1; i <= arrayLen(arguments.filesLines); i++) {
			var line = trim(arguments.filesLines[i]);
			if (line == "") break;
			var num = listFirst(line, ":");
			var path = listRest(line, ":");

			// Early file existence check
			if ( !fileExists( path ) ) {
				variables.fileIgnoreCache[ path ] = "file doesn't exist [" & num & "]";
				skipped[ path ] = "file doesn't exist";
				continue;
			}

			// Early allow/block list filtering
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
			}

			if (!skip) {
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
			}

			if ( !skip ) {
				// Cache file contents immediately
				if ( !structKeyExists( variables.fileContentsCache, path) ) {
					variables.fileContentsCache[ path] = fileRead( path );
				}

				// Build line mapping cache if not exists
				if ( !structKeyExists( variables.lineMappingsCache, path) ) {
					variables.lineMappingsCache[ path] = variables.utils.buildCharacterToLineMapping(
						variables.fileContentsCache[ path]
					);
				}

				var sourceLines = readFileAsArrayBylines( path );
				var lineInfo = {};

				if (arguments.useAstForLinesFound) {
					var ast = astFromPath( path );
					lineInfo = variables.ast.countExecutableLinesFromAst( ast );
				} else {
					lineInfo = variables.ast.countExecutableLinesSimple( sourceLines );
				}

				files[ num ] = {
					"path": path,
					"lineCount": arrayLen( variables.lineMappingsCache[ path] ),
					"linesFound": lineInfo.count,
					"lines": sourceLines,
					"executableLines": lineInfo.executableLines
				};
			}
		}

		var validFiles = structCount(files);
		var skippedFiles = structCount(skipped);
		logger("Post Filter: " & validFiles & " valid files, " & skippedFiles & " skipped, in "
			& numberFormat(getTickCount() - startFiles) & "ms");

		return {
			"files": files,
			"skipped": skipped
		};
	}

	public numeric function getLineFromCharacterPosition( charPos, path, lineMapping, mappingLen, minLine = 1 ) {
		// Binary search to find the line
		var low = arguments.minLine;
		var high = arguments.mappingLen;

		while (low <= high) {
			var mid = int((low + high) / 2);

			if (mid == arguments.mappingLen) {
				// Last line - check if charPos is beyond the start of this line
				return arguments.lineMapping[mid] <= arguments.charPos ? mid : mid - 1;
			} else if (arguments.lineMapping[mid] <= arguments.charPos
				&& arguments.charPos < arguments.lineMapping[mid + 1]) {
				return mid;
			} else if (arguments.lineMapping[mid] > arguments.charPos) {
				high = mid - 1;
			} else {
				low = mid + 1;
			}
		}

		return 0; // Not found
	}

	/**
	* Same as original
	*/
	private array function readFileAsArrayBylines( string path ) {
		if ( !structKeyExists( variables.fileContentsCache, arguments.path ) ) {
			variables.fileContentsCache[ arguments.path ] = fileRead( arguments.path );
		}
		return listToArray( variables.fileContentsCache[ arguments.path ], chr(10), true, false );
	}

	/**
	 * Parse metadata lines from EXL file
	 */
	public struct function parseMetadata(array lines) {
		var metadata = {};
		for (var metaLine in arguments.lines) {
			var parts = listToArray(metaLine, ":", true, true);
			if (arrayLen(parts) >= 2) {
				metadata[parts[1]] = listRest(metaLine, ":");
			}
		}
		return metadata;
	}

}