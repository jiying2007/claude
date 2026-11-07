# Claude Code integration: ADK-only architecture

The reusable Skill/Agent source is ADK. The Claude Code runtime is the consumer,
not the source of public reusable capability.

- Optional Git checkout: `~/claude` (integration source, not live configuration).
- Native runtime configuration: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.
- Native Skills: `<config-root>/skills/<skill-name>/SKILL.md`.
- Project-owned Skills: `<project>/.claude/skills/<name>/SKILL.md`.
- Project `CLAUDE.md`, installed plugins, user settings, auth, MCP, and sessions
  remain runtime-owned.
- Source-to-live assets are built and deployed with ADK plan/apply/receipt/rollback.
- Claude Code direct target is still static/experimental until authenticated native evidence is verified.

Former Superpowers commands, global using-skills hook, and whole-directory links are
retired. Do not alias removed commands to ADK skills. For scope-specific workflows
use native descriptions, one primary Skill, and actual target permissions.
The old R1/R2 source-set contracts remain immutable historical evidence, not permission
to overwrite user configuration.
