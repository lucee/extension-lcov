component accessors=true {
	// Top-level properties
	// accessors=true automatically generates public getters and setters for all properties below (e.g., setMetadata(), getMetadata(), setStats(), etc.)
	// Always use these methods for property access in tests and core logic; do not use direct assignment or member access.
	property name="metadata" type="struct" default="#{}#";
	property name="stats" type="struct" default="#{}#"; // overall stats for all files
	property name="coverage" type="struct" default="#{}#"; // per file coverage data
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
	 */
	public array function getFileLines(required numeric fileIndex) {
		if (!isStruct(variables.files) || !structKeyExists(variables.files, arguments.fileIndex)) {
			throw(message="No files struct present or missing file index: " & arguments.fileIndex & " exeLog: " & variables.exeLog);
		}
		return variables.files[arguments.fileIndex].lines;
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
	 * Gets a file entry from the result's files struct, throws if missing.
	 * @fileIndex The file index (numeric)
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

	/**
	 * Validates the result model for required canonical fields and structure.
	 * Collects all problems and throws a single error at the end if any are found.
	 */
	public array function validate(boolean throw=true) {
		var problems = [];

		// Example: check for required top-level properties
		if (!structKeyExists(variables, "metadata") || !isStruct(variables.metadata)) {
			arrayAppend(problems, "Missing or invalid 'metadata' struct");
		}
		if (!structKeyExists(variables, "stats") || !isStruct(variables.stats)) {
			arrayAppend(problems, "Missing or invalid 'stats' struct");
		}
		if (!structKeyExists(variables, "files") || !isStruct(variables.files)) {
			arrayAppend(problems, "Missing or invalid 'files' struct");
		}
		if (!structKeyExists(variables, "coverage") || !isStruct(variables.coverage)) {
			arrayAppend(problems, "Missing or invalid 'coverage' struct");
		}

		// Example: check for canonical stats fields
		var requiredStats = ["totalLinesFound", "totalLinesHit", "totalLinesSource", "totalExecutions", "totalExecutionTime"];
		for (var s in requiredStats) {
			if (!structKeyExists(variables.stats, s)) {
				arrayAppend(problems, "Missing stats field: " & s);
			}
		}

		// Validate isFile business rule: if isFile=true, files must have only one entry with key "0"
		if (variables.isFile) {
			var fileKeys = structKeyArray(variables.files);
			if (arrayLen(fileKeys) != 1 || fileKeys[1] != "0") {
				arrayAppend(problems, "When isFile=true, files struct must have exactly one entry with key '0', found: " & arrayToList(fileKeys));
			}
		}

		// Example: validate each file entry
		var filePaths = structKeyArray(variables.files);
		for (var filePath in filePaths) {
			// file path should be numeric
			if (!isNumeric(filePath)) {
				arrayAppend(problems, "File path is not numeric: " & filePath);
				continue;
			}
			var fileData = variables.files[filePath];
			if (!isStruct(fileData)) {
				arrayAppend(problems, "File entry for " & filePath & " is not a struct");
				continue;
			}
			var requiredFileFields = ["linesFound", "linesHit", "linesSource", "path"];
			for (var f in requiredFileFields) {
				if (!structKeyExists(fileData, f)) {
					arrayAppend(problems, "Missing file field '" & f & "' for file: " & filePath);
				} else if (f == "path" && isEmpty(fileData[f])) {
					arrayAppend(problems, "Invalid value for file field 'path' in file: " & filePath & " (should be string file path)");
				} else if (f != "path" && (!isNumeric(fileData[f]) || fileData[f] < 0)) {
					arrayAppend(problems, "Invalid value for file field '" & f & "' in file: " & filePath);
				}
			}
			// Check linesHit does not exceed linesFound
			if (structKeyExists(fileData, "linesHit") && structKeyExists(fileData, "linesFound")) {
				if (fileData.linesHit > fileData.linesFound) {
					arrayAppend(problems, "linesHit [" & fileData.linesHit
						& "] exceeds linesFound [" & fileData.linesFound & "] for file: " & filePath);
				}
			}
		}

		// Validate execution time consistency
		var executionTimeProblems = validateExecutionTime();
		for (var problem in executionTimeProblems) {
			arrayAppend(problems, problem);
		}

		if (arrayLen(problems) > 0) {
			arrayPrepend(problems, "src/exeLog: " & variables.exeLog);
		}

		if (arguments.throw && arrayLen(problems) > 0) {

			throw "Result validation failed: " & arrayToList(problems, "; ");
		}
		return problems;
	}

	/**
	 * Validates execution time consistency in coverage data.
	 * @return array of problem messages
	 */
	private array function validateExecutionTime() {
		var problems = [];

		if (structKeyExists(variables, "coverage") && isStruct(variables.coverage)) {
			var calculatedTotalTime = 0;
			var calculatedTotalExecutions = 0;

			for (var fileIdx in variables.coverage) {
				var fileCoverage = variables.coverage[fileIdx];
				if (!isStruct(fileCoverage)) continue;

				for (var lineNum in fileCoverage) {
					var lineData = fileCoverage[lineNum];
					if (isArray(lineData) && arrayLen(lineData) >= 2) {
						var hitCount = lineData[1];
						var execTime = lineData[2];

						// Check for negative values
						if (hitCount < 0) {
							arrayAppend(problems, "Negative hit count [" & hitCount & "] for file " & fileIdx & ", line " & lineNum);
						}
						if (execTime < 0) {
							arrayAppend(problems, "Negative execution time [" & execTime & "] for file " & fileIdx & ", line " & lineNum);
						}

						// Check that lines with hits have execution time (unless it's genuinely 0)
						if (hitCount > 0 && execTime == 0) {
							// This is a warning, not necessarily an error - some lines might execute in < 1 microsecond
							// But if ALL lines have 0 time, that's suspicious
						}

						// Sum up for total validation
						calculatedTotalTime += execTime;
						calculatedTotalExecutions += hitCount;
					}
				}
			}

			// Compare calculated totals with reported stats
			if (structKeyExists(variables.stats, "totalExecutionTime")) {
				var reportedTotalTime = variables.stats.totalExecutionTime;
				// Allow small differences due to rounding/aggregation
				var timeDiff = abs(calculatedTotalTime - reportedTotalTime);
				if (timeDiff > reportedTotalTime * 0.01 && timeDiff > 1000) { // More than 1% difference and more than 1ms
					arrayAppend(problems, "Total execution time mismatch: calculated [" & calculatedTotalTime
						& "] vs reported [" & reportedTotalTime & "], difference: " & timeDiff);
				}
			}

			if (structKeyExists(variables.stats, "totalExecutions")) {
				var reportedTotalExecutions = variables.stats.totalExecutions;
				if (calculatedTotalExecutions != reportedTotalExecutions) {
					arrayAppend(problems, "Total executions mismatch: calculated [" & calculatedTotalExecutions
						& "] vs reported [" & reportedTotalExecutions & "]");
				}
			}
		}

		return problems;
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
