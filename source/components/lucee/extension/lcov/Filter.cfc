component {

	/**
	 * Baseline approach - current implementation
	 */
	public struct function approach1_baseline(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			var fileIdx = p[1];
			var startPos = p[2];
			var endPos = p[3];
			var execTime = p[4];

			if (!structKeyExists(arguments.validFileIds, fileIdx)) {
				continue;
			}

			// Extract key directly from line - avoids string concatenation
			var key = mid(line, len(fileIdx) + 1, len(line) - len(fileIdx) - len(execTime) - 1);

			if (structKeyExists(aggregated, key)) {
				var entry = aggregated[key];
				entry.count++;
				entry.totalTime += int(execTime);
				duplicateCount++;
			} else {
				aggregated[key] = {
					"fileIdx": fileIdx,
					"startPos": int(startPos),
					"endPos": int(endPos),
					"count": 1,
					"totalTime": int(execTime)
				};
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "1_baseline"
		};
	}

	/**
	 * Approach 2 - Use find() for parsing instead of listToArray
	 */
	public struct function approach2_findParsing(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];

			var tab1 = find(tabChar, line);
			if (tab1 == 0) continue;
			var fileIdx = left(line, tab1 - 1);

			if (!structKeyExists(arguments.validFileIds, fileIdx)) {
				continue;
			}

			var tab2 = find(tabChar, line, tab1 + 1);
			if (tab2 == 0) continue;
			var startPos = mid(line, tab1 + 1, tab2 - tab1 - 1);

			var tab3 = find(tabChar, line, tab2 + 1);
			if (tab3 == 0) continue;
			var endPos = mid(line, tab2 + 1, tab3 - tab2 - 1);

			var execTime = mid(line, tab3 + 1, len(line) - tab3);

			// Use original line segment as key
			var key = mid(line, tab1, tab3 - tab1);

			if (structKeyExists(aggregated, key)) {
				var entry = aggregated[key];
				entry.count++;
				entry.totalTime += int(execTime);
				duplicateCount++;
			} else {
				aggregated[key] = {
					"fileIdx": fileIdx,
					"startPos": int(startPos),
					"endPos": int(endPos),
					"count": 1,
					"totalTime": int(execTime)
				};
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "2_findParsing"
		};
	}

	/**
	 * Approach 3 - Minimal string operations
	 */
	public struct function approach3_minimalString(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];

			// Find first tab to get fileIdx
			var tab1 = find(tabChar, line);
			if (tab1 == 0) continue;

			// Check fileIdx validity using substring
			if (!structKeyExists(arguments.validFileIds, left(line, tab1 - 1))) {
				continue;
			}

			// Find last tab to get execTime position
			var lastTab = 0;
			var tabPos = tab1;
			while (tabPos > 0) {
				lastTab = tabPos;
				tabPos = find(tabChar, line, tabPos + 1);
			}

			// Use middle portion as key (everything except fileIdx and execTime)
			var key = mid(line, tab1, lastTab - tab1);
			var execTime = mid(line, lastTab + 1, len(line) - lastTab);

			if (structKeyExists(aggregated, key)) {
				aggregated[key].count++;
				aggregated[key].totalTime += int(execTime);
				duplicateCount++;
			} else {
				// Parse remaining fields only when creating new entry
				var p = listToArray(line, tabChar, false, false);
				aggregated[key] = {
					"fileIdx": p[1],
					"startPos": int(p[2]),
					"endPos": int(p[3]),
					"count": 1,
					"totalTime": int(execTime)
				};
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "3_minimalString"
		};
	}

	/**
	 * Approach 4 - Struct get with default
	 */
	public struct function approach4_structGetDefault(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			var fileIdx = p[1];

			if (!structKeyExists(arguments.validFileIds, fileIdx)) {
				continue;
			}

			var startPos = p[2];
			var endPos = p[3];
			var execTime = p[4];
			var execTimeInt = int(execTime);

			// Extract key directly from line
			var key = mid(line, len(fileIdx) + 1, len(line) - len(fileIdx) - len(execTime) - 1);

			// Try to get existing entry, create if not exists
			if (!structKeyExists(aggregated, key)) {
				aggregated[key] = {
					"fileIdx": fileIdx,
					"startPos": int(startPos),
					"endPos": int(endPos),
					"count": 0,
					"totalTime": 0
				};
			}

			var entry = aggregated[key];
			entry.count++;
			entry.totalTime += execTimeInt;

			if (entry.count > 1) {
				duplicateCount++;
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "4_structGetDefault"
		};
	}

	/**
	 * Approach 5 - Batch processing
	 */
	public struct function approach5_batchProcess(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();
		var batchSize = 1000;
		var batch = [];

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			arrayAppend(batch, arguments.fileCoverage[i]);

			if (arrayLen(batch) == batchSize || i == arrayLen(arguments.fileCoverage)) {
				// Process batch
				for (var line in batch) {
					var p = listToArray(line, tabChar, false, false);
					if (arrayLen(p) < 4) continue;

					var fileIdx = p[1];
					if (!structKeyExists(arguments.validFileIds, fileIdx)) continue;

					var startPos = p[2];
					var endPos = p[3];
					var execTime = p[4];

					var key = mid(line, len(fileIdx) + 1, len(line) - len(fileIdx) - len(execTime) - 1);

					if (structKeyExists(aggregated, key)) {
						var entry = aggregated[key];
						entry.count++;
						entry.totalTime += int(execTime);
						duplicateCount++;
					} else {
						aggregated[key] = {
							"fileIdx": fileIdx,
							"startPos": int(startPos),
							"endPos": int(endPos),
							"count": 1,
							"totalTime": int(execTime)
						};
					}
				}
				batch = [];
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "5_batchProcess"
		};
	}

	/**
	 * Approach 6 - ArrayEach
	 */
	public struct function approach6_arrayEach(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		arrayEach(arguments.fileCoverage, function(line) {
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) return;

			var fileIdx = p[1];

			if (!structKeyExists(validFileIds, fileIdx)) {
				return;
			}

			var startPos = p[2];
			var endPos = p[3];
			var execTime = p[4];

			// Extract key directly from line
			var key = mid(line, len(fileIdx) + 1, len(line) - len(fileIdx) - len(execTime) - 1);

			if (structKeyExists(aggregated, key)) {
				var entry = aggregated[key];
				entry.count++;
				entry.totalTime += int(execTime);
				duplicateCount++;
			} else {
				aggregated[key] = {
					"fileIdx": fileIdx,
					"startPos": int(startPos),
					"endPos": int(endPos),
					"count": 1,
					"totalTime": int(execTime)
				};
			}
		});

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "6_arrayEach"
		};
	}

	/**
	 * Approach 7 - Baseline without intermediate variables
	 */
	public struct function approach7_baselineNoVars(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(arguments.validFileIds, p[1])) {
				continue;
			}

			// Extract key directly from line - avoids string concatenation
			var key = mid(line, len(p[1]) + 1, len(line) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(aggregated, key)) {
				var entry = aggregated[key];
				entry.count++;
				entry.totalTime += int(p[4]);
				duplicateCount++;
			} else {
				aggregated[key] = {
					"fileIdx": p[1],
					"startPos": int(p[2]),
					"endPos": int(p[3]),
					"count": 1,
					"totalTime": int(p[4])
				};
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "7_baselineNoVars"
		};
	}

	/**
	 * Approach 8 - Baseline with no variables at all
	 */
	public struct function approach8_baselineNoLineVar(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var p = listToArray(arguments.fileCoverage[i], tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(arguments.validFileIds, p[1])) {
				continue;
			}

			// Extract key directly from original array element
			var key = mid(arguments.fileCoverage[i], len(p[1]) + 1, len(arguments.fileCoverage[i]) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(aggregated, key)) {
				var entry = aggregated[key];
				entry.count++;
				entry.totalTime += int(p[4]);
				duplicateCount++;
			} else {
				aggregated[key] = {
					"fileIdx": p[1],
					"startPos": int(p[2]),
					"endPos": int(p[3]),
					"count": 1,
					"totalTime": int(p[4])
				};
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "8_baselineNoLineVar"
		};
	}

	/**
	 * Approach 9 - Use array instead of struct for aggregated values
	 */
	public struct function approach9_arrayValues(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(arguments.validFileIds, p[1])) {
				continue;
			}

			// Extract key directly from line
			var key = mid(line, len(p[1]) + 1, len(line) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(aggregated, key)) {
				// Array format: [fileIdx, startPos, endPos, count, totalTime]
				aggregated[key][4]++;  // increment count
				aggregated[key][5] += int(p[4]);  // add to totalTime
				duplicateCount++;
			} else {
				// Store as array: [fileIdx, startPos, endPos, count, totalTime]
				aggregated[key] = [
					p[1],           // fileIdx
					int(p[2]),      // startPos
					int(p[3]),      // endPos
					1,              // count
					int(p[4])       // totalTime
				];
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "9_arrayValues"
		};
	}

	/**
	 * Approach 10 - Array values with reference variable
	 */
	public struct function approach10_arrayValuesRef(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(arguments.validFileIds, p[1])) {
				continue;
			}

			// Extract key directly from line
			var key = mid(line, len(p[1]) + 1, len(line) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(aggregated, key)) {
				// Store reference to avoid double lookup
				var a = aggregated[key];
				a[4]++;  // increment count
				a[5] += int(p[4]);  // add to totalTime
				duplicateCount++;
			} else {
				// Store as array: [fileIdx, startPos, endPos, count, totalTime]
				aggregated[key] = [
					p[1],           // fileIdx
					int(p[2]),      // startPos
					int(p[3]),      // endPos
					1,              // count
					int(p[4])       // totalTime
				];
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "10_arrayValuesRef"
		};
	}

	/**
	 * Approach 11 - Array values ref with local scope vars
	 */
	public struct function approach11_arrayValuesLocalScope(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var tabChar = chr(9);
		var startTime = getTickCount();
		// Avoid arguments scope lookup
		var _fileCoverage = arguments.fileCoverage;
		var _validFileIds = arguments.validFileIds;
		var len_fileCoverage = arrayLen(_fileCoverage);

		for (var i = 1; i <= len_fileCoverage; i++) {
			var line = _fileCoverage[i];
			var p = listToArray(line, tabChar, false, false);

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(_validFileIds, p[1])) {
				continue;
			}

			// Extract key directly from line
			var key = mid(line, len(p[1]) + 1, len(line) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(aggregated, key)) {
				// Store reference to avoid double lookup
				var a = aggregated[key];
				a[4]++;  // increment count
				a[5] += int(p[4]);  // add to totalTime
				duplicateCount++;
			} else {
				// Store as array: [fileIdx, startPos, endPos, count, totalTime]
				aggregated[key] = [
					p[1],           // fileIdx
					int(p[2]),      // startPos
					int(p[3]),      // endPos
					1,              // count
					int(p[4])       // totalTime
				];
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "11_arrayValuesLocalScope"
		};
	}

	/**
	 * Approach 12 - Array values with short variable names
	 */
	public struct function approach12_shortVarNames(required array fileCoverage, required struct validFileIds) {
		var a = {};  // aggregated
		var d = 0;   // duplicateCount
		var t = chr(9); // tabChar
		var s = getTickCount(); // startTime
		// Avoid arguments scope lookup
		var f = arguments.fileCoverage;
		var v = arguments.validFileIds;
		var n = arrayLen(f);

		for (var i = 1; i <= n; i++) {
			var l = f[i];  // line
			var p = listToArray(l, t, false, false);

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(v, p[1])) {
				continue;
			}

			// Extract key directly from line
			var k = mid(l, len(p[1]) + 1, len(l) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(a, k)) {
				// Store reference to avoid double lookup
				var r = a[k];  // ref
				r[4]++;  // increment count
				r[5] += int(p[4]);  // add to totalTime
				d++;
			} else {
				// Store as array: [fileIdx, startPos, endPos, count, totalTime]
				a[k] = [
					p[1],           // fileIdx
					int(p[2]),      // startPos
					int(p[3]),      // endPos
					1,              // count
					int(p[4])       // totalTime
				];
			}
		}

		return {
			"aggregated": a,
			"duplicateCount": d,
			"time": getTickCount() - s,
			"approach": "12_shortVarNames"
		};
	}

	/**
	 * Approach 13 - Use chr(9) directly without variable
	 */
	public struct function approach13_noChrVar(required array fileCoverage, required struct validFileIds) {
		var a = {};  // aggregated
		var d = 0;   // duplicateCount
		var s = getTickCount(); // startTime
		// Avoid arguments scope lookup
		var f = arguments.fileCoverage;
		var v = arguments.validFileIds;
		var n = arrayLen(f);

		for (var i = 1; i <= n; i++) {
			var l = f[i];  // line
			var p = listToArray(l, chr(9), false, false);  // Direct chr(9) usage

			if (arrayLen(p) < 4) continue;

			if (!structKeyExists(v, p[1])) {
				continue;
			}

			// Extract key directly from line
			var k = mid(l, len(p[1]) + 1, len(l) - len(p[1]) - len(p[4]) - 1);

			if (structKeyExists(a, k)) {
				// Store reference to avoid double lookup
				var r = a[k];  // ref
				r[4]++;  // increment count
				r[5] += int(p[4]);  // add to totalTime
				d++;
			} else {
				// Store as array: [fileIdx, startPos, endPos, count, totalTime]
				a[k] = [
					p[1],           // fileIdx
					int(p[2]),      // startPos
					int(p[3]),      // endPos
					1,              // count
					int(p[4])       // totalTime
				];
			}
		}

		return {
			"aggregated": a,
			"duplicateCount": d,
			"time": getTickCount() - s,
			"approach": "13_noChrVar"
		};
	}

	/**
	 * Approach 14 - Pre-compiled regex
	 */
	public struct function approach14_regex(required array fileCoverage, required struct validFileIds) {
		var aggregated = {};
		var duplicateCount = 0;
		var startTime = getTickCount();
		var pattern = "^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$";

		for (var i = 1; i <= arrayLen(arguments.fileCoverage); i++) {
			var line = arguments.fileCoverage[i];
			var matches = reMatchNoCase(pattern, line);

			if (arrayLen(matches) == 0) continue;

			// Extract captured groups
			var parts = reFindNoCase(pattern, line, 1, true);
			if (arrayLen(parts.match) < 5) continue;

			var fileIdx = mid(line, parts.pos[2], parts.len[2]);
			if (!structKeyExists(arguments.validFileIds, fileIdx)) continue;

			var startPos = mid(line, parts.pos[3], parts.len[3]);
			var endPos = mid(line, parts.pos[4], parts.len[4]);
			var execTime = mid(line, parts.pos[5], parts.len[5]);

			// Use middle portion as key
			var key = mid(line, parts.pos[2] + parts.len[2], parts.pos[5] - parts.pos[2] - parts.len[2] - 1);

			if (structKeyExists(aggregated, key)) {
				var entry = aggregated[key];
				entry.count++;
				entry.totalTime += int(execTime);
				duplicateCount++;
			} else {
				aggregated[key] = {
					"fileIdx": fileIdx,
					"startPos": int(startPos),
					"endPos": int(endPos),
					"count": 1,
					"totalTime": int(execTime)
				};
			}
		}

		return {
			"aggregated": aggregated,
			"duplicateCount": duplicateCount,
			"time": getTickCount() - startTime,
			"approach": "6_regex"
		};
	}

	/**
	 * Run all approaches and compare
	 */
	public struct function benchmark(required array fileCoverage, required struct validFileIds, numeric limit = 500000) {
		var results = {};
		var testData = arraySlice(arguments.fileCoverage, 1, min(arguments.limit, arrayLen(arguments.fileCoverage)));

		systemOutput("Testing with " & arrayLen(testData) & " rows", true);
		systemOutput("", true);

		// Run each approach
		results.approach1 = approach1_baseline(testData, arguments.validFileIds);
		results.approach7 = approach7_baselineNoVars(testData, arguments.validFileIds);
		results.approach2 = approach2_findParsing(testData, arguments.validFileIds);
		results.approach3 = approach3_minimalString(testData, arguments.validFileIds);
		results.approach4 = approach4_structGetDefault(testData, arguments.validFileIds);
		results.approach5 = approach5_batchProcess(testData, arguments.validFileIds);
		results.approach6 = approach6_arrayEach(testData, arguments.validFileIds);
		results.approach8 = approach8_baselineNoLineVar(testData, arguments.validFileIds);
		results.approach9 = approach9_arrayValues(testData, arguments.validFileIds);
		results.approach10 = approach10_arrayValuesRef(testData, arguments.validFileIds);
		results.approach11 = approach11_arrayValuesLocalScope(testData, arguments.validFileIds);
		results.approach12 = approach12_shortVarNames(testData, arguments.validFileIds);
		results.approach13 = approach13_noChrVar(testData, arguments.validFileIds);
		// Skip regex - too slow
		// results.approach14 = approach14_regex(testData, arguments.validFileIds);

		// Display results
		var fastest = "";
		var fastestTime = 999999;

		systemOutput("Performance Results:", true);
		systemOutput("====================", true);
		for (var key in results) {
			var result = results[key];
			systemOutput(result.approach & ": " & result.time & "ms (found " & structCount(result.aggregated) & " unique entries)", true);
			if (result.time < fastestTime) {
				fastestTime = result.time;
				fastest = result.approach;
			}
		}
		systemOutput("", true);
		systemOutput("Winner: " & fastest & " (" & fastestTime & "ms)", true);

		return results;
	}
}