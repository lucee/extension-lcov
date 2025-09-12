# Result Model Migration Tracking

## Overview
Migrating from direct struct access to result model with getters/setters.

## Migration Status

### Phase 1: Fix Direct Property Access

#### CoverageStats.cfc
- [x] Line 50: Changed argument type from `any result` to `result result`
- [x] Line 69: Changed `arguments.result.source.files` to use `getSource()`
- [x] Lines 74-77: Changed direct access to use `sourceData` variable
- [x] Line 78: Changed `arguments.result.coverage` to use `getCoverage()`
- [x] Line 96: Fixed setSource() call (was setSourceFile)

#### CoverageMerger.cfc
- [ ] Lines 146-147: Replace `arguments.result.source.files` with getters
- [ ] Lines 164: Fix direct assignment to `entry.coverage`
- [ ] Lines 166-168: Fix direct access in source check
- [ ] Lines 173-174: Fix direct access in files check

#### develop/CoverageBlockProcessor.cfc
- [ ] Line 23: Replace `arguments.result.source.files` with getters
- [ ] Line 27: Replace direct access with getters
- [ ] Line 29: Replace direct access with getters

#### HtmlReporter.cfc
- [ ] Line 40: Change argument type from `any result` to `result result`

### Phase 2: Separated Files Feature

#### Design Clarification

**Data Flow:**
1. .exl files (execution logs) → parsed to request-based JSON files
2. When `separateFiles: false` → HTML reports based on request URLs (`request-*.html`)
3. When `separateFiles: true` → Merge coverage by source file → Write directly to `file-*.json` files → Generate `file-*.html` reports

**File Naming Patterns:**
- `request-{number}-{scriptname}.json/html` - Per-request files (regular mode)
- `file-{hashOfDir}-{filename}.json/html` - Per-source-file files (separateFiles mode)
- `summary-*.json` - Aggregate/overview files (merged results, index, etc.)

**Key Insight:**
- We don't need to store separated/merged results back in the main results structure
- Merged source file data should be written directly to `file-*.json` files
- This avoids polluting the original results structure with source file paths as keys
- Original results structure stays clean with only .exl-based results

#### Current Issues
- Separated files are being added as top-level keys in the results structure (BAD)
- Missing proper file naming patterns
- Incomplete implementation with TODO comments

#### Files Involved
- CoverageMerger.cfc - `mergeResultsBySourceFile()` function
- HtmlReporter.cfc - File naming logic (lines 155-170)
- LcovFunctions.cfc - Post-processing logic (lines 226-231)


### Separated Files JSON Path Inclusion (2025-09-17)

**Problem:**
- In separated files mode, per-file result JSONs did not include the file path as a top-level property, making downstream processing and report generation more difficult.
- There was confusion about whether to use file index or file path as the key in coverage data. The correct approach is to always use the file index as the key (even for single-file mode, where the index is always 0), but also include the file path as a property in the result JSON for clarity and traceability.

**Solution:**
- Updated `CoverageMerger.cfc` so that each per-file result JSON written in separated files mode now includes a `path` property at the top level, containing the full file path for that result.
- This ensures that downstream consumers and HTML report generators can always determine the source file for each result, regardless of the keying scheme.
- The file index remains the key for coverage and source data, matching the .exl and original data structure.

**Rationale:**
- This approach maintains consistency with the source data and avoids ambiguity, while making the per-file JSONs self-describing and easier to process.

### Phase 3: Testing & Validation

#### Test Files Needing Updates
- SeparateFilesTest.cfc
- GenerateJsonTest.cfc
- GenerateHtmlTest.cfc
- GenerateLcovTest.cfc

## Error Tracking

### Fixed Errors
- ✅ Fixed: `Component [lucee.extension.lcov.model.result] has no accessible Member with name [SOURCE]`
- ✅ Fixed: `variable [MODEL] doesn't exist` in CoverageStats.cfc

### Current Test Status
- Down from 46 errors to 4 test failures
- Remaining issues are functional test failures, not model migration issues

## Next Steps
1. Continue fixing CoverageMerger.cfc
2. Fix develop/CoverageBlockProcessor.cfc
3. Fix HtmlReporter.cfc argument type
4. Run tests to verify fixes
5. Document and rationalize separated files feature