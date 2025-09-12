
# Develop Components: Factory Pattern for Experimentation

This folder contains experimental versions of core components (e.g., `ExecutionLogParser.cfc`, `CoverageBlockProcessor.cfc`).

**Always use the `CoverageComponentFactory` to instantiate these components.**

- The factory allows switching between stable and develop implementations globally or per-call (see `AGENTS.md`).
- Never instantiate develop or stable components directly with `new` in tests or core logic.
- This enables side-by-side testing and safe experimentation without affecting production code.

To use the develop version in any test or logic:

```cfml
var factory = new lucee.extension.lcov.CoverageComponentFactory();
var devBlockProcessor = factory.getCoverageBlockProcessor(useDevelop=true);
```

For more, see `AGENTS.md` and the main project README.
