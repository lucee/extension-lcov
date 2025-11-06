# Test Artifacts

This folder contains CFML test files used to generate code coverage data for testing the LCOV extension.

DO NOT ADD NEW FILES TO THE ROOT, use a subfolder

## Output Methods

### Why systemOutput() vs writeOutput()

When running CFML scripts in headless mode (using script-runner without a web server):
- `systemOutput()` writes directly to the console (stdout) - visible in terminal/command line
- `writeOutput()` writes to the HTTP response buffer - not visible in headless mode

### Current Approach: Using echo()

These test artifacts use `echo()` instead of `systemOutput()` because:
1. **Test Output Clarity**: `systemOutput()` would spam the test runner output with artifact execution messages
2. **Coverage Testing Focus**: We're testing code coverage tracking, not the output itself
3. **Silent Execution**: `echo()` allows the code to execute (generating coverage data) without producing console output

The artifacts include various code patterns to test coverage tracking:
- Simple sequential execution (`coverage-simple-sequential.cfm`)
- Conditional branches (`conditional.cfm`)
- Loop structures (`loops.cfm`)
- Function definitions and calls (`functions-example.cfm`)
- Exception handling (`exception.cfm`)
- Component usage (`kitchen-sink-example.cfm`)

## Components

The `.cfc` files in this folder are test components used by the artifacts to verify that component method coverage is properly tracked.