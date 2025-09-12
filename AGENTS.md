### Lucee LCOV extension

- targets Lucee 7
- reads the output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java) 
- produces an LCOV file, json data files and html reports about line coverage
- this vs code extension supports the LCOV files produced https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters



### Code Quality Policies

- Always use tabs for indentation. Never use spaces for indentation in any CFML, Java, or script files in this project.

- Never use `val()`; it is a code smell that hides errors and should be avoided. Always handle type conversion explicitly and fail fast on invalid input.

### Tests

- tests go in the /tests folder
- use testbox for testings
- all tests should extend  org.lucee.cfml.test.LuceeTestCase
- all tests should use the label "lcov", when running tests, always pass in the filter -DtestLables="lcov"
- as a general approach to testing, always leave any generated artifacts in place for review afterwards, simply clean them in the beforeAll steps
- tests can be run using script-runner, read the d:\work\script-runner\README.md
- refer to https://docs.lucee.org/guides/working-with-source/build-from-source.html#build-performance-tips for how the lucee test runner works
- don't repeat logic in tests, use a private method
- use matchers https://apidocs.ortussolutions.com/testbox/3.2.0/testbox/system/Expectation.html READ this file, don't imagine it's contents from the url!
- when writing expect statements, pass in the object, le tthe matcher to the work, no arraylen(), or stuctKeyExists, or isNumeric in the argument for expect

- Never add defensive code to mask errors or inconsistencies. Always fail early and fail hard.
- Never use an elvis expression (?:) without explicit permission; it usually hides an underlying error. Always prefer explicit error handling and fail fast.
- Avoid try/catch unless you are adding useful info to the error; always rethrow, never swallow errors.
- If a test fails, let it error—Lucee exceptions are more meaningful than custom error handling.
- Do not cap, clamp, or auto-correct values in core logic or tests. All mismatches and invalid states should result in immediate failure.
- If you are catching an error to add useful info, use `throw` and include `e.stacktrace` instead of `e.message` and the cause attribute.
- Avoid long tests; split them into smaller tests if they get too large.
- When running tests and an error occurs, always show the error.
- After running tests, always provide a summary of any errors or warnings produced.
- Accessibility is important—ensure sufficient color contrast for readability.
- Admin password is stored in `request.SERVERADMINPASSWORD`.
- Only check for the existence of public methods, as in the public API, not private methods.

### Running Tests

⚠️ **CRITICAL**: Never use a leading slash in the -Dexecute parameter. It can cause path conversion issues.

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
