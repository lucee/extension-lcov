# Lucee LCOV extension

- Requires Lucee 7 or newer
- Reads the output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java)
- Produces an LCOV file, json data files and html reports about line coverage
- LCOV.info files can be used with this VS Code extension that supports LCOV files produced https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters

## Building

Build the extension:
```bash
mvn package
```

## Code Quality Policies

- When a component has `accessors=true`, getters and setters are automatically generated for all properties. Always use these methods (e.g., `getSource()`, `setSource()`) instead of direct property access (e.g., `result.source`).

### Fail fast and explain why

- If a required property is missing or invalid, throw an error immediately.
- Avoid defensive coding. Let code fail fast and loudly on invalid input or unexpected state. Defensive checks often hide real problems and make technical debt harder to detect and fix.
- Never use the elvis operator (`?:`) to provide fallback values for required properties.

### Code Formatting

- Always use tabs for indentation. Never use spaces for indentation in any CFML, Java, or script files in this project, for `.yml` it's allowed, as that's the standard.
- Never use `val()`; it is a code smell that hides errors and should be avoided. Always handle type conversion explicitly and fail fast on invalid input.
- Never use `evaluate`. It is unsafe, can hide errors, and should be avoided in all code and tests. Always use explicit, safe alternatives for dynamic logic.
- Avoid wrapping code in try/catch blocks. Only use try/catch when you are adding useful context to the error. When you do, always use the `catch` attribute to include the original exception (e.g., `cause=e`) so the full stack trace and context are preserved.

### Exception Messages

When throwing exceptions, include context values wrapped in square brackets for clarity (e.g., "Source file [/path/to/file.cfc] does not exist" or "Execution log directory argument [executionLogDir] does not exist: [/actual/path]").

This makes it easy to identify the actual values causing issues.

### Missing Source Files

When parsing execution logs, if a referenced source file doesn't exist, throw a clear exception with the actual path: "Source file referenced in execution log does not exist: [path]".

Never silently skip or ignore missing source files as they are required to calculate lines of code.

### Directory Handling

- Input directories (e.g., arguments like `executionLogDir`) must exist - throw if missing with actual path in brackets
- Base output directories must exist - throw if missing with actual path in brackets
- Subdirectories within output directories (e.g., `/html`, `/json`) can be created as needed
- When using `expandPath()` on directories, always check they exist first to avoid Lucee path resolution issues

### The /develop Folder and Component Swapping Pattern

The `/develop` folder contains experimental or optimized versions of core components (such as `CoverageBlockProcessor`, `CoverageStats`, etc). To support seamless switching between the stable and develop implementations, the codebase uses a **factory pattern**:

- The `CoverageComponentFactory` component provides methods to obtain either the stable or develop version of a component.
- The factory supports both a global flag (`useDevelop`) and a per-call override (e.g., `getCoverageBlockProcessor(useDevelop=true)`).
- All core logic and tests must use the factory to instantiate these components, never directly with `new`.
- This ensures that tests can compare stable and develop implementations side-by-side, and that the main code can be switched globally or per-call for experiments or rollouts.

Example usage of factory with develop folder:

```cfml
var factory = new lucee.extension.lcov.CoverageComponentFactory();
var stableBlockProcessor = factory.getCoverageBlockProcessor(useDevelop=false);
var developBlockProcessor = factory.getCoverageBlockProcessor(useDevelop=true);
```

See [develop/README.md](source/components/lucee/extension/lcov/develop/README.md) for more details on the develop branch and its usage.

### Assets

- Assets are included inline, but read from normal `js` and `css` files.
- No inline styles, CSS goes in `source/assets/css/coverage-report.css`
- Accessibility is important, use strong color contrast for readability, in both dark and light modes.
- numeric data in table cells should be right aligned via css

### Testing

For all testing practices, guidelines, and workflows, see [TESTING-GUIDE.md](TESTING-GUIDE.md).

### CFML Tips

see [CFML-TIPS](CFML-TIPS.md)