# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Lucee LCOV extension that:
- Targets Lucee 7
- Reads output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java)
- Produces LCOV files, JSON data files and HTML reports about line coverage
- Works with VS Code Coverage Gutters extension

## Building and Testing

### Build Extension
```bash
mvn package
```

### Run Tests
Use the batch script for simplest execution:
```bash
tests\run-tests.bat                    # Run all tests
tests\run-tests.bat AstComparisonTest  # Run specific test
```

### Running Tests with Ant Directly
**⚠️ CRITICAL**: Never use a leading slash in the -Dexecute parameter.

Full TestBox command:
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

Standalone CFML scripts:
```bash
ant -f "d:/work/script-runner/build.xml" \
    -Dwebroot="d:/work/lucee-extensions/extension-lcov/tests" \
    -Dexecute="your-test-script.cfm" \
    -DextensionDir="d:/work/lucee-extensions/extension-lcov/target" \
    -DluceeVersionQuery="7/all/jar"
```

## Testing Guidelines

- Tests go in `/tests` folder
- Use TestBox framework
- All tests extend `org.lucee.cfml.test.LuceeTestCase`
- Always use label "lcov" and pass `-DtestLabels="lcov"`
- Use `systemOutput()` instead of `writeOutput()` for console output
- **Test Artifacts**: Leave artifacts in place for review. Use `GenerateTestData` component in `beforeAll()` with the test name - it handles directory creation and cleanup. Add comment "Leave test artifacts for inspection - no cleanup in afterAll" and omit `afterAll()` method.
- Use matchers from TestBox expectations
- Avoid try catch unless adding useful error info (then rethrow with cause)
- Split large tests into smaller ones
- Only test public API methods, not private methods
- Admin password stored in `request.SERVERADMINPASSWORD`
- **Variable Scoping**: In standalone CFML scripts (.cfm files), don't use `var` keyword outside functions - it causes "Unsupported Context for Local Scope" errors. Use unscoped variables instead: `myVar = "value"` not `var myVar = "value"`
- **Testing Tip**: In `expect()` assertions, use the actual result value as the message instead of custom text. This provides actionable feedback showing exactly what the test received when it fails: `expect(result.length()).toBeLT(100, result)` instead of `expect(result.length()).toBeLT(100, "Should have minimal content")`

## Concurrent Execution
Script-runner supports concurrent execution:
```bash
ant -f "d:/work/script-runner/build.xml" \
    -DuniqueWorkingDir=true \
    -Dwebroot="d:/work/lucee-extensions/extension-lcov/tests" \
    -Dexecute="test1.cfm"
```