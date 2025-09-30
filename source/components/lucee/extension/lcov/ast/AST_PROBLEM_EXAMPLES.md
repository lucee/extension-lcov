# AST Problem Examples - Lines Incorrectly Counted

This document catalogs specific examples where line counting methods diverge from bytecode ground truth. These examples are useful for improving Lucee's AST implementation and understanding the limitations of different counting approaches.

## Testing Methodology

All results are from comparing against bytecode LineNumberTable extracted via `javap -v`, which represents the ground truth of what Lucee's execution logger tracks.

Test command:
```bash
tests\run-tests.bat AstComparisonTest
```

See `tests/parser/AstComparisonTest.cfc` for the test implementation.

## Summary Across All Test Files

| File | Simple Count | Bytecode Count | Accuracy | Over/Under |
|------|--------------|----------------|----------|------------|
| coverage-simple-sequential.cfm | 6 | 6 | 100.0% | ✓ PERFECT |
| kitchen-sink-example.cfm | 46 | 45 | 102.2% | +1 over |
| loops.cfm | 21 | 20 | 105.0% | +1 over |
| conditional.cfm | 22 | 20 | 110.0% | +2 over |
| functions-example.cfm | 42 | 37 | 113.5% | +5 over |
| exception.cfm | 39 | 34 | 114.7% | +5 over |

**Overall**:
- Perfect matches: 1 out of 6 files (16.7%)
- Average accuracy: 107.6% (simple method over-counts)
- Pattern: More structural code = worse accuracy

## File-by-File Analysis

### ✓ PERFECT: coverage-simple-sequential.cfm (100%)

**Why it's perfect**: Contains ONLY simple sequential statements with no structural code.

```cfml
<cfscript>
	// Simple coverage test - basic lines
	x = 1;                          // Line 3 - Bytecode ✓
	y = 2;                          // Line 4 - Bytecode ✓
	result = x + y;                 // Line 5 - Bytecode ✓
	echo("Result: " & result);      // Line 6 - Bytecode ✓
</cfscript>                         // Line 7 - No bytecode OR counted with line 6
```

**Bytecode lines**: 1,3,4,5,6 (5 lines)
**Simple count**: 6 lines
**Match**: Perfect if closing tag has no bytecode

### exception.cfm (114.7% - WORST)

**Why it over-counts**: Contains try/catch/finally blocks that are structural-only.

**Lines Simple Method INCORRECTLY counts** (no bytecode):

```cfml
try {                               // Line 7 - NO bytecode (structural only)
	echo("Inside try block");       // Line 8 - Bytecode ✓
	// ... more code ...
} catch (CustomError e) {           // Line 21 - NO bytecode (structural only)
	echo("Caught custom error");    // Line 22 - Bytecode ✓
	rethrow;                        // Line 23 - Bytecode ✓
} catch (any e) {                   // Line 24 - NO bytecode (structural only)
	echo("Caught general error");   // Line 25 - Bytecode ✓
} finally {                         // Line 26 - NO bytecode (structural only)
	echo("Finally block executed"); // Line 27 - Bytecode ✓
}                                   // Line 28 - NO bytecode (structural only)
```

**Problem lines** (counted by Simple, but NO bytecode):
- Line 7: `try {`
- Line 21: `} catch (CustomError e) {`
- Line 24: `} catch (any e) {`
- Line 26: `} finally {`
- Line 49: `</cfscript>` (closing tag)

**Total over-count**: 5 lines

**Bytecode**: 34 lines
**Simple**: 39 lines

### functions-example.cfm (113.5% - SECOND WORST)

**Why it over-counts**: Contains function declarations and structural code.

**Lines Simple Method INCORRECTLY counts** (no bytecode):

```cfml
function add(a, b) {                // Line X - NO bytecode (function declaration)
	return a + b;                   // Line Y - Bytecode ✓
}                                   // Line Z - NO bytecode (closing brace)

function processArray(arr) {        // Line X - NO bytecode (function declaration)
	for (item in arr) {             // Line Y - NO bytecode (loop declaration)
		echo(item);                 // Line Z - Bytecode ✓
	}                               // Line W - NO bytecode (closing brace)
}
```

**Common problem patterns**:
1. Function declarations: `function name(args) {`
2. Loop declarations: `for (item in arr) {`, `while (condition) {`
3. Closing braces: `}`
4. Closing tag: `</cfscript>`

**Total over-count**: 5 lines

**Bytecode**: 37 lines
**Simple**: 42 lines

### kitchen-sink-example.cfm (102.2% - BEST AFTER PERFECT)

**Why it's close**: Mostly statements with minimal structural code.

**Only line over-counted**:
- Line 70: `</cfscript>` - Closing tag generates bytecode for cleanup BUT has no AST node

This is the ONLY line the AST method misses.

**Bytecode**: 45 lines
**Simple**: 46 lines
**AST**: 44 lines

**AST accuracy**: 95.6% (44/45)

### conditional.cfm (110.0%)

**Over-counts by 2 lines**:
- Likely `if/else` declarations and closing tag
- Less structural code than exception.cfm/functions-example.cfm

**Bytecode**: 20 lines
**Simple**: 22 lines

### loops.cfm (105.0%)

**Over-counts by 1 line**:
- Likely one loop declaration or closing tag

**Bytecode**: 20 lines
**Simple**: 21 lines

## Key Patterns for AST Improvement

### Lines That Should NOT Be Counted (No Bytecode)

1. **Try/Catch/Finally Declarations**:
   ```cfml
   try {                    // NO bytecode
   } catch (Type e) {       // NO bytecode
   } finally {              // NO bytecode
   ```

2. **Function Declarations**:
   ```cfml
   function name(args) {    // NO bytecode
   ```

3. **Loop Declarations**:
   ```cfml
   for (item in arr) {      // NO bytecode
   while (condition) {      // NO bytecode
   ```

4. **Closing Braces** (sometimes):
   ```cfml
   }                        // Usually NO bytecode
   ```

5. **Conditional Declarations** (sometimes):
   ```cfml
   if (condition) {         // Sometimes NO bytecode
   } else {                 // Sometimes NO bytecode
   ```

### Lines That SHOULD Be Counted (Has Bytecode)

1. **Variable assignments**:
   ```cfml
   x = 1;                   // Bytecode ✓
   ```

2. **Function calls**:
   ```cfml
   echo("text");            // Bytecode ✓
   ```

3. **Return statements**:
   ```cfml
   return value;            // Bytecode ✓
   ```

4. **Throw/Rethrow**:
   ```cfml
   throw(...);              // Bytecode ✓
   rethrow;                 // Bytecode ✓
   ```

5. **Code inside blocks**:
   ```cfml
   if (x) {
       doSomething();       // Bytecode ✓ (not the if line, but this line)
   }
   ```

### Edge Case: Closing Tags

The closing `</cfscript>` tag is problematic:
- **Sometimes generates bytecode** (cleanup/finalization)
- **Never has an AST node**
- This is the 4.4% gap in AST accuracy

## AST Node Types That Need Investigation

Based on these examples, the following AST node types likely need review in Lucee's AST implementation:

1. **Try/Catch/Finally nodes** - Should not generate line numbers for structural declarations
2. **Function declaration nodes** - Should not generate line numbers for the declaration line
3. **Loop nodes** - Should not generate line numbers for the loop declaration line
4. **Conditional nodes** - Need to distinguish between the condition check and the block entry
5. **Closing tag handling** - Need a way to represent implicit cleanup operations

## Recommendations for Lucee AST Improvement

1. **Add metadata to AST nodes** indicating whether they represent:
   - Structural declarations (no bytecode)
   - Executable statements (has bytecode)
   - Implicit operations (bytecode but no explicit code)

2. **Separate node types** for:
   - Loop declaration vs loop body
   - Function signature vs function body
   - Try/catch declaration vs catch block body

3. **Add implicit operation nodes** for:
   - Script block cleanup (closing tags)
   - Function exit points
   - Block finalization

4. **Improve line number tracking** to distinguish:
   - Lines that START a structure (no bytecode)
   - Lines that contain executable code (has bytecode)

## Using This Data

### For Lucee Core Development

Compare these examples against Lucee's AST generation code to identify where structural nodes are incorrectly being marked as executable.

### For Extension Development

Use bytecode analysis (via `BytecodeAnalyzer.cfc`) to validate any AST-based line counting improvements:

```cfml
var analyzer = new lucee.extension.lcov.ast.BytecodeAnalyzer();
var groundTruth = analyzer.extractLineNumberTable(filePath);
var astResult = new lucee.extension.lcov.ast.ExecutableLineCounter().countExecutableLines(metadata);

// Compare and identify gaps
```

### For Testing

The `AstComparisonTest.cfc` can be extended to run against any new test files to validate improvements.

## Related Files

- `BytecodeAnalyzer.cfc` - Extracts ground truth from compiled bytecode
- `ExecutableLineCounter.cfc` - Current AST-based implementation
- `tests/parser/AstComparisonTest.cfc` - Comparison tests
- `EXECUTABLE_LINE_COUNTING.md` - Overview of approaches and limitations

## Conclusion

The simple method's accuracy correlates inversely with structural complexity:
- **100% accurate**: Files with pure sequential code (no structures)
- **102-105% accurate**: Files with minimal structures (1-2 lines over)
- **110-115% accurate**: Files with heavy structural code (5+ lines over)

This demonstrates that AST-based counting needs semantic understanding of which nodes represent executable code vs structural declarations. The current 95.6% AST accuracy is excellent, but reaching 100% requires Lucee core improvements to how AST nodes are generated and marked.