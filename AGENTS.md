### Lucee LCOV extension

- targets Lucee 7
- reads the output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java) 
- produces an LCOV file, json data files and html reports about line coverage
- this vs code extension supports the LCOV files produced https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters

### Tests

- tests go in the /tests folder
- use testbox for testings
- all tests should extend  org.lucee.cfml.test.LuceeTestCase
- all tests should use the label "lcov"
- as a general approach to testing, always leave any generated artifacts in place for review afterwards, simply clean them in the beforeAll steps
- tests can be run using script-runner, read the d:\work\script-runner\README.md
- refer to https://docs.lucee.org/guides/working-with-source/build-from-source.html#build-performance-tips for how the lucee test runner works
- don't repeat logic in tests, use a private method
- use matchers https://testbox.ortusbooks.com/digging-deeper/expectations/matchers
- avoid try catch, if a test fails, let error, the lucee exception is more meaningful
- if you are catching an error to add useful info the the error, throw don't systemOutput and use e.stacktrace instead of e.message and the cause attribute
- avoid long tests, split them into smaller tests if they get too large
- when running tests and an error occurs, always show me the error
- after running tests, always provide a summary of any errors or warnings produced
- accessibility is important - ensure sufficient color contrast for readability
- admin password is stored in `request.SERVERADMINPASSWORD`
- only check for the existance of public methods, as in the public API, not private methods

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
    -DtestFilter="YourTestName"
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
