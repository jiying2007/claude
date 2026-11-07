# Refactor — ADK workflow map

1. Freeze existing behavior and representative regression tests.
2. Use `adk-lightweight-planning` for scope and dependency boundaries.
3. Make incremental changes; use `adk-code-simplification` when relevant.
4. Verify functional parity and review via `adk-code-review-loop`.
5. Record rollback identity and actual verification before completion.

Do not equate deterministic source checks with native runtime qualification.
