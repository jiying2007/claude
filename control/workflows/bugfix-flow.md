# Bugfix — ADK workflow map

Scope: reproducible unexpected behavior or failing tests.

1. Freeze reproduction inputs and observable failure.
2. Use `adk-systematic-debugging` if the root cause is unknown.
3. Implement the smallest verified repair.
4. Use `adk-test-strategy` and project-specific checks for regression evidence.
5. Use `adk-code-review-loop` when review is required.
6. Before claiming completion use `adk-verification-before-completion`.

This document is guidance only; it is not an alternate executable Skill or route owner.
