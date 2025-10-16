# Overlap Filter Data Loss Analysis

## Overview

The overlap filtering system removes nested/overlapping execution blocks to avoid double-counting coverage. However, this process **discards execution count and timing data** from filtered blocks.

## Current Implementation

### What Gets Filtered

From `OverlapFilterPosition.cfc`, the `filterOverlappingBlocks()` algorithm:

1. **Sorts blocks by span size** (smallest first)
2. **Removes nested blocks** - if block A is fully contained within block B, one is discarded
3. **Removes containing blocks** - if block A fully contains block B, one is discarded
4. **Keeps the most specific blocks** (smallest spans)

### Block Data Format

**Input format (aggregated):**
```cfml
[fileIdx, startPos, endPos, count, totalTime]
```

Where:
- `fileIdx` - File identifier
- `startPos` - Character offset start position
- `endPos` - Character offset end position
- `count` - **Number of times this block was executed** ⚠️
- `totalTime` - **Total accumulated execution time in nanoseconds** ⚠️

**During filtering:**
```cfml
[fileIdx, startPos, endPos, execTime]
```

Only position data is preserved for overlap detection. Count is lost.

## Data Loss Examples

### Example 1: Function with nested block

```cfml
function foo() {          // Block A: positions 0-100, executed 50 times, 500ms
    if (condition) {      // Block B: positions 20-40, executed 25 times, 50ms
        doSomething();
    }
}
```

**Scenario 1 - Keep smaller block (B):**
- ✅ Block B kept: positions 20-40, executed 25 times, 50ms
- ❌ Block A lost: **50 executions and 500ms discarded**

**Scenario 2 - Keep larger block (A):**
- ✅ Block A kept: positions 0-100, executed 50 times, 500ms
- ❌ Block B lost: **25 executions and 50ms discarded**

### Example 2: Loop with multiple iterations

```cfml
for (i = 1; i <= 100; i++) {    // Block A: positions 0-200, 100 iterations, 1000ms
    processItem(i);              // Block B: positions 50-100, 100 calls, 800ms
}
```

**If B is filtered:**
- Lost: 100 executions of `processItem()`
- Lost: 800ms of execution time data
- **Impact:** Can't distinguish time spent in loop overhead vs. function call

### Example 3: Nested function calls

```cfml
function outer() {           // Block A: pos 0-300, 10 calls, 500ms
    inner1();                // Block B: pos 100-120, 10 calls, 100ms
    inner2();                // Block C: pos 150-170, 10 calls, 150ms
}
```

If we keep only the smallest blocks (B, C) and filter A:
- ✅ Kept: inner1() + inner2() = 250ms
- ❌ Lost: outer() overhead = **250ms unaccounted for**

## Current Behavior in Code

### OverlapFilterPosition.cfc (line 107-112)

```cfml
if (structKeyExists(arguments.aggregatedOrBlocksByFile, key)) {
    result[key] = arguments.aggregatedOrBlocksByFile[key];
} else {
    // Fallback: reconstruct entry (shouldn't happen normally)
    result[key] = [fileIdx, fBlock[2], fBlock[3], 1, fBlock[4]];
}
```

**When a block IS kept:**
- ✅ Original `count` and `totalTime` preserved

**When a block IS filtered:**
- ❌ All data for that block is permanently lost
- ❌ No aggregation or rollup happens

## Impact Assessment

### On Coverage Reporting

**Line Coverage:** ✅ Not affected
- Overlap filtering happens BEFORE line aggregation
- If ANY block covers a line, it's marked as covered
- ✅ Coverage percentages remain accurate

**Execution Counts:** ❌ Significantly affected
- Hit counts are **underreported** when nested blocks are filtered
- Example: A line executed 100 times might show only 25 hits if the smaller nested block is kept

**Execution Time:** ❌ Significantly affected
- Total execution time is **incomplete**
- Cannot accurately measure performance hotspots
- Parent function time vs. child function time is distorted

### Real-World Example from Lucee-Docs Build

From the meta-analysis report:
- **CallTreeParallelHelpers.cfc**: 862,125 executions, 4.5s own time
- **CoverageAggregator.cfc**: 33.5 million executions, 8.0s own time

If these have nested blocks, we're potentially losing:
- Thousands of execution counts
- Seconds of execution time data
- Ability to distinguish parent vs. child time accurately

## Potential Solutions

### Option 1: Aggregate Filtered Data (Recommended)

Instead of discarding filtered blocks, **roll up their data to the parent block**:

```cfml
if (blockIsContainedBy(current, kept)) {
    // Add current block's data to the containing block
    kept.count += current.count;
    kept.totalTime += current.totalTime;
    kept.childBlocks = kept.childBlocks ?: [];
    arrayAppend(kept.childBlocks, current); // Track what was merged
    // Don't add current to keptBlocks
}
```

**Pros:**
- ✅ No data loss - all counts and times preserved
- ✅ Parent blocks get accurate total time (self + children)
- ✅ Can still distinguish child vs. parent time if needed

**Cons:**
- Requires tracking parent-child relationships
- More complex overlap logic

### Option 2: Keep All Blocks, Mark Overlaps

Don't filter at all - keep all blocks but mark which ones overlap:

```cfml
result[key] = [fileIdx, startPos, endPos, count, totalTime, isNested, parentKey];
```

**Pros:**
- ✅ Zero data loss
- ✅ Full execution information preserved
- ✅ Can generate multiple reports (with/without overlap filtering)

**Cons:**
- Larger data structures
- Downstream consumers need to handle overlaps
- Line coverage calculations become more complex

### Option 3: Weighted Filtering

Keep multiple blocks per region, weighted by execution count:

```cfml
// Instead of keeping only 1 block, keep top N blocks by execution count
var topBlocks = getTopNBlocksByCount(overlappingBlocks, maxBlocksPerRegion=3);
```

**Pros:**
- ✅ Preserves high-frequency execution data
- ✅ Balances data loss vs. data volume

**Cons:**
- Still loses some data (low-frequency blocks)
- Arbitrary threshold (how many blocks to keep?)

### Option 4: Separate Overlap Filtering for Coverage vs. Timing

Use different strategies for different purposes:

**For Line Coverage:**
- Filter aggressively (keep smallest blocks)
- Focus: accurate covered/not covered

**For Execution Analysis:**
- Filter less aggressively or aggregate
- Focus: accurate counts and timing

**Pros:**
- ✅ Best of both worlds
- ✅ Coverage reports stay clean
- ✅ Performance analysis gets full data

**Cons:**
- Two separate data paths
- More complexity

## Questions to Answer

1. **How much data are we losing?**
   - Need metrics: % of blocks filtered, % of execution counts lost, % of time lost
   - Should add logging to track this

2. **Does it matter for coverage reporting?**
   - For line coverage: probably not
   - For execution analysis: definitely yes
   - For performance profiling: absolutely critical

3. **What's the use case priority?**
   - If primary goal is **code coverage**: current approach OK
   - If primary goal is **performance profiling**: need to preserve timing data
   - If both: need hybrid approach (Option 4)

4. **What was the shower idea?**
   - Was it about preserving this data?
   - About aggregating filtered blocks into parents?
   - About detecting where we're losing the most information?

## Recommendation

Based on the code analysis, I recommend **Option 1 (Aggregate Filtered Data)** because:

1. **Preserves all execution data** - no loss of counts or timing
2. **Maintains current architecture** - still filters overlaps for coverage
3. **Enables accurate performance analysis** - parent time = self time + child time
4. **Relatively simple to implement** - extend existing overlap detection logic

The key insight: **Overlap filtering is necessary for coverage, but we shouldn't throw away the data - we should merge it.**

## Implementation Notes

If implementing Option 1, the changes would be in:
- `OverlapFilterPosition.filterOverlappingBlocks()` (lines 151-210)
- Add accumulation logic when blocks are filtered
- Track parent-child relationships
- Preserve original block data for reporting

This would enable:
- Accurate line coverage (as today)
- Accurate execution counts (sum of all overlapping blocks)
- Accurate timing analysis (parent time includes child time)
- Call tree visualization showing nesting relationships
