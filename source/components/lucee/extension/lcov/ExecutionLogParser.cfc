component {

	/**
	* Initialize the parser with cache structures
	* @options Configuration options struct (optional)
	* @sharedAstCache Optional shared AST cache for multi-file processing (avoids re-parsing same files)
	*/
	public function init(struct options = {}, struct sharedAstCache) {
		// Store options and extract logLevel
		variables.options = arguments.options;
		var logLevel = variables.options.logLevel ?: "none";
		variables.logger = new lucee.extension.lcov.Logger(level=logLevel);

		// Initialize core helpers
		variables.CoverageBlockProcessor = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=variables.logger );
		variables.ast = new ast.ExecutableLineCounter( logger=variables.logger, options=arguments.options );
		variables.callTreeAnalyzer = new ast.CallTreeAnalyzer( logger=variables.logger );

		// Cache structures for performance optimization
		variables.fileIgnoreCache = {}; // files not allowed due to allow/block lists
		variables.fileAnalysisCache = {}; // cache for file analysis (AST + executable lines) to avoid regenerating across .exl files

		// Use shared AST cache if provided (for parallel processing), otherwise use instance cache
		if (structKeyExists(arguments, "sharedAstCache")) {
			variables.astCache = arguments.sharedAstCache;
		} else {
			variables.astCache = {}; // parsed AST cache to avoid re-parsing same files
		}

		// Initialize parser helpers
		variables.fileFilterHelper = new parser.FileFilterHelper( logger=variables.logger );
		variables.fileCacheHelper = new parser.FileCacheHelper( logger=variables.logger, blockProcessor=variables.CoverageBlockProcessor );
		variables.astParserHelper = new parser.AstParserHelper( logger=variables.logger, sharedAstCache=variables.astCache );
		variables.fileEntryBuilder = new parser.FileEntryBuilder( logger=variables.logger, executableLineCounter=variables.ast );
		variables.cacheValidator = new parser.CacheValidator( logger=variables.logger );
		variables.exlSectionReader = new parser.ExlSectionReader( logger=variables.logger );

		// Initialize coverage processing helpers
		variables.coverageAggregationPipeline = new lucee.extension.lcov.coverage.CoverageAggregationPipeline( logger=variables.logger, blockProcessor=variables.CoverageBlockProcessor );
		variables.blockToLineAggregator = new lucee.extension.lcov.coverage.BlockToLineAggregator( logger=variables.logger );

		return this;
	}

	/**
	* Parse a single .exl file and extract sections and file coverage data
	* @exlPath Path to the .exl file to parse
	* @allowList Array of allowed file patterns/paths
	* @blocklist Array of blocked file patterns/paths
	* @writeJsonCache Whether to write a JSON cache file
	* @includeCallTree Whether to include call tree analysis
	* @includeSourceCode Whether to include source code in output
	* @return Result object containing sections and fileCoverage data
	*/
	public function parseExlFile(exlPath, allowList=[], blocklist=[], writeJsonCache=false, includeCallTree=false, includeSourceCode=true) {

		var startTime = getTickCount();

		// Check for cached result
		var cacheCheck = variables.cacheValidator.loadCachedResultIfValid(
			exlPath=arguments.exlPath,
			allowList=arguments.allowList,
			blocklist=arguments.blocklist,
			includeCallTree=arguments.includeCallTree
		);
		if (cacheCheck.valid) {
			return cacheCheck.result;
		}

		// Read .exl sections (metadata, files, coverage start byte)
		var sections = variables.exlSectionReader.readExlSections(arguments.exlPath);

		// Build result object from sections
		var coverage = new lucee.extension.lcov.model.result();
		coverage.setMetadata(parseMetadata(sections.metadata));
		coverage.setExeLog(arguments.exlPath);
		coverage.setCoverageStartByte(sections.coverageStartByte);

		// Parse files if sections are not empty
		if (arrayLen(sections.files) > 0) {
			var parsedFiles = parseFiles(
				sections.files,
				arguments.exlPath,
				arguments.allowList,
				arguments.blocklist,
				arguments.includeSourceCode
			);
			coverage.setFiles(parsedFiles.files);
		} else {
			coverage.setFiles({});
		}

		// Calculate and store checksum
		if (fileExists(arguments.exlPath)) {
			try {
				var fileInfo = fileInfo(arguments.exlPath);
				coverage.setExlChecksum(fileInfo.checksum);
			} catch (any e) {
				variables.logger.debug("Warning: Failed to calculate checksum for [" & arguments.exlPath & "]: " & e.message);
				coverage.setExlChecksum("");
			}
		}

		// Store options hash (delegate to CacheValidator for consistency)
		var optionsHash = variables.cacheValidator.calculateOptionsHash(
			arguments.allowList,
			arguments.blocklist,
			arguments.includeCallTree
		);
		coverage.setOptionsHash(optionsHash);

		// If result is empty, return it without processing coverage
		if (structCount(coverage.getFiles()) == 0 || sections.coverageStartByte == 0) {
			variables.logger.debug("Skipping file with empty files or no coverage data: [" & arguments.exlPath & "]");
			return coverage;
		}

		// Parse coverage data (the expensive part)
		parseCoverage(
			coverageData=coverage,
			callTreeAnalyzer=variables.callTreeAnalyzer,
			includeCallTree=arguments.includeCallTree
		);

		var totalTime = getTickCount() - startTime;
		variables.logger.debug("Parsed coverage from: " & structCount(coverage.getFiles()) & " files, in " & numberFormat(totalTime) & "ms");

		// Write JSON cache if requested
		if (arguments.writeJsonCache) {
			var jsonPath = reReplace(arguments.exlPath, "\.exl$", ".json");
			variables.logger.debug("parseExlFile: Writing JSON cache to " & jsonPath);
			fileWrite(jsonPath, coverage.toJson(pretty=false, excludeFileCoverage=true));
		}

		variables.logger.debug("");
		return coverage;
	}

	/**
	 * Combine identical coverage entries before line processing
	 * @coverageData The result object containing coverage data to parse
	 * @callTreeAnalyzer The call tree analyzer component for AST analysis
	 * @includeCallTree Whether to include call tree analysis (default: false)
	 * @return The updated coverageData result object
	 */
	private function parseCoverage(coverageData, callTreeAnalyzer, includeCallTree) localmode=true {
		var files = arguments.coverageData.getFiles();
		var exlPath = arguments.coverageData.getExeLog();
		var start = getTickCount();

		// Get line mappings cache from FileCacheHelper
		var lineMappingsCache = variables.fileCacheHelper.getLineMappingsCache();
		var validFileIds = {};
		cfloop( collection=files, key="local.fileIdx" ) {
			validFileIds[fileIdx] = true;
		}

		// STAGE 1 & 1.5: Aggregate and filter coverage
		var aggregationResult = variables.coverageAggregationPipeline.aggregateAndFilter(
			exlPath,
			validFileIds,
			files,
			lineMappingsCache
		);

		// Store aggregated format (parseExecutionLogs - minimal JSON)
		arguments.coverageData.setAggregated( aggregationResult.aggregated );

		// Set flags to indicate no enrichment has been done yet
		arguments.coverageData.setFlags({
			"hasCallTree": false,
			"hasBlocks": false,
			"hasCoverage": false
		});

		// Calculate totals and store performance data
		var totalTime = getTickCount() - start;

		arguments.coverageData.setParserPerformance({
			"processingTime": totalTime,
			"optimizationsApplied": ["pre-aggregation", "array-storage", "streaming-aggregation"],
			"preAggregation": {
				"aggregatedEntries": aggregationResult.aggregatedEntries,
				"duplicatesFound": aggregationResult.duplicateCount,
				"aggregationTime": aggregationResult.aggregationTime
			},
			"memoryOptimizations": true,
			"parallelProcessing": false
		});

		// parseExecutionLogs complete - STOP HERE
		// No CallTree, no blocks, no coverage yet
		// Those happen later in buildLineCoverage/annotateCallTree
		return arguments.coverageData;
	}

	/**
	* File parsing with early validation
	* @filesLines Array of file lines from .exl file (format: "index:path")
	* @exlPath Path to the .exl file being parsed
	* @allowList Array of allowed file patterns/paths for filtering
	* @blocklist Array of blocked file patterns/paths for filtering
	* @includeSourceCode Whether to include source code in file entries (default: true)
	* @return Struct containing "files" (valid parsed files) and "skipped" (filtered files)
	*/
	private function parseFiles(filesLines, exlPath, allowList, blocklist, includeSourceCode = true) localmode=true {

		var files = structNew('regular');
		var skipped = structNew('regular');
		var startFiles = getTickCount();

		cfloop( array=arguments.filesLines, index="local.i", item="local.line" ) {
			line = trim(line);
			if (line == "") break;
			var num = listFirst(line, ":");
			var path = listRest(line, ":");

			// Use FileFilterHelper for allow/blocklist filtering
			if (variables.fileFilterHelper.shouldSkipFile(path, arguments.allowList, arguments.blocklist)) {
				variables.fileIgnoreCache[path] = "filtered by allow/blocklist";
				skipped[path] = path & " filtered";
				continue;
			}

			// Early file existence check
			if (!fileExists(path)) {
				throw(
					type="ExecutionLogParser.SourceFileNotFound",
					message="Source file [#path#] referenced in execution log does not exist",
					detail="File path: [" & path & "] (index: " & num & ") - The execution log references a source file that cannot be found. This typically happens when parsing logs from a different system or after files have been moved/deleted."
				);
			}

			// Get all file data (content, lineMapping, sourceLines) in a single call
			var fileData = variables.fileCacheHelper.getFileData(path);

			// OPTIMIZATION: Skip AST parsing during parseExlFile phase
			// AST metadata (including linesFound) is extracted later in batch via extractAstMetadata
			// This eliminates duplicate AST parsing (5,307 .exl files × ~15 files = ~80k parses → 74 unique parses)

			// Use FileEntryBuilder to create file entry struct
			files[num] = variables.fileEntryBuilder.buildFileEntry(
				fileIndex=num,
				path=path,
				lineMapping=fileData.lineMapping,
				fileContent=fileData.content,
				sourceLines=fileData.sourceLines,
				includeSourceCode=arguments.includeSourceCode
			);
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

	/**
	 * Parse metadata lines from EXL file
	 */
	public struct function parseMetadata(array lines) localmode=true {
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