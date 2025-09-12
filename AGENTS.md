### Lucee LCOV extension

- targets Lucee 7
- reads the output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java) 
- produces an LCOV file, json data files and html reports about line coverage
- this vs code extension supports the LCOV files produced https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters

### Code Quality Policies

- When a component has `accessors=true`, getters and setters are automatically generated for all properties. Always use these methods (e.g., `getSource()`, `setSource()`) instead of direct property access (e.g., `result.source`).

- Fail fast and loudly if required properties are missing or invalid:
    - Never use defensive checks (e.g., `structKeyExists` with fallback/defaults) or default to 0 or any other value for missing stats.
    - Never use the elvis operator (`?:`) to provide fallback values for required properties.
    - If a required property is missing or invalid, throw an error immediately.

- Avoid defensive coding. Let code fail fast and loudly on invalid input or unexpected state. Defensive checks often hide real problems and make technical debt harder to detect and fix.

- Always use tabs for indentation. Never use spaces for indentation in any CFML, Java, or script files in this project, for .yml it's allowed.

- Never use `val()`; it is a code smell that hides errors and should be avoided. Always handle type conversion explicitly and fail fast on invalid input.


- Never use `evaluate`. It is unsafe, can hide errors, and should be avoided in all code and tests. Always use explicit, safe alternatives for dynamic logic.

- Avoid using too many try/catch blocks. Only use try/catch when you are adding useful context to the error. When you do, always use the `catch` attribute to include the original exception (e.g., `cause=e`) so the full stack trace and context are preserved.

- Accessibility is important—ensure sufficient color contrast for readability.


### The /develop Folder and Component Swapping Pattern

The `/develop` folder contains experimental or optimized versions of core components (such as `CoverageBlockProcessor`, `CoverageStats`, etc). To support seamless switching between the stable and develop implementations, the codebase uses a **factory pattern**:

- The `CoverageComponentFactory` component provides methods to obtain either the stable or develop version of a component.
- The factory supports both a global flag (`useDevelop`) and a per-call override (e.g., `getCoverageBlockProcessor(useDevelop=true)`).
- All core logic and tests must use the factory to instantiate these components, never directly with `new`.
- This ensures that tests can compare stable and develop implementations side-by-side, and that the main code can be switched globally or per-call for experiments or rollouts.

**Example usage:**

```cfml
var factory = new lucee.extension.lcov.CoverageComponentFactory();
var stableBlockProcessor = factory.getCoverageBlockProcessor(useDevelop=false);
var developBlockProcessor = factory.getCoverageBlockProcessor(useDevelop=true);
```

Refer to [develop/README.md](source\components\lucee\extension\lcov\develop\README.md) for more details on the develop branch and its usage.

### Tests

- tests go in the `/tests` folder
- use testbox for tests, prefer BDD style
- all tests should extend  org.lucee.cfml.test.LuceeTestCase
- all tests must include labels="lcov" on the component declaration, when running tests, always pass in the filter -DtestLabels="lcov"
- as a general approach to testing, leave any generated artifacts in place for review afterwards, simply clean the target folder them in the `beforeAll` steps next time the test is run
- tests can be run using [script-runner](https://github.com/lucee/script-runner/tree/main), read the d:\work\script-runner\README.md
- refer to https://docs.lucee.org/guides/working-with-source/build-from-source.html#build-performance-tips for how the lucee test runner works
- don't repeat logic in tests, create and re-use private methods
- use matchers https://apidocs.ortussolutions.com/testbox/3.2.0/testbox/system/Expectation.html READ this file, don't imagine it's contents from the url!
- when writing `expect()` statements, pass in the object, i.e. the matcher to the work, no `arraylen()`, or `stuctKeyExists()`, or `isNumeric()` in the argument for `expect()`

- **CFML function calls:** Never mix named and unnamed (positional) arguments in a single function call. All arguments must be either positional or all named, matching the function signature. Mixing them will cause a runtime error
- Never add defensive code to mask errors or inconsistencies. Always fail early and fail hard.
- Never use an elvis expression (`?:`) without explicit permission; it usually hides an underlying error. Always prefer explicit error handling and fail fast.
- Avoid try/catch unless you are adding useful info to the error; always rethrow, never swallow errors.
- If a test fails, let it error—Lucee exceptions are more meaningful than custom error handling.
- Do not cap, clamp, or auto-correct values in core logic or tests. All mismatches and invalid states should result in immediate failure.
- If you are catching an error to add useful info, use `throw` and include `e.stacktrace` instead of `e.message` and the `cause` attribute.
- Avoid long tests; split them into smaller tests if they get too large, but ask first
- When running tests and an error occurs, always show the error before actioning the error, propose changes.
- After running tests, always provide a summary of any errors or warnings produced.

- Admin password is stored in `request.SERVERADMINPASSWORD`, but only when using script-runner and the lucee bootstrap-tests.cfm runner
- Only check for the existence of public methods, as in the public API, not private methods.

### Running Tests

⚠️ **CRITICAL**: Never use a leading slash in the -Dexecute parameter. It can cause path conversion issues.


- When tests fail, always show the concise CFML stacktrace (with file paths and line numbers in your code). If both are present, prioritize showing the CFML stacktrace for clarity.

#### Using run-tests.bat
The simplest way to run tests is using the `tests\run-tests.bat` script:
```batch
# Run default test filter (if no parameter provided)
tests\run-tests.bat

# Run specific test by name
tests\run-tests.bat AstComparisonTest
```

#### Using ant directly with script-runner
When using ant directly, be aware of these important points:

1. **Execute parameter format**: Do NOT use a leading slash in the execute parameter as it can cause path conversion issues:
```bash
# ❌ WRONG - leading slash causes path conversion issues
ant -f "d:/work/script-runner/build.xml" -Dexecute="/test.cfm"

# ✅ CORRECT - no leading slash
ant -f "d:/work/script-runner/build.xml" -Dexecute="test.cfm"
```

2. **Full test command with TestBox**:
```bash
ant -f "d:/work/script-runner/build.xml" \
    -Dwebroot="d:/work/lucee7/test" \
    -Dexecute="bootstrap-tests.cfm" \
    -DextensionDir="d:/work/lucee-extensions/extension-lcov/target" \
    -DluceeVersionQuery="7/all/jar" \
    -DtestAdditional="d:/work/lucee-extensions/extension-lcov/tests" \
    -DtestLabels="lcov" \
    -DtestFilter="optionally a specific test name"
```

3. **Running standalone CFML scripts** (for quick testing):
```bash
ant -f "d:/work/script-runner/build.xml" \
    -Dwebroot="d:/work/lucee-extensions/extension-lcov/tests" \
    -Dexecute="your-test-script.cfm" \
    -DextensionDir="d:/work/lucee-extensions/extension-lcov/target" \
    -DluceeVersionQuery="7/all/jar"
```

#### Important Notes:
- Always use `systemOutput()` instead of `writeOutput()` in test scripts for console output
- The extension must be built first using `mvn package` before running tests
- Use forward slashes in paths even on Windows when using ant directly

#### Concurrent Execution:
Script-runner now supports concurrent execution using the `uniqueWorkingDir` parameter:
```bash
# Enable concurrent execution with auto-generated unique directories
ant -f "d:/work/script-runner/build.xml" \
    -DuniqueWorkingDir=true \
    -Dwebroot="d:/work/lucee-extensions/extension-lcov/tests" \
    -Dexecute="test1.cfm"

# Each instance gets its own directory like: temp-unique/lucee-7.0.0.374-20250909-112035-669
```

This allows running multiple tests in parallel without conflicts

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