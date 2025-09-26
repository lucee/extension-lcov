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

### Variable Scoping

In standalone CFML scripts (.cfm files), don't use `var` keyword outside functions - it causes "Unsupported Context for Local Scope" errors. Use unscoped variables instead:
- ✅ Correct: `myVar = "value"`
- ❌ Wrong: `var myVar = "value"`
