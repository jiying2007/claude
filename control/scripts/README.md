# Claude runtime integration scripts

- `install.sh`: reviewed **ADK skill-only** plan; `--apply` explicitly writes managed assets.
- `doctor.sh`: read-only checks for legacy links, global injection and active ADK receipt.
- `dw_runtime.py`: retained historical source-set and R1/R2 binding tooling.
- `runtime-r2-local.sh`: historical R2 local execution with fail-closed asset-copy policy.

The legacy `activate-profile.sh`, `gen-registry.sh` and `session-start.sh`
were removed. No command symlink activation or automatic global prompt injection remains.
Use the ADK CLI for profiles and native Claude Code discovery for Skills.
