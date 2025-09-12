# EXL (Execution Log) File Format Documentation

## Current EXL File Structure

The EXL file is produced by Lucee's execution logging and has three sections separated by empty lines:

```
[METADATA SECTION]
<empty line>
[FILES SECTION]
<empty line>
[COVERAGE DATA SECTION]
```

### Section 1: Metadata
- Contains execution metadata as key:value pairs
- Parsed by `parseMetadata()` in `CoverageBlockProcessor.cfc`

### Section 2: File Mappings
- Format: `fileIndex:absolutePath`
- Example: `1:D:\work\project\file.cfc`
- Maps numeric indices to actual file paths

### Section 3: Coverage Data
- Tab-delimited format with 4 columns:
  1. File index (references Files section)
  2. Start character position
  3. End character position  
  4. Execution time (microseconds)
- Example: `1	245	367	1500`

## Current Limitations

### 1. Character Position Granularity
- **Issue**: Coverage is tracked by character positions, not line numbers
- **Impact**: Requires conversion from character position to line number
- **Current Solution**: `getLineFromCharacterPosition()` uses binary search on cached line mappings
- **Problem**: Character positions may not align perfectly with statement boundaries

### 2. Execution Block Granularity
- **Issue**: EXL logs execution blocks, not individual lines
- **Impact**: A single block may span multiple lines, making line-level coverage less precise
- **Example**: An if-statement block covers lines 10-15, but only line 10 is the actual condition
- **Current Workaround**: Mark all lines in the block as executed

### 3. Instrumentation Overhead
- **Issue**: Some entries represent Lucee's internal instrumentation overhead
- **Impact**: Whole-file coverage entries (line 1 to EOF) that don't represent actual code
- **Current Detection**: Check if `startLine <= 1 && endLine >= fileTotalLines`
- **Current Handling**: Log warning but still process (commented out skip)

### 4. Missing Statement Types
- **Issue**: EXL doesn't distinguish between different types of statements
- **Impact**: Can't differentiate between:
  - Simple statements vs control flow
  - Function declarations vs function calls
  - Variable declarations vs assignments
- **Future Improvement**: Need statement type indicators in EXL format

### 5. Branch Coverage
- **Issue**: EXL only tracks if a block was executed, not which branch was taken
- **Impact**: Can't determine if both branches of an if/else were tested
- **Example**: `if (condition)` block executed doesn't tell us if the else branch was covered
- **Future Need**: Branch execution tracking in EXL format

### 6. Loop Iteration Tracking
- **Issue**: Loops show as single execution blocks
- **Impact**: Can't determine:
  - If loop body was entered
  - How many iterations occurred
  - If loop condition was fully tested
- **Current State**: Loop treated as single coverage block

### 7. Function Entry/Exit
- **Issue**: Function execution tracked as block, not entry/exit points
- **Impact**: Can't track:
  - Function call count
  - Early returns
  - Exception paths
- **Future Need**: Function-level execution markers

## Workarounds Implemented

### 1. Line Mapping Cache
- Build character-to-line mapping once per file
- Cache for performance: `variables.lineMappingsCache`
- Binary search for efficient lookup

### 2. Parallel Processing
- Process coverage data in chunks for large files
- Default chunk size: 50,000 lines
- Uses `arrayEach()` with parallel=true

### 3. File Filtering
- Allow/block lists to exclude files from processing
- Skip non-existent files
- Cache file existence checks

### 4. Coverage Aggregation
- Combine overlapping execution blocks
- Track execution count per line
- Calculate total execution time per line

## Future Core Improvements (Lucee)

As a Lucee core developer, consider these enhancements to the EXL format:

### Version 2 EXL Format Proposal
```
[METADATA]
version:2
timestamp:...

[FILES]
1:path:checksum:linecount

[STATEMENTS]
1:type:startLine:startCol:endLine:endCol

[COVERAGE]
statementId:executionCount:totalTime:branchInfo
```

### Improvements Needed
1. **Line-based tracking** instead of character positions
2. **Statement type indicators** (function, loop, conditional, etc.)
3. **Branch coverage data** (which paths taken)
4. **Loop iteration counts**
5. **Function call tracking**
6. **Exception path tracking**
7. **Metadata about instrumentation overhead**

## Current Acceptance Strategy

For now, we accept these limitations and work around them:

1. Use AST parsing to supplement EXL data
2. Apply heuristics to detect instrumentation overhead
3. Aggregate block-level coverage to line-level
4. Document coverage accuracy limitations
5. Focus on statement coverage, not branch coverage

## Notes for Future Development

- Consider backward compatibility when enhancing EXL format
- Maintain performance - execution logging overhead must be minimal
- Consider optional verbosity levels for different coverage needs
- Coordinate with Lucee test framework development