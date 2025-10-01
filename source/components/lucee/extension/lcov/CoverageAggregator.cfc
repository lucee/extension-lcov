component {

	// Imports for aggregateStreamingWithImports method
	import java.io.File;
	import java.io.RandomAccessFile;
	import java.io.FileInputStream;
	import java.lang.Byte;
	import java.lang.reflect.Array;
	import java.lang.String;

	variables.debug = true;

	/**
	 * Optimized aggregation of coverage entries using performance techniques
	 * Returns struct with aggregated data, metrics, and performance stats
	 */
	public struct function aggregate(array fileCoverage, struct validFileIds, numeric totalLines) {
		var jfr = new JfrEvent();
		var jfrEvent = jfr.begin("CoverageAggregation");
		jfrEvent.method = "aggregate";
		jfrEvent.totalLines = arguments.totalLines;

		var aggregationStart = getTickCount();
		var a = structNew('regular');  // aggregated
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

			if (variables.debug && i % 100000 == 0) {
				systemOutput("Processed " & numberFormat(i) & " of " & numberFormat(n)
					& " rows in " & numberFormat(getTickCount() - rowStart) & "ms", true);
				rowStart = getTickCount();
			}
		}

		var aggregatedEntries = structCount(a);
		var reductionPercent = n > 0 ?
				numberFormat(((n - aggregatedEntries) / n) * 100, "0.000") : "0";
		var aggregationTime = getTickCount() - aggregationStart;
		if (variables.debug) {
			systemOutput("Post merging: " & numberFormat(aggregatedEntries)
				& " unique (" & reductionPercent & "% reduction)"
				& " in " & numberFormat(aggregationTime) & "ms", true);
		}

		jfrEvent.aggregatedEntries = aggregatedEntries;
		jfrEvent.duplicateCount = d;
		jfrEvent.reductionPercent = reductionPercent;
		jfr.commit(jfrEvent);

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
		var jfr = new JfrEvent();
		var jfrEvent = jfr.begin("CoverageAggregationChunked");
		jfrEvent.method = "aggregateChunked";
		jfrEvent.totalLines = arguments.totalLines;

		var aggregationStart = getTickCount();
		var a = structNew('regular');  // aggregated - hashmap
		var v = arguments.validFileIds;  // local copy to avoid scope lookup
		var n = arguments.totalLines;  // pre-calculated length

		// Calculate chunk size - use larger chunks to reduce coordination overhead
		var chunkSize = 200000;  // Increased chunk size to reduce memory overhead
		var numChunks = ceiling(n / chunkSize);
		var g = [];  // chunkResults
		jfrEvent.numChunks = numChunks;
		jfrEvent.chunkSize = chunkSize;

		// chunk numberformat mask
		var chunkMask = repeatString("0", len(ToString(numChunks)));
		if (variables.debug) {
			systemOutput("Aggregating " & numberFormat(n) & " entries in " & numberFormat(numChunks) 
				& " chunks of " & numberFormat(chunkSize), true);
		}

		// Process chunks in parallel - duplicate small variables to avoid closure capture contention
		var sharedFileCov = arguments.fileCoverage;  // shared reference (unavoidable, too large to duplicate)

		for (var chunkIdx = 1; chunkIdx <= numChunks; chunkIdx++) {
			var startIdx = ((chunkIdx - 1) * chunkSize) + 1;
			var endIdx = min(chunkIdx * chunkSize, n);

			// Duplicate validFileIds struct for each chunk to avoid contention
			var validIdsCopy = duplicate(v);

			// Store as array: [startIdx, endIdx, chunkIdx, fileCoverage, validFileIds, debug, numChunks, chunkMask]
			arrayAppend(g, [startIdx, endIdx, chunkIdx, sharedFileCov, validIdsCopy, variables.debug, numChunks, chunkMask]);
		}

		var chunkResults = arrayMap(g, function(b) {
			var chunkStart = getTickCount();
			var c = structNew('regular');  // chunkAgg - hashmap

			// b is: [startIdx, endIdx, chunkIdx, fileCoverage, validFileIds, debug, numChunks, chunkMask]
			for (var i = b[1]; i <= b[2]; i++) {  // startIdx to endIdx
				var l = b[4][i];  // line from fileCoverage
				var p = listToArray(l, chr(9), false, false);  // direct chr(9) usage

				// Validate data
				if (arrayLen(p) < 4) continue;

				// Skip if file not valid
				if (!structKeyExists(b[5], p[1])) continue;  // validFileIds

				// Extract key - optimized: join parts 2 and 3 with tab (19% faster than mid())
				var k = chr(9) & p[2] & chr(9) & p[3];

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

			if (b[6]) {  // debug
				systemOutput("Chunk " & numberFormat(b[3], b[8]) & " of " & numberFormat(b[7], b[8]) & " processed "
					& numberFormat(b[2] - b[1] + 1) & " rows in "
					& numberFormat(getTickCount() - chunkStart) & "ms", true);
			}

			// Return aggregated results for this chunk
			return c;
		}, true);  // parallel=true

		// Merge chunk results sequentially
		var mergeEvent = jfr.begin("CoverageAggregationMerge");
		mergeEvent.numChunks = numChunks;

		for (var chunkAgg in chunkResults) {
			for (var k in chunkAgg) {  // direct iteration - no structKeyArray overhead
				if (structKeyExists(a, k)) {
					var r = a[k];  // reference to avoid double lookup
					var e = chunkAgg[k];  // chunkEntry
					r[4] += e[4];  // add counts
					r[5] += e[5];  // add execution times
				} else {
					a[k] = chunkAgg[k];  // copy from chunk
				}
			}
		}

		jfr.commit(mergeEvent);

		var aggregatedEntries = structCount(a);
		var totalProcessedEntries = 0;
		for (var key in a) {
			totalProcessedEntries += a[key][4]; // sum all hit counts
		}
		var duplicateCount = totalProcessedEntries - aggregatedEntries;
		var reductionPercent = n > 0 ?
				numberFormat(((n - aggregatedEntries) / n) * 100, "0.000") : "0";
		var aggregationTime = getTickCount() - aggregationStart;
		if (variables.debug) {
			systemOutput("Aggregated lines after merging: " & numberFormat(aggregatedEntries)
				& " unique (" & reductionPercent & "% reduction)"
				& " in " & numberFormat(aggregationTime) & "ms", true);
		}

		jfrEvent.aggregatedEntries = aggregatedEntries;
		jfrEvent.duplicateCount = duplicateCount;
		jfrEvent.reductionPercent = reductionPercent;
		jfr.commit(jfrEvent);

		return {
			"aggregated": a,
			"duplicateCount": duplicateCount,
			"aggregatedEntries": aggregatedEntries,
			"reductionPercent": reductionPercent,
			"aggregationTime": aggregationTime
		};
	}

	/**
	 * Byte-aligned chunked parallel aggregation - splits file by bytes, no shared array
	 * Each chunk reads directly from file using FileInputStream.skip() + BufferedReader
	 */
	public struct function aggregateStreaming(string exlFile, struct validFileIds, numeric numChunks=0) {
		var jfr = new JfrEvent();
		var jfrEvent = jfr.begin("CoverageAggregationStreaming");
		jfrEvent.method = "aggregateStreaming";

		var aggregationStart = getTickCount();
		var a = structNew('regular');  // aggregated

		// Get file size
		var file = createObject("java", "java.io.File").init(arguments.exlFile);
		var fileSize = file.length();
		jfrEvent.fileSize = fileSize;

		if (variables.debug) {
			systemOutput("File size: " & numberFormat(fileSize) & " bytes", true);
		}

		// Calculate optimal chunk count based on 1MB target chunk size
		var targetChunkSize = 1 * 1024 * 1024; // 1MB
		var calculatedChunks = max(1, int(fileSize / targetChunkSize));
		var actualNumChunks = (arguments.numChunks > 0) ? arguments.numChunks : calculatedChunks;

		// Calculate chunk boundaries by bytes
		var chunkByteSize = int(fileSize / actualNumChunks);
		jfrEvent.numChunks = actualNumChunks;
		jfrEvent.chunkByteSize = chunkByteSize;

		if (variables.debug) {
			systemOutput("Splitting " & numberFormat(fileSize) & " bytes into " & numberFormat(actualNumChunks)
				& " chunks of ~" & numberFormat(chunkByteSize) & " bytes", true);
		}

		// Find actual chunk boundaries aligned to line breaks
		var boundaryStart = getTickCount();
		var chunks = [];

		for (var chunkIdx = 1; chunkIdx <= actualNumChunks; chunkIdx++) {
			var approxStart = (chunkIdx - 1) * chunkByteSize;
			var approxEnd = chunkIdx * chunkByteSize;

			// First chunk starts at 0
			var actualStart = (chunkIdx == 1) ? 0 : approxStart;

			// Last chunk ends at file size
			var actualEnd = (chunkIdx == actualNumChunks) ? fileSize : approxEnd;

			// For chunks that aren't first, adjust start to next newline
			if (chunkIdx > 1) {
				var raf = createObject("java", "java.io.RandomAccessFile").init(arguments.exlFile, "r");
				try {
					raf.seek(approxStart);
					// Read until we find newline
					var b = raf.read();
					while (b != -1 && b != 10) {  // 10 = \n
						approxStart++;
						b = raf.read();
					}
					if (b == 10) approxStart++;  // move past the newline
					actualStart = approxStart;
				} finally {
					raf.close();
				}
			}

			// For chunks that aren't last, adjust end to next newline
			if (chunkIdx < actualNumChunks) {
				var raf = createObject("java", "java.io.RandomAccessFile").init(arguments.exlFile, "r");
				try {
					raf.seek(approxEnd);
					// Read until we find newline
					var b = raf.read();
					while (b != -1 && b != 10) {  // 10 = \n
						approxEnd++;
						b = raf.read();
					}
					if (b == 10) approxEnd++;  // move past the newline
					actualEnd = approxEnd;
				} finally {
					raf.close();
				}
			}

			// Store chunk: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks, debug]
			arrayAppend(chunks, [arguments.exlFile, actualStart, actualEnd, chunkIdx, duplicate(arguments.validFileIds), actualNumChunks, variables.debug]);
		}

		var boundaryTime = getTickCount() - boundaryStart;
		jfrEvent.boundaryTime = boundaryTime;

		if (variables.debug) {
			systemOutput("Chunk boundaries calculated in " & numberFormat(boundaryTime) & "ms", true);
		}

		// Process chunks in parallel
		var chunkResults = arrayMap(chunks, function(chunk) {
			var chunkStart = getTickCount();
			var c = structNew('regular');

			// chunk is: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks, debug]
			var exlFile = chunk[1];
			var startByte = chunk[2];
			var endByte = chunk[3];
			var chunkIdx = chunk[4];
			var validFileIds = chunk[5];
			var numChunks = chunk[6];
			var debug = chunk[7];

			// Open FileInputStream and skip to start position
			var fis = new FileInputStream(exlFile);

			try {
				fis.skip(startByte);

				// Read entire chunk at once (5x faster than line-by-line)
				var chunkBytes = endByte - startByte;
				var ByteClass = Byte::TYPE;
				var buffer = Array::newInstance(ByteClass, chunkBytes);
				var bytesActuallyRead = fis.read(buffer);

				// Convert to string and split into lines
				var chunkString = new String(buffer, "UTF-8");
				var lines = listToArray(chunkString, chr(10), false, false);
				var linesProcessed = 0;

				// Process each line
				for (var line in lines) {
					linesProcessed++;

					var parts = listToArray(line, chr(9), false, false);

					// Validate data
					if (arrayLen(parts) < 4) continue;

					// Skip if file not valid
					if (!structKeyExists(validFileIds, parts[1])) continue;

					// Extract key - optimized: join parts 2 and 3 with tab
					var key = chr(9) & parts[2] & chr(9) & parts[3];

					// Aggregate
					if (structKeyExists(c, key)) {
						var r = c[key];
						r[4]++;
						r[5] += int(parts[4]);
					} else {
						c[key] = [parts[1], int(parts[2]), int(parts[3]), 1, int(parts[4])];
					}
				}

				if (debug) {
					systemOutput("Chunk " & chunkIdx & " of " & numChunks
						& " processed " & numberFormat(linesProcessed) & " lines in "
						& numberFormat(getTickCount() - chunkStart) & "ms", true);
				}

			} finally {
				fis.close();
			}

			return {aggregated: c, linesProcessed: linesProcessed};
		}, true);  // parallel=true

		var aggTime = getTickCount() - aggregationStart;

		// Merge chunk results
		var mergeEvent = jfr.begin("CoverageAggregationMerge");
		mergeEvent.numChunks = numChunks;
		var mergeStart = getTickCount();
		var totalLinesProcessed = 0;

		for (var chunkResult in chunkResults) {
			totalLinesProcessed += chunkResult.linesProcessed;
			var chunkAgg = chunkResult.aggregated;
			for (var k in chunkAgg) {
				if (structKeyExists(a, k)) {
					var r = a[k];
					var e = chunkAgg[k];
					r[4] += e[4];
					r[5] += e[5];
				} else {
					a[k] = chunkAgg[k];
				}
			}
		}

		var mergeTime = getTickCount() - mergeStart;
		jfr.commit(mergeEvent);

		// Calculate stats
		var aggregatedEntries = structCount(a);
		var totalHits = 0;
		for (var key in a) {
			totalHits += a[key][4];
		}
		var duplicateCount = totalHits - aggregatedEntries;
		var aggregationTime = getTickCount() - aggregationStart;

		if (variables.debug) {
			var linesPerSecond = aggregationTime > 0 ? int((totalLinesProcessed / aggregationTime) * 1000) : 0;
			systemOutput("Aggregated " & numberFormat(totalLinesProcessed) & " lines (" & numberFormat(fileSize / 1024 / 1024, "0.0") & " MB) "
				& "to " & numberFormat(aggregatedEntries) & " unique in " & numberFormat(aggregationTime) & "ms"
				& " (" & numberFormat(linesPerSecond) & " lines/sec)", true);
		}

		jfrEvent.aggregatedEntries = aggregatedEntries;
		jfrEvent.duplicateCount = duplicateCount;
		jfrEvent.mergeTime = mergeTime;
		jfr.commit(jfrEvent);

		return {
			"aggregated": a,
			"duplicateCount": duplicateCount,
			"aggregatedEntries": aggregatedEntries,
			"aggregationTime": aggregationTime,
			"boundaryTime": boundaryTime,
			"mergeTime": mergeTime
		};
	}

}