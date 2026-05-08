#!/usr/bin/env bash
# doctor.sh — 一致性体检

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
ERRORS=0
WARNINGS=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo "  ✓ $desc"
  elif [ "$result" = "warn" ]; then
    echo "  ⚠ $desc"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ✗ $desc"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "=== Claude Framework Doctor ==="
echo "  仓库：$REPO"
echo "  目标：$CLAUDE_DIR"
echo ""

# 检查激活层
echo "--- 激活层 ---"
[ -f "$CLAUDE_DIR/CLAUDE.md" ] && check "CLAUDE.md 存在" "ok" || check "CLAUDE.md 缺失" "error"
[ -d "$CLAUDE_DIR/commands" ] && check "commands/ 存在" "ok" || check "commands/ 缺失" "error"
[ -d "$CLAUDE_DIR/agents" ] && check "agents/ 存在" "ok" || check "agents/ 缺失" "error"
[ -f "$CLAUDE_DIR/settings.json" ] && check "settings.json 存在" "ok" || check "settings.json 缺失" "warn"

# 检查 SessionStart hook
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  if grep -q "SessionStart" "$CLAUDE_DIR/settings.json" 2>/dev/null; then
    check "settings.json 包含 SessionStart hook" "ok"
  else
    check "settings.json 缺少 SessionStart hook（自动 skill 触发将不工作）" "warn"
  fi
fi

# 检查 using-skills
echo ""
echo "--- 元 Skill ---"
[ -f "$CLAUDE_DIR/commands/using-skills.md" ] && check "using-skills.md 存在" "ok" || check "using-skills.md 缺失（框架无法自动触发）" "error"

# 检查 session-start 脚本
[ -f "$REPO/control/scripts/session-start.sh" ] && \
  [ -x "$REPO/control/scripts/session-start.sh" ] && \
  check "session-start.sh 可执行" "ok" || check "session-start.sh 不可执行" "warn"

# 检查 commands catalog 一致性
echo ""
echo "--- Commands Catalog ---"
CATALOG="$REPO/control/catalog/commands.csv"
if [ -f "$CATALOG" ]; then
  while IFS=, read -r name enabled rest; do
    [ "$name" = "name" ] && continue
    [ "$enabled" = "0" ] && continue
    cmd_file="$CLAUDE_DIR/commands/${name}.md"
    if [ -f "$cmd_file" ]; then
      check "$name" "ok"
    else
      check "$name 缺失（在 catalog 中启用但文件不存在）" "warn"
    fi
  done < "$CATALOG"
else
  check "commands.csv 不存在" "error"
fi

# 检查 agents catalog 一致性
echo ""
echo "--- Agents Catalog ---"
AGENTS_CATALOG="$REPO/control/catalog/agents.csv"
if [ -f "$AGENTS_CATALOG" ]; then
  while IFS=, read -r name enabled rest; do
    [ "$name" = "name" ] && continue
    [ "$enabled" = "0" ] && continue
    agent_file="$CLAUDE_DIR/agents/${name}.md"
    if [ -f "$agent_file" ]; then
      check "$name" "ok"
    else
      check "$name 缺失" "warn"
    fi
  done < "$AGENTS_CATALOG"
fi

echo ""
echo "=== 结果 ==="
echo "  errors=$ERRORS  warnings=$WARNINGS"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "  ✓ 全部通过"
elif [ "$ERRORS" -eq 0 ]; then
  echo "  ⚠ 有警告，建议处理"
else
  echo "  ✗ 有错误，需要修复"
  exit 1
fi
