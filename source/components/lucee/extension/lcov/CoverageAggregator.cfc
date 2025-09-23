component {

	/**
	 * Optimized aggregation of coverage entries using performance techniques
	 * Returns struct with aggregated data, metrics, and performance stats
	 */
	public struct function aggregate(array fileCoverage, struct validFileIds, numeric totalLines) {
		var aggregationStart = getTickCount();
		var a = {};  // aggregated
		var d = 0;   // duplicateCount
		var rowStart = getTickCount();
		var f = arguments.fileCoverage;  // local copy to avoid scope lookup
		var v = arguments.validFileIds;  // local copy to avoid scope lookup
		var n = arguments.totalLines;  // pre-calculated length

		for (var i = 1; i <= n; i++) {
			var l = f[i];  // line
			var p = listToArray(l, chr(9), false, false);  // direct chr(9) usage

			// Validate data
			if (arrayLen(p) < 4) continue;

			// Skip if file not valid
			if (!structKeyExists(v, p[1])) {
				continue;
			}

			// Extract key directly from line - avoids string concatenation
			var k = mid(l, len(p[1]) + 1, len(l) - len(p[1]) - len(p[4]) - 1);

			// Use array storage for better performance
			if (structKeyExists(a, k)) {
				var r = a[k];  // reference to avoid double lookup
				r[4]++;  // increment count
				r[5] += int(p[4]);  // add execution time
				d++;
			} else {
				// Store as array: [fileIdx, startPos, endPos, count, totalTime]
				a[k] = [p[1], int(p[2]), int(p[3]), 1, int(p[4])];
			}

			if (i % 100000 == 0) {
				systemOutput("Processed " & numberFormat(i) & " of " & numberFormat(n)
					& " rows in " & numberFormat(getTickCount() - rowStart) & "ms", true);
				rowStart = getTickCount();
			}
		}

		var aggregatedEntries = structCount(a);
		var reductionPercent = n > 0 ?
				numberFormat(((n - aggregatedEntries) / n) * 100, "0.0") : "0";
		var aggregationTime = getTickCount() - aggregationStart;

		systemOutput("Post merging: " & numberFormat(aggregatedEntries)
			& " unique (" & reductionPercent & "% reduction)"
			& " in " & numberFormat(aggregationTime) & "ms", true);

		return {
			"aggregated": a,
			"duplicateCount": d,
			"aggregatedEntries": aggregatedEntries,
			"reductionPercent": reductionPercent,
			"aggregationTime": aggregationTime
		};
	}

	/**
	 * Chunked parallel aggregation - divide data into chunks and process in parallel
	 */
	public struct function aggregateChunked(array fileCoverage, struct validFileIds, numeric totalLines) {
		var aggregationStart = getTickCount();
		var a = structNew('regular');  // aggregated - hashmap
		var v = arguments.validFileIds;  // local copy to avoid scope lookup
		var n = arguments.totalLines;  // pre-calculated length

		// Calculate chunk size - use larger chunks to reduce coordination overhead
		var chunkSize = 100000;
		var numChunks = ceiling(n / chunkSize);
		var g = [];  // chunkResults

		systemOutput("Processing " & n & " entries in " & numChunks & " chunks of " & chunkSize, true);

		// Process chunks in parallel - use arrays instead of structs
		for (var chunkIdx = 1; chunkIdx <= numChunks; chunkIdx++) {
			var startIdx = ((chunkIdx - 1) * chunkSize) + 1;
			var endIdx = min(chunkIdx * chunkSize, n);

			// Store as array: [startIdx, endIdx, chunkIdx, aggregated]
			arrayAppend(g, [startIdx, endIdx, chunkIdx, {}]);
		}

		// Process chunks in parallel using arrayEach
		var s = arguments.fileCoverage;  // local copy for closure access
		ArrayEach(g, function(b) {
			var f = s;   // local copy for closure
			var c = structNew('regular');  // chunkAgg - hashmap

			// b is now an array: [startIdx, endIdx, chunkIdx, aggregated]
			for (var i = b[1]; i <= b[2]; i++) {  // startIdx to endIdx
				var l = f[i];  // line
				var p = listToArray(l, chr(9), false, false);  // direct chr(9) usage

				// Validate data
				if (arrayLen(p) < 4) continue;

				// Skip if file not valid
				if (!structKeyExists(v, p[1])) continue;

				// Extract key directly from line
				var k = mid(l, len(p[1]) + 1, len(l) - len(p[1]) - len(p[4]) - 1);

				// Use array storage for better performance
				if (structKeyExists(c, k)) {
					var r = c[k];  // reference to avoid double lookup
					r[4]++;  // increment count
					r[5] += int(p[4]);  // add execution time
				} else {
					// Store as array: [fileIdx, startPos, endPos, count, totalTime]
					c[k] = [p[1], int(p[2]), int(p[3]), 1, int(p[4])];
				}
			}

			// Store results back to chunk array
			b[4] = c;  // aggregated

			systemOutput("Chunk " & b[3] & " processed: " & structCount(c) & " unique entries", true);
		}, true);  // parallel=true

		// Merge chunk results sequentially
		for (var i = 1; i <= arrayLen(g); i++) {
			var c = g[i];  // c is an array: [startIdx, endIdx, chunkIdx, aggregated]
			for (var k in c[4]) {  // direct iteration - no structKeyArray overhead
				if (structKeyExists(a, k)) {
					var r = a[k];  // reference to avoid double lookup
					var e = c[4][k];  // chunkEntry from aggregated
					r[4] += e[4];  // add counts
					r[5] += e[5];  // add execution times
				} else {
					a[k] = c[4][k];  // copy from chunk aggregated
				}
			}
		}

		var aggregatedEntries = structCount(a);
		var totalProcessedEntries = 0;
		for (var key in a) {
			totalProcessedEntries += a[key][4]; // sum all hit counts
		}
		var duplicateCount = totalProcessedEntries - aggregatedEntries;
		var reductionPercent = n > 0 ?
				numberFormat(((n - aggregatedEntries) / n) * 100, "0.0") : "0";
		var aggregationTime = getTickCount() - aggregationStart;

		systemOutput("Chunked post merging: " & numberFormat(aggregatedEntries)
			& " unique (" & reductionPercent & "% reduction)"
			& " in " & numberFormat(aggregationTime) & "ms", true);

		return {
			"aggregated": a,
			"duplicateCount": duplicateCount,
			"aggregatedEntries": aggregatedEntries,
			"reductionPercent": reductionPercent,
			"aggregationTime": aggregationTime
		};
	}

}