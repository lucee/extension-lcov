# Plan: Migration to Canonical `files` Struct (Remove `source.files`)

## Objective
Unify all per-file metadata and computed stats under a single canonical `files` struct. Remove all usage of `source.files` throughout the codebase, so that only `files` exists and contains both basic info and computed stats for each file.

## Motivation
- Eliminate confusion and duplication between `source.files` and `files`/`stats.files`.
- Simplify the data model: all per-file info (path, linesFound, linesSource, linesHit, totalExecutions, etc.) is in one place.
- Reduce code complexity and maintenance burden.

## Steps

1. **Inventory and Audit**
   - Identify all code that reads, writes, or expects `source.files` (accessors, setters, direct struct access, etc.).
   - List all tests and scripts that reference `source.files`.

2. **Refactor Model and Accessors**
   - Remove `source.files` from the result model (`result.cfc`).
   - Update or remove all accessors (`getSource`, `setSource`, `getSourceFile`, etc.) to use the canonical `files` struct.
   - Ensure all per-file info and stats are written to and read from `files` only.

3. **Update Core Logic**
   - Refactor all core components (e.g., `CoverageMerger.cfc`, `CoverageStats.cfc`, `ExecutionLogParser.cfc`, etc.) to use only the canonical `files` struct.
   - Remove any logic that populates or syncs `source.files`.
   - Ensure all stats calculations and reporting use the unified `files` struct.

4. **Update Tests**
   - Update all tests to expect only the canonical `files` struct.
   - Remove or refactor any test logic that references `source.files`.
   - Validate that all tests pass with the new model.

5. **Documentation and Examples**
   - Update documentation to describe the new canonical model.
   - Update or remove any examples that reference `source.files`.

6. **Validation and Cleanup**
   - Run the full test suite and validate all outputs.
   - Remove any remaining references to `source.files`.
   - Perform code cleanup and final review.

## Acceptance Criteria
- No code or tests reference `source.files`.
- All per-file info and stats are present and correct under the canonical `files` struct.
- All tests pass.
- Documentation and examples are up to date.

---

**Author:** GitHub Copilot
**Date:** 2025-09-17
