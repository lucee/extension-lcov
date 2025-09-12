# Develop Components: Experimental Extension Points

This folder contains the `ExecutionLogParser.cfc` and `codeCoverageUtils.cfc` components, which are designed as extension points for experimental and in-development logic within the LCOV extension for Lucee.

## Purpose

- **Isolation for Experimentation:**
  - These components extend the original, stable implementations (`ExecutionLogParser` and `codeCoverageUtils`).
  - You can override or add methods here to test new algorithms, bug fixes, or performance improvements without affecting production logic.

- **Safe Testing:**
  - All test references to the optimized/experimental logic now point to these `develop` components.
  - This allows you to run the full test suite against experimental changes, ensuring correctness and performance before merging into the mainline code.

## Usage

- To experiment, simply override methods in `develop/ExecutionLogParser.cfc` or `develop/codeCoverageUtils.cfc`.
- All tests that previously referenced "Optimized" components now use these develop components.
- No changes to the original components are required for experimentation.

## Testing Approach

- **TestBox Integration:**
  - The test suite is configured to run both the original and develop implementations side-by-side for comparison.
  - Any changes in the develop components are immediately validated by the existing tests.

- **Artifact Review:**
  - Test artifacts (e.g., .exl, .json, .html reports) are left in place for manual inspection after test runs.
  - This makes it easy to compare outputs and debug differences between original and experimental logic.

## Benefits

- **Rapid Prototyping:**
  - Safely try new ideas without risk to production code.
- **Easy Rollback:**
  - Revert to the original logic instantly by removing or disabling overrides in the develop components.
- **Continuous Validation:**
  - All experiments are automatically tested for correctness and compatibility.
- **Clean Codebase:**
  - Keeps experimental logic separate from stable code, reducing merge conflicts and technical debt.

---

For more details, see the main project README and the test guidelines in `AGENTS.md`.
