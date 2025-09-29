component {
	/**
	 * Maps call tree position-based data to line numbers for display in line-by-line coverage reports.
	 * Takes call tree blocks with character positions and maps them to the corresponding line numbers.
	 */

	/**
	 * Maps call tree data from character positions to line numbers
	 * @callTree The call tree result structure from CallTreeAnalyzer (with blocks and metrics)
	 * @files The files structure with line data
	 * @blockProcessor The block processor for line mapping
	 * @return Struct with line-based call tree data keyed by "fileIdx:lineNum"
	 */
	public struct function mapCallTreeToLines(
		required struct callTree,
		required struct files,
		required any blockProcessor
	) {
		var lineCallTree = {};

		// Extract blocks from the call tree structure
		var blocks = arguments.callTree.blocks;

		// Process each block in the call tree
		for (var blockKey in blocks) {
			var block = blocks[blockKey];
			var fileIdx = block.fileIdx;

			// Get the file's information
			if (!structKeyExists(arguments.files, fileIdx)) {
				throw "Block references non-existent file index: " & fileIdx & " in block: " & blockKey;
			}

			var fileInfo = arguments.files[fileIdx];
			var filePath = fileInfo.path;

			// Build line mapping if not already cached
			if (!structKeyExists(fileInfo, "lineMapping")) {
				if (structKeyExists(fileInfo, "lines") && isArray(fileInfo.lines)) {
					var fileContent = arrayToList(fileInfo.lines, chr(10));
				} else {
					// Try to read the file
					if (fileExists(filePath)) {
						var fileContent = fileRead(filePath);
					} else {
						throw "Cannot map call tree for non-existent file: " & filePath & " (fileIdx: " & fileIdx & ")";
					}
				}
				fileInfo.lineMapping = arguments.blockProcessor.buildCharacterToLineMapping(fileContent);
				fileInfo.mappingLen = arrayLen(fileInfo.lineMapping);
			}

			// Convert character position to line number
			// AST uses 0-based positions but line mapping uses 1-based positions
			var lineNum = arguments.blockProcessor.getLineFromCharacterPosition(
				block.startPos + 1,  // Add 1 to convert from 0-based to 1-based
				filePath,
				fileInfo.lineMapping,
				fileInfo.mappingLen
			);

			if (lineNum > 0) {
				var lineKey = fileIdx & ":" & lineNum;

				// If this line already has call tree data, aggregate it
				if (!structKeyExists(lineCallTree, lineKey)) {
					lineCallTree[lineKey] = {
						fileIdx: fileIdx,
						lineNum: lineNum,
						isChildTime: block.isChildTime ?: false,
						isBuiltIn: block.isBuiltIn ?: false,
						blocks: []
					};
				} else {
					// Update flags if this block is child time or built-in
					if (block.isChildTime) {
						lineCallTree[lineKey].isChildTime = true;
					}
					if (block.isBuiltIn) {
						lineCallTree[lineKey].isBuiltIn = true;
					}
				}

				// Track block information for this line
				arrayAppend(lineCallTree[lineKey].blocks, {
					startPos: block.startPos,
					endPos: block.endPos,
					executionTime: block.executionTime,
					isChildTime: block.isChildTime ?: false,
					isBuiltIn: block.isBuiltIn ?: false
				});
			}
		}

		return lineCallTree;
	}

	/**
	 * Creates a simple lookup structure for line-based call tree data by file
	 * @lineCallTree The line-based call tree from mapCallTreeToLines
	 * @return Struct keyed by fileIdx with nested struct keyed by lineNum
	 */
	public struct function createLineLookup(required struct lineCallTree) {
		var lookup = {};

		for (var lineKey in arguments.lineCallTree) {
			var lineData = arguments.lineCallTree[lineKey];
			var fileIdx = lineData.fileIdx;
			var lineNum = lineData.lineNum;

			if (!structKeyExists(lookup, fileIdx)) {
				lookup[fileIdx] = {};
			}

			lookup[fileIdx][lineNum] = {
				isChildTime: lineData.isChildTime,
				isBuiltIn: lineData.isBuiltIn ?: false,
				blockCount: arrayLen(lineData.blocks)
			};
		}

		return lookup;
	}

	/**
	 * Adds line-based call tree data to coverage structure
	 * This enriches the coverage data with own/child time information per line
	 * @coverage The existing coverage structure
	 * @lineCallTree The line-based call tree data
	 * @return Modified coverage structure
	 */
	public struct function enrichCoverageWithCallTree(
		required struct coverage,
		required struct lineCallTree
	) {
		// Create lookup for efficient access
		var lookup = createLineLookup(arguments.lineCallTree);

		// First, ensure ALL coverage arrays have 3 elements
		// [count, executionTime, isChildTime]
		for (var fileIdx in arguments.coverage) {
			var fileCoverage = arguments.coverage[fileIdx];
			if (!isStruct(fileCoverage)) {
				throw "Coverage data for file index " & fileIdx & " must be a struct, got: " & getMetadata(fileCoverage).getName();
			}

			for (var lineNum in fileCoverage) {
				var lineData = fileCoverage[lineNum];
				if (isArray(lineData) && arrayLen(lineData) == 2) {
					// Add default isChildTime flag of false
					arrayAppend(lineData, false);
				}
			}
		}

		// Now mark lines that represent child time (function calls)
		for (var fileIdx in lookup) {
			if (!structKeyExists(arguments.coverage, fileIdx)) {
				arguments.coverage[fileIdx] = {};
			}

			var fileCoverage = arguments.coverage[fileIdx];
			var fileCallTree = lookup[fileIdx];

			for (var lineNum in fileCallTree) {
				var callTreeData = fileCallTree[lineNum];

				// If line already has coverage data, mark if it's child time
				if (structKeyExists(fileCoverage, lineNum) && isArray(fileCoverage[lineNum])) {
					// Ensure array has at least 3 elements
					while (arrayLen(fileCoverage[lineNum]) < 3) {
						arrayAppend(fileCoverage[lineNum], false);
					}
					// [hitCount, executionTime, isChildTime]
					// Mark as child time if this line represents a function call
					fileCoverage[lineNum][3] = callTreeData.isChildTime ?: false;
				} else if (!structKeyExists(fileCoverage, lineNum)) {
					// Create new coverage entry with call tree flag
					fileCoverage[lineNum] = [0, 0, callTreeData.isChildTime ?: false];
				}
			}
		}

		return arguments.coverage;
	}
}