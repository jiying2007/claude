#!/usr/bin/env bash
# Read-only post-migration and runtime safety checks.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
config_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
errors=0
warnings=0
err() { printf '[FAIL] %s\n' "$*" >&2; errors=$((errors+1)); }
warn() { printf '[WARN] %s\n' "$*" >&2; warnings=$((warnings+1)); }
ok() { printf '[PASS] %s\n' "$*"; }
if [[ -d "$repo/vendor/plugins/superpowers" ]]; then
  err "retired plugin source still present in the integration repository"
else
  ok "retired plugin source absent"
fi
if [[ -e "$repo/control/scripts/session-start.sh" || -e "$repo/commands/using-skills.md" ]]; then
  err "legacy global Skill injection still exists"
else
  ok "legacy global Skill injection absent"
fi
if [[ -L "$config_root" ]]; then
  err "Claude configuration root is a symlink: $config_root"
elif [[ ! -d "$config_root" ]]; then
  warn "Claude configuration root does not exist: $config_root"
else
  ok "Claude configuration root exists"
  for name in agents commands skills; do
    if [[ -L "$config_root/$name" ]]; then
      err "legacy whole-directory symlink: $config_root/$name"
    fi
  done
  if [[ -f "$config_root/settings.json" ]]; then
    if grep -Eq 'session-start\.sh|using-skills|superpowers' "$config_root/settings.json"; then
      err "legacy/global injection remains in live settings.json; do not overwrite it automatically"
    fi
  fi
  if [[ -d "$config_root/commands" ]]; then
    while IFS= read -r -d '' path; do
      if [[ -L "$path" && "$(readlink "$path")" == *superpowers* ]]; then
        err "legacy plugin command symlink: $path"
      fi
    done < <(find "$config_root/commands" -maxdepth 1 -type l -print0)
  fi
  if [[ -e "$config_root/.adk-install-receipt.json" ]]; then
    ok "ADK installation receipt is present (digest and inventory must be verified by ADK)"
  else
    warn "no ADK install receipt; install only through reviewed ADK plan/apply"
  fi
fi
printf 'RESULT errors=%s warnings=%s\n' "$errors" "$warnings"
[[ "$errors" -eq 0 ]]
