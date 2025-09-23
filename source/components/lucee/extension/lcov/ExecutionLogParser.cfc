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

		// Use factory for code coverage helpers, support useDevelop override
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.CoverageBlockProcessor = variables.factory.getComponent(name="CoverageBlockProcessor");
		variables.ast = new ExecutableLineCounter(arguments.options);
		return this;
	}

	/**
	* Private logging function that respects verbose setting
	* @message The message to log
	*/
	private void function logger(required string message) {
		if (true || variables.verbose) {
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
	* @return Result object containing sections and fileCoverage data
	*/
	public result function parseExlFile(string exlPath, boolean needSingleFileCoverage = false,
		array allowList=[], array blocklist=[], boolean useAstForLinesFound = false) {

		var startTime = getTickCount();

		var lines = [];
		try {
			lines = listToArray(fileRead(arguments.exlPath), chr(10), true, false);
		} catch (any e) {
			logger("Error reading file [" & arguments.exlPath & "]: " & e.message);
			return { "sections": {}, "fileCoverage": {} };
		}

		// cleanup, the last row is often empty
		if (arrayLen(lines) > 0 && len(trim(lines[arrayLen(lines)])) == 0) {
			arrayDeleteAt(lines, arrayLen(lines));
		}

		var section = 0; // 0=metadata, 1=files, 2=coverage
		var emptyLineCount = 0;
		var metadata = [];
		var files = [];
		var fileCoverage = [];
		var totalLines = arrayLen( lines );
		var start = getTickCount();
		systemOutput("Starting to process " & totalLines & " lines...", true);

		for ( var i = 1; i <= totalLines; i++ ) {
			var line = lines[i];
			if ( len( line ) === 0 ) {
				emptyLineCount++;
				if ( emptyLineCount === 1 ) {
					section = 1; // Start files section
				} else if ( emptyLineCount === 2 ) {
					section = 2; // Start coverage section - use arraySlice for performance
					fileCoverage = arraySlice(lines, i + 1, totalLines - i);
					break; // Bail out - we have everything we need
				}
			} else {
				if ( section === 0 ) {
					arrayAppend( metadata, line );
				} else if ( section === 1 ) {
					arrayAppend( files, line );
				}
			}	
		}
		systemOutput("Processed " & totalLines & " lines in " & numberFormat(getTickCount() - start, "0.0") & "ms", true);
		lines = ""; // free memory
3
		var coverage = new lucee.extension.lcov.model.result();

		coverage.setMetadata(parseMetadata( metadata ));
		// Parse files and assign to canonical files struct
		var parsedFiles = parseFiles( files, exlPath, allowList, blocklist, arguments.useAstForLinesFound );
		coverage.setFiles(parsedFiles.files);
		coverage.setFileCoverage(fileCoverage);
		coverage.setExeLog(exlPath);

		if ( structCount( coverage.getFiles() ) == 0 && arrayLen( coverage.getFileCoverage() ) == 0 ) {
			logger("Skipping file with empty files and fileCoverage: [" & exlPath & "]");
			return {};
		}

		// OPTIMIZATION: Pre-aggregate coverage data before expensive processing
		parseCoverage( coverage );

		var totalTime = getTickCount() - startTime;
		logger("Files: " & structCount( coverage.getFiles() ) &
			//", skipped files: " & len( coverage.source.skipped ) & "] skipped" &
			", raw rows: " & numberFormat(arrayLen( coverage.getFileCoverage() )) &
			", in " & numberFormat(totalTime ) & "ms");

		// Write out filecoverage as json using compact=false for debugging
		fileWrite( replace( arguments.exlPath, ".exl", ".json" ), coverage.toJson(pretty=true) );
		logger( "" );


		return coverage;
	}

	/**
	* Combine identical coverage entries before line processing
	*/
	private struct function parseCoverage( result coverageData) {
		var totalLines = arrayLen(arguments.coverageData.getFileCoverage());
		var files = arguments.coverageData.getFiles();
		var fileCoverage = arguments.coverageData.getFileCoverage();
		var exlPath = arguments.coverageData.getExeLog();
		var start = getTickCount();

		// Build line mappings cache for all files and create fileIdx lookup
		var lineMappingsCache = {};
		var validFileIds = {};
		for (var fileIdx in files) {
			var fpath = files[fileIdx].path;
			lineMappingsCache[fpath] = variables.lineMappingsCache[fpath];
			validFileIds[fileIdx] = true; // Pre-compute valid fileIdx lookup
		}

		// STAGE 1: Pre-aggregate identical coverage entries using optimized chunked parallel approach
		var aggregator = new lucee.extension.lcov.CoverageAggregator();
		var aggregationResult = aggregator.aggregateChunked(fileCoverage, validFileIds, totalLines);

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
		var processor = new lucee.extension.lcov.CoverageProcessor();
		var processingResult = processor.processAggregatedToLineCoverage(
			aggregationResult.aggregated,
			files,
			lineMappingsCache,
			this
		);
		var coverage = processingResult.coverage;
		var processingTime = processingResult.processingTime;
		var totalTime = getTickCount() - start;
		var timePerOriginalLine = totalLines > 0 ? numberFormat((totalTime / totalLines), "0.00") : "0";
		var timePerAggregatedEntry = aggregationResult.aggregatedEntries > 0 ? numberFormat((processingTime / aggregationResult.aggregatedEntries), "0.00") : "0";

		/*
		logger("Processing " & numberFormat(aggregatedEntries)
			& " aggregated entries completed in " & numberFormat(processingTime)
			& "ms (" & timePerAggregatedEntry & "ms per entry), "
			& "Total time:" & numberFormat(totalTime) & "ms, (" & timePerOriginalLine
			& "ms per original line)");
		*/

		// Store performance data to be added at main level
		coverageData.setParserPerformance({
			"processingTime": totalTime,
			"timePerLine": timePerOriginalLine,
			"totalLines": totalLines,
			"optimizationsApplied": ["pre-aggregation", "array-storage", "reference-variables", "direct-chr9"],
			"preAggregation": {
				"originalEntries": totalLines,
				"aggregatedEntries": aggregationResult.aggregatedEntries,
				"duplicatesFound": aggregationResult.duplicateCount,
				"reductionPercent": aggregationResult.reductionPercent,
				"aggregationTime": aggregationResult.aggregationTime,
				"processingTime": processingTime,
				"timePerAggregatedEntry": timePerAggregatedEntry
			},
			"memoryOptimizations": true,
			"parallelProcessing": false
		});
		coverageData.setCoverage(coverage);
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
				variables.lineMappingsCache[fpath] = variables.CoverageBlockProcessor.buildCharacterToLineMapping(
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
			array allowList, array blocklist, boolean useAstForLinesFound = false) {

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
					variables.lineMappingsCache[ path] = variables.CoverageBlockProcessor.buildCharacterToLineMapping(
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
					   "linesSource": arrayLen( variables.lineMappingsCache[ path] ),
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
		return LinePositionUtils::getLineFromCharacterPosition(
			arguments.charPos,
			arguments.lineMapping,
			arguments.mappingLen,
			arguments.minLine
		);
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