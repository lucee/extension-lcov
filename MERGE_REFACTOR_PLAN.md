# Coverage Merging Refactor Plan

## Current Problem
When merging coverage data from multiple execution runs (.exl files) of the same source files, the current implementation has several issues:
1. Stats are calculated in multiple places (CoverageMerger and CoverageStats)
2. Merged results can have multiple file indices pointing to the same source file
3. This causes `linesHit` to be counted multiple times (e.g., 38 instead of 19)
4. The separation of concerns is unclear between merging data and calculating stats

## Core Concepts

### What is Coverage Merging?
Merging transforms request-based coverage logs into file-based coverage results:
- **Input**: Multiple .exl files (one per HTTP request)
  - Each request may execute multiple source files (e.g., test suite run)
  - Or just one file (e.g., manual testing of a single page)
- **Output**: One result object per unique source file with accumulated coverage

### Key Invariants
1. **Per file**: `linesFound` (executable lines) is always the same regardless of how many runs
2. **Per file**: `linesHit` is the count of unique lines that were executed at least once across all runs
3. **Per file**: `linesHit` ≤ `linesFound` always
4. **Hit counts**: Individual line hit counts are accumulated (if line 5 was hit 3 times in run 1 and 2 times in run 2, the merged hit count is 5)
5. **File uniqueness**: Each merged result object contains exactly ONE file at index 0

## Data Structures

### Input: Multiple .exl Files (Request-Based)
Each .exl file represents one HTTP request and may cover multiple source files:
```
// Request 1 (.exl) - Test suite run covering multiple files
result1 = {
    files: {
        "0": { path: "/path/to/file1.cfm", linesFound: 20, executableLines: {...} },
        "1": { path: "/path/to/file2.cfm", linesFound: 15, executableLines: {...} }
    },
    coverage: {
        "0": { "5": [1, 100], "10": [2, 200], ... },  // line_num: [hit_count, exec_time]
        "1": { "3": [1, 50], ... }
    }
}

// Request 2 (.exl) - Another request hitting file1.cfm again
result2 = {
    files: {
        "0": { path: "/path/to/file1.cfm", linesFound: 20, executableLines: {...} }
    },
    coverage: {
        "0": { "5": [2, 150], "15": [1, 100], ... }  // Same file, different/overlapping lines
    }
}
```

### Output: Per-File Merged Results
After merging, we get a struct of result objects, ONE per unique source file:
```
mergedResults = {
    "0": {  // Canonical index for file1.cfm
        files: {
            "0": { path: "/path/to/file1.cfm", linesFound: 20, executableLines: {...} }
            // ALWAYS index 0, only ONE file per result object
        },
        coverage: {
            "0": {  // Coverage for the single file at index 0
                "5": [3, 250],   // 1+2 hits, 100+150 time
                "10": [2, 200],  // From request 1
                "15": [1, 100]   // From request 2
            }
        },
        stats: {
            totalLinesFound: 20,
            totalLinesHit: 3,     // Lines 5, 10, 15 were hit
            totalExecutions: 6,   // 3+2+1 total hits
            totalExecutionTime: 550
        }
    },
    "1": {  // Canonical index for file2.cfm
        files: {
            "0": { path: "/path/to/file2.cfm", linesFound: 15, executableLines: {...} }
        },
        coverage: {
            "0": { "3": [1, 50], ... }
        },
        stats: { ... }
    }
}
```

## Proposed Architecture

### 1. Clear Separation of Concerns

#### CoverageMerger
**Responsibility**: Merge raw coverage data only
- Combine coverage arrays (accumulate hit counts and execution times)
- Merge executable lines from different runs
- Create a single canonical file entry per source file
- **DO NOT** calculate statistics

#### CoverageStats
**Responsibility**: Calculate all statistics from merged data
- Count `linesFound` from executable lines
- Count `linesHit` from coverage data (unique lines with hits > 0)
- Calculate totals and percentages
- Validate invariants (linesHit ≤ linesFound)

### 2. Merging Algorithm

#### Step 1: Build File Mappings
- Scan all input .exl results to find unique file paths
- Assign a canonical index (0, 1, 2...) to each unique file path
- Create bidirectional mappings: path ↔ canonical index

#### Step 2: Create Per-File Result Objects
For each unique file path:
```cfml
mergedResults[canonicalIndex] = new result() {
    files: {
        "0": { path: filePath, linesFound: 0, executableLines: {} }
    },
    coverage: {
        "0": {}  // Will accumulate line coverage
    },
    stats: {}    // Calculated later by CoverageStats
}
```

#### Step 3: Merge File Metadata
For each .exl result and each file within it:
- Find the corresponding merged result by canonical index
- Merge `executableLines` (union of all executable lines)
- Keep consistent `linesSource` (should be same across all runs)
- Update the single file entry at index 0

#### Step 4: Merge Coverage Data
For each .exl result and each file within it:
- Find the corresponding merged result by canonical index
- For each line in coverage:
  - If line doesn't exist in merged coverage[0]: add it
  - If line exists: accumulate hit count and execution time

#### Step 5: Calculate Statistics (CoverageStats only)
For each merged result object:
- Call `calculateCoverageStats` which will:
  - Process the single file at index 0
  - Count lines from coverage data
  - Set stats on the result object
  - Validate invariants

## Implementation Changes Required

### 1. Fix CoverageMerger
- Remove `finalizeFileStats` function entirely ✓
- Verify merged result objects have exactly ONE file entry at index 0
- Ensure no duplicate file entries are created during merging

### 2. Debug Current Issue
The bug appears to be that after merging, the result object for a file has:
- Multiple entries in its `files` struct (e.g., indices 0 and 1 both for loops.cfm)
- This causes `calculateCoverageStats` to iterate multiple times over the same file
- Leading to `linesHit` being counted twice (38 instead of 19)

Need to verify:
1. What does the merged result's `files` struct actually contain?
2. Is `initializeSourceFileEntry` being called multiple times for the same file?
3. Is coverage data being duplicated somewhere?

### 3. Fix CoverageStats
- Ensure `calculateCoverageStats` handles single-file results correctly
- Verify it only processes index 0 (since merged results have one file at index 0)
- Add validation that merged results only have one file entry

### 4. Update Tests
- Remove tests for `finalizeFileStats` ✓
- Add tests for single-file-entry invariant in merged results
- Verify stats are calculated correctly for merged data
- Add specific test for the 19 vs 38 bug scenario

## Success Criteria
1. `linesHit` never exceeds `linesFound`
2. Merging the same file multiple times produces correct cumulative coverage
3. Each merged result object contains exactly ONE file at index 0
4. Stats are calculated in one place only (CoverageStats)
5. All existing tests pass
6. The loops.cfm test shows 19 lines hit, not 38