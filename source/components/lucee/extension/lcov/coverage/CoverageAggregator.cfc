component {

	// Imports for aggregateStreamingWithImports method
	import java.io.File;
	import java.io.RandomAccessFile;
	import java.io.FileInputStream;
	import java.lang.Byte;
	import java.lang.reflect.Array;
	import java.lang.String;

	public function init(required Logger logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Byte-aligned chunked parallel aggregation - splits file by bytes, no shared array
	 * Each chunk reads directly from file using FileInputStream.skip() + BufferedReader
	 */
	public struct function aggregate(string exlFile, any validFileIds, numeric chunkSizeMb=5) localmode="modern" {
		var event = variables.logger.beginEvent("CoverageAggregation");

		var aggregationStart = getTickCount();
		var a = structNew('regular');  // aggregated

		// Get file size
		var file = new File(arguments.exlFile);
		var fileSize = file.length();
		event["fileSize"] = fileSize;

		// Adaptive chunk sizing: smaller chunks for smaller files to enable parallelism
		var fileSizeMb = fileSize / 1024 / 1024;
		var effectiveChunkSize = arguments.chunkSizeMb;
		if (fileSizeMb < 10) {
			effectiveChunkSize = 1; // 1MB chunks for files under 10MB for better parallelism
		}

		// Calculate chunk count based on effective chunk size
		var chunkByteSize = effectiveChunkSize * 1024 * 1024;
		var actualNumChunks = max(1, int(fileSize / chunkByteSize));

		// Ensure we have at least 2x processor cores for optimal work-stealing parallelism
		var processorCount = createObject("java", "java.lang.Runtime").getRuntime().availableProcessors();
		var minChunks = processorCount * 2;
		if (actualNumChunks < minChunks && fileSize > 1024 * 1024) {
			// File is large enough (>1MB) to benefit from more chunks
			actualNumChunks = minChunks;
		}

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

			// Store chunk: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks, logger]
			arrayAppend(chunks, [arguments.exlFile, actualStart, actualEnd, chunkIdx, duplicate(arguments.validFileIds), actualNumChunks, variables.logger]);
		}

		var boundaryTime = getTickCount() - boundaryStart;
		event["boundaryTime"] = boundaryTime;

		// Process chunks in parallel
		var chunkResults = arrayMap(chunks, processChunk, true);  // parallel=true

		// Merge chunk results
		var mergeStart = getTickCount();
		var totalLinesProcessed = 0;

		cfloop( array=chunkResults, item="local.chunkResult" ) {
			totalLinesProcessed += chunkResult.linesProcessed;
			var chunkAgg = chunkResult.aggregated;
			for ( var k in chunkAgg ) {
				if ( structKeyExists( a, k ) ) {
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

		variables.logger.debug("Aggregated " & numberFormat(totalLinesProcessed) & " lines (" & numberFormat(fileSize / 1024 / 1024, "0.0") & " MB) "
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

	/**
	 * Process a single chunk of the exl file
	 * chunk is: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks, logger]
	 */
	private function processChunk( chunk ) localmode="modern" {
		var chunkStart = getTickCount();

		// chunk is: [exlFile, startByte, endByte, chunkIdx, validFileIds, numChunks, logger]
		var exlFile = chunk[1];
		var startByte = chunk[2];
		var endByte = chunk[3];
		var chunkIdx = chunk[4];
		var validFileIds = chunk[5];
		var numChunks = chunk[6];
		var logger = chunk[7];

		// Open FileInputStream and skip to start position
		var fis = new FileInputStream(exlFile);

		try {
			fis.skip(startByte);

			// Read entire chunk at once (5x faster than line-by-line)
			var buffer = Array::newInstance(Byte::TYPE, endByte - startByte);
			fis.read(buffer);

			// Convert to string, split into lines, and process
			var result = processLines(
				listToArray(new String(buffer, "UTF-8"), chr(10), false, false),
				validFileIds
			);

			logger.debug("Chunk " & chunkIdx & " of " & numChunks
				& " processed " & numberFormat(result.linesProcessed) & " lines in "
				& numberFormat(getTickCount() - chunkStart) & "ms");

		} finally {
			fis.close();
		}

		return result;
	}

	/**
	 * Process lines from chunk and aggregate coverage data
	 * Returns struct with aggregated data and lines processed count
	 */
	private function processLines( lines, validFileIds ) localmode="modern" {
		var lines = arguments.lines; // Cache for performance
		var skipped = 0; // count skipped lines instead of incrementing processed count
		var a = structNew('regular'); // Create local aggregated struct - avoids concurrent conversion

		// Copy validFileIds to local regular struct to avoid concurrent struct overhead
		var v = structNew('regular');
		for ( var key in arguments.validFileIds ) {
			v[key] = true;
		}

		// Process each line
		cfloop( array=lines, item="local.l" ) {
			var p = listToArray( l, "	", false, false );

			// Skip if file not valid (trust data model - fail fast if format is wrong)
			if ( !structKeyExists( v, p[1] ) ) {
				skipped++;
				continue;
			}

			// Extract key - include fileIdx to aggregate per-file: fileIdx + startPos + endPos
			// Using literal tab in string template is 17% faster than chr(9) concatenation
			var k = "#p[1]#	#p[2]#	#p[3]#";

			// Aggregate (we use ints, half the memory size of doubles)
			if ( structKeyExists( a, k ) ) {
				var r = a[k];
				r[4]++;
				r[5] += int( p[4] );
			} else {
				a[k] = [p[1], int( p[2] ), int( p[3] ), 1, int( p[4] )];
			}
		}

		return {aggregated: a, linesProcessed: arrayLen( lines ) - skipped};
	}

}