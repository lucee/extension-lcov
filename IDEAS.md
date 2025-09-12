# Ideas for LCOV Extension Improvements

## Incremental Processing

### Performance Optimizations
- Don't reprocess .exl files that haven't changed
- Track processing state in `coverage-state.json`
- Only parse new/changed files based on hash or timestamp
- Cache results to avoid redundant processing

### State Management
```json
{
  "processedFiles": {
    "1-test.exl": {
      "hash": "abc123",
      "processedAt": "2024-01-01T10:00:00",
      "size": 1024
    }
  },
  "lastProcessed": "2024-01-01T10:00:00",
  "totalStats": { /* aggregated stats */ },
  "sourceFiles": { /* map of source files to .exl files that touched them */ }
}
```

### Separated Files as View Transformation
- Make `separateFiles` a view transformation rather than reprocessing
- If state exists, just run merger to create `file-*.json` without reparsing
- Allow changing between request-based and source-based views on-demand

## Future Considerations

### Expiry/Cleanup of Old .exl Files
- Implement configurable retention policies
- Auto-cleanup of .exl files older than X days
- Option to archive old coverage data
- Compress historical data for long-term storage

### Merge Coverage from Different Test Runs
- Support merging coverage from:
  - Different test suites (unit, integration, e2e)
  - Different environments (CI, local development)
  - Different branches for comparison
- Track coverage trends over time
- Generate diff reports between test runs

### Real-time Updates as Tests Run
- Watch mode for continuous coverage updates
- WebSocket or SSE for live coverage display
- Hot-reload coverage reports in browser
- Show coverage changes as code is edited
- Integration with IDE extensions for live feedback
- Progress indicators during long test runs

## Architecture Improvements

### Better Separation of Concerns
- Move file I/O to dedicated writer components
- Separate parsing, calculation, and presentation layers
- Make functions more composable and testable

### API Improvements
```cfml
// Enhanced options
lcovGenerateJson(
  executionLogDir = "...",
  outputDir = "...",
  options = {
    incremental: true,        // Only process new files
    separateFiles: false,     // Can change without reprocessing
    forceReprocess: false,    // Force full reprocessing
    watch: true,              // Watch for changes
    retention: 30,            // Days to keep old data
    merge: ["../other-run"]   // Merge with other coverage data
  }
)
```

## Additional Ideas

### Coverage Trends
- Track coverage over time
- Generate trend graphs
- Set coverage thresholds and alerts
- Compare coverage between branches

### Enhanced Reporting
- Coverage by package/namespace
- Complexity-weighted coverage
- Test impact analysis
- Identify untested code paths
- Suggest high-value test cases

### Integration Features
- GitHub/GitLab integration for PR comments
- Slack/Teams notifications for coverage changes
- JIRA integration for uncovered code tracking
- CI/CD pipeline integration with coverage gates