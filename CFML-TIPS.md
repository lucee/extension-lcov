### CFML serializeJSON usage

> **Note:** The `compact` argument for `serializeJSON` is NOT the second argument. Always use named arguments for clarity and correctness. For pretty-printed JSON, use:

```cfml
// CORRECT: Use all named arguments (do not mix positional and named)
var json = serializeJSON(var=data, compact=false); // pretty print
```

> **Important:** You cannot mix named and unnamed arguments in a single function call. All arguments must be either positional or all named, matching the function signature. Mixing them will cause a runtime error.

Do **not** use positional arguments for `compact`:

```cfml
// INCORRECT: This does NOT control pretty print
var json = serializeJSON(data, true);
```

### CFML Specifics

- **Quoting**: In CFML, escape quotes using double quotes ("") not backslashes (\"). Better to alternate between single and double quotes to avoid escaping.
- **Function calls**: Never mix named and unnamed (positional) arguments in a single function call. All arguments must be either positional or all named, matching the function signature. Mixing them will cause a runtime error.

### Performance

**Function scoping:** Always use `localmode="true"` (or `localmode=true`) for functions - it's much faster:

- ✅ Best: `public function myFunc() localmode="true" { ... }`
- ✅ Best: `public function myFunc() localmode=true { ... }`
- ⚠️ Slower: `public function myFunc() { ... }` (without localmode)

Local mode eliminates expensive scope lookups and makes variable access much faster.

**Loop constructs:** Prefer `cfloop` over `for` loops - they are the most efficient in CFML:

- ✅ Best: `cfloop(collection=myStruct, item="local.key") { ... }`
- ✅ Best: `cfloop(array=myArray, item="local.item") { ... }`
- ⚠️ Slower: `for (var key in myStruct) { ... }`

The `cfloop` tag/function syntax is optimized at the engine level and performs better than for-in loops.

### Variable Scoping

In standalone CFML scripts (.cfm files), don't use `var` keyword outside functions - it causes "Unsupported Context for Local Scope" errors. Use unscoped variables instead:
- ✅ Correct: `myVar = "value"`
- ❌ Wrong: `var myVar = "value"`

### Special Characters in Strings

**TAB characters:** The escape sequence `\t` does NOT work in CFML strings. Use an actual TAB character in string templates for best performance:

- ✅ Best: `var key = "0<TAB>#startPos#<TAB>#endPos#"` (type actual TAB character, not the word TAB)
- ✅ Works: `var key = "0" & chr(9) & startPos & chr(9) & endPos`
- ❌ Wrong: `var key = "0\t#startPos#\t#endPos#"` (creates literal backslash-t, not TAB)

Using an actual TAB character in the string template is fastest - no function calls needed. Just press the TAB key between the quotes in your editor.

### CFML Tags in Test Strings

When writing tests that need to output CFML tags as strings (e.g., writing test files with `<cfscript>` content), split the tags to prevent the parser from interpreting them:

```cfml
// Split tags to avoid parser interpretation
fileWrite(testFile, "<" & "cf" & "script>test code<" & "/cf" & "script>");

// This prevents the parser from executing the tags within the string
```

This is particularly important in test files where you're generating CFML code as test data.

