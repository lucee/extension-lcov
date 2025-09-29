# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Lucee LCOV extension that:
- Targets Lucee 7
- Reads output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java)
- Produces LCOV files, JSON data files and HTML reports about line coverage
- Works with VS Code Coverage Gutters extension

## Building and Testing

Always use linux style paths (/d/work instead of d:\work) with Git Bash on Windows

Always show the errors a script throws, ask how to continue



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

## Testing

See [TESTING-GUIDE.md](TESTING-GUIDE.md) for comprehensive testing documentation including:
- Test organization and structure
- Writing tests with TestBox
- Using GenerateTestData component
- Test-Driven Development workflow
- Running tests with script-runner
- Best practices and guidelines

## CFML Tips

See [CFML-TIPS.md](CFML-TIPS.md) for CFML-specific guidance including:
- Variable scoping rules
- Quoting and escaping
- Performance optimization
- Common pitfalls and solutions

## Concurrent Execution
Script-runner supports concurrent execution:
```bash
ant -f "d:/work/script-runner/build.xml" \
    -DuniqueWorkingDir=true \
    -Dwebroot="d:/work/lucee-extensions/extension-lcov/tests" \
    -Dexecute="test1.cfm"
```