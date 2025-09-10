# LCOV Extension External API Design

## Overview

The Lucee LCOV Extension provides code coverage analysis by reading execution logs from Lucee 7's ResourceExecutionLog and generating LCOV files, JSON reports, and HTML reports.

## Extension Functions

As a Lucee extension, all functionality is exposed through global `lcov*()` functions that accept main arguments, plus optional structs for configuration.

As cfml supports named arguments, all examples should use them

### 1. Coverage Data Collection

#### `lcovStartLogging(adminPassword, executionLogDir, options)` - Enable Execution Logging

```cfml
// Simple usage - only admin password required, returns auto-generated temp directory
logDirectory = lcovStartLogging(adminPassword=AdminPassword);

// Specify custom directory using named arguments
logDirectory = lcovStartLogging(
    adminPassword=AdminPassword,
    executionLogDir="/custom/log/path/"
);

// Custom directory with additional options
logDirectory = lcovStartLogging(
    adminPassword=AdminPassword,
    executionLogDir="/custom/log/path/",
    options={
        unit: "nano",                     // Time unit: nano, micro, milli
        minTime: 0,                      // Minimum execution time to log (0 = all)
        maxLogs: 0,                      // Maximum log entries (0 = unlimited)
        className: "ResourceExecutionLog"    // Log implementation className
    }
);

// Auto temp directory with options using named arguments
logDirectory = lcovStartLogging(
    adminPassword=AdminPassword,
    executionLogDir="",
    options={
        unit: "milli",
        minTime: 1
    }
);
```

**Returns**: String path to the log directory being used

**Parameters**:

- `adminPassword` (string, required): Lucee server admin password - required for execution log management
- `executionLogDir` (string, optional): Log directory path. If empty/null, auto-generates unique temp directory
- `options` (struct, optional): Additional configuration options

**Default Behavior**:

- If no `executionLogDir` or empty string, Lucee uses `{lucee-config}/execution-log/` directory
- File naming: `{pageContext.getId()}-{createUUID()}.exl`
- Automatic directory creation if it doesn't exist
- Each request gets a unique .exl file based on PageContext ID + UUID

**Important Notes**:

- **MODIFIES SERVER CONFIG**: This function modifies Lucee's server configuration (.CFConfig.json)
- **PERSISTENT CHANGE**: Execution logging remains enabled until explicitly disabled
- **SERVER RESTART**: Configuration changes persist across server restarts
- **PRODUCTION WARNING**: Only use in development/testing - impacts server performance

#### `lcovStopLogging(adminPassword, className)` - Disable Execution Logging

```cfml
// Simple usage - stops default ResourceExecutionLog
lcovStopLogging(adminPassword=AdminPassword);

// Stop specific log class using named argument
lcovStopLogging(
    adminPassword=AdminPassword,
    className="ResourceExecutionLog"
);

// Stop custom log implementation
lcovStopLogging(
    adminPassword=AdminPassword,
    className="ConsoleExecutionLog"
);
```

**Parameters**:

- `adminPassword` (string, required): Lucee server admin password - required for execution log management
- `className` (string, optional): Log implementation class to disable. Defaults to "ResourceExecutionLog"

**Important Notes**:

- **MODIFIES SERVER CONFIG**: This function modifies Lucee's server configuration (.CFConfig.json)
- **PERSISTENT CHANGE**: Removes execution logging configuration from server settings
- **ALWAYS CALL**: Essential to disable logging after coverage collection is complete
- **CLEANUP**: Failure to call this function leaves logging enabled permanently

## Common Options

All parsing and generation functions accept an `options` struct with the following common parameters:

### Processing Options

- `verbose` (boolean, default: false): Enable console output during processing
- `chunkSize` (numeric, default: 50000): Number of coverage lines to process per chunk for parallel processing

### Filtering Options

**Why Filtering Matters:**

When running code coverage on CFML applications, execution logs capture everything - your application code, test frameworks (TestBox, MXUnit), third-party libraries, Lucee system files, and vendor dependencies.

Without filtering, your coverage reports become polluted with irrelevant files that:

- Inflate coverage percentages artificially
- Hide gaps in your actual application code
- Slow down processing and bloat reports
- Make it harder to focus on the code you actually maintain

Use filtering to focus coverage metrics on the code that matters to your project.

**Filter Options:**

- `allowList` (array, optional): File patterns to include in processing. If specified, only files matching these patterns will be processed
- `blocklist` (array, optional): File patterns to exclude from processing. Files matching these patterns will be ignored

**Common Blocklist Patterns:**

```cfml
blocklist: [
    expandPath("/testbox"),           // TestBox framework files
    expandPath("/tests"),             // TestBox test suites
    expandPath("/coldbox"),           // ColdBox framework files
    expandPath("/vendor"),            // Third-party dependencies
    expandPath("{lucee-config}"),     // Lucee server files / base component /etc
    expandPath("/lib"),               // Library directories
    expandPath("/framework")          // Framework directories
]
```

### Display Options

- `displayUnit` (string, default varies): Time unit for display in reports
  - `"nano"` or `"ns"`: Nanoseconds
  - `"micro"` or `"μs"`: Microseconds
  - `"milli"` or `"ms"`: Milliseconds

### Path Options

- `useRelativePath` (boolean, default: false): **LCOV generation only** - Use relative paths instead of absolute paths in LCOV output. When `true`, converts absolute file paths to relative paths using Lucee's `contractPath()` function. This makes LCOV files more portable and cleaner for tools like VS Code Coverage Gutters.

### Report Generation Options

**File Organization Options:**

- `mergeFiles` (boolean, default: true): **LCOV generation only** - Combine coverage data from multiple .exl files into a single unified LCOV report. When `true`, aggregates line hit counts across test runs. When `false`, treats each .exl file separately.

- `separateFiles` (boolean, default: false): **JSON generation only** - Generate individual JSON files for each source file instead of consolidated reports. When `true`, creates `MyComponent.cfc.json`, `MyService.cfc.json`, etc. When `false`, creates single combined JSON files.

**JSON Formatting Options:**

- `compact` (boolean, default: false): Use compact JSON formatting (applies to JSON generation)
- `includeStats` (boolean, default: true): Include statistics in output files

### Performance Tuning

**Why Chunk Size Matters:**

When running test suites, nearly all code execution occurs within a single request, resulting in a single potentially huge .exl file containing thousands or millions of coverage entries. Processing this entire dataset at once can consume excessive memory and cause performance issues.

The `chunkSize` option breaks large .exl files into smaller processing chunks that are handled in parallel, significantly reducing peak memory usage while maintaining good performance through parallelization.

**Chunk Size Guidelines:**

- **Default: 50,000**: Starting point for most use cases
- **Adjust based on your environment**: Test different values to find optimal performance for your specific use case

**Note**: Larger chunks may improve throughput but increase memory usage. Smaller chunks may reduce memory footprint but could increase processing overhead. Optimal chunk size depends on your specific environment, test suite size, and available memory.

### 2. Convenience Function

#### `lcovGenerateAllReports(executionLogDir, outputDir, options)` - Generate All Report Types

```cfml
// One-stop function for common use case (no console output by default)
result = lcovGenerateAllReports(
    executionLogDir=logDir,
    outputDir="/reports/"
);

// With options and verbose output
result = lcovGenerateAllReports(
    executionLogDir=logDir,
    outputDir="/reports/",
    options={
        allowList: [expandPath("/myapp")],
        blocklist: [expandPath("/tests")],
        displayUnit: "milli",
        verbose: true,     // Enable console progress output
        chunkSize: 50000
    }
);
```

**Parameters**:

- `executionLogDir` (string, required): Directory containing .exl execution log files
- `outputDir` (string, required): Base directory for all generated reports
- `options` (struct, optional): See [Common Options](#common-options) above. Commonly used: `verbose`, `displayUnit`

**Note**: This function generates ALL report types (HTML, JSON, and LCOV) - the name says it all. Use individual generation functions if you need only specific report types.

**Returns:**

A structure pointing to the files produced in the `outputDir`.

Refer to the individual report generation functions for further information

```cfml
{
    "lcovFile": "/path/to/lcov.info",
    "htmlIndex": "/path/to/index.html",
    "htmlFiles": ["/path/to/file1.html", ...],
    "jsonFiles": {
        "results": "/path/to/results.json",
        "merged": "/path/to/mergedCoverage.json",
        "stats": "/path/to/lcov-stats.json"
    },
    "stats": {
        "totalLines": 1000,
        "coveredLines": 750,
        "coveragePercentage": 75.0,
        "totalFiles": 25,
        "processingTimeMs": 1250  // Actual time varies based on data size and system
    }
}
```

### 3. Individual Report Generation

#### `lcovGenerateLcov(executionLogDir, outputFile, options)` - Generate LCOV Format

Generates a `LCOV.info` type summary, containing line coverage which can be used by other tools or IDEs.

```cfml
// Generate LCOV file from execution logs (no console output by default)
lcovContent = lcovGenerateLcov(
    executionLogDir=logDir,
    outputFile="/reports/lcov.info"
);

// Get LCOV content as string without writing to file
lcovContent = lcovGenerateLcov(
    executionLogDir=logDir
);

// With verbose console output and relative paths
lcovContent = lcovGenerateLcov(
    executionLogDir=logDir,
    outputFile="/reports/lcov.info",
    options={
        verbose: true,          // Enable console progress output
        useRelativePath: true   // Convert absolute paths to relative paths
    }
);
```

**Parameters**:

- `executionLogDir` (string, required): Directory containing .exl execution log files
- `outputFile` (string, optional): Path for LCOV output file. If not provided, returns LCOV content as string
- `options` (struct, optional): See [Common Options](#common-options) above. Commonly used: `verbose`, `allowList`, `blocklist`, `useRelativePath`

**Returns**:

A string containing LCOV file coverage content, i.e.

```cfml
"SF:/path/to/file.cfm
DA:1,5
DA:2,0
DA:3,12
LH:2
LF:3
end_of_record"
```

**Note**: When `useRelativePath: true` is specified, absolute paths are converted to relative paths:

```cfml
// With useRelativePath: false (default)
"SF:D:/work/myapp/components/MyService.cfc
DA:1,5
...

// With useRelativePath: true  
"SF:components/MyService.cfc
DA:1,5
...

#### `lcovGenerateHtml(executionLogDir, outputDir, options)` - Generate HTML Reports

Writes out html reports into the output directory, one per request with a summary index.html file.

```cfml
// Generate HTML reports (no console output by default)
result = lcovGenerateHtml(
    executionLogDir=logDir,
    outputDir="/reports/html/"
);

// With display options and verbose output
result = lcovGenerateHtml(
    executionLogDir=logDir,
    outputDir="/reports/html/",
    options={
        displayUnit: "milli",
        verbose: true  // Enable console progress output
    }
);
```

**Parameters**:

- `executionLogDir` (string, required): Directory containing .exl execution log files
- `outputDir` (string, required): Directory where HTML files will be generated
- `options` (struct, optional): See [Common Options](#common-options) above. Commonly used: `verbose`, `displayUnit`, `allowList`, `blocklist`

**Returns:**

{
    "htmlIndex": "/path/to/index.html",
    "stats": {
        "totalLines": 1000,
        "coveredLines": 750,
        "coveragePercentage": 75.0,
        "totalFiles": 25,
        "processingTimeMs": 1250  // Actual time varies based on data size and system
    }
}

#### `lcovGenerateJson(executionLogDir, outputDir, options)` - Generate JSON Reports

Writes out detailed json files summarising the execution logs

```cfml
// Generate JSON reports (no console output by default)
result = lcovGenerateJson(
    executionLogDir=logDir,
    outputDir="/reports/json/"
);

// With formatting options and verbose output
result = lcovGenerateJson(
    executionLogDir=logDir,
    outputDir="/reports/json/",
    options={
        compact: false,
        includeStats: true,
        separateFiles: true,
        verbose: true  // Enable console progress output
    }
);
```

**Parameters**:

- `executionLogDir` (string, required): Directory containing .exl execution log files
- `outputDir` (string, required): Directory where JSON files will be saved
- `options` (struct, optional): See [Common Options](#common-options) above. Commonly used: `verbose`, `separateFiles`, `compact`, `allowList`, `blocklist`

**Returns:**

```cfml
{
    "jsonFiles": {
        "results": "/path/to/results.json",
        "merged": "/path/to/mergedCoverage.json",
        "stats": "/path/to/lcov-stats.json"
    },
    "stats": {
        "totalLines": 1000,
        "coveredLines": 750,
        "coveragePercentage": 75.0,
        "totalFiles": 25,
        "processingTimeMs": 1250  // Actual time varies based on data size and system
    }
}
```

#### `lcovGenerateSummary(executionLogDir, options)` - Generate Coverage Statistics Only

```cfml
// Generate just the coverage statistics (no console output by default)
stats = lcovGenerateSummary(
    executionLogDir=logDir
);

// With filtering options and verbose output
stats = lcovGenerateSummary(
    executionLogDir=logDir,
    options={
        allowList: [expandPath("/myapp")],
        blocklist: [expandPath("/tests"), expandPath("/vendor")],
        verbose: true,     // Enable console progress output
        chunkSize: 25000   // Use smaller chunks for memory-constrained environments
    }
);

systemOutput("Coverage: " & stats.coveragePercentage & "% (" &
             stats.coveredLines & "/" & stats.totalLines & " lines)");
```

**Parameters**:

- `executionLogDir` (string, required): Directory containing .exl execution log files
- `options` (struct, optional): See [Common Options](#common-options) above. Commonly used: `verbose`, `displayUnit`

**Returns**:

```cfml
{
    "totalLines": 1000,
    "coveredLines": 750,
    "coveragePercentage": 75.0,
    "totalFiles": 25,
    "executedFiles": 20,
    "processingTimeMs": 250,  // Actual time varies based on data size and system
    "fileStats": {
        "/path/to/file1.cfm": {
            "totalLines": 100,
            "coveredLines": 85,
            "coveragePercentage": 85.0
        },
        "/path/to/file2.cfm": {
            "totalLines": 50,
            "coveredLines": 30,
            "coveragePercentage": 60.0
        }
    }
}
```

## Example Use Cases

### Example 1: Test Suite Coverage

```cfml
// 1. Enable logging before tests (automatic temp directory)
logDir = lcovStartLogging(
    adminPassword=AdminPassword);

// 2. Run tests (in separate request to activate logging)
internalRequest(
    template = "/path/to/test-runner.cfm",
    throwonerror = true
);

// 3. Disable logging
lcovStopLogging(adminPassword=AdminPassword);

// 4. Generate all reports using the returned log directory
result = lcovGenerateAllReports(
    executionLogDir=logDir,
    outputDir="/path/to/reports/",
    options={
        blocklist: [expandPath("/testbox"), expandPath("/specs")]
    }
);

systemOutput("Coverage: " & result.stats.coveragePercentage & "%");
```

### Example 2: Development Mode Coverage

```cfml
// Enable logging with custom options, still returns directory
logDir = lcovStartLogging(
    adminPassword=AdminPassword,
    executionLogDir="",
    options={
        unit: "milli",
        minTime: 1,              // Only log operations > 1ms
        maxLogs: 10000           // Limit logs to prevent disk issues
    }
);

// ... normal development work ...

// Generate incremental reports using returned directory
result = lcovGenerateAllReports(
    executionLogDir=logDir,
    outputDir="/dev/reports/",
    options={
        allowList: [expandPath("/myapp")]  // Only my application code
    }
);

systemOutput("Generated: " & result.htmlIndex);
```

### Example 3: Ultra-Simple Coverage

```cfml
// Minimal code for basic coverage
logDir = lcovStartLogging(
    adminPassword=AdminPassword,);
internalRequest(
    template = "/run-my-code.cfm",
    throwonerror = true
);
lcovStopLogging(adminPassword=AdminPassword);

result = lcovGenerateAllReports(
    executionLogDir=logDir,
    outputDir=expandPath("/reports/")
);

systemOutput("Coverage: " & result.stats.coveragePercentage & "%");
```

### Example 4: Granular Control

```cfml
// Enable logging and run tests
logDir = lcovStartLogging(
    adminPassword=AdminPassword,);
internalRequest(
    template = "/tests/all.cfm",
    throwonerror = true
);
lcovStopLogging(adminPassword=AdminPassword);

// Generate only LCOV for CI
lcovGenerateLcov(
    executionLogDir=logDir,
    outputFile="/reports/lcov.info",
    options={
        blocklist: [expandPath("/tests")]
    }
);

// Generate HTML for developers
lcovGenerateHtml(
    executionLogDir=logDir,
    outputDir="/reports/html/",
    options={
        displayUnit: "milli",
        blocklist: [expandPath("/tests")]
    }
);

// Generate JSON for custom tooling
lcovGenerateJson(
    executionLogDir=logDir,
    outputDir="/reports/json/",
    options={
        compact: false,
        separateFiles: true,
        blocklist: [expandPath("/tests")]
    }
);

systemOutput("Generated LCOV, HTML, and JSON reports with individual control");
```

### Example 6: Quick Coverage Check

```cfml
// Minimal overhead - just get the statistics
logDir = lcovStartLogging(
    adminPassword=AdminPassword);
internalRequest(
    template = "/tests/critical.cfm",
    throwonerror = true
);
lcovStopLogging(adminPassword=AdminPassword);

// Fast stats-only generation (no file I/O for reports)
stats = lcovGenerateSummary(
    executionLogDir=logDir,
    options={
        blocklist: [expandPath("/tests")]
    }
);

// Quick coverage gate check
if (stats.coveragePercentage < 80) {
    throw("Critical path coverage too low: " & stats.coveragePercentage & "%");
}

systemOutput("✓ Critical path coverage: " & stats.coveragePercentage & "% OK");
systemOutput("Files tested: " & stats.executedFiles & "/" & stats.totalFiles);
```

## Configuration Options

### Execution Log Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `className` | string | `ResourceExecutionLog` | Log implementation class |
| `unit` | string | `nano` | Time unit: "nano"/"ns", "micro"/"μs", "milli"/"ms" |
| `minTime` | numeric | `0` | Minimum execution time to log (in nanoseconds) |
| `executionLogDir` | string | auto-generated | Output directory for .exl files |
| `maxLogs` | numeric | `0` | Maximum log entries (0=unlimited) - **Note**: Only applies to ConsoleExecutionLog, not ResourceExecutionLog |

### Report Generation Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `allowList` | array | `[]` | File patterns to include (empty=all) |
| `blocklist` | array | `[]` | File patterns to exclude |
| `displayUnit` | string | `milli` | Time unit for HTML reports |

## Output Formats

### 1. LCOV Format

Standard LCOV format compatible with tools like VS Code Coverage Gutters:

```lcov
SF:/path/to/file.cfm
DA:1,5
DA:2,0
DA:3,12
LH:2
LF:3
end_of_record
```

### Raw .EXL File Format (from ResourceExecutionLog.java)

```
context-path:/myapp
remote-user:admin
script-name:/index.cfm
unit:ns
min-time-nano:0
execution-time:1234567

0:/path/to/file.cfm
1:/path/to/another.cfm

0	1245	1267	1234567
1	890	920	567890
0	1300	1350	987654
```

**Format**: `fileIndex \t startPos \t endPos \t executionTime`

### 2. HTML Reports

Interactive HTML reports with:

- File-by-file coverage details
- Line-by-line execution counts and timing
- Heatmap reports
- Dark mode support
- Coverage statistics

### 3. JSON Outputs

Detailed JSON files for programmatic access:

- `results.json`: Raw parsed coverage data
- `mergedCoverage.json`: Merged coverage across all files
- `lcov-stats.json`: Coverage statistics

## Error Handling

### Common Error Scenarios

- An invalid admin password throw an exception, like other '<cfadmin>' or `ConfigImport()`
- File system permissions for output directories
- Directory creation failures (logged to Lucee's internal log system)

## Performance Considerations

### Logging Overhead

- **SERVER CONFIG CHANGES**: Each start/stop operation modifies .CFConfig.json on disk
- **PERSISTENT PERFORMANCE IMPACT**: Logging remains active until explicitly disabled
- `min-time` filters reduce log volume
- `maxlogs` prevents unbounded growth
- `unit` affects precision vs performance trade-off

### Processing Performance

- **Parallel processing**: Chunks .exl files for parallel processing using configurable `chunkSize` (default: 50,000 coverage lines)
- **Memory management**: Critical for test suites that generate massive .exl files - single test runs can produce millions of coverage entries in one file
- **Chunking strategy**: Breaks large .exl files into smaller processing units to prevent memory exhaustion while maintaining parallelization benefits
- **Caching**: File content and line mapping caches to avoid redundant I/O
- **Chunk size tuning**: Configurable based on your specific environment and requirements
- **Actual performance**: Varies significantly based on file size, hardware, and .exl file complexity

## Integration Examples

### CI/CD Pipeline

```cfml
<!-- coverage-ci.cfm -->
<cfscript>
// Start logging (auto temp directory)
logDir = lcovStartLogging(
    adminPassword=AdminPassword,);

// Run test suite in separate request
internalRequest(
    template = "/tests/run-all.cfm",
    throwonerror = true
);

// Stop logging and generate reports
lcovStopLogging(adminPassword=AdminPassword);
result = lcovGenerateAllReports(
    executionLogDir=logDir,
    outputDir="/ci/reports/",
    options={
        blocklist: [expandPath("/tests")]
    }
);

// Fail build if coverage too low
if (result.stats.coveragePercentage < 80) {
    throw("Build failed: Coverage " & result.stats.coveragePercentage & "% below threshold");
}

systemOutput("✓ Coverage: " & result.stats.coveragePercentage & "% (" &
             result.stats.coveredLines & "/" & result.stats.totalLines & " lines)");

// Optional: Clean up temp logs
directoryDelete(logDir, true);
</cfscript>
```

### IDE Integration

Works with [VS Code Coverage Gutters extension](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) by generating standard LCOV format files.

