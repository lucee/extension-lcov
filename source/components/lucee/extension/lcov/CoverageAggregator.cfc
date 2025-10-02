component {

	// Imports for aggregateStreamingWithImports method
	import java.io.File;
	import java.io.RandomAccessFile;
	import java.io.FileInputStream;
	import java.lang.Byte;
	import java.lang.reflect.Array;
	import java.lang.String;

	public function init(string logLevel="none") {
		variables.logger = new lucee.extension.lcov.Logger(level=arguments.logLevel);
		return this;
	}

	/**
	 * Byte-aligned chunked parallel aggregation - splits file by bytes, no shared array
	 * Each chunk reads directly from file using FileInputStream.skip() + BufferedReader
	 */
	public struct function aggregate(string exlFile, struct validFileIds, numeric chunkSizeMb=1) {
		var event = variables.logger.beginEvent("CoverageAggregation");

		var aggregationStart = getTickCount();
		var a = structNew('regular');  // aggregated

		// Get file size
		var file = new File(arguments.exlFile);
		var fileSize = file.length();
		event["fileSize"] = fileSize;

		// Calculate chunk count based on requested chunk size
		var chunkByteSize = arguments.chunkSizeMb * 1024 * 1024;
		var actualNumChunks = max(1, int(fileSize / chunkByteSize));

		// Recalculate actual chunk byte size based on chunk count
		chunkByteSize = int(fileSize / actualNumChunks);
		event["numChunks"] = actualNumChunks;
		event["chunkByteSize"] = chunkByteSize;

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
				var raf = new RandomAccessFile(arguments.exlFile, "r");
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
				var raf = new RandomAccessFile(arguments.exlFile, "r");
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

			// Store chunk: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks]
			arrayAppend(chunks, [arguments.exlFile, actualStart, actualEnd, chunkIdx, duplicate(arguments.validFileIds), actualNumChunks]);
		}

		var boundaryTime = getTickCount() - boundaryStart;
		event["boundaryTime"] = boundaryTime;

		// Process chunks in parallel
		var chunkResults = arrayMap(chunks, function(chunk) {
			var chunkStart = getTickCount();
			var c = structNew('regular');

			// chunk is: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks]
			var exlFile = chunk[1];
			var startByte = chunk[2];
			var endByte = chunk[3];
			var chunkIdx = chunk[4];
			var validFileIds = chunk[5];
			var numChunks = chunk[6];

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

					// Extract key - include fileIdx to aggregate per-file: fileIdx + startPos + endPos
					var key = parts[1] & chr(9) & parts[2] & chr(9) & parts[3];

					// Aggregate
					if (structKeyExists(c, key)) {
						var r = c[key];
						r[4]++;
						r[5] += int(parts[4]);
					} else {
						c[key] = [parts[1], int(parts[2]), int(parts[3]), 1, int(parts[4])];
					}
				}

				variables.logger.trace("Chunk " & chunkIdx & " of " & numChunks
					& " processed " & numberFormat(linesProcessed) & " lines in "
					& numberFormat(getTickCount() - chunkStart) & "ms");

			} finally {
				fis.close();
			}

			return {aggregated: c, linesProcessed: linesProcessed};
		}, true);  // parallel=true

		// Merge chunk results
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
		event["mergeTime"] = mergeTime;

		// Calculate stats
		var aggregatedEntries = structCount(a);
		var totalHits = 0;
		for (var key in a) {
			totalHits += a[key][4];
		}
		var duplicateCount = totalHits - aggregatedEntries;
		var aggregationTime = getTickCount() - aggregationStart;
		var linesPerSecond = aggregationTime > 0 ? int((totalLinesProcessed / aggregationTime) * 1000) : 0;

		variables.logger.info("Aggregated " & numberFormat(totalLinesProcessed) & " lines (" & numberFormat(fileSize / 1024 / 1024, "0.0") & " MB) "
			& "to " & numberFormat(aggregatedEntries) & " unique in " & numberFormat(aggregationTime) & "ms"
			& " (" & numberFormat(linesPerSecond) & " lines/sec)"
			& " [totalHits=" & totalHits & ", duplicates=" & duplicateCount & "]");

		event["aggregatedEntries"] = aggregatedEntries;
		event["duplicateCount"] = duplicateCount;
		event["totalLinesProcessed"] = totalLinesProcessed;
		variables.logger.commitEvent(event);

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