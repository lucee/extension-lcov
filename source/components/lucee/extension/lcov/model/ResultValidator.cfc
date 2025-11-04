/**
 * ResultValidator.cfc
 *
 * Validates result objects for structural integrity and data consistency.
 * Extracted from result.cfc to separate concerns: result is the data model, validator is the validation logic.
 */
component {

	/**
	 * Validates the result model for required canonical fields and structure.
	 * Collects all problems and throws a single error at the end if any are found.
	 * @resultObject The result object to validate
	 * @throw Whether to throw on validation failure (default true)
	 * @return Array of problem messages
	 */
	public array function validate(required any resultObject, boolean throw=true) {
		var problems = [];

		problems.append(validateMetadata(arguments.resultObject), true);
		problems.append(validateStats(arguments.resultObject), true);
		problems.append(validateFiles(arguments.resultObject), true);
		problems.append(validateIsFileBusinessRule(arguments.resultObject), true);
		problems.append(validateExecutionTime(arguments.resultObject), true);

		if (arrayLen(problems) > 0) {
			arrayPrepend(problems, "src/exeLog: " & arguments.resultObject.getExeLog());
		}

		if (arguments.throw && arrayLen(problems) > 0) {
			throw "Result validation failed: " & arrayToList(problems, "; ");
		}
		return problems;
	}

	/**
	 * Validates metadata struct
	 * @resultObject The result object to validate
	 * @return Array of problem messages
	 */
	private array function validateMetadata(required any resultObject) {
		var problems = [];
		var metadata = arguments.resultObject.getMetadata();

		if (!isStruct(metadata)) {
			arrayAppend(problems, "Missing or invalid 'metadata' struct");
		}

		return problems;
	}

	/**
	 * Validates stats struct and required fields
	 * @resultObject The result object to validate
	 * @return Array of problem messages
	 */
	private array function validateStats(required any resultObject) {
		var problems = [];
		var stats = arguments.resultObject.getStats();

		if (!isStruct(stats)) {
			arrayAppend(problems, "Missing or invalid 'stats' struct");
			return problems;
		}

		var requiredStats = ["totalLinesFound", "totalLinesHit", "totalLinesSource", "totalExecutions", "totalExecutionTime"];
		for (var s in requiredStats) {
			if (!structKeyExists(stats, s)) {
				arrayAppend(problems, "Missing stats field: " & s);
			}
		}

		return problems;
	}

	/**
	 * Validates files struct and each file entry
	 * @resultObject The result object to validate
	 * @return Array of problem messages
	 */
	private array function validateFiles(required any resultObject) {
		var problems = [];
		var files = arguments.resultObject.getFiles();

		if (!isStruct(files)) {
			arrayAppend(problems, "Missing or invalid 'files' struct");
			return problems;
		}

		var coverage = arguments.resultObject.getCoverage();
		if (!isStruct(coverage)) {
			arrayAppend(problems, "Missing or invalid 'coverage' struct");
		}

		var filePaths = structKeyArray(files);
		for (var filePath in filePaths) {
			if (!isNumeric(filePath)) {
				arrayAppend(problems, "File path is not numeric: " & filePath);
				continue;
			}

			var fileData = files[filePath];
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

			if (structKeyExists(fileData, "linesHit") && structKeyExists(fileData, "linesFound")) {
				if (fileData.linesHit > fileData.linesFound) {
					arrayAppend(problems, "linesHit [" & fileData.linesHit
						& "] exceeds linesFound [" & fileData.linesFound & "] for file: " & filePath);
				}
			}
		}

		return problems;
	}

	/**
	 * Validates isFile business rule: if isFile=true, files must have only one entry with key "0"
	 * @resultObject The result object to validate
	 * @return Array of problem messages
	 */
	private array function validateIsFileBusinessRule(required any resultObject) {
		var problems = [];

		if (arguments.resultObject.getIsFile()) {
			var files = arguments.resultObject.getFiles();
			var fileKeys = structKeyArray(files);
			if (arrayLen(fileKeys) != 1 || fileKeys[1] != "0") {
				arrayAppend(problems, "When isFile=true, files struct must have exactly one entry with key '0', found: " & arrayToList(fileKeys));
			}
		}

		return problems;
	}

	/**
	 * Validates execution time consistency in coverage data.
	 * @resultObject The result object to validate
	 * @return Array of problem messages
	 */
	private array function validateExecutionTime(required any resultObject) {
		var problems = [];
		var coverage = arguments.resultObject.getCoverage();
		var stats = arguments.resultObject.getStats();

		if (!isStruct(coverage)) {
			return problems;
		}

		var calculatedTotalTime = 0;
		var calculatedTotalExecutions = 0;

		for (var fileIdx in coverage) {
			var fileCoverage = coverage[fileIdx];
			if (!isStruct(fileCoverage)) continue;

			for (var lineNum in fileCoverage) {
				var lineData = fileCoverage[lineNum];
				if (isArray(lineData) && arrayLen(lineData) >= 2) {
					var hitCount = lineData[1];
					var execTime = lineData[2];

					if (hitCount < 0) {
						arrayAppend(problems, "Negative hit count [" & hitCount & "] for file " & fileIdx & ", line " & lineNum);
					}
					if (execTime < 0) {
						arrayAppend(problems, "Negative execution time [" & execTime & "] for file " & fileIdx & ", line " & lineNum);
					}

					calculatedTotalTime += execTime;
					calculatedTotalExecutions += hitCount;
				}
			}
		}

		// NOTE: We no longer validate totalExecutionTime match because:
		// - CoverageStats now calculates totalExecutionTime as ownTime + childTime from coverage arrays
		// - This is the correct total time and may differ from .exl metadata which only tracks ownTime
		// - The coverage data is the source of truth for execution times

		if (structKeyExists(stats, "totalExecutions")) {
			var reportedTotalExecutions = stats.totalExecutions;
			if (calculatedTotalExecutions != reportedTotalExecutions) {
				arrayAppend(problems, "Total executions mismatch: calculated [" & calculatedTotalExecutions
					& "] vs reported [" & reportedTotalExecutions & "]");
			}
		}

		return problems;
	}

}
