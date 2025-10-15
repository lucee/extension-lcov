# Phase Rename and Merge Optimization Plan

## Overview

This document outlines a two-stage optimization plan for the LCOV extension:

1. **Stage 1**: Optimize existing pipeline + rename phases (meaningful names)
2. **Stage 2**: Turbo-charge with early mergeToSourceFiles (future work)

This document covers **Stage 1** only.

## Current Performance Bottleneck

For lucee-docs (5,308 request JSONs → 74 unique source files), the merge workflow takes **107.9 seconds**:

```
Load 5308 JSON files:          32,652ms (32.6s)  - Initial deserialize
Build file mappings:              956ms ( 1.0s)
Merge coverage:                 8,313ms ( 8.3s)  - Merging 5308→74
Aggregate CallTree:            35,047ms (35.0s)  - 🔥 THE KILLER (reloads all 5,308 JSONs!)
Calculate stats:                   36ms ( 0.0s)
Hydrate source code:               21ms ( 0.0s)
Write 74 per-file JSONs:          208ms ( 0.2s)
Write merged.json:             30,685ms (30.7s)  - 🔥 REDUNDANT (re-merges all 5,308 JSONs!)
──────────────────────────────────────────────
TOTAL:                        107,918ms (107.9s ≈ 1m 48s)
```

## Stage 1: Optimize Existing Pipeline

### Step 1: Rename Phases (Meaningful Names)

**Problem**: Numbered phases (Phase 1, 2, 3, 4, 5) are painful to maintain. Adding or reordering phases requires renumbering everywhere.

**Solution**: Use meaningful, self-documenting phase names.

#### Phase Name Mapping

| Current | New Name | What it does |
|---------|----------|--------------|
| Phase 1 | **parseExecutionLogs** | Parse .exl files → minimal JSON files |
| Phase 2 | **extractAstMetadata** | Extract AST metadata (CallTree + executable lines) |
| Phase 3 | **buildLineCoverage** | Build line coverage from aggregated blocks |
| Phase 4 | **annotateCallTree** | Annotate CallTree (mark blocks with isChild flags) |
| Phase 5 | **generateReports** | Generate HTML/JSON/LCOV reports |

#### Files to Update

Search for "Phase [0-9]" and "phase[0-9]" and replace in:

- `ExecutionLogProcessor.cfc` (7 log messages)
- `AstMetadataGenerator.cfc` (4 log messages, 2 comments)
- `LineCoverageBuilder.cfc` (3 log messages, 5 comments)
- `CallTreeAnnotator.cfc` (2 log messages, 4 comments)
- `LcovFunctions.cfc` (comments for all phases)
- `ReportGenerator.cfc` (function comments)
- `ExecutionLogParser.cfc` (2 comments)
- `AstMetadataExtractor.cfc` (1 comment)
- `BlockAggregator.cfc` (4 comments)

#### Example Changes

**Before**:
```cfml
variables.logger.info("Phase 1: Processing execution logs from: " & arguments.executionLogDir);
```

**After**:
```cfml
variables.logger.info("parseExecutionLogs: Processing execution logs from: " & arguments.executionLogDir);
```

**Before**:
```cfml
// Phase 3: Build line coverage (lazy - skips if already done)
```

**After**:
```cfml
// buildLineCoverage: Build line coverage (lazy - skips if already done)
```

#### Benefits

- **Future-proof**: Adding/reordering phases won't require renumbering
- **Self-documenting**: Log messages clearly say what's happening
- **Less confusing**: "buildLineCoverage" is clearer than "Phase 3"
- **Grep-friendly**: Easy to find all references to a specific phase

### Step 2: Optimize CallTree Aggregation (Save ~35 seconds)

**Problem**: `aggregateCallTreeMetricsForMergedResults()` reloads all 5,308 JSONs a second time just to sum up childTime values from blocks.

**Current Code** (ReportGenerator.cfc:214-229):
```cfml
if ( arguments.aggregateCallTree ) {
    var callTreeEvent = arguments.logger.beginEvent( "Merge: Aggregate CallTree metrics" );
    // Reload results one-at-a-time for CallTree aggregation
    for ( var jsonPath in arguments.jsonFilePaths ) {
        var result = resultFactory.fromJson( fileRead( jsonPath ), false );
        validResults[jsonPath] = result;
    }
    merger.aggregateCallTreeMetricsForMergedResults( mergedResults, validResults );
    validResults = {};
    arguments.logger.commitEvent( callTreeEvent, 0, "info" );
}
```

**Why It's Slow**: Reloads and deserializes all 5,308 JSON files a second time (32+ seconds) just to aggregate childTime.

**Solution**: Aggregate childTime during the initial merge in `mergeAllCoverageDataFromResults()`.

**Proposed Changes**:

1. Modify `CoverageMerger.mergeAllCoverageDataFromResults()` to track childTime accumulation:

```cfml
public struct function mergeAllCoverageDataFromResults(
    required struct validResults,
    required struct mergedResults,
    required struct mappings,
    required struct sourceFileStats,
    numeric totalMergeOperations = 0
) {
    // Track childTime per canonical index
    var childTimeByFile = structNew( "regular" );

    cfloop( collection=arguments.validResults, item="local.exlPath" ) {
        var result = arguments.validResults[exlPath];
        var coverageData = result.getCoverage();
        var blocks = result.getBlocks();

        cfloop( collection=coverageData, item="local.fileIndex" ) {
            var sourceFilePath = result.getFileItem(fileIndex).path;
            var canonicalIndex = arguments.mappings.filePathToIndex[sourceFilePath];

            // Merge coverage data (existing logic)
            var mergedLines = mergeCoverageData(...);

            // NEW: Accumulate childTime from blocks while we have them in memory
            if (structKeyExists(blocks, fileIndex)) {
                if (!structKeyExists(childTimeByFile, canonicalIndex)) {
                    childTimeByFile[canonicalIndex] = 0;
                }

                var fileBlocks = blocks[fileIndex];
                cfloop( collection=fileBlocks, item="local.blockKey" ) {
                    var block = fileBlocks[blockKey];
                    if (structKeyExists(block, "isChild") && block.isChild) {
                        childTimeByFile[canonicalIndex] += block.execTime;
                    }
                }
            }
        }
    }

    // Set aggregated childTime on merged results
    cfloop( collection=childTimeByFile, item="local.canonicalIndex" ) {
        var mergedResult = arguments.mergedResults[canonicalIndex];
        mergedResult.setCallTreeMetrics({ totalChildTime: childTimeByFile[canonicalIndex] });

        // Also set in stats so HTML reporter can display it
        var stats = mergedResult.getStats();
        stats.totalChildTime = childTimeByFile[canonicalIndex];
        mergedResult.setStats(stats);
    }

    return arguments.mergedResults;
}
```

2. Remove the reload loop in `ReportGenerator.generateSeparateFileMergedResults()`:

```cfml
// REMOVE THIS ENTIRE BLOCK:
if ( arguments.aggregateCallTree ) {
    var callTreeEvent = arguments.logger.beginEvent( "Merge: Aggregate CallTree metrics" );
    for ( var jsonPath in arguments.jsonFilePaths ) {
        var result = resultFactory.fromJson( fileRead( jsonPath ), false );
        validResults[jsonPath] = result;
    }
    merger.aggregateCallTreeMetricsForMergedResults( mergedResults, validResults );
    validResults = {};
    arguments.logger.commitEvent( callTreeEvent, 0, "info" );
}
```

3. Update `CoverageMerger.aggregateCallTreeMetricsForMergedResults()` to become a no-op (keep for backward compatibility):

```cfml
/**
 * @deprecated This function is no longer needed - CallTree metrics are aggregated during merge.
 * Kept for backward compatibility.
 */
public void function aggregateCallTreeMetricsForMergedResults(
    required struct mergedResults,
    required struct sourceResults
) {
    // No-op - aggregation now happens in mergeAllCoverageDataFromResults()
    variables.logger.debug("aggregateCallTreeMetricsForMergedResults: Skipped (aggregation now done during merge)");
}
```

**Impact**: Saves ~35 seconds for lucee-docs by eliminating the JSON reload.

### Step 3: Optimize merged.json Generation (Save ~30.7 seconds)

**Problem**: `mergeResultsByFile()` reloads and re-merges all 5,308 JSONs a third time just to write merged.json.

**Current Code** (ReportGenerator.cfc:247-253):
```cfml
// Also write merged.json that contains all coverage aggregated together
// This is needed by tests and for overall coverage reporting
var mergedJsonEvent = arguments.logger.beginEvent( "Merge: Write merged.json for #structCount(mergedResults)# files" );
var mergedByFile = merger.mergeResultsByFile( arguments.jsonFilePaths, arguments.logLevel );
var mergedFile = arguments.outputDir & "/merged.json";
fileWrite( mergedFile, serializeJSON( var=mergedByFile, compact=false ) );
arguments.logger.commitEvent( mergedJsonEvent, 0, "info" );
```

**Why It's Slow**: `mergeResultsByFile()` loops through all 5,308 JSONs again, loading and merging them by file path (30+ seconds).

**Solution**: Build merged.json from the already-merged `mergedResults` struct in memory.

**Proposed Changes**:

1. Add new function `CoverageMerger.buildMergedJsonFromMergedResults()`:

```cfml
/**
 * Build merged.json structure from already-merged results
 * This is much faster than reloading and re-merging all JSONs
 * @mergedResults Struct of merged result objects keyed by canonical index
 * @return Struct with mergedCoverage and files (same format as mergeResultsByFile)
 */
public struct function buildMergedJsonFromMergedResults(required struct mergedResults) localmode="modern" {
    var merged = {
        "files": structNew( "regular" ),
        "coverage": structNew( "regular" ),
        "blocks": structNew( "regular" )
    };

    cfloop( collection=arguments.mergedResults, item="local.canonicalIndex" ) {
        var mergedResult = arguments.mergedResults[canonicalIndex];
        var files = mergedResult.getFiles();
        var coverage = mergedResult.getCoverage();
        var blocks = mergedResult.getBlocks();

        // Each merged result has exactly one file (at index 0)
        var fileInfo = files[0];
        var filePath = fileInfo.path;

        // Copy file metadata
        merged.files[filePath] = fileInfo;

        // Copy coverage data (keyed by file path instead of index)
        if (structKeyExists(coverage, 0)) {
            merged.coverage[filePath] = coverage[0];
        }

        // Copy block data (keyed by file path instead of index)
        if (structKeyExists(blocks, 0)) {
            merged.blocks[filePath] = blocks[0];
        }
    }

    return {
        "mergedCoverage": merged,
        "files": merged.files
    };
}
```

2. Update `ReportGenerator.generateSeparateFileMergedResults()`:

```cfml
// BEFORE (30.7 seconds):
var mergedJsonEvent = arguments.logger.beginEvent( "Merge: Write merged.json for #structCount(mergedResults)# files" );
var mergedByFile = merger.mergeResultsByFile( arguments.jsonFilePaths, arguments.logLevel );
var mergedFile = arguments.outputDir & "/merged.json";
fileWrite( mergedFile, serializeJSON( var=mergedByFile, compact=false ) );
arguments.logger.commitEvent( mergedJsonEvent, 0, "info" );

// AFTER (~0.1 seconds):
var mergedJsonEvent = arguments.logger.beginEvent( "Merge: Build merged.json from memory" );
var mergedByFile = merger.buildMergedJsonFromMergedResults( mergedResults );
var mergedFile = arguments.outputDir & "/merged.json";
fileWrite( mergedFile, serializeJSON( var=mergedByFile, compact=false ) );
arguments.logger.commitEvent( mergedJsonEvent, 0, "info" );
```

**Impact**: Saves ~30 seconds for lucee-docs by building merged.json from memory instead of reloading files.

### Expected Performance After Stage 1

**Before**:
```
Total merge time: 107.9 seconds
```

**After**:
```
Load 5308 JSON files:          32,652ms (32.6s)
Build file mappings:              956ms ( 1.0s)
Merge coverage + CallTree:      8,313ms ( 8.3s)  ← Aggregates childTime during merge
Calculate stats:                   36ms ( 0.0s)
Hydrate source code:               21ms ( 0.0s)
Write 74 per-file JSONs:          208ms ( 0.2s)
Build merged.json from memory:    ~100ms ( 0.1s)  ← No file reload!
──────────────────────────────────────────────
TOTAL:                          ~42,286ms (42.3s)

Savings: 65.6 seconds (60% faster!)
```

## Testing Strategy

### Tests That Must Pass

1. **All 281 existing tests** - No regressions
2. **RequestAggregationTest** - Validates merged.json format and childTime aggregation
3. **DuplicateIndexJsonTest** - Validates merged.json exists
4. **CallTreeReportGenerationTest** - Validates CallTree metrics in HTML reports
5. **HtmlReporterValidationTest** - Validates childTime in detail pages

### Validation Checks

1. **merged.json format matches old output** - Compare struct keys, coverage format, childTime values
2. **childTime aggregation is correct** - Sum of all childTime values matches expected totals
3. **HTML reports show correct childTime** - Detail pages and index show proper own time vs child time

## Implementation Order

1. **Phase Rename** (low risk, high clarity)
   - Update all log messages and comments
   - Run tests to ensure no breakage
   - Commit: "Rename numbered phases to meaningful names"

2. **Optimize CallTree Aggregation** (medium risk)
   - Modify `mergeAllCoverageDataFromResults()` to aggregate during merge
   - Remove reload loop in `generateSeparateFileMergedResults()`
   - Run tests to validate childTime values
   - Commit: "Aggregate CallTree metrics during merge (eliminate 35s reload)"

3. **Optimize merged.json Generation** (low risk)
   - Add `buildMergedJsonFromMergedResults()` function
   - Replace `mergeResultsByFile()` call
   - Run tests to validate merged.json format
   - Commit: "Build merged.json from memory (eliminate 30s reload)"

## Stage 2: Future Work (Not in This Plan)

After Stage 1 is complete and proven stable, we can tackle Stage 2:

**Early mergeToSourceFiles** - Merge 5,308 request JSONs → 74 source file JSONs right after parseExecutionLogs, before buildLineCoverage/annotateCallTree. This would make subsequent phases work on 74 files instead of 5,308.

Benefits:
- buildLineCoverage works on 74 files (72x fewer!)
- annotateCallTree works on 74 files
- No late-stage merge needed at all

This is a bigger architectural change and should be done separately after Stage 1 proves successful.

## Open Questions

1. Do we need to keep `CoverageMerger.aggregateCallTreeMetricsForMergedResults()` for backward compatibility, or can we remove it entirely?
2. Should we add explicit test validation that merged.json format exactly matches the old output?
3. Any edge cases where the optimization assumptions break down?

## Success Criteria

- All 281 tests pass
- lucee-docs merge time drops from 107.9s to ~42s
- merged.json format is identical to current output
- childTime aggregation is correct in all HTML reports
- Log messages use meaningful phase names
