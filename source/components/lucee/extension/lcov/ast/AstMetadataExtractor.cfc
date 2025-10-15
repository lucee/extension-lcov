/**
 * Extracts metadata from AST for caching.
 *
 * Performs ONE AST traversal to extract:
 * 1. CallTree positions (function call locations)
 * 2. Executable line counts (which lines have executable code)
 *
 * This avoids duplicate AST parsing - both extractions happen in one pass.
 */
component {

	property name="logger";
	property name="astCallAnalyzer";
	property name="executableLineCounter";
	property name="astParserHelper";

	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( logLevel="ERROR" );
		variables.astCallAnalyzer = new lucee.extension.lcov.ast.AstCallAnalyzer( logger=variables.logger );
		variables.executableLineCounter = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );
		variables.astParserHelper = new lucee.extension.lcov.parser.AstParserHelper( logger=variables.logger );
		return this;
	}

	/**
	 * Extract all metadata from AST (CallTree + executable lines).
	 *
	 * @ast The parsed AST object
	 * @filePath The file path (for logging/debugging)
	 * @return Struct with {callTree, executableLineCount, executableLines}
	 */
	public struct function extractMetadata(required any ast, required string filePath) localmode="modern" {
		var startTime = getTickCount();

		// 1. Extract CallTree positions using AstCallAnalyzer
		var functions = variables.astCallAnalyzer.extractFunctions( arguments.ast );
		var callTree = structNew( "regular" );

		// Extract all calls from all functions
		// Key by position only (no fileIdx yet - that's determined per-request in annotateCallTree)
		cfloop( array=functions, item="local.func" ) {
			// Add calls from this function's body
			if ( structKeyExists( func, "calls" ) && isArray( func.calls ) ) {
				cfloop( array=func.calls, item="local.call" ) {
					if ( structKeyExists( call, "position" ) ) {
						// Store by position only - CallTreeAnnotator will add fileIdx prefix in annotateCallTree
						var key = call.position;
						callTree[key] = {
							"isChildTime": true,
							"isBuiltIn": call.isBuiltIn ?: false,
							"functionName": call.name ?: ""
						};
					}
				}
			}
		}

		// 1b. ALSO extract top-level calls from AST body (for .cfm files and top-level scripts)
		// This is essential for .cfm files which have code at the root level, not in functions
		var topLevelCalls = [];
		var helper = new lucee.extension.lcov.ast.CallTreeParallelHelpers();
		helper.extractCFMLTagsAndCalls( arguments.ast, topLevelCalls );

		// Add top-level calls to callTree
		cfloop( array=topLevelCalls, item="local.call" ) {
			if ( structKeyExists( call, "position" ) && call.position > 0 ) {
				callTree[call.position] = {
					"isChildTime": true,
					"isBuiltIn": call.isBuiltIn ?: false,
					"functionName": call.name ?: ""
				};
			}
		}

		// 2. Extract executable lines using ExecutableLineCounter
		var lineInfo = variables.executableLineCounter.countExecutableLinesFromAst( arguments.ast );

		var elapsedTime = getTickCount() - startTime;
		variables.logger.debug( "Extracted metadata for [#arguments.filePath#] in #elapsedTime#ms: #structCount(callTree)# call positions, #lineInfo.count# executable lines" );

		return {
			"callTree": callTree,
			"executableLineCount": lineInfo.count,
			"executableLines": lineInfo.executableLines
		};
	}

	/**
	 * Extract metadata for multiple files (batch processing).
	 *
	 * @files Struct of {fileIdx: {path: "..."}} or array of file paths
	 * @return Struct keyed by file path with metadata for each
	 */
	public struct function extractMetadataForFiles(required any files) localmode="modern" {
		var metadata = structNew( "regular" );
		var filePaths = [];

		// Normalize input to array of paths
		if ( isStruct( arguments.files ) ) {
			cfloop( collection=arguments.files, item="local.idx" ) {
				arrayAppend( filePaths, arguments.files[idx].path );
			}
		} else if ( isArray( arguments.files ) ) {
			filePaths = arguments.files;
		} else {
			throw( type="AstMetadataExtractor.InvalidInput", message="files must be struct or array" );
		}

		// Extract metadata for each unique file
		cfloop( array=filePaths, item="local.filePath" ) {
			if ( !fileExists( filePath ) ) {
				variables.logger.warn( "Skipping metadata extraction for missing file: #filePath#" );
				continue;
			}

			// Parse AST using AstParserHelper (has fallback logic for .cfm files)
			var ast = variables.astParserHelper.parseFileAst( filePath, fileRead( filePath ) );
			metadata[filePath] = extractMetadata( ast, filePath );
		}

		return metadata;
	}

}
