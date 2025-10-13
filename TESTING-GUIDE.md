# TESTING-GUIDE.md

This guide covers all testing practices, tools, and workflows for the Lucee LCOV extension project.

## Test Organization

- Tests go in the `/tests` folder
- Use TestBox framework, only use BDD style
- All tests must extend `org.lucee.cfml.test.LuceeTestCase`
- All tests must include `labels="lcov"` on the component declaration
- When running tests, always pass the filter `-DtestLabels="lcov"`

## Test Artifacts

Leave artifacts in place for review. Use `GenerateTestData` component in `beforeAll()` with the test name - it handles directory creation and cleanup. Omit the `afterAll()` method.

## Writing Tests

### General Guidelines

- Tests can be run using [script-runner](https://github.com/lucee/script-runner/)
- Refer to https://docs.lucee.org/guides/working-with-source/build-from-source.html#build-performance-tips for how the Lucee test runner works
- Don't repeat logic in tests, create and re-use private methods
- Use matchers from https://apidocs.ortussolutions.com/testbox/3.2.0/testbox/system/Expectation.html (READ this file, don't imagine its contents from the URL!)
- When writing `expect()` statements, pass in the object, i.e. let the matcher do the work, no `arrayLen()`, `structKeyExists()`, or `isNumeric()` in the argument for `expect()`
- Only check for the existence of public methods (public API), not private methods
- Admin password is stored in `request.SERVERADMINPASSWORD`, but only when using script-runner and the lucee bootstrap-tests.cfm runner
- private helper methods go at the end of the files


### Logging

Debug logging is great for figuring out problems, make sure the logging has enough context, but isn't verbose. prefix the log message with the method name, `"mergeFiles: file [/path/to/file] doesn't exist!`

Always add a `variables.debug` = boolean flag to `beforeAll()`. Wrap all `systemOutput()` in a `if (variables.debug)` block, that way we can easily enable debugging when needed, but avoid verbose test output.


### Testing Tips

- In `expect()` assertions, use the actual result value as the message instead of custom text. This provides actionable feedback showing exactly what the test received when it fails:
  - ✅ Good: `expect(result.length()).toBeLT(100, result)`
  - ❌ Bad: `expect(result.length()).toBeLT(100, "Should have minimal content")`

## Test Quality Standards

- Never add defensive code to mask errors or inconsistencies. Always fail early and fail hard.
- Never use an elvis expression (`?:`) without explicit permission; it usually hides an underlying error. Always prefer explicit error handling and fail fast.
- If you are catching an error to add useful info, use `throw` and include `e.stacktrace` instead of `e.message` and the `cause` attribute.
- If a test fails, let it error—Lucee exceptions are more meaningful than custom error handling.
- Do not cap, clamp, or auto-correct values in core logic or tests. All mismatches and invalid states should result in immediate failure.
- Avoid long tests (>500 lines); split them into smaller tests if they get too large, but ask first.
- When running tests and an error occurs, always show the developer the error before acting on the error, propose changes. Always provide a summary of any errors or warnings produced.
- never comment out a test, use xit or xdescribe instead

## GenerateTestData Component

Always use the `GenerateTestData` component for test setup unless there's a specific reason not to. This component:
- Handles test directory creation and management
- Executes test artifacts to generate real execution logs
- Provides consistent test data generation across all tests
- Manages cleanup automatically

Example usage:
```cfscript
function beforeAll() {
    variables.testDataGenerator = new "../GenerateTestData"(testName="MyTest");
    variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(
        adminPassword: request.SERVERADMINPASSWORD,
        fileFilter: "specific-file.cfm"  // Optional: filter which files to execute
    );
    variables.testDir = variables.testData.coverageDir;
}
```

## Test-Driven Development Workflow

**CRITICAL PRINCIPLE**: Always fix the test to catch the problem BEFORE addressing the actual bug.

### Workflow Steps

1. **Identify the Bug**: When a bug is reported, first understand exactly what the incorrect behavior is
2. **Fix the Test First**: Update or create tests so they FAIL and properly detect the bug
3. **Verify Test Fails**: Run the test to confirm it fails for the right reasons
4. **Fix the Bug**: Only after the test is failing, fix the actual implementation
5. **Verify Test Passes**: Run the test again to confirm the fix works

### Why This Matters

- Ensures tests actually catch the bug (prevents false positives)
- Validates that your understanding of the problem is correct
- Creates proper regression tests for the future
- Follows true TDD principles where failing tests drive development
- Prevents the trap of "fixing" code without verifying the test would have caught it

### Example

```
// ❌ WRONG: Fix code first, then update test
1. Fix HtmlIndex.cfc total time formatting
2. Update test to validate the fix

// ✅ CORRECT: Fix test first, then code
1. Update ValidateHtmlReports.cfc to expect proper auto-formatting
2. Run test - confirm it FAILS detecting the bug
3. Fix HtmlIndex.cfc total time formatting
4. Run test - confirm it now PASSES
```

## Running Tests

⚠️ **CRITICAL**: Never use a leading slash in the -Dexecute parameter. It can cause path conversion issues.

When tests fail, always show the concise CFML stacktrace (with file paths and line numbers in your code). If both are present, prioritize showing the CFML stacktrace for clarity.

### Using run-tests.bat

The simplest way to run tests is using the `tests\run-tests.bat` script:

```batch
REM Run default test filter (if no parameter provided)
tests\run-tests.bat

REM Run specific test by name
tests\run-tests.bat AstComparisonTest
```

### Using ant directly with script-runner

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

### Important Notes

- Always use `systemOutput()` instead of `writeOutput()` to write to the console. The second boolean argument for `systemOutput()` adds a new line - use it.
- The extension must be built first using `mvn package` before running tests
- Use forward slashes in paths even on Windows when using ant directly

### Concurrent Execution

Script-runner supports concurrent execution using the `uniqueWorkingDir` parameter:

```bash
# Enable concurrent execution with auto-generated unique directories
ant -f "d:/work/script-runner/build.xml" \
    -DuniqueWorkingDir=true \
    -Dwebroot="d:/work/lucee-extensions/extension-lcov/tests" \
    -Dexecute="test1.cfm"

# Each instance gets its own directory like: temp-unique/lucee-7.0.0.374-20250909-112035-669
```

This allows running multiple tests in parallel without conflicts.
