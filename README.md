# Claude Code — ADK consumer (Superpowers retired)

This repository is an **integration and historical runtime source**, not the canonical Skill catalog.
Reusable Agent/Skill source is [jiying2007/agent-dev-kit](https://github.com/jiying2007/agent-dev-kit).
Project-only Skills stay in their own projects; Claude Code owns discovery, permissions and sessions.

## Source vs live paths

- `~/claude` is an optional Git checkout, **not** a Claude Code configuration directory.
- `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` is the user configuration root.
- ADK Skills are installed into `<config-root>/skills/<name>/SKILL.md`; no whole-directory links.
- Do not copy `settings.json`, `CLAUDE.md`, `commands/`, `agents/` or plugin data over existing user files.

## Install ADK Skills (explicit, source-bound)

Use a reviewed, immutable ADK checkout (Python >= 3.11) as the build/install source:

```bash
ADK_ROOT=/reviewed/agent-dev-kit control/scripts/install.sh --profile core
# Review the generated PLAN=/tmp/.../plan.json, then apply that exact file:
ADK_ROOT=/reviewed/agent-dev-kit control/scripts/install.sh --apply-plan /tmp/.../plan.json
control/scripts/doctor.sh
```

The wrapper creates an ADK **skill-only** install plan; only `--apply-plan` writes the exact previously reviewed plan.
Existing unmanaged files or old/changed receipt-managed assets block the ADK transaction.
Cross-version upgrades must follow ADK's exact-previous-source migration procedure; this wrapper
does not bypass old receipts. The plan is left in the path printed to stdout.
For optional/domain assets, use the ADK native CLI with the reviewed profile and source.

## Removed runtime behavior

The old `using-skills` SessionStart injection, Superpowers plugin, command symlink activation,
and whole-`commands/` or whole-`agents/` directory installation are retired.
The checked-in `settings.json` is a historical baseline only and is never applied automatically.
The archived vendor-owned personal Skills are **not activated** by this repository; review them
individually and assign each to ADK Optional, its project, or a separate trusted source.

The original R1/R2 execution binding remains frozen as historical evidence. Its runtime copier
now refuses overwrite and symlink-parent traversal; its independently pinned source must be
reviewed before any migration. No source-layout check claims authenticated native conformance.

## Recovery and trust

ADK owns plan/apply/receipt/rollback for assets it manages. User data, authentication, plugins,
MCP, hooks, logs and sessions remain Claude Code-owned. Never delete an unmanaged file or
uninstall an independently installed plugin based only on its name.
If `doctor.sh` finds a legacy hook or symlink, inspect that exact live path and owner first.
