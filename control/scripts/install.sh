#!/usr/bin/env bash
# ADK plan/apply only: no home-wide Claude runtime configuration writes.
set -euo pipefail
usage() {
  cat <<'USAGE'
Usage:
  ADK_ROOT=/exact/agent-dev-kit control/scripts/install.sh [--profile NAME] [--plan-out ABS_PATH]
  ADK_ROOT=/exact/agent-dev-kit control/scripts/install.sh --apply-plan ABS_PATH
The second invocation applies the SAME reviewed plan, not a freshly generated one.
No Claude settings, CLAUDE.md, agents, hooks, commands, or plugins are deployed.
Old-version receipt migration requires the canonical ADK --previous-source flow.
USAGE
}
profile=core
profile_explicit=false
plan_out=
apply_plan=
while (( $# )); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --profile) (( $# >= 2 )) || { echo "missing --profile argument" >&2; exit 2; }
      profile=$2; profile_explicit=true; shift 2 ;;
    --plan-out) (( $# >= 2 )) || { echo "missing --plan-out argument" >&2; exit 2; }
      plan_out=$2; shift 2 ;;
    --apply-plan) (( $# >= 2 )) || { echo "missing --apply-plan argument" >&2; exit 2; }
      apply_plan=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
if [[ -n "$apply_plan" && ( -n "$plan_out" || "$profile_explicit" == true ) ]]; then
  echo "--apply-plan cannot be combined with --profile or --plan-out" >&2
  exit 2
fi
: "${HOME:?HOME is required}"
: "${ADK_ROOT:?ADK_ROOT must identify a reviewed exact ADK checkout}"
case "$ADK_ROOT" in /*) ;; *) echo "ADK_ROOT must be absolute" >&2; exit 2;; esac
case "$profile" in *[!a-zA-Z0-9_-]*|"") echo "invalid profile" >&2; exit 2;; esac
if [[ ! -f "$ADK_ROOT/manifest.json" || ! -f "$ADK_ROOT/scripts/devkit.sh" ]]; then
  echo "ADK_ROOT lacks manifest.json or scripts/devkit.sh" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1 || ! git -C "$ADK_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ADK_ROOT must be a Git checkout" >&2
  exit 2
fi
if [[ -n "$(git -C "$ADK_ROOT" status --porcelain=v1 --untracked-files=all)" ]]; then
  echo "ADK_ROOT is dirty; use a clean reviewed exact checkout" >&2
  exit 2
fi
adk_sha="$(git -C "$ADK_ROOT" rev-parse HEAD)"
config_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
case "$config_root" in /*) ;; *) echo "Claude configuration path must be absolute" >&2; exit 2;; esac
if [[ -L "$config_root" || ( -e "$config_root" && ! -d "$config_root" ) ]]; then
  echo "Claude configuration root must not be a symlink or non-directory" >&2
  exit 2
fi
echo "ADK_SOURCE=$adk_sha"
echo "CLAUDE_TARGET=$config_root"
if [[ -n "$apply_plan" ]]; then
  case "$apply_plan" in /*) ;; *) echo "--apply-plan must be absolute" >&2; exit 2;; esac
  if [[ -L "$apply_plan" || ! -f "$apply_plan" ]]; then
    echo "--apply-plan must be an existing regular file (not a symlink)" >&2
    exit 2
  fi
  # A supplied plan is untrusted. ADK will additionally revalidate the complete
  # exact source, active receipt, freshness, asset inventory, target and contract.
  python3 - "$apply_plan" "$config_root" <<'PY'
import json
import pathlib
import sys

plan_path = pathlib.Path(sys.argv[1])
expected_target = pathlib.Path(sys.argv[2]).resolve()
try:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
except (OSError, ValueError, UnicodeError) as exc:
    raise SystemExit("unreadable ADK plan: " + str(exc))
if not isinstance(plan, dict) or plan.get("tool") != "claude-code":
    raise SystemExit("plan must be for claude-code")
if plan.get("asset_kind") != "skill" or plan.get("status") != "ready":
    raise SystemExit("plan is not a ready skill-only install")
if plan.get("target") != str(expected_target):
    raise SystemExit("plan target differs from current Claude config root")
PY
  bash "$ADK_ROOT/scripts/devkit.sh" install apply --plan "$apply_plan"
  echo "APPLIED_PLAN=$apply_plan"
  exit 0
fi
if [[ -n "$plan_out" ]]; then
  case "$plan_out" in /*) ;; *) echo "--plan-out must be absolute" >&2; exit 2;; esac
  if [[ -e "$plan_out" || -L "$plan_out" ]]; then
    echo "plan output already exists (refusing overwrite): $plan_out" >&2
    exit 2
  fi
else
  private_dir="$(mktemp -d "${TMPDIR:-/tmp}/adk-claude-plan.XXXXXXXX")"
  plan_out="$private_dir/plan.json"
fi
bash "$ADK_ROOT/scripts/devkit.sh" install plan \
  --tool claude-code --target "$config_root" --profile "$profile" \
  --asset-kind skill --mode copy --output "$plan_out"
echo "PLAN=$plan_out"
echo "PLAN_ONLY: inspect the exact plan, then use --apply-plan $plan_out"
