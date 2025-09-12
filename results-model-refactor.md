# Results Model Refactor

## Background

The results model is the core data structure for representing per-file and merged coverage data in the Lucee LCOV extension. It is used for all downstream reporting (JSON, HTML, summary, etc.) and must be consistent, canonical, and easy to consume.

## Problems Identified

- Inconsistent keying in output JSONs (e.g., 'IDX' instead of numeric 0)
- Redundant or unsynchronized stats sections (e.g., 'stats', 'files', 'source', etc.)
- linesFound and linesSource mismatches due to inconsistent calculation or propagation
- OutputFilename and artifact naming logic scattered and duplicated
- Per-file outputs must always use file index 0, never arbitrary or string keys


## Refactor Goals


1. **Canonical Top-Level Structure:**
   - The top-level `files` section is the single source of truth for all per-file stats and metadata.
   - For per-file results (e.g., `file-*.json`), `files` contains only one entry, always keyed by 0.
   - For per-request or merged results (e.g., `results.json`, `merged.json`), `files` contains multiple entries, keyed by 0, 1, 2, ... (one for each file covered in that request or merge).
   - No string keys like 'IDX' or 'fileIndex' in output JSONs.
   - The `stats` section contains only overall totals and summary values (e.g., totalLinesFound, totalLinesHit, totalLinesSource, totalExecutions, etc.), not per-file breakdowns.
   - The `source` section contains only the raw source context: file path(s), source lines, and any mapping needed for reporting (e.g., `lines`, `path`, `executableLines`). It does not duplicate stats or per-file summary data.

2. **No Redundant Sections:**
   - Remove all redundant `files` sections under `source` and `stats`.
   - All consumers and tests reference only the top-level `files` for per-file data, and `stats` for overall totals.

3. **OutputFilename Consistency:**
   - outputFilename must be set canonically and early, and all artifact naming must derive from it.

4. **No Defensive Coding:**
   - Fail fast and loudly on missing or invalid data.
   - No fallback/defaults for required properties.

5. **Test Alignment:**
   - All tests must expect the canonical structure and stats propagation.
   - No test should expect legacy or inconsistent output.


## Refactor Steps

1. Refactor the result model to always use numeric 0 as the file index for per-file outputs in the top-level `files` section.
2. Remove all redundant `files` sections under `source` and `stats`.
3. Ensure the `stats` section contains only overall totals, not per-file breakdowns.
4. Ensure the `source` section contains only raw source context (file path, lines, executableLines if needed), not stats.
5. Centralize outputFilename logic and artifact naming.
6. Remove all defensive code and fail fast on errors.
7. Update all tests to expect the new canonical structure.


## Acceptance Criteria

- All output JSONs and HTML reports use numeric 0 as the file index in the top-level `files` section only.
- The top-level `files` section is the only place for per-file stats and metadata.
- The `stats` section contains only overall totals and summary values.
- The `source` section contains only raw source context (file path, lines, executableLines if needed).
- No string keys like 'IDX' appear in any output.
- All tests (SeparateFilesTest, GenerateJsonTest, etc.) pass with no mapping or stats errors.
- Code is free of defensive coding and legacy fallback logic.

---

*Last updated: 2025-09-17*
