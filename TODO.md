# Performance Review: filterOverlappingBlocksOptimized

### Strengths
- Uses arrays for block info, which is faster than structs in Lucee/CFML.
- Only one pass to build the blockInfo array.
- The overlap check is correct and concise.
- Comments clarify array indices, reducing maintenance risk.

### Potential Performance Issues
1. **O(n²) Complexity**:  The nested loop (for each block, compare to every other block) means performance degrades rapidly as the number of blocks increases. For small arrays (tens or low hundreds), this is fine, but for thousands of blocks, it will be slow.
2. **No Early Exit for Sorted/Disjoint Blocks**:  If blocks are sorted by start position, you could break early in the inner loop when other[3] (other start) is greater than info[4] (info end), skipping unnecessary comparisons.
3. **No Pre-Sorting**:  Sorting blocks by start position before the main loop could allow for more efficient overlap checks (e.g., sweep line algorithm), reducing unnecessary comparisons.
4. **ArrayAppend in Loops**:  arrayAppend is fast, but if the number of blocks is very large, pre-sizing the array (if possible) could help.

### Suggestions for Large Datasets
- If you expect large numbers of blocks, consider:
  - Sorting blocks by start position.
  - Using a sweep line or interval tree approach to reduce comparisons.
  - Breaking inner loop early when possible.

### For Most Use Cases
- For typical code coverage block counts (usually < 1000 per file), this implementation is efficient and clear.
- The array-based approach is optimal for Lucee/CFML.

If you want, consider implementing a more advanced algorithm for large datasets, but for most real-world coverage scenarios, this code is performant and maintainable.
# TODO: Implement LCOV Extension API Design

This document outlines the tasks needed to implement the API design specified in `API_DESIGN.md`.

## Core API Functions to Implement

### 1. Coverage Data Collection

#### `lcovStartLogging(adminPassword, executionLogDir, options)`
- [ ] Create global function in extension
- [ ] Implement admin password validation
- [ ] Handle executionLogDir parameter (optional, auto-generate if empty)
- [ ] Process options struct:
  - [ ] `unit` (nano, micro, milli)
  - [ ] `minTime` (numeric, nanoseconds)
  - [ ] `maxLogs` (numeric, 0=unlimited)
  - [ ] `className` (string, default="ResourceExecutionLog")
- [ ] Modify Lucee server configuration (.CFConfig.json)
- [ ] Enable ResourceExecutionLog with specified parameters
- [ ] Return string path to log directory being used
- [ ] Add error handling for invalid admin password
- [ ] Add error handling for directory creation failures

#### `lcovStopLogging(adminPassword, className)`
- [ ] Create global function in extension
- [ ] Implement admin password validation
- [ ] Handle className parameter (optional, default="ResourceExecutionLog")
- [ ] Remove execution logging configuration from server settings
- [ ] Modify Lucee server configuration (.CFConfig.json)
- [ ] Add error handling for invalid admin password

### 2. Convenience Function

#### `lcovGenerateAllReports(executionLogDir, outputDir, options)`
- [ ] Create global function in extension
- [ ] Process executionLogDir parameter (required)
- [ ] Process outputDir parameter (required)
- [ ] Process options struct:
  - [ ] `verbose` (boolean, default: false)
  - [ ] `chunkSize` (numeric, default: 50000)
  - [ ] `allowList` (array, file patterns to include)
  - [ ] `blocklist` (array, file patterns to exclude)
  - [ ] `displayUnit` (string, time unit for display)
- [ ] Generate ALL report types (HTML, JSON, LCOV)
- [ ] Return struct with all generated file paths and stats:
  ```cfml
  {
      "lcovFile": "/path/to/lcov.info",
      "htmlIndex": "/path/to/index.html", 
      "htmlFiles": [...],
      "jsonFiles": {...},
      "stats": {...}
  }
  ```

### 3. Individual Report Generation

#### `lcovGenerateLcov(executionLogDir, outputFile, options)`
- [ ] Create global function in extension
- [ ] Process executionLogDir parameter (required)
- [ ] Process outputFile parameter (optional - if empty, return string content)
- [ ] Process options struct:
  - [ ] `verbose` (boolean, default: false)
  - [ ] `allowList` (array)
  - [ ] `blocklist` (array)
  - [ ] `useRelativePath` (boolean, default: false)
- [ ] Parse .exl files from executionLogDir
- [ ] Generate LCOV format content
- [ ] If outputFile provided: write to file and return file path
- [ ] If outputFile empty: return LCOV content as string
- [ ] Support filtering with allowList/blocklist

#### `lcovGenerateHtml(executionLogDir, outputDir, options)`
- [ ] Create global function in extension
- [ ] Process executionLogDir parameter (required)
- [ ] Process outputDir parameter (required)
- [ ] Process options struct:
  - [ ] `verbose` (boolean, default: false)
  - [ ] `displayUnit` (string)
  - [ ] `allowList` (array)
  - [ ] `blocklist` (array)
- [ ] Parse .exl files from executionLogDir
- [ ] Generate HTML reports (one per file + index.html)
- [ ] Return struct with generated file paths and stats
- [ ] Support filtering with allowList/blocklist

#### `lcovGenerateJson(executionLogDir, outputDir, options)`
- [ ] Create global function in extension
- [ ] Process executionLogDir parameter (required)
- [ ] Process outputDir parameter (required)
- [ ] Process options struct:
  - [ ] `verbose` (boolean, default: false)
  - [ ] `separateFiles` (boolean, default: false)
  - [ ] `compact` (boolean, default: false)
  - [ ] `includeStats` (boolean, default: true)
  - [ ] `allowList` (array)
  - [ ] `blocklist` (array)
- [ ] Parse .exl files from executionLogDir
- [ ] Generate JSON reports (combined or separate per separateFiles option)
- [ ] Return struct with generated file paths and stats
- [ ] Support filtering with allowList/blocklist

#### `lcovGenerateSummary(executionLogDir, options)`
- [ ] Create global function in extension
- [ ] Process executionLogDir parameter (required)
- [ ] Process options struct:
  - [ ] `verbose` (boolean, default: false)
  - [ ] `chunkSize` (numeric, default: 50000)
  - [ ] `allowList` (array)
  - [ ] `blocklist` (array)
- [ ] Parse .exl files from executionLogDir (stats only, no file generation)
- [ ] Return struct with coverage statistics:
  ```cfml
  {
      "totalLines": 1000,
      "coveredLines": 750,
      "coveragePercentage": 75.0,
      "totalFiles": 25,
      "executedFiles": 20,
      "processingTimeMs": 250,
      "fileStats": {...}
  }
  ```

## Core Processing Components

### EXL File Parser
- [ ] Implement .exl file format parser
- [ ] Parse metadata section (headers like context-path, unit, etc.)
- [ ] Parse file mappings section (fileIndex:filePath)
- [ ] Parse coverage data section (fileIndex, startPos, endPos, executionTime)
- [ ] Handle character position to line number mapping
- [ ] Implement parallel processing with configurable chunk size
- [ ] Add memory management for large .exl files
- [ ] Support filtering with allowList/blocklist patterns

### Coverage Data Processing
- [ ] Implement line hit counting and aggregation
- [ ] Support mergeFiles option (combine multiple .exl files)
- [ ] Calculate coverage statistics (percentage, totals, etc.)
- [ ] Handle file pattern matching for filtering
- [ ] Implement caching for file contents and line mappings
- [ ] Add performance optimization for large datasets

### Report Generators

#### LCOV Generator
- [ ] Generate standard LCOV format
- [ ] Support SF (source file) records
- [ ] Support DA (data array/line hits) records  
- [ ] Support LF (lines found) and LH (lines hit) records
- [ ] Support end_of_record markers
- [ ] Ensure compatibility with VS Code Coverage Gutters
- [ ] **Add useRelativePath option**: When enabled, use `contractPath()` to convert absolute file paths to relative paths in SF records for more portable LCOV files

#### HTML Generator
- [ ] Generate index.html with overview
- [ ] Generate individual HTML files per source file
- [ ] Support different time unit displays (nano, micro, milli)
- [ ] Include coverage statistics
- [ ] Support dark mode (if implemented)
- [ ] Include heatmap reports (if implemented)
- [ ] **NEW: Sequential Execution View** - When NOT separating by file (separateFiles=false), add a sequential execution timeline view showing each line of code executed in request order with timing information

#### JSON Generator
- [ ] Generate results.json (raw coverage data)
- [ ] Generate mergedCoverage.json (merged across files)
- [ ] Generate lcov-stats.json (statistics)
- [ ] Support separateFiles option (individual JSON per source file)
- [ ] Support compact vs. pretty-printed JSON
- [ ] Include statistics based on includeStats option

## Error Handling

### Admin Password Validation
- [ ] Validate admin password against Lucee server configuration
- [ ] Throw specific exceptions for invalid passwords
- [ ] Provide clear error messages

### File System Operations
- [ ] Handle missing or corrupted .exl files
- [ ] Handle directory creation failures
- [ ] Handle file permission issues
- [ ] Handle disk space limitations
- [ ] Log errors to Lucee's internal log system

### Configuration Issues
- [ ] Validate file paths in allow/block lists
- [ ] Handle malformed .exl data gracefully
- [ ] Detect orphaned logging configuration
- [ ] Provide recovery suggestions

## Performance Optimizations

### Parallel Processing
- [ ] Implement configurable chunk size (default: 50,000 lines)
- [ ] Use arrayEach with parallel=true for chunk processing
- [ ] Optimize for test suites with large .exl files
- [ ] Add memory usage monitoring
- [ ] **ISSUE: Duplicate Processing** - ExecutionLogParser already converts character positions to line numbers, but excludeOverlappingBlocks in CoverageBlockProcessor is doing the same conversion again with parallel processing, causing thread deadlocks
- [ ] **MAJOR OPTIMIZATION: Pre-aggregation Pass** - Add Pass 0 before all processing to combine repeated file:startPos:endPos entries, potentially reducing processing volume by 90%+

### Caching
- [ ] Cache file contents to avoid redundant I/O
- [ ] Cache line mapping calculations
- [ ] Cache file existence checks
- [ ] Implement cache invalidation strategies

### Memory Management
- [ ] Process data in chunks to avoid loading entire datasets
- [ ] Clean up temporary data structures
- [ ] Monitor memory usage during processing

### Thread Contention Issues
- [ ] **CRITICAL: Double Processing** - We have two `getLineFromCharacterPosition` functions:
  1. ExecutionLogParser.cfc (optimized version) - processes character positions to line numbers in parallel
  2. CoverageBlockProcessor.cfc (original version) - called by excludeOverlappingBlocks, doing the same conversion again
- [ ] **Thread Deadlocks** - excludeOverlappingBlocks uses `structEach(..., parallel=true)` causing parking/deadlock issues
- [ ] **Performance Impact** - Same data being processed twice with expensive character-to-line conversions
- [ ] **Solution Options**:
  - [ ] Bypass excludeOverlappingBlocks entirely when blocks are already line-based
  - [ ] Disable parallel processing in excludeOverlappingBlocks
  - [ ] Create optimized line-based processing path
  - [ ] Consolidate duplicate getLineFromCharacterPosition functions

### Major Performance Optimization Opportunities

#### 1. Pre-Aggregation Pass (MASSIVE IMPACT)
- [ ] **PERFORMANCE OPPORTUNITY: Redundant Coverage Lines** - .exl files contain massive duplication where the same file:startPos:endPos combinations are repeated hundreds/thousands of times
- [ ] **Current Inefficiency**: Processing each individual execution separately with expensive character-to-line conversion
- [ ] **Solution: Pre-aggregation Pass**:
  - [ ] **Pass 0: Aggregate Raw Coverage** - Before any processing, combine identical file:startPos:endPos entries
  - [ ] **Combine Metrics**: Sum execution counts and execution times for identical positions
  - [ ] **Reduce Processing Volume**: Instead of processing 10,000 identical lines, process 1 aggregated line
  - [ ] **Maintain Accuracy**: Final coverage statistics remain identical
- [ ] **Expected Gains**: 90%+ reduction in processing volume

#### 2. File Existence Pre-Check (EARLY FILTERING)
- [ ] **PERFORMANCE OPPORTUNITY**: Currently checking file existence during processing for each coverage line
- [ ] **Current Inefficiency**: `fileExists()` calls scattered throughout processing pipeline
- [ ] **Solution: Pre-validate File Map**:
  - [ ] **Pass -1: File Validation** - Before aggregation, validate all files in the files section exist
  - [ ] **Filter Coverage Early**: Remove all coverage lines for non-existent files immediately
  - [ ] **Cache Results**: Store validated file map for entire processing session
- [ ] **Expected Gains**: Eliminate thousands of redundant `fileExists()` calls

#### 3. Character Position Caching (ELIMINATE REDUNDANT CONVERSIONS)
- [ ] **PERFORMANCE OPPORTUNITY**: Same character positions converted to line numbers multiple times
- [ ] **Current Inefficiency**: Each unique file:startPos:endPos does binary search independently
- [ ] **Solution: Position-to-Line Cache**:
  - [ ] **Cache Key**: `"filePath:charPos"` → `lineNumber`
  - [ ] **Shared Across Processing**: Same character positions reused across different ranges
  - [ ] **Memory vs Speed Trade-off**: Small memory cost for massive CPU savings
- [ ] **Expected Gains**: Eliminate redundant binary searches, especially for common positions

#### 4. Line Mapping Pre-computation (FRONT-LOAD EXPENSIVE OPERATIONS)
- [ ] **PERFORMANCE OPPORTUNITY**: Building character-to-line mappings during processing
- [ ] **Current Inefficiency**: Line mappings built on-demand when first file accessed
- [ ] **Solution: Pre-compute All Mappings**:
  - [ ] **Pass -2: Build All Line Mappings** - Before any processing, build mappings for all files
  - [ ] **Parallel Pre-computation**: Use parallel processing for independent file mapping operations
  - [ ] **Fail Fast**: Identify problematic files before main processing begins
- [ ] **Expected Gains**: Smoother parallel processing, no blocking on first access per file

#### 5. AST Computation Caching (EXPENSIVE OPERATION OPTIMIZATION)
- [ ] **PERFORMANCE OPPORTUNITY**: AST parsing for executable line detection is expensive and repeated
- [ ] **Current Inefficiency**: AST parsing happens for every file in every .exl processing run
- [ ] **Solution: AST Result Caching**:
  - [ ] **Cache Key**: `"filePath:fileModifiedDate:fileSize"` → `executableLines`
  - [ ] **Persistent Cache**: Store AST results across multiple .exl processing sessions
  - [ ] **Invalidation Strategy**: Check file modification dates for cache invalidation
- [ ] **Expected Gains**: Eliminate expensive AST parsing for unchanged files

#### 6. Chunking Strategy Optimization (RIGHT-SIZE OPERATIONS)
- [ ] **PERFORMANCE OPPORTUNITY**: Fixed chunk size may not be optimal for all datasets
- [ ] **Current Inefficiency**: 50K chunk size might be too large or too small depending on content
- [ ] **Solution: Adaptive Chunking**:
  - [ ] **Content-Aware Sizing**: Base chunk size on unique positions after aggregation, not raw lines
  - [ ] **Memory-Aware Sizing**: Adjust chunk size based on available system memory
  - [ ] **File Distribution**: Ensure chunks contain multiple files for better parallel distribution
- [ ] **Expected Gains**: Optimal parallel processing distribution and memory usage

#### 7. Character Position Block Detection (ELIMINATE LINE CONVERSION)

> [!TIP]
> **PERFORMANCE OPPORTUNITY**: Overlapping block detection currently converts to lines first
> 
> **Current Inefficient Flow**:
> ```
> Character Positions → Line Numbers → Overlap Detection → Continue Processing
>      (expensive)        (expensive)         (logic)
> ```
> 
> **Optimized Flow**:
> ```
> Character Positions → Overlap Detection → Line Numbers (only remaining blocks)
>                          (simple math)        (fewer conversions)
> ```

- [ ] **Current Inefficiency**: Character positions → line numbers → overlap detection → back to processing
- [ ] **Solution: Character-Based Overlap Detection**:
  - [ ] **Direct Comparison**: Compare startPos/endPos directly without line conversion
  - [ ] **Simple Logic**: `block1.endPos < block2.startPos` (no overlap) vs expensive line math
  - [ ] **Filter Early**: Remove overlapping blocks before any character-to-line conversion
  - [ ] **Preserve Precision**: Character positions are more precise than line numbers anyway
- [ ] **Expected Gains**: Eliminate entire line conversion step for overlap detection

#### 8. String Operations Optimization (MICRO-OPTIMIZATIONS)
- [ ] **PERFORMANCE OPPORTUNITY**: Heavy string operations in hot paths
- [ ] **Current Inefficiencies**: 
  - [ ] `listToArray(line, chr(9), false, false)` called millions of times
  - [ ] String concatenation for logging in hot loops
  - [ ] `structKeyExists()` on the same keys repeatedly
- [ ] **Solutions**:
  - [ ] **Pre-split Optimization**: Split all coverage lines once, store as arrays
  - [ ] **Conditional Logging**: Skip string building when verbose=false
  - [ ] **Key Existence Caching**: Cache struct key existence results
- [ ] **Expected Gains**: Reduce string processing overhead in hot paths

### New Feature Requests

#### Sequential Execution Timeline View
- [ ] **Purpose**: Provide developers with chronological view of code execution flow
- [ ] **When**: Available when `separateFiles=false` (unified view mode)
- [ ] **Data Source**: Use original .exl fileCoverage section which maintains execution order
- [ ] **Display Features**:
  - [ ] Show each executed line in temporal sequence
  - [ ] Display file path + line number + source code
  - [ ] Show execution time for each line
  - [ ] Color-code by execution duration (heatmap)
  - [ ] Add jump-to-file links
  - [ ] Include request timeline with cumulative timing
- [ ] **Use Cases**:
  - [ ] Debug performance bottlenecks
  - [ ] Understand execution flow through complex applications
  - [ ] Identify hot paths in request processing
  - [ ] Analyze conditional logic execution patterns
- [ ] **Implementation Notes**:
  - [ ] Parse fileCoverage array sequentially (don't group by file)
  - [ ] Resolve character positions to file:line
  - [ ] Maintain original execution order
  - [ ] Generate separate HTML view or additional section

## Testing

### Unit Tests
- [ ] Test all global functions with various parameter combinations
- [ ] Test error conditions and exception handling
- [ ] Test filtering with allowList/blocklist
- [ ] Test different output formats and options

### Integration Tests
- [ ] Test complete workflow: logging → stopping → report generation
- [ ] Test with real .exl files from test suites
- [ ] Test performance with large datasets
- [ ] Test compatibility with VS Code Coverage Gutters

### Edge Cases
- [ ] Test with empty .exl files
- [ ] Test with malformed .exl data
- [ ] Test with missing files
- [ ] Test with permission issues
- [ ] Test concurrent access scenarios

## Documentation

### Function Documentation
- [ ] Document all parameters and return values
- [ ] Include usage examples for each function
- [ ] Document error conditions and exceptions
- [ ] Provide performance tuning guidelines

### User Guide
- [ ] Create getting started guide
- [ ] Document common use cases
- [ ] Provide troubleshooting section
- [ ] Include integration examples (CI/CD, IDE)

## Extension Packaging

### Extension Structure
- [ ] Set up proper extension directory structure
- [ ] Configure extension.xml manifest
- [ ] Include all required components and functions
- [ ] Set up proper Java/CFML integration

### Build Process
- [ ] Configure Maven build for .lex file generation
- [ ] Include all dependencies
- [ ] Set up proper versioning
- [ ] Create installation/deployment procedures

## Validation

### API Compliance
- [ ] Ensure all functions match API_DESIGN.md specifications
- [ ] Verify all return values match documented structures
- [ ] Test all documented examples work as specified
- [ ] Validate error handling matches documentation

### Quality Assurance
- [ ] Code review for all implementations
- [ ] Performance testing with various dataset sizes
- [ ] Memory leak testing
- [ ] Cross-platform testing (Windows, Linux, macOS)

---

## Implementation Priority

1. **High Priority** - Core EXL parsing and basic LCOV generation
2. **Medium Priority** - HTML and JSON report generation  
3. **Low Priority** - Performance optimizations and advanced features

## Notes

- Follow existing codebase patterns and conventions
- Use existing utility components where possible
- Ensure thread safety for parallel processing
- Consider future extensibility for custom report formats