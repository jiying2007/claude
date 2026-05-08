#!/usr/bin/env bash
# doctor.sh — 一致性体检

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
CATALOG="$REPO/control/catalog/commands.csv"
STATE_FILE="$REPO/control/state/active-profile.env"
ERRORS=0
WARNINGS=0

PROFILE="team-collab"
if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

has_profile() {
  local field="$1" profile="$2" token
  IFS='|' read -r -a parts <<< "$field"
  for token in "${parts[@]}"; do
    [ "$token" = "$profile" ] && return 0
  done
  return 1
}

ok()   { echo "  [OK  ] $1"; }
warn() { echo "  [WARN] $1"; WARNINGS=$((WARNINGS + 1)); }
err()  { echo "  [ERR ] $1"; ERRORS=$((ERRORS + 1)); }

echo "=== Claude Framework Doctor ==="
echo "  仓库    : $REPO"
echo "  目标    : $CLAUDE_DIR"
echo "  profile : $PROFILE"
echo ""

# ---- 激活层 ----
echo "--- 激活层 ---"
if [ -L "$CLAUDE_DIR/CLAUDE.md" ] && [ "$(readlink "$CLAUDE_DIR/CLAUDE.md")" = "$REPO/CLAUDE.md" ]; then
  ok "CLAUDE.md 软链接正确"
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  warn "CLAUDE.md 存在但非软链接（建议重新运行 install.sh）"
else
  err "CLAUDE.md 缺失"
fi

if [ -L "$CLAUDE_DIR/commands" ] && [ "$(readlink "$CLAUDE_DIR/commands")" = "$REPO/commands" ]; then
  ok "commands/ 软链接正确"
elif [ -d "$CLAUDE_DIR/commands" ]; then
  warn "commands/ 存在但非软链接（建议重新运行 install.sh）"
else
  err "commands/ 缺失"
fi

if [ -L "$CLAUDE_DIR/agents" ] && [ "$(readlink "$CLAUDE_DIR/agents")" = "$REPO/agents" ]; then
  ok "agents/ 软链接正确"
elif [ -d "$CLAUDE_DIR/agents" ]; then
  warn "agents/ 存在但非软链接（建议重新运行 install.sh）"
else
  err "agents/ 缺失"
fi

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  ok "settings.json 存在"
  if grep -q "SessionStart" "$CLAUDE_DIR/settings.json" 2>/dev/null; then
    ok "settings.json 包含 SessionStart hook"
  else
    warn "settings.json 缺少 SessionStart hook（skill 自动触发将不工作）"
  fi
else
  warn "settings.json 缺失"
fi

# ---- 元 Skill ----
echo ""
echo "--- 元 Skill ---"
if [ -f "$REPO/commands/using-skills.md" ] && [ ! -L "$REPO/commands/using-skills.md" ]; then
  ok "using-skills.md 为本地文件（正确）"
elif [ -L "$REPO/commands/using-skills.md" ]; then
  warn "using-skills.md 是软链接（应为本地文件）"
else
  err "using-skills.md 缺失（框架无法自动触发）"
fi

if [ -f "$REPO/control/scripts/session-start.sh" ] && [ -x "$REPO/control/scripts/session-start.sh" ]; then
  ok "session-start.sh 可执行"
else
  warn "session-start.sh 不存在或不可执行"
fi

# ---- Vendor 层 ----
echo ""
echo "--- Vendor 层 ---"
VENDOR="$REPO/vendor"
if [ -d "$VENDOR/plugins/superpowers" ]; then
  ok "superpowers plugin 存在"
else
  err "缺少 vendor/plugins/superpowers（运行 install.sh 同步 vendor）"
fi

for skill in session-wrap commit-daily-summary project-daily-summary research-note-wrap worktree-closeout caveman; do
  if [ -d "$VENDOR/skills/$skill" ]; then
    ok "vendor/skills/$skill"
  else
    err "缺少 vendor/skills/$skill"
  fi
done

# ---- Commands Catalog ----
echo ""
echo "--- Commands Catalog（profile=$PROFILE）---"
if [ -f "$CATALOG" ]; then
  while IFS=, read -r name enabled source_kind _version source_rel profiles _tags; do
    [ "$name" = "name" ] && continue
    [ -z "$name" ] && continue
    [ "$enabled" != "1" ] && continue

    in_profile=false
    has_profile "$profiles" "$PROFILE" && in_profile=true

    cmd_file="$REPO/commands/${name}.md"

    if $in_profile; then
      if [ "$source_kind" = "local" ]; then
        if [ -f "$REPO/$source_rel" ] && [ ! -L "$REPO/$source_rel" ]; then
          ok "$name (local)"
        else
          err "$name local 文件不存在: $source_rel"
        fi
      else
        # vendor：验证 symlink
        source_abs="$REPO/$source_rel"
        if [ ! -f "$source_abs" ]; then
          err "$name vendor 源不存在: $source_rel"
        elif [ -L "$cmd_file" ] && [ "$(readlink "$cmd_file")" = "$source_abs" ]; then
          ok "$name (vendor symlink)"
        elif [ -L "$cmd_file" ]; then
          warn "$name symlink 目标不一致（重新运行 activate-profile.sh）"
        else
          warn "$name 未激活为 symlink（运行 activate-profile.sh $PROFILE）"
        fi
      fi
    else
      # 不在当前 profile：symlink 应已被移除
      if [ -L "$cmd_file" ]; then
        warn "$name symlink 存在但不在 profile=$PROFILE（运行 activate-profile.sh $PROFILE）"
      fi
    fi
  done < "$CATALOG"
else
  err "commands.csv 不存在"
fi

# ---- Agents Catalog ----
echo ""
echo "--- Agents Catalog ---"
AGENTS_CATALOG="$REPO/control/catalog/agents.csv"
if [ -f "$AGENTS_CATALOG" ]; then
  while IFS=, read -r name enabled _rest; do
    [ "$name" = "name" ] && continue
    [ "$enabled" = "0" ] && continue
    agent_file="$CLAUDE_DIR/agents/${name}.md"
    if [ -f "$agent_file" ]; then
      ok "$name"
    else
      warn "$name 缺失"
    fi
  done < "$AGENTS_CATALOG"
fi

echo ""
echo "=== 结果 ==="
echo "  errors=$ERRORS  warnings=$WARNINGS"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "  全部通过"
elif [ "$ERRORS" -eq 0 ]; then
  echo "  有警告，建议处理"
else
  echo "  有错误，需要修复"
  exit 1
fi
