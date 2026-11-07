#!/usr/bin/env bash
# Safe skill-only ADK install front-end for Claude Code. Does not manage user configuration.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ADK_ROOT=/exact/reviewed/agent-dev-kit control/scripts/install.sh [--profile NAME] [--plan-out ABSOLUTE_PATH] [--apply]
Without --apply only a reviewable ADK install plan is created.
Existing users must use the ADK exact-previous-source migration command when upgrading.
This script does not install settings, CLAUDE.md, agents, hooks, commands or plugins.
USAGE
}
profile=core
apply=false
plan_out=
while (( $# )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --profile) (( $# >= 2 )) || { echo "missing --profile argument" >&2; exit 2; }; profile=$2; shift 2 ;;
    --plan-out) (( $# >= 2 )) || { echo "missing --plan-out argument" >&2; exit 2; }; plan_out=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

: "${HOME:?HOME is required}"
: "${ADK_ROOT:?ADK_ROOT must identify a reviewed exact ADK checkout}"
case "$ADK_ROOT" in /*) ;; *) echo "ADK_ROOT must be an absolute path" >&2; exit 2;; esac
case "$profile" in *[!a-zA-Z0-9_-]*|"") echo "invalid profile" >&2; exit 2;; esac
if [[ ! -f "$ADK_ROOT/manifest.json" || ! -f "$ADK_ROOT/scripts/devkit.sh" ]]; then
  echo "ADK_ROOT lacks manifest.json or scripts/devkit.sh" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1 || ! git -C "$ADK_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ADK_ROOT must be a Git checkout with an exact source identity" >&2
  exit 2
fi
if [[ -n "$(git -C "$ADK_ROOT" status --porcelain=v1 --untracked-files=all)" ]]; then
  echo "ADK_ROOT is dirty; use a clean, reviewed exact checkout" >&2
  exit 2
fi
adk_sha="$(git -C "$ADK_ROOT" rev-parse HEAD)"
config_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
case "$config_root" in
  /*) ;;
  *) echo "Claude configuration path must be absolute" >&2; exit 2;;
esac
if [[ -L "$config_root" || ( -e "$config_root" && ! -d "$config_root" ) ]]; then
  echo "Claude configuration root is not a regular directory" >&2
  exit 2
fi
# Do not create/replace any runtime root unless explicitly applying.
if [[ -n "$plan_out" ]]; then
  case "$plan_out" in /*) ;; *) echo "--plan-out must be absolute" >&2; exit 2;; esac
  if [[ -e "$plan_out" || -L "$plan_out" ]]; then
    echo "plan output already exists (refusing overwrite): $plan_out" >&2
    exit 2
  fi
else
  plan_out="$(mktemp "${TMPDIR:-/tmp}/adk-claude-plan.XXXXXXXX.json")"
  rm -- "$plan_out"
fi

echo "ADK_SOURCE=$adk_sha"
echo "CLAUDE_TARGET=$config_root"
bash "$ADK_ROOT/scripts/devkit.sh" install plan \
  --tool claude-code --target "$config_root" --profile "$profile" \
  --asset-kind skill --mode copy --output "$plan_out"
echo "PLAN=$plan_out"
if [[ "$apply" == true ]]; then
  echo "Applying only the reviewed ADK skill selection; unmanaged conflicts fail closed"
  bash "$ADK_ROOT/scripts/devkit.sh" install apply --plan "$plan_out"
else
  echo "PLAN_ONLY: no Claude runtime files were changed"
fi
