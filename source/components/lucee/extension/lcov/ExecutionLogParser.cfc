component accessors="true" {
	// Cache structures for performance optimization
	property name="fileContentsCache" type="struct" default="#{}#";
	property name="fileBlockIgnoreCache" type="struct" default="#{}#";
	property name="lineMappingsCache" type="struct" default="#{}#";
	property name="positionMappingsCache" type="struct" default="#{}#";
	property name="fileExistsCache" type="struct" default="#{}#";
	property name="fileIgnoreCache" type="struct" default="#{}#"; // files not allowed due to allow/block lists
	property name="astCache" type="struct" default="#{}#"; // parsed AST cache to avoid re-parsing same files

	/**
	* Initialize the parser with cache structures
	* @options Configuration options struct (optional)
	*/
	public function init(struct options = {}) {
		// Store options and extract logLevel
		variables.options = arguments.options;
		var logLevel = structKeyExists(variables.options, "logLevel") ? variables.options.logLevel : "none";
		variables.logger = new lucee.extension.lcov.Logger(level=logLevel);

		// Use factory for code coverage helpers, support useDevelop override
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.CoverageBlockProcessor = variables.factory.getComponent( name="CoverageBlockProcessor" );
		variables.ast = new ast.ExecutableLineCounter( logger=variables.logger, options=arguments.options );
		variables.callTreeAnalyzer = new ast.CallTreeAnalyzer( logger=variables.logger );

		// Cache for file analysis (AST + executable lines) to avoid regenerating across .exl files
		variables.fileAnalysisCache = {};
		return this;
	}

	/**
	* Parse a single .exl file and extract sections and file coverage data
	* @exlPath Path to the .exl file to parse
	* @allowList Array of allowed file patterns/paths
	* @blocklist Array of blocked file patterns/paths
	* @writeJsonCache Whether to write a JSON cache file
	* @return Result object containing sections and fileCoverage data
	*/
	public result function parseExlFile(string exlPath,
		array allowList=[], array blocklist=[], boolean writeJsonCache = false, boolean includeCallTree = false) {

		var startTime = getTickCount();

		// Check for cached JSON result with matching checksum and options
		var jsonPath = reReplace(arguments.exlPath, "\.exl$", ".json");
		if (fileExists(jsonPath) && fileExists(arguments.exlPath)) {
			try {
				// Calculate current .exl file checksum
				var currentChecksum = fileInfo(arguments.exlPath).checksum;

				// Parse JSON directly and check checksum and options
				var cachedData = deserializeJSON(fileRead(jsonPath));
				var cachedChecksum = structKeyExists(cachedData, "exlChecksum") ? cachedData.exlChecksum : "";

				// Create options hash for comparison
				var currentOptionsHash = hash(serializeJSON([arguments.allowList, arguments.blocklist, arguments.includeCallTree]), "MD5");
				var cachedOptionsHash = structKeyExists(cachedData, "optionsHash") ? cachedData.optionsHash : "";

				if (len(cachedChecksum) && cachedChecksum == currentChecksum && currentOptionsHash == cachedOptionsHash) {
					variables.logger.debug("Using cached result for [" & getFileFromPath(arguments.exlPath) & "]");
					// Use the static fromJson method but disable validation to avoid schema issues
					var cachedResult = new lucee.extension.lcov.model.result().fromJson(fileRead(jsonPath), false);
					return cachedResult;
				} else {
					variables.logger.debug("Checksum mismatch for [" & arguments.exlPath & "] - re-parsing (cached: " & cachedChecksum & ", current: " & currentChecksum & ")");
					// Delete outdated cached file
					fileDelete(jsonPath);
				}
			} catch (any e) {
				variables.logger.debug("Failed to load cached result for [" & arguments.exlPath & "]: " & e.message & " - re-parsing");
				// Delete invalid cached file
				fileDelete(jsonPath);
			}
		}

		// OPTIMIZATION: Use BufferedReader to parse metadata/files sections without loading entire file
		var section = 0; // 0=metadata, 1=files, 2=coverage
		var emptyLineCount = 0;
		var metadata = [];
		var files = [];
		var coverageStartByte = 0;
		var start = getTickCount();

		try {
			var reader = createObject("java", "java.io.BufferedReader").init(
				createObject("java", "java.io.FileReader").init(arguments.exlPath)
			);

			try {
				var bytesRead = 0;
				var line = "";

				while (true) {
					line = reader.readLine();
					if (isNull(line)) break;

					var lineLength = len(line) + 1; // +1 for newline character

					if (len(line) == 0) {
						emptyLineCount++;
						if (emptyLineCount == 1) {
							section = 1; // Start files section
						} else if (emptyLineCount == 2) {
							// Found start of coverage section
							coverageStartByte = bytesRead + lineLength;
							break; // Stop reading - we have metadata and files
						}
					} else {
						if (section == 0) {
							arrayAppend(metadata, line);
						} else if (section == 1) {
							arrayAppend(files, line);
						}
					}

					bytesRead += lineLength;
				}
			} finally {
				reader.close();
			}

			variables.logger.trace("Parsed metadata and files sections in " & numberFormat(getTickCount() - start) & "ms. Coverage starts at byte " & numberFormat(coverageStartByte));
		} catch (any e) {
			variables.logger.debug("Error reading file [" & arguments.exlPath & "]: " & e.message);
			// Return empty result object instead of plain struct
			var emptyResult = new lucee.extension.lcov.model.result();
			emptyResult.setMetadata({});
			emptyResult.setFiles({});
			emptyResult.setExeLog(arguments.exlPath);
			return emptyResult;
		}
3
		var coverage = new lucee.extension.lcov.model.result();

		coverage.setMetadata(parseMetadata( metadata ));
		// Parse files and assign to canonical files struct
		var parsedFiles = parseFiles( files, exlPath, allowList, blocklist );
		coverage.setFiles(parsedFiles.files);
		coverage.setExeLog(exlPath);
		coverage.setCoverageStartByte(coverageStartByte); // Store byte offset for streaming aggregation

		// Calculate and store checksum of the .exl file to detect reprocessing
		if (fileExists(exlPath)) {
			try {
				var fileInfo = fileInfo(exlPath);
				coverage.setExlChecksum(fileInfo.checksum);
			} catch (any e) {
				// If checksum calculation fails, leave it empty
				// log a warning
				variables.logger.debug("Warning: Failed to calculate checksum for [" & exlPath & "]: " & e.message);
				coverage.setExlChecksum("");
			}
		}

		// Store options hash for cache validation
		var optionsHash = hash(serializeJSON([arguments.allowList, arguments.blocklist]), "MD5");
		coverage.setOptionsHash(optionsHash);

		if ( structCount( coverage.getFiles() ) == 0 || coverageStartByte == 0 ) {
			variables.logger.debug("Skipping file with empty files or no coverage data: [" & exlPath & "]");
			// Return the empty coverage result object instead of plain struct
			return coverage;
		}

		// OPTIMIZATION: Pre-aggregate coverage data before expensive processing
		parseCoverage( coverageData=coverage, callTreeAnalyzer=variables.callTreeAnalyzer, includeCallTree=arguments.includeCallTree );

		var totalTime = getTickCount() - startTime;
		variables.logger.debug("Parsed coverage from: " & structCount( coverage.getFiles() ) & " files,  in " & numberFormat(totalTime ) & "ms");

		// Write JSON cache if requested
		if (arguments.writeJsonCache) {
			variables.logger.debug("parseExlFile: Writing JSON cache to " & jsonPath);
			fileWrite(jsonPath, coverage.toJson(pretty=false, excludeFileCoverage=true));
		}

		variables.logger.debug( "" );


		return coverage;
	}

	/**
	* Combine identical coverage entries before line processing
	*/
	private struct function parseCoverage( result coverageData, required any callTreeAnalyzer, boolean includeCallTree = false) localmode="modern" {
		var files = arguments.coverageData.getFiles();
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

		// STAGE 1: Pre-aggregate identical coverage entries using optimized streaming parallel approach
		var aggregator = new lucee.extension.lcov.CoverageAggregator( logger=variables.logger );
		var aggregationResult = aggregator.aggregate( exlPath, validFileIds );

		var exclusionStart = getTickCount();
		var beforeEntities = structCount(aggregationResult.aggregated);
		variables.logger.debug("Total aggregated entries before exclusion: " & numberFormat(beforeEntities));

		// STAGE 1.5: Exclude overlapping blocks using position-based filtering
		var overlapFilter = variables.factory.getComponent(name="OverlapFilterPosition");
		aggregationResult.aggregated = overlapFilter.filter(aggregationResult.aggregated, files, lineMappingsCache);
		var remaining = structCount(aggregationResult.aggregated);
		variables.logger.debug("After excluding overlapping blocks, remaining aggregated entries: "
			& numberFormat(remaining) & " (took "
			& numberFormat(getTickCount() - exclusionStart) & "ms)");

		// STAGE 1.6: Call tree analysis using AST
		var callTreeStart = getTickCount();
		var callTreeData = {};
		var callTreeResult = arguments.callTreeAnalyzer.analyzeCallTree( aggregationResult.aggregated, files );
		var callTreeMetrics = arguments.callTreeAnalyzer.getCallTreeMetrics( callTreeResult );

		callTreeData = {
			"callTree": callTreeResult.blocks,
			"callTreeMetrics": callTreeMetrics
		};

		variables.logger.debug("Call tree analysis completed in " & numberFormat(getTickCount() - callTreeStart)
			& "ms. Blocks: " & callTreeMetrics.totalBlocks
			& ", Child time blocks: " & callTreeMetrics.childTimeBlocks
			& ", Built-in blocks: " & callTreeMetrics.builtInBlocks);

		// STAGE 1.7: Map call tree data to lines for display
		var lineMapperStart = getTickCount();
		var callTreeLineMapper = new lucee.extension.lcov.ast.CallTreeLineMapper();
		var blockProcessor = factory.getComponent(name="CoverageBlockProcessor");
		var lineCallTree = callTreeLineMapper.mapCallTreeToLines(callTreeResult, files, blockProcessor);

		variables.logger.debug("Call tree line mapping completed in " & numberFormat(getTickCount() - lineMapperStart)
			& "ms. Lines with call tree data: " & structCount(lineCallTree));

		// STAGE 1.8: Store block-level data in result model with isChild flag from call tree
		var blockStorageStart = getTickCount();
		var blockAggregator = new lucee.extension.lcov.BlockAggregator();
		var blocks = blockAggregator.convertAggregatedToBlocks(aggregationResult.aggregated, callTreeResult.blocks);
		arguments.coverageData.setBlocks(blocks);
		variables.logger.debug("Block storage completed in " & numberFormat(getTickCount() - blockStorageStart) & "ms");

		// STAGE 2: Aggregate blocks to line coverage using new block-based pipeline
		var aggregatorStart = getTickCount();
		var blockAggregator = new lucee.extension.lcov.BlockAggregator();
		var coverage = {};

		for (var fileIdx in files) {
			var fileInfo = files[fileIdx];

			// Aggregate blocks for this file
			if (structKeyExists(blocks, fileIdx) && structCount(blocks[fileIdx]) > 0) {
				// Ensure line mapping exists for this file
				if (!structKeyExists(variables.lineMappingsCache, fileInfo.path)) {
					throw(message="Line mapping not found for file: " & fileInfo.path & " (fileIdx: " & fileIdx & ")");
				}

				coverage[fileIdx] = blockAggregator.aggregateBlocksToLines(
					arguments.coverageData,
					fileIdx,
					variables.lineMappingsCache[fileInfo.path]
				);
			} else {
				coverage[fileIdx] = {};
			}

			// STAGE 2.5: Add zero-count entries for unexecuted executable lines
			// This makes coverage the single source of truth (all executable lines present)
			if (structKeyExists(fileInfo, "executableLines")) {
				for (var lineNum in fileInfo.executableLines) {
					if (!structKeyExists(coverage[fileIdx], lineNum)) {
						coverage[fileIdx][lineNum] = [0, 0, 0]; // [hitCount, ownTime, childTime] - NEW FORMAT
					}
				}
			}

			// Remove temporary fields now that coverage has been populated
			structDelete(fileInfo, "executableLines");
			structDelete(fileInfo, "ast");  // AST only needed during parsing, not in JSON output
			structDelete(fileInfo, "lineMapping");  // Line mapping only needed during parsing
			structDelete(fileInfo, "mappingLen");  // Mapping length only needed during parsing
		}

		var processingTime = getTickCount() - aggregatorStart;
		variables.logger.debug("Block aggregation to lines completed in " & numberFormat(processingTime) & "ms");

		var totalTime = getTickCount() - start;
		var timePerAggregatedEntry = aggregationResult.aggregatedEntries > 0 ? numberFormat((processingTime / aggregationResult.aggregatedEntries), "0.00") : "0";

		// Store performance data to be added at main level
		coverageData.setParserPerformance({
			"processingTime": totalTime,
			"timePerEntry": timePerAggregatedEntry,
			"optimizationsApplied": ["pre-aggregation", "array-storage", "reference-variables", "direct-chr9", "ast-call-tree", "streaming-aggregation"],
			"preAggregation": {
				"aggregatedEntries": aggregationResult.aggregatedEntries,
				"duplicatesFound": aggregationResult.duplicateCount,
				"aggregationTime": aggregationResult.aggregationTime,
				"processingTime": processingTime,
				"timePerAggregatedEntry": timePerAggregatedEntry
			},
			"memoryOptimizations": true,
			"parallelProcessing": false
		});
		coverageData.setCoverage(coverage);

		// Add call tree data if available (only when explicitly requested to reduce JSON size)
		if (!structIsEmpty(callTreeData)) {
			if (arguments.includeCallTree) {
				coverageData.setCallTree(callTreeData.callTree);
			}
			coverageData.setCallTreeMetrics(callTreeData.callTreeMetrics);
		}
		return coverageData;
	}

	/**
	* File parsing with early validation
	*/
	private struct function parseFiles(array filesLines, string exlPath,
			array allowList, array blocklist) localmode="modern" {

		var files = {};
		var skipped = {};
		var startFiles = getTickCount();

		//logger("Filtering " & arrayLen(arguments.filesLines) & " files");

		for (var i = 1; i <= arrayLen(arguments.filesLines); i++) {
			var line = trim(arguments.filesLines[i]);
			if (line == "") break;
			var num = listFirst(line, ":");
			var path = listRest(line, ":");

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
				if (skip) {
					variables.logger.debug("Skipping file [" & path & "] - not in allowList");
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
						variables.logger.debug("Skipping file [" & path & "] - found in blocklist pattern [" & pattern & "]");
						break;
					}
				}
			}

			if ( !skip ) {
				// Early file existence check
				if ( !fileExists( path ) ) {
					throw(
						type="ExecutionLogParser.SourceFileNotFound",
						message="Source file [#path#] referenced in execution log does not exist",
						detail="File path: [" & path & "] (index: " & num & ") - The execution log references a source file that cannot be found. This typically happens when parsing logs from a different system or after files have been moved/deleted."
					);
				}

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


				// Check AST cache first
				if ( structKeyExists( variables.astCache, path ) ) {
					var ast = variables.astCache[ path ];
				} else {
					// WORKAROUND: astFromString() treats .cfc files as StringLiteral (Lucee bug LDEV-5839)
					// Use astFromPath() which parses .cfc files correctly
					try {
						var ast = astFromPath( path );
					} catch ( any e ) {
						// astFromPath() can fail with certain files - fall back to astFromString()
						variables.logger.debug( "astFromPath failed for [" & path & "], falling back to astFromString: " & e.message );
						var fileContent = variables.fileContentsCache[ path ];

						// Fix for .cfc files: wrap in cfscript tags if it doesn't contain cfcomponent tag
						if ( path.endsWith( ".cfc" ) && !findNoCase( "<" & "cfcomponent", fileContent ) ) {
							fileContent = "<" & "cfscript>" & fileContent & "</" & "cfscript>";
						}

						var ast = astFromString( fileContent );
					}

					// Cache the AST for future use
					variables.astCache[ path ] = ast;
				}

				// DEBUG: write the ast to a debug file
				var debugAstOutput = structKeyExists(server.system.environment, "LCOV_DEBUG_AST") && server.system.environment.LCOV_DEBUG_AST == "true";
				if (debugAstOutput) {
					var astDebugDir = getTempDirectory() & "lcov-ast-debug/";
					if (!directoryExists(astDebugDir)) {
						directoryCreate(astDebugDir);
					}
					var fileName = listLast(path, "\/");
					var astDebugPath = astDebugDir & fileName & ".ast.json";
					variables.logger.debug( "Writing AST debug file: " & astDebugPath );
					fileWrite( astDebugPath, serializeJSON(ast, false, "utf-8") );
				}

				// Always use AST-based counting (matches what Lucee tracks)
				lineInfo = variables.ast.countExecutableLinesFromAst( ast );

				files[ num ] = {
					"path": path,
					"linesSource": arrayLen( variables.lineMappingsCache[ path] ),
					"linesFound": lineInfo.count,
					"lines": sourceLines,
					"content": variables.fileContentsCache[ path ],  // Full file content for block extraction
					"ast": ast,  // Store AST for call tree analysis
					"executableLines": lineInfo.executableLines  // Temporary - used for zero-count population then removed from struct
				};
			}
		}

		var validFiles = structCount(files);
		var skippedFiles = structCount(skipped);
		variables.logger.debug("Post Filter: " & validFiles & " valid files, "
			& skippedFiles & " skipped, in "
			& numberFormat(getTickCount() - startFiles) & "ms");
			

		return {
			"files": files,
			"skipped": skipped
		};
	}

	public numeric function getLineFromCharacterPosition( charPos, path, lineMapping, mappingLen, minLine = 1 ) localmode="modern" {
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
	private array function readFileAsArrayBylines( string path ) localmode="modern" {
		if ( !structKeyExists( variables.fileContentsCache, arguments.path ) ) {
			variables.fileContentsCache[ arguments.path ] = fileRead( arguments.path );
		}
		return listToArray( variables.fileContentsCache[ arguments.path ], chr(10), true, false );
	}


	/**
	 * Parse metadata lines from EXL file
	 */
	public struct function parseMetadata(array lines) localmode="modern" {
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