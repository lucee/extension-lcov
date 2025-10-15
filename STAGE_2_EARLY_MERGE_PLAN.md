# Stage 2: Early Merge Optimization Plan

## Overview

After completing Stage 1 (58% faster, saved 65 seconds), we've identified the remaining bottleneck:
**Loading all 5,308 JSON files into memory at once causes a 7.8GB memory spike.**

Stage 2 will merge 5,308 request JSONs → 74 source file JSONs **immediately after parsing**,
then keep those 74 results **in memory** for the entire pipeline.

## Current Performance Bottleneck

For lucee-docs (5,308 request JSONs → 74 unique source files):

```
Phase parseExecutionLogs:      81,549ms (81.5s)  - Parse .exl → minimal JSONs
Phase extractAstMetadata:         344ms ( 0.3s)  - Extract AST for 74 files
Phase buildLineCoverage:       29,754ms (29.8s)  - Process 5,308 JSONs (disk I/O)
Phase Merge (current):         45,587ms (45.6s)  - Load all 5,308 into memory (7.8GB!)
  - Load 5308 JSONs:           34,724ms          - 🔥 THE KILLER (7.8GB spike)
  - Build mappings:               440ms
  - Merge coverage:            10,112ms          - Sequential merge
  - Other operations:             311ms
─────────────────────────────────────────────────
TOTAL:                        157,234ms (157.2s ≈ 2m 37s)
```

## Memory Analysis

**Current Peak Memory Usage:**
- After parseExecutionLogs: 1.3GB (5,308 minimal JSONs on disk)
- After buildLineCoverage: 2.5GB (processing 5,308 JSONs one-at-a-time)
- During Merge Load: **7.8GB** ← THE PROBLEM (all 5,308 in memory at once)

**Why so much memory?**
Each result object contains:
- Files metadata (~10KB per file)
- Coverage data (line-by-line hit counts and times)
- Blocks data (execution blocks with times)
- Stats, AST references, etc.

5,308 results × ~1.5MB average = ~7.8GB

## Stage 2: Early Merge Solution

### New Workflow

```
1. parseExecutionLogs:     Parse 5,308 .exl → 5,308 minimal JSONs (on disk)
2. earlyMergeToSourceFiles: Stream merge 5,308 → 74 in-memory results
   - Load one JSON at a time
   - Merge into corresponding source file result (by file path)
   - Discard source JSON after merging
   - Memory: Only 74 results + 1 current = ~500MB peak
3. extractAstMetadata:     Extract AST for 74 files (no change)
4. buildLineCoverage:      Process 74 IN-MEMORY results (no disk I/O!)
5. annotateCallTree:       Process 74 IN-MEMORY results (no disk I/O!)
6. generateReports:        Generate from 74 IN-MEMORY results
```

### Expected Performance

**Memory:**
- parseExecutionLogs: 1.3GB (minimal JSONs on disk)
- earlyMergeToSourceFiles: **~500MB** (74 results + 1 current) ← 94% reduction!
- buildLineCoverage: 500MB (processing in-memory results)
- Rest of pipeline: 500-800MB (stays in memory)

**Speed:**
- parseExecutionLogs: 81.5s (no change)
- **earlyMergeToSourceFiles: ~20-25s** (streaming merge, can be parallel)
- extractAstMetadata: 0.3s (no change)
- **buildLineCoverage: ~5-10s** (only 74 files, in memory, 70% faster)
- **generateReports: ~10-15s** (no JSON loading, already in memory)
- **TOTAL: ~120s** (24% faster overall, 76% less memory)

## Implementation Plan

### Step 1: Create StreamingMerger Component

Add new `StreamingMerger.cfc` component that:
- Takes array of JSON file paths
- Builds file path → canonical index mapping (one pass, no loading)
- Initializes empty merged results (74 result objects)
- Streams through JSON files one-at-a-time:
  - Load JSON
  - Extract coverage/blocks data
  - Merge into corresponding merged result
  - Aggregate childTime during merge
  - Discard JSON (nullValue for GC)
- Returns struct of 74 merged results in memory

**Key features:**
- **Parallel processing**: Split 5,308 files into chunks, process chunks in parallel
- **Memory efficient**: Never hold more than ~74 + chunk size in memory
- **Single pass**: Do everything during merge (coverage + childTime)

### Step 2: Update ReportGenerator Workflow

Modify `ReportGenerator.cfc` to call new workflow:

```cfml
// NEW: Early merge right after parsing
public struct function earlyMergeToSourceFiles(
	required array jsonFilePaths,
	required struct logger
) {
	var merger = new lucee.extension.lcov.StreamingMerger( logger=arguments.logger );

	// Stream merge 5,308 → 74 in-memory results
	var mergedResults = merger.streamMergeToSourceFiles(
		arguments.jsonFilePaths,
		parallel=true  // Process in parallel chunks
	);

	return mergedResults;
}
```

### Step 3: Update buildLineCoverage to Accept In-Memory Results

Modify `LineCoverageBuilder.cfc`:

**Before:**
```cfml
public array function buildCoverage(
	required array jsonFilePaths,  // Array of file paths to load
	required string astMetadataPath,
	boolean buildWithCallTree = false
) {
	// Load each JSON file from disk...
}
```

**After:**
```cfml
public struct function buildCoverage(
	required struct results,  // Already-loaded result objects
	required string astMetadataPath,
	boolean buildWithCallTree = false
) {
	// Process in-memory results (no disk I/O!)
	cfloop( collection=arguments.results, item="local.canonicalIndex" ) {
		var result = arguments.results[canonicalIndex];
		buildCoverageForResult( result, astMetadataPath, ... );
	}
	return arguments.results;
}
```

### Step 4: Update LcovFunctions.cfc Main Entry Points

Update the three main functions to use new workflow:

```cfml
// Phase parseExecutionLogs: Parse .exl files → minimal JSON files
var parseResult = processor.parseExecutionLogs( arguments.executionLogDir, _options );
var jsonFilePaths = parseResult.jsonFilePaths;

// NEW: Phase earlyMergeToSourceFiles: Merge 5,308 → 74 in-memory results
var mergedResults = generator.earlyMergeToSourceFiles( jsonFilePaths, _options.logger );

// Phase extractAstMetadata: Extract AST metadata (CallTree + executable lines)
var astMetadataPath = generator.extractAstMetadata(
	arguments.executionLogDir,
	parseResult.allFiles,  // Still use allFiles from parse
	_options
);

// Phase buildLineCoverage: Process 74 IN-MEMORY results (no disk I/O!)
var resultsWithCoverage = generator.buildLineCoverageFromResults(
	mergedResults,  // In-memory results instead of file paths
	astMetadataPath,
	_options,
	buildWithCallTree=true  // HTML format includes CallTree
);

// Phase generateReports: Generate from IN-MEMORY results
var htmlReporter = generator.createHtmlReporter( logger, _options.displayUnit );
htmlReporter.generateFromResults(
	resultsWithCoverage,  // Already in memory!
	arguments.outputDir
);
```

## StreamingMerger Implementation Details

### Parallel Streaming Strategy

```cfml
component {
	public struct function streamMergeToSourceFiles(
		required array jsonFilePaths,
		boolean parallel = true
	) localmode="modern" {
		// Step 1: Build file mappings (no loading, just read file lists)
		var mappings = buildFileMappingsWithoutLoading( arguments.jsonFilePaths );

		// Step 2: Initialize empty merged results (74 result objects)
		var mergedResults = initializeEmptyMergedResults( mappings );

		// Step 3: Stream merge with parallel chunks
		if ( arguments.parallel ) {
			streamMergeParallel( arguments.jsonFilePaths, mergedResults, mappings );
		} else {
			streamMergeSequential( arguments.jsonFilePaths, mergedResults, mappings );
		}

		return mergedResults;
	}

	private void function streamMergeParallel(
		required array jsonFilePaths,
		required struct mergedResults,
		required struct mappings
	) localmode="modern" {
		// Split into chunks for parallel processing
		var chunkSize = 100;  // Process 100 files per thread
		var chunks = [];

		for ( var i = 1; i <= arrayLen(arguments.jsonFilePaths); i += chunkSize ) {
			var chunk = [];
			for ( var j = i; j < i + chunkSize && j <= arrayLen(arguments.jsonFilePaths); j++ ) {
				arrayAppend( chunk, arguments.jsonFilePaths[j] );
			}
			arrayAppend( chunks, chunk );
		}

		// Process chunks in parallel
		// Each thread loads its chunk of JSONs, merges them, then discards
		var results = arrayMap( chunks, function( chunk ) {
			return processChunk( chunk, mergedResults, mappings );
		}, true );  // parallel=true

		// Results are merged into mergedResults by reference (thread-safe structInsert)
	}

	private void function processChunk(
		required array jsonPaths,
		required struct mergedResults,
		required struct mappings
	) localmode="modern" {
		var resultFactory = new lucee.extension.lcov.model.result();

		// Load and merge each JSON in this chunk
		for ( var jsonPath in arguments.jsonPaths ) {
			var result = resultFactory.fromJson( fileRead( jsonPath ), false );

			// Merge this result into the appropriate merged results
			mergeResultIntoMergedResults( result, arguments.mergedResults, arguments.mappings );

			// Discard to allow GC
			result = nullValue();
		}
	}

	private void function mergeResultIntoMergedResults(
		required any result,
		required struct mergedResults,
		required struct mappings
	) localmode="modern" {
		var coverageData = arguments.result.getCoverage();
		var blocks = arguments.result.getBlocks();
		var files = arguments.result.getFiles();

		// For each file in this result
		cfloop( collection=coverageData, item="local.fileIndex" ) {
			var filePath = files[fileIndex].path;
			var canonicalIndex = arguments.mappings.filePathToIndex[filePath];
			var mergedResult = arguments.mergedResults[canonicalIndex];

			// Merge coverage data
			var sourceCoverage = coverageData[fileIndex];
			mergeCoverageData( mergedResult, sourceCoverage, filePath );

			// Accumulate childTime from blocks
			if ( structKeyExists(blocks, fileIndex) ) {
				var fileBlocks = blocks[fileIndex];
				cfloop( collection=fileBlocks, item="local.blockKey" ) {
					var block = fileBlocks[blockKey];
					if ( structKeyExists(block, "isChild") && block.isChild ) {
						// Accumulate childTime (thread-safe)
						var metrics = mergedResult.getCallTreeMetrics();
						if ( !structKeyExists(metrics, "totalChildTime") ) {
							metrics.totalChildTime = 0;
						}
						metrics.totalChildTime += block.execTime;
						mergedResult.setCallTreeMetrics( metrics );
					}
				}
			}
		}
	}
}
```

### Thread Safety Considerations

**Challenge**: Multiple threads merging into shared `mergedResults` struct.

**Solution**:
1. Each merged result is keyed by `canonicalIndex` (0-73)
2. Each JSON file only touches specific canonical indices (based on which files it executed)
3. Use Lucee's built-in struct thread-safety for read-modify-write operations
4. Alternative: Use locks per canonicalIndex if needed

## Testing Strategy

### Tests That Must Pass

1. **All 281 existing tests** - No regressions
2. **Memory test** - Verify peak memory < 1GB (not 7.8GB)
3. **Performance test** - Verify merge time < 25 seconds
4. **Correctness test** - Compare merged.json output byte-for-byte with old approach

### New Tests to Add

1. **StreamingMergerTest** - Unit test for streaming merge logic
2. **ParallelMergeTest** - Verify parallel merge produces same results as sequential
3. **MemoryUsageTest** - Monitor memory during merge, assert < 1GB peak
4. **LargeDatasetTest** - Test with lucee-docs (5,308 JSONs)

## Migration Strategy

### Phase 1: Add Parallel Streaming Merge (Keep Old Path)

- Add `StreamingMerger.cfc` component
- Add `earlyMergeToSourceFiles()` function to ReportGenerator
- Add feature flag: `separateFiles=true` uses old path, `earlyMerge=true` uses new path
- Test new path thoroughly
- Compare output byte-for-byte

### Phase 2: Update Pipeline to Use In-Memory Results

- Modify `buildLineCoverage()` to accept struct of results instead of file paths
- Modify `annotateCallTree()` to accept struct of results
- Modify `generateReports()` to accept struct of results
- Run all tests with new pipeline

### Phase 3: Switch Default and Deprecate Old Path

- Switch default to `earlyMerge=true`
- Mark old merge functions as deprecated
- Remove old code after validation period

## Success Criteria

✅ All 281 tests pass
✅ Peak memory < 1GB (down from 7.8GB)
✅ Merge time < 25 seconds (down from 45 seconds)
✅ Overall pipeline time < 120 seconds (down from 157 seconds)
✅ merged.json output matches old approach byte-for-byte
✅ No performance regression on small datasets (< 100 JSONs)

## Risk Assessment

### Medium Risk

**Memory Management**: Parallel threads accessing shared mergedResults struct
- Mitigation: Use thread-safe operations, add locks if needed
- Test: Memory stress test with large dataset

**Coverage Data Corruption**: Race conditions during merge
- Mitigation: Each canonical index touched by limited set of threads
- Test: Compare parallel vs sequential merge output

### Low Risk

**Performance Regression**: New approach might be slower for small datasets
- Mitigation: Feature flag allows falling back to old approach
- Test: Benchmark on small, medium, large datasets

**Backward Compatibility**: Changes to function signatures
- Mitigation: Keep old functions, add new ones
- Test: All existing tests continue to pass

## Future Enhancements (Post-Stage 2)

1. **Skip disk write for merged results**: Keep 74 results in memory, never write to disk
2. **Optimize buildLineCoverage**: Process 74 files in parallel (currently sequential)
3. **Memory-mapped files**: Use memory-mapped I/O for very large .exl files
4. **Delta merging**: For CI, merge only changed files

## Open Questions

1. What chunk size for parallel processing? (100, 200, 500?)
2. Should we use locks for mergedResults struct access, or trust Lucee's thread-safety?
3. Should we keep old merge path as fallback, or remove it entirely?
4. Do we need to write the 74 merged results to disk, or keep them in-memory only?

---

**Bottom Line**: Stage 2 will reduce memory usage by 94% (7.8GB → 500MB) and speed up the pipeline by ~24% (~157s → ~120s) by merging early and keeping results in memory.
