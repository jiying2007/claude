#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash control/scripts/runtime-r2-local.sh \
    --digital-worker-root /path/to/digital-worker \
    --target-root /path/to/frozen-target \
    --frozen-plan /path/to/frozen-plan.json \
    --adk-contract-root /path/to/agent-dev-kit-contract-checkout \
    --adk-release-root /path/to/agent-dev-kit-release-checkout \
    --out /path/to/output

The script must be run from an exact Claude runtime-binding checkout that
matches frozen-plan.json. It uses local Claude Code authentication only; no
provider credential is read from or written to GitHub.
EOF
}

DW_ROOT=
TARGET_ROOT=
PLAN=
ADK_CONTRACT_ROOT=
ADK_RELEASE_ROOT=
OUT=
PYTHON_BIN=${PYTHON_BIN:-python3}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --digital-worker-root) DW_ROOT=$2; shift 2 ;;
    --target-root) TARGET_ROOT=$2; shift 2 ;;
    --frozen-plan) PLAN=$2; shift 2 ;;
    --adk-contract-root) ADK_CONTRACT_ROOT=$2; shift 2 ;;
    --adk-release-root) ADK_RELEASE_ROOT=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for value in "$DW_ROOT" "$TARGET_ROOT" "$PLAN" "$ADK_CONTRACT_ROOT" "$ADK_RELEASE_ROOT" "$OUT"; do
  if [ -z "$value" ]; then
    usage >&2
    exit 2
  fi
done

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DW_ROOT=$(cd "$DW_ROOT" && pwd)
TARGET_ROOT=$(cd "$TARGET_ROOT" && pwd)
PLAN=$(cd "$(dirname "$PLAN")" && pwd)/$(basename "$PLAN")
ADK_CONTRACT_ROOT=$(cd "$ADK_CONTRACT_ROOT" && pwd)
ADK_RELEASE_ROOT=$(cd "$ADK_RELEASE_ROOT" && pwd)
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

for cmd in git claude tar sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing command: $cmd" >&2; exit 2; }
done
command -v "$PYTHON_BIN" >/dev/null 2>&1 || { echo "missing Python 3 interpreter: $PYTHON_BIN" >&2; exit 2; }
"$PYTHON_BIN" - <<'PY'
import sys
if sys.version_info < (3, 9):
    raise SystemExit(f"Python >= 3.9 required, got {sys.version}")
PY

read_plan() {
  "$PYTHON_BIN" - "$PLAN" "$1" <<'PY'
import json, pathlib, sys
value=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for part in sys.argv[2].split("."):
    value=value[part]
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

EXPECTED_BINDING=$(read_plan runtime_bindings.claude-code.commit)
EXPECTED_DW=$(read_plan digital_worker_governance.provider_commit)
EXPECTED_BASE=$(read_plan controlled_task.exact_base_commit)
TARGET_REPOSITORY=$(read_plan controlled_task.repo_root)

test "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED_BINDING" || {
  echo "Claude binding checkout does not match frozen plan" >&2
  exit 2
}
test "$(git -C "$DW_ROOT" rev-parse HEAD)" = "$EXPECTED_DW" || {
  echo "Digital Worker checkout does not match frozen plan" >&2
  exit 2
}
test "$(git -C "$TARGET_ROOT" rev-parse HEAD)" = "$EXPECTED_BASE" || {
  echo "target checkout does not match frozen base" >&2
  exit 2
}
test -z "$(git -C "$TARGET_ROOT" status --porcelain=v1 --untracked-files=all)" || {
  echo "target checkout must be clean before R2 execution" >&2
  exit 2
}

"$PYTHON_BIN" "$DW_ROOT/scripts/runtime_r2_evidence.py" prepare \
  --root "$DW_ROOT" \
  --target-root "$TARGET_ROOT" \
  --output "$OUT/recomputed-plan.json"

"$PYTHON_BIN" - "$PLAN" "$OUT/recomputed-plan.json" <<'PY'
import json, pathlib, sys
a=json.loads(pathlib.Path(sys.argv[1]).read_text())
b=json.loads(pathlib.Path(sys.argv[2]).read_text())
if a["frozen_inputs_sha256"] != b["frozen_inputs_sha256"]:
    raise SystemExit("recomputed frozen inputs do not match supplied plan")
if a["controlled_task"] != b["controlled_task"]:
    raise SystemExit("recomputed controlled task does not match supplied plan")
PY

MAT="$OUT/claude-materialized"
"$PYTHON_BIN" "$ROOT/control/scripts/dw_runtime.py" materialize \
  --adk-contract-root "$ADK_CONTRACT_ROOT" \
  --adk-release-root "$ADK_RELEASE_ROOT" \
  --out "$MAT" \
  --runtime-profile solo-dev

R2_HOME="$OUT/claude-home"
mkdir -p "$R2_HOME/.claude"
cp -a "$MAT/distribution/." "$R2_HOME/.claude/"

"$PYTHON_BIN" - "$MAT/runtime-distribution.json" "$R2_HOME/.claude" <<'PY'
import hashlib, json, pathlib, sys
manifest=json.loads(pathlib.Path(sys.argv[1]).read_text())
root=pathlib.Path(sys.argv[2])
for item in manifest["files"]:
    path=root/item["path"]
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=item["sha256"]:
        raise SystemExit("installed Claude asset identity mismatch: "+item["path"])
PY

"$PYTHON_BIN" - "$PLAN" "$OUT/provider-authorization.json" <<'PY'
import hashlib, json, pathlib, sys
plan_path=pathlib.Path(sys.argv[1])
out=pathlib.Path(sys.argv[2])
plan=json.loads(plan_path.read_text())
value={
    "schema":"claude-r2-provider-authorization/v1",
    "authorized":True,
    "authorization_mode":"explicit-local-operator-execution",
    "actor":"local-operator",
    "runtime_host":"local-terminal",
    "frozen_plan_sha256":hashlib.sha256(plan_path.read_bytes()).hexdigest(),
    "frozen_inputs_sha256":plan["frozen_inputs_sha256"],
    "scope":"claude-provider-execution-only",
    "verification_or_release_authority":False,
    "github_provider_credential_used":False,
}
out.write_text(json.dumps(value, indent=2, sort_keys=True)+"\n")
PY

"$PYTHON_BIN" - "$PLAN" "$OUT/prompt.txt" <<'PY'
import json, pathlib, sys
plan=json.loads(pathlib.Path(sys.argv[1]).read_text())
pathlib.Path(sys.argv[2]).write_text(plan["prompt"]+"\n", encoding="utf-8")
PY

date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/started-at.txt"
set +e
(
  cd "$TARGET_ROOT"
  HOME="$R2_HOME" claude -p "$(cat "$OUT/prompt.txt")" \
    --output-format json \
    --max-turns 20 \
    --permission-mode dontAsk \
    --allowedTools "Read,Grep,Glob,Edit,Write,Bash(python *),Bash(python3 *),Bash(pytest *),Bash(sha256sum *),Bash(git status*),Bash(git diff*),Bash(git rev-parse*),Bash(ls *),Bash(find *)"
) > "$OUT/claude-execution.json" 2> "$OUT/claude-stderr.log"
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  cat >&2 <<EOF
Claude local R2 execution failed with exit code $RC.
If this isolated HOME is not authenticated, run:
  HOME="$R2_HOME" claude
then complete /login, exit, and rerun this script from a clean frozen target checkout.
EOF
  exit "$RC"
fi
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/finished-at.txt"

HOME="$R2_HOME" claude --version > "$OUT/claude-version.txt"
git -C "$TARGET_ROOT" status --porcelain=v1 --untracked-files=all > "$OUT/claude-status.txt"
git -C "$TARGET_ROOT" diff --binary > "$OUT/claude.patch"
tar --exclude=.git -C "$TARGET_ROOT" -czf "$OUT/result-tree.tar.gz" .

"$PYTHON_BIN" - "$PLAN" "$OUT/provider-authorization.json" \
  "$MAT/source-set.json" "$MAT/runtime-distribution.json" \
  "$TARGET_ROOT" "$OUT/claude-execution.json" "$OUT/result-tree.tar.gz" \
  "$OUT/claude-native.json" "$TARGET_REPOSITORY" <<'PY'
import hashlib, json, pathlib, sys
plan_path,auth_path,source_path,distribution_path,target,execution_file,result_archive,out=map(pathlib.Path,sys.argv[1:9])
target_repository=sys.argv[9]
plan=json.loads(plan_path.read_text())
auth=json.loads(auth_path.read_text())
source=json.loads(source_path.read_text())
distribution=json.loads(distribution_path.read_text())
if auth["authorized"] is not True or auth["frozen_inputs_sha256"] != plan["frozen_inputs_sha256"]:
    raise SystemExit("local provider authorization does not match frozen plan")
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def tree_digest(root):
    rows=[]
    for p in sorted(x for x in root.rglob("*") if x.is_file() and ".git" not in x.parts):
        rows.append((p.relative_to(root).as_posix(),sha(p)))
    return hashlib.sha256(json.dumps(rows,separators=(",",":")).encode()).hexdigest()
controlled=plan["controlled_task"]
version=pathlib.Path(out.parent,"claude-version.txt").read_text().strip()
result_identity=hashlib.sha256(
    (sha(execution_file)+tree_digest(target)+sha(result_archive)).encode()
).hexdigest()
receipt={
    "schema_version":2,
    "status":"completed",
    "runtime":"claude-code",
    "frozen_inputs_sha256":plan["frozen_inputs_sha256"],
    "verification_pass_claimed":False,
    "runtime_identity":{
        "runtime_binding_repository":"jiying2007/claude",
        "runtime_binding_commit":plan["runtime_bindings"]["claude-code"]["commit"],
        "runtime_target":"claude-code",
        "runtime_profile":"solo-dev",
        "runtime_host":"local-terminal",
        "runtime_provider":"anthropic",
        "runtime_version":version,
        "runtime_source_set_identity_ref":source["identity"],
        "runtime_distribution_identity_ref":distribution["identity"],
    },
    "execution":{
        "started_at":pathlib.Path(out.parent,"started-at.txt").read_text().strip(),
        "completed_at":pathlib.Path(out.parent,"finished-at.txt").read_text().strip(),
        "result_identity_ref":"sha256:"+result_identity,
        "source_identity_ref":controlled["runtime_source_set_identity_ref"],
        "exit_code":0,
        "summary":"Real Claude runtime execution in a local terminal; no Verification PASS claim.",
    },
    "evidence_refs":[
        "provider-authorization:sha256:"+sha(auth_path),
        "claude-execution-file:sha256:"+sha(execution_file),
        "worktree-result:sha256:"+tree_digest(target),
        "replay-result-archive:sha256:"+sha(result_archive),
    ],
}
out.write_text(json.dumps(receipt, indent=2, sort_keys=True)+"\n")
PY

"$PYTHON_BIN" "$ROOT/control/scripts/dw_runtime.py" receipt \
  --input "$OUT/claude-native.json" \
  --output "$OUT/claude-native-validated.json"

"$PYTHON_BIN" "$DW_ROOT/scripts/runtime_r2_evidence.py" project-receipt \
  --root "$DW_ROOT" \
  --runtime claude-code \
  --native-receipt "$OUT/claude-native.json" \
  --frozen-plan "$PLAN" \
  --output "$OUT/claude-portable.json"

"$PYTHON_BIN" - "$OUT" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1])
files=[]
for p in sorted(x for x in root.iterdir() if x.is_file() and x.name != "bundle-manifest.json"):
    files.append({"path":p.name,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
manifest={
    "schema":"claude-r2-local-evidence-bundle/v1",
    "runtime":"claude-code",
    "execution_venue":"local-terminal",
    "github_provider_credential_used":False,
    "verification_pass_claimed":False,
    "r2_qualified":False,
    "files":files,
}
(root/"bundle-manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
PY

tar -C "$OUT" -czf "$OUT/claude-r2-local-evidence.tar.gz" \
  bundle-manifest.json provider-authorization.json \
  claude-native.json claude-native-validated.json claude-portable.json \
  claude-status.txt claude.patch claude-version.txt claude-execution.json result-tree.tar.gz
sha256sum "$OUT/claude-r2-local-evidence.tar.gz" > "$OUT/claude-r2-local-evidence.tar.gz.sha256"

echo "Claude local R2 execution evidence ready: $OUT/claude-portable.json"
