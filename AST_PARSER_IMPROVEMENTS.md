# AST Parser Improvements for LCOV Extension

## Current Implementation Overview

### File Structure
- **AST Component**: `source/components/lucee/extension/lcov/ExecutableLineCounter.cfc`
- **Parser Component**: `source/components/lucee/extension/lcov/ExecutionLogParser.cfc`
- **Lucee AST Integration**: Uses `AstUtil.astFromPath()` from Lucee core

### Existing Functions

#### 1. AST-based Line Counting (`ExecutableLineCounter.cfc`)
- `countExecutableLinesFromAst(struct ast)` - Line 9
  - Attempts to extract line numbers from AST nodes
  - Falls back to source line parsing if AST doesn't contain sourceLines
  - Only looks for `start.line` properties in nodes
  - Returns minimum 1 for non-empty files

- `countExecutableLinesSimple(array sourceLines)` - Line 92
  - Simple line parser that counts non-empty, non-comment lines
  - Skips lines starting with `//`, `/*`, or `*`
  - More reliable than AST parsing for LCOV compliance

#### 2. Integration in Parser (`ExecutionLogParser.cfc`)
- `parseFiles()` - Line 260
  - Calls `astFromPath(path)` at line 311
  - Uses `ast.countExecutableLinesSimple(sourceLines)` for `linesFound` property (line 316)
  - Stores both AST and source lines but primarily uses line counting

### Current Limitations

1. **Underutilized AST Structure**
   - AST is generated but not fully leveraged
   - Only extracts `start.line` from nodes, missing many executable statements
   - Doesn't traverse the full AST tree to identify all executable lines

2. **Oversimplified Line Counting**
   - Current approach just skips empty lines and comments
   - Doesn't handle:
     - Multi-line statements
     - Closures and anonymous functions
     - Complex CFML constructs (tags, script blocks)
     - Conditional compilation or preprocessor directives

3. **Missing Line Classifications**
   - No distinction between:
     - Executable statements
     - Declaration lines
     - Control flow statements
     - Expression lines

## Improvement Goals

### Phase 1: Enhanced AST Traversal
- [ ] Implement comprehensive AST node visitor pattern
- [ ] Identify all executable node types in Lucee AST
- [ ] Map AST node types to executable line classifications
- [ ] Handle multi-line statements properly

### Phase 2: Accurate Line Detection
- [ ] Detect function declarations vs function calls
- [ ] Identify control flow statements (if, while, for, try/catch)
- [ ] Handle CFML-specific constructs (cfquery, cfloop, etc.)
- [ ] Process closures and lambda expressions

### Phase 3: Coverage Accuracy
- [ ] Improve branch detection for conditional statements
- [ ] Handle switch/case statements
- [ ] Track function entry/exit points
- [ ] Better handling of implicit returns

## Technical Approach

### AST Node Types to Handle
- Statement nodes (assignments, function calls)
- Control flow nodes (if/else, loops, try/catch)
- Declaration nodes (functions, variables)
- Expression nodes (that can have side effects)
- CFML tag nodes
- Script block nodes

### Implementation Strategy
1. Study the Lucee AST structure format
2. Create a recursive AST visitor
3. Build a map of executable lines with their types
4. Use this map for accurate coverage reporting

## Testing Requirements
- Unit tests for each node type detection
- Integration tests with real CFML files
- Comparison with existing coverage tools
- Edge case handling (empty files, syntax errors)

## Success Metrics
- More accurate `linesFound` count
- Better correlation between reported coverage and actual code execution
- Reduced false positives/negatives in coverage reporting
- Improved handling of complex CFML constructs

## Notes
- The Lucee AST is accessed via Java interop through `AstUtil.astFromPath()`
- Current implementation is in `D:\work\lucee7\loader\src\main\java\lucee\runtime\util\AstUtil.java`
- Uses BIF `lucee.runtime.functions.ast.AstFromPath` internally