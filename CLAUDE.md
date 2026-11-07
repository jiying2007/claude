# Claude Code Runtime Rules — ADK-first

This is a historical user-level configuration source; do not implicitly overwrite a project's
`CLAUDE.md`, a user's `~/.claude/CLAUDE.md`, settings, or runtime state.

## Workflow

- Follow the user's current instructions, repository policy, and native Claude Code safety rules.
- Prefer the available ADK Skills selected by the native runtime using their `name` and
  `description`. Invoke one primary Skill for a task; consult supporting references only when needed.
- Requirements: `adk-requirements-triage`; planning: `adk-lightweight-planning` or
  `adk-task-breakdown`; debugging: `adk-systematic-debugging`; review:
  `adk-code-review-loop`; completion evidence: `adk-verification-before-completion`.
- Do not treat missing/unavailable Skills as an obligation to load another framework.
- For a small, well-specified task, execute and verify directly; for larger changes,
  agree on scope and make reproducible incremental changes.
- Never claim completion without real evidence; distinguish static checks from native behavior.
- All mutation needs the active host's permission; Skills never grant their own tool permissions.

## Source boundary

ADK is the canonical cross-runtime reusable Skill/Agent source. Project-local capabilities stay
in their project; runtime credentials and private configuration stay in the native Claude home.
Do not run the former global SessionStart metaprompt, legacy command activation, or unreviewed
third-party plugin from this repository. No compatibility aliases are published.

## Communication

Default to clear Chinese explanations when the user writes Chinese; retain English
source identifiers and follow project-specific formatting rules. Avoid redundant context.
