# Executable Line Counting - Analysis & Shortcomings

This document analyzes the different approaches to counting executable lines in CFML code and their respective limitations.

## Goal

Count "executable lines" to match what Lucee's ResourceExecutionLog tracks. This ensures coverage percentages are accurate.

## Definition: What is an "Executable Line"?

An **executable line** is any source line that appears in the compiled bytecode's LineNumberTable. These are lines where Lucee's execution logger places tracking hooks.

**Ground Truth**: The LineNumberTable in compiled `.class` files shows exactly which lines Lucee tracks.

## Approaches Compared

### 1. Simple Line-Based Counting

**Method**: Count non-empty, non-comment lines

**Accuracy**: ~102% (over-counts by 2 lines compared to bytecode)

**Results** (kitchen-sink-example.cfm):
- Simple method: 46 lines
- Bytecode ground truth: 45 lines

**Shortcomings**:
- Counts declaration-only lines as executable (e.g., closing tags, property declarations)
- Cannot distinguish between executable statements and structural declarations
- No understanding of CFML syntax or semantics
- Over-counts compared to actual bytecode

**Example Over-Counting**:
```cfml
<cfscript>
    echo("Hello");  // Line 2 - Counted ✓ (correct)
</cfscript>         // Line 3 - Counted ✓ (incorrect - just closing tag)
```

### 2. AST-Based Counting

**Method**: Parse AST metadata from `.exl` files and count nodes that generate executable code

**Accuracy**: 95.6% (44/45 lines compared to bytecode)

**Results** (kitchen-sink-example.cfm):
- AST method: 44 lines
- Bytecode ground truth: 45 lines
- Missing: Line 70 (`</cfscript>` closing tag)

**Shortcomings**:

#### Missing Implicit Operations
- **Closing tags without explicit code**: The closing `</cfscript>` tag generates bytecode for cleanup/finalization but has no AST node
- **Implicit returns**: Some implicit operations don't appear in the AST

**Example Under-Counting**:
```cfml
<cfscript>
    echo("Coverage Testing Complete");  // Line 69 - Counted ✓
</cfscript>                              // Line 70 - NOT counted (no AST node, but has bytecode)
```

#### AST Limitations
- AST represents the logical structure of code, not the actual bytecode generated
- Compiler optimizations and implicit operations are invisible to AST analysis
- No way to detect cleanup code, implicit returns, or compiler-inserted instructions

### 3. Bytecode Analysis (Ground Truth)

**Method**: Parse compiled `.class` files using `javap` to extract LineNumberTable

**Accuracy**: 100% (by definition - this is what Lucee's execution logger tracks)

**Implementation**: See `BytecodeAnalyzer.cfc`

**How it works**:
1. Find compiled `.class` file in `{lucee-server}/cfclasses`
2. Run `javap -v` to get verbose bytecode output
3. Parse LineNumberTable sections
4. Extract line numbers

**Example javap output**:
```
LineNumberTable:
  line 1: 7
  line 3: 19
  line 6: 57
```

**Shortcomings**:

#### Production Unsuitability
- **Performance**: Requires finding and reading `.class` files from disk
- **Reliability**: Class files may not exist yet, could be in different locations
- **Complexity**: Requires executing external `javap` command and parsing output
- **Timing**: Class files are only available after code has been compiled and executed

#### Use Case Limitation
- **Only suitable for validation/tuning**: Cannot be used in production for real-time analysis
- **Async problem**: Coverage analysis needs to count lines before execution completes
- **File I/O overhead**: Requires directory scanning and file reading

**Why Not Production**:
The execution log (`.exl`) files are generated during code execution and contain the AST metadata. By the time bytecode is available for analysis, we already need to have the executable line count to calculate coverage percentages. Bytecode analysis is only useful for validating our AST-based approach, not for production use.

## Recommendation

**Use AST-based counting for production** with the understanding that:
- 95.6% accuracy is excellent for code coverage analysis
- The missing 4.4% represents implicit compiler operations that don't affect meaningful coverage metrics
- The performance and reliability benefits far outweigh the minor accuracy loss
- AST data is readily available in `.exl` files without additional file I/O

**Use bytecode analysis for tuning only** to:
- Validate AST heuristics
- Identify patterns that AST-based counting misses
- Benchmark accuracy improvements
- Understand compiler behavior

## Test Results

From `kitchen-sink-example.cfm` (70 total lines):

| Method | Lines Found | Accuracy | Performance |
|--------|-------------|----------|-------------|
| Simple | 46 | 102% (over) | Fast |
| AST | 44 | 95.6% | Fast |
| Bytecode | 45 | 100% | Slow |

**Lines Found**:
- **Bytecode (ground truth)**: 1,3,6,7,8,11,12,13,16,17,18,21,22,23,26,27,28,31,34,35,36,37,38,39,42,43,44,45,47,48,49,52,53,55,56,57,58,59,62,63,64,66,67,69,70
- **AST**: Missing line 70 (`</cfscript>` closing tag)
- **Simple**: Includes lines without bytecode (over-counts declarations)

## Execution Log Shortcomings

The execution log (`.exl` files) produced by Lucee's `ResourceExecutionLog` has its own limitations:

### What's NOT in the Execution Log

1. **Lines never executed**: Only executed lines appear in the log
2. **Unexecuted branches**: If-statements, loops, and conditionals that weren't taken leave no trace
3. **Dead code**: Unreachable code is never logged
4. **Declaration-only lines**: Property declarations, component metadata don't generate execution log entries

### Why This Matters

To calculate coverage percentages, we need:
```
Coverage % = (Lines Executed / Total Executable Lines) × 100
```

The execution log only tells us the **numerator** (lines executed). We need AST analysis to determine the **denominator** (total executable lines).

### Example Execution Log Gap

```cfml
<cfscript>
    if (condition) {
        echo("True");   // Line 3 - May or may not appear in .exl
    } else {
        echo("False");  // Line 5 - May or may not appear in .exl
    }
</cfscript>
```

If `condition` is true:
- Execution log contains: Line 3
- Execution log missing: Line 5 (never executed)
- AST must identify: Both lines 3 and 5 are executable

This is why we cannot rely solely on execution logs - we need AST analysis to find all *potentially* executable lines, even those not executed in a given test run.

## Testing

The `AstComparisonTest.cfc` test compares all three methods and validates AST accuracy against bytecode ground truth.

**Key test files**:
- `tests/parser/AstComparisonTest.cfc` - Comparison test
- `tests/artifacts/kitchen-sink-example.cfm` - Comprehensive test file
- `source/components/lucee/extension/lcov/ast/ExecutableLineCounter.cfc` - AST implementation
- `source/components/lucee/extension/lcov/ast/BytecodeAnalyzer.cfc` - Bytecode validation tool

## Conclusion

The combination of **AST-based line counting** (for finding executable lines) and **execution log parsing** (for tracking which lines ran) provides the best balance of accuracy, performance, and reliability for production code coverage analysis.

Bytecode analysis serves as valuable validation tool but is not suitable for production use.