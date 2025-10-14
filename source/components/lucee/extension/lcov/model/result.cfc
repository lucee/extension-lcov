component accessors=true {
	// Top-level properties
	// accessors=true automatically generates public getters and setters for all properties below (e.g., setMetadata(), getMetadata(), setStats(), etc.)
	// Always use these methods for property access in tests and core logic; do not use direct assignment or member access.
	property name="metadata" type="struct" default="#{}#";
	property name="stats" type="struct" default="#{}#"; // overall stats for all files
	property name="coverage" type="struct" default="#{}#"; // per file coverage data (line-based, derived from blocks)
	property name="blocks" type="struct" default="#{}#"; // per file block-level execution data: {fileIdx: {"startPos-endPos": {hitCount, execTime, isChild}}}
	property name="files" type="struct" default="#{}#"; // contains per file stats, source and info 
	property name="exeLog" type="string" default=""; // file path of the .exl used to generate this result
	property name="exlChecksum" type="string" default=""; // checksum of the .exl file to detect reprocessing
	property name="optionsHash" type="string" default=""; // hash of parsing options to detect option changes
	property name="coverageStartByte" type="numeric" default="0"; // byte offset where coverage section starts in .exl file
	property name="outputFilename" type="string" default=""; // name of the output, without an file extension
	property name="parserPerformance" type="struct" default="#{}#";
	property name="callTree" type="struct" default="#{}#"; // call tree analysis data
	property name="callTreeMetrics" type="struct" default="#{}#"; // call tree summary metrics
	property name="isFile" type="boolean" default="false"; // true if this is a file-level result (merged), false if request-level
	property name="aggregated" type="struct" default="#{}#"; // raw aggregated coverage data: {"fileIdx\tstartPos\tendPos": [fileIdx, startPos, endPos, hitCount, execTime]}
	property name="flags" type="struct" default="#{}#"; // processing flags: {hasCallTree: false, hasBlocks: false, hasCoverage: false}


	/**
	 * Returns an array of all file paths in the result.
	 */
	public array function getAllFilePaths() {
		if (!isStruct(variables.files)) return [];
		var filePaths = [];
		for (var idx in variables.files) {
			var fileData = variables.files[idx];
			if (structKeyExists(fileData, "path")) {
				arrayAppend(filePaths, fileData.path);
			}
		}
		return filePaths;
	}

	/**
	 * Returns the coverage struct for a specific file index.
	 */
	public struct function getCoverageForFile(required numeric fileIndex) {
		if (!isStruct(variables.coverage) || !structKeyExists(variables.coverage, arguments.fileIndex)) {
			throw(message="No coverage for file index: " & arguments.fileIndex & " exeLog: " & variables.exeLog);
		}
		return variables.coverage[arguments.fileIndex];
	}

	/**
	 * Returns the array of source lines for a specific file index.
	 * If lines[] is not present (e.g., not loaded during parsing), returns empty array.
	 * Callers should check if empty and hydrate from disk if needed.
	 */
	public array function getFileLines(required numeric fileIndex) {
		if (!isStruct(variables.files) || !structKeyExists(variables.files, arguments.fileIndex)) {
			throw(message="No files struct present or missing file index: " & arguments.fileIndex & " exeLog: " & variables.exeLog);
		}
		var fileData = variables.files[arguments.fileIndex];
		if (!structKeyExists(fileData, "lines") || !isArray(fileData.lines)) {
			return [];
		}
		return fileData.lines;
	}

	/**
	 * Returns the struct of executable lines for a specific file index.
	 * Extracts executable lines from coverage (which includes all executable lines with zero-counts).
	 * Returns struct of {lineNum: true} for all lines in coverage.
	 */
	public struct function getExecutableLines(required numeric fileIndex) {
		var executableLines = {};

		// Check if coverage exists for this file
		if (!isStruct(variables.coverage) || !structKeyExists(variables.coverage, arguments.fileIndex)) {
			// No coverage means no executable lines found/tracked (empty file or parse error)
			return executableLines;
		}

		var fileCoverage = variables.coverage[arguments.fileIndex];

		// Extract line numbers from coverage (which now contains all executable lines including zero-counts)
		for (var lineNum in fileCoverage) {
			executableLines[lineNum] = true;
		}

		return executableLines;
	}

	/**
	 * Returns the overall coverage percentage for the result.
	 */
	public numeric function getTotalCoveragePercent() {
		if (!isStruct(variables.stats) || !structKeyExists(variables.stats, "totalLinesFound") || !structKeyExists(variables.stats, "totalLinesHit")) {
			throw(message="Missing totalLinesFound or totalLinesHit in stats" & " exeLog: " & variables.exeLog);
		}
		return variables.stats.totalLinesFound > 0 ? (variables.stats.totalLinesHit / variables.stats.totalLinesFound) * 100 : 0;
	}

	/**
	 * Returns a display-friendly version of the file path for HTML reports.
	 * For now, just returns the filePath as-is. Can be extended for normalization.
	 */
	public string function getFileDisplayPath(required string filePath) {
		return arguments.filePath;
	}

	/**
	 * Returns the value of a metadata property, or throws if missing and no default provided.
	 * @key The metadata property key (e.g. "script-name")
	 * @defaultValue Optional default value to return if property is missing
	 */
	public any function getMetadataProperty(required string key, any defaultValue) {
		if (!structKeyExists(variables.metadata, arguments.key)) {
			if (structKeyExists(arguments, "defaultValue")) {
				return arguments.defaultValue;
			}
			throw "Missing required metadata property: " & arguments.key 
				& ". Available keys: " & structKeyList(variables.metadata) 
				& " exeLog: " & variables.exeLog;
		}
		return variables.metadata[arguments.key];
	}

	/**
	 * Sets the value of a metadata property.
	 * @key The metadata property key (e.g. "script-name")
	 * @value The value to set
	 */
	public void function setMetadataProperty(required string key, required any value) {
		variables.metadata[arguments.key] = arguments.value;
	}

	/**
	 * Returns the value of a stats property, or throws if missing.
	 * @key The stats property key (e.g. "totalLinesHit")
	 */
	public any function getStatsProperty(required string key) {
		if (!structKeyExists(variables.stats, arguments.key)) {
			throw "Missing required stats property: " & arguments.key 
				& ". Available keys: " & structKeyList(variables.stats) 
				& " exeLog: " & variables.exeLog;
		}
		return variables.stats[arguments.key];
	}

	/**
	 * Sets the value of a stats property.
	 * @key The stats property key (e.g. "totalLinesHit")
	 * @value The value to set
	 */
	public void function setStatsProperty(required string key, required any value) {
		variables.stats[arguments.key] = arguments.value;
	}

	/**
	 * Ensures all canonical stats fields are present and initialized.
	 */
	public void function initStats() {
		if (!structKeyExists(variables, "stats") || !isStruct(variables.stats)) {
			variables.stats = {};
		}
		if (!structKeyExists(variables.stats, "totalLinesFound")) variables.stats.totalLinesFound = 0;
		if (!structKeyExists(variables.stats, "totalLinesHit")) variables.stats.totalLinesHit = 0;
		if (!structKeyExists(variables.stats, "totalLinesSource")) variables.stats.totalLinesSource = 0;
		if (!structKeyExists(variables.stats, "totalExecutions")) variables.stats.totalExecutions = 0;
		if (!structKeyExists(variables.stats, "totalExecutionTime")) variables.stats.totalExecutionTime = 0;
		if (!structKeyExists(variables.stats, "totalChildTime")) variables.stats.totalChildTime = 0;
	}

	/**
	 * Returns array of allowed stats keys
	 */
	public array function getAllowedStatsKeys() {
		return [ "totalLinesFound", "totalLinesHit", "totalLinesSource", "totalExecutions", "totalExecutionTime", "totalChildTime" ];
	}

	/**
	 * Sets or updates a source file entry in the result's source.files struct.
	 * @fileIndex The file index or path
	 * @data The file data struct
	 */

	public any function getFileItem(required numeric fileIndex, string property) {
		if (!structKeyExists(variables, "files") || !isStruct(variables.files) || !structKeyExists(variables.files, arguments.fileIndex)) {
			throw "File entry not found for index: " & arguments.fileIndex & " exeLog: " & variables.exeLog;
		}
		var fileItem = variables.files[arguments.fileIndex];
		if (structKeyExists(arguments, "property")) {
			return fileItem[arguments.property];
		}
		return fileItem;
	}

	/**
	 * Sets or updates a file entry in the result's files struct.
	 * @fileIndex The file index (follows the .exl approach)
	 * @data The file data struct
	 */
	public void function setFileItem(required numeric fileIndex, required struct data) {
		if (!structKeyExists(variables, "files") || !isStruct(variables.files)) {
			variables.files = {};
		}
		variables.files[arguments.fileIndex] = arguments.data;
	}

	/**
	 * Sets or updates coverage for a file index in the result's coverage struct.
	 * @fileIndex The file index (numeric)
	 * @data The coverage data struct
	 */
	public void function setCoverageItem(required numeric fileIndex, required struct data) {
		if (!structKeyExists(variables, "coverage") || !isStruct(variables.coverage)) {
			variables.coverage = {};
		}
		variables.coverage[arguments.fileIndex] = arguments.data;
	}

	/**
	 * Gets the coverage struct for a specific file index, throws if missing.
	 * @fileIndex The file index (numeric)
	 */
	public struct function getCoverageItem(required numeric fileIndex) {
		if (!isStruct(variables.coverage) || !structKeyExists(variables.coverage, arguments.fileIndex)) {
			throw(message="No coverage for file index: " & arguments.fileIndex & " exeLog: " & variables.exeLog);
		}
		return variables.coverage[arguments.fileIndex];
	}

	/**
	 * Removes coverage for a specific file index.
	 * @fileIndex The file index (numeric)
	 */
	public void function removeCoverageItem(required numeric fileIndex) {
		if (isStruct(variables.coverage) && structKeyExists(variables.coverage, arguments.fileIndex)) {
			structDelete(variables.coverage, arguments.fileIndex);
		}
	}

	/**
	 * Gets the blocks struct for a specific file index.
	 * Returns empty struct if no blocks found for this file.
	 * @fileIndex The file index (numeric)
	 */
	public struct function getBlocksForFile(required numeric fileIndex) {
		if (!isStruct(variables.blocks)) {
			variables.blocks = {};
		}
		if (!structKeyExists(variables.blocks, arguments.fileIndex)) {
			return {};
		}
		return variables.blocks[arguments.fileIndex];
	}

	/**
	 * Sets the blocks for a specific file index.
	 * @fileIndex The file index (numeric)
	 * @data The blocks data struct (keyed by "startPos-endPos")
	 */
	public void function setBlocksForFile(required numeric fileIndex, required struct data) {
		if (!isStruct(variables.blocks)) {
			variables.blocks = {};
		}
		variables.blocks[arguments.fileIndex] = arguments.data;
	}

	/**
	 * Adds a single block for a file.
	 * @fileIndex The file index (numeric)
	 * @startPos Block start position
	 * @endPos Block end position
	 * @blockData Struct containing hitCount, execTime, isChild
	 */
	public void function addBlock(required numeric fileIndex, required numeric startPos, required numeric endPos, required struct blockData) {
		if (!isStruct(variables.blocks)) {
			variables.blocks = {};
		}
		if (!structKeyExists(variables.blocks, arguments.fileIndex)) {
			variables.blocks[arguments.fileIndex] = {};
		}
		var blockKey = arguments.startPos & "-" & arguments.endPos;
		variables.blocks[arguments.fileIndex][blockKey] = arguments.blockData;
	}

	/**
	 * Serializes the result model to JSON.
	 * @pretty Whether to format the JSON with indentation
	 */
	public string function toJson(boolean pretty=true) {
		return serializeJSON(var=this, compact=!arguments.pretty);
	}

	/**
	 * returns the instance data as a struct
	 */
	public struct function getData() {
		var props = getMetaData(this).properties;
		var result = [=];
		for (var prop in props) {
			var propName = prop.name;
			result[propName] = this["get#PropName#"]();
		}
		return result;
	}

	/**
	 * Static: populates this model from a JSON string.
	 */
	public static any function fromJson(required string json, boolean validate=true) {
		var data = deserializeJSON(arguments.json);
		var model = new lucee.extension.lcov.model.result();
		var props = getMetaData(model).properties;
		var validKeys = [];
		for (var prop in props) {
			arrayAppend(validKeys, prop.name);
		}
		for (var key in data) {
			if (!arrayFindNoCase(validKeys, key)) {
				throw(message="Unexpected top-level key in JSON: " & key);
			}
			var setter = "set" & key;
			if (isCustomFunction(model[setter])) {
				model[setter](data[key]);
			} else {
				throw(message="No setter found for property: " & key);
			}
		}
		if (arguments.validate) model.validate();
		return model;
	}

	/*
	MARK: Validation
	*/

	/**
	 * Validates the result model for required canonical fields and structure.
	 * Delegates to ResultValidator component.
	 * @throw Whether to throw on validation failure (default true)
	 * @return Array of problem messages
	 */
	public array function validate(boolean throw=true) {
		var validator = new lucee.extension.lcov.model.ResultValidator();
		return validator.validate(this, arguments.throw);
	}

	/**
	 * Get call tree data for a specific file
	 * @fileIndex The file index
	 * @return Struct of call tree entries for this file
	 */
	public struct function getCallTreeForFile(required numeric fileIndex) {
		var fileCallTree = {};

		if (!structKeyExists(variables, "callTree") || !isStruct(variables.callTree)) {
			return fileCallTree;
		}

		// Filter call tree entries for this file
		for (var blockKey in variables.callTree) {
			var block = variables.callTree[blockKey];
			if (structKeyExists(block, "fileIdx") && block.fileIdx == arguments.fileIndex) {
				fileCallTree[blockKey] = block;
			}
		}

		return fileCallTree;
	}
}
