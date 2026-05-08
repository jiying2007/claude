#!/usr/bin/env bash
# install.sh — 首次安装：将 ~/claude/ 仓库链接到 ~/.claude/

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "安装 claude 框架..."
echo "  仓库：$REPO"
echo "  目标：$CLAUDE_DIR"

# 确保 ~/.claude/ 存在
mkdir -p "$CLAUDE_DIR"

# 链接 CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "  备份已有 CLAUDE.md → $CLAUDE_DIR/CLAUDE.md.bak"
  mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
fi
ln -sf "$REPO/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "  ✓ CLAUDE.md"

# 链接 settings.json（合并模式：仅当不存在时）
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
  ln -sf "$REPO/settings.json" "$CLAUDE_DIR/settings.json"
  echo "  ✓ settings.json"
else
  echo "  ⚠ settings.json 已存在，跳过（手动合并 hooks 配置）"
  echo "    参考：$REPO/settings.json"
fi

# 链接 commands/
if [ -d "$CLAUDE_DIR/commands" ] && [ ! -L "$CLAUDE_DIR/commands" ]; then
  echo "  备份已有 commands/ → $CLAUDE_DIR/commands.bak"
  mv "$CLAUDE_DIR/commands" "$CLAUDE_DIR/commands.bak"
fi
ln -sf "$REPO/commands" "$CLAUDE_DIR/commands"
echo "  ✓ commands/"

# 链接 agents/
if [ -d "$CLAUDE_DIR/agents" ] && [ ! -L "$CLAUDE_DIR/agents" ]; then
  echo "  备份已有 agents/ → $CLAUDE_DIR/agents.bak"
  mv "$CLAUDE_DIR/agents" "$CLAUDE_DIR/agents.bak"
fi
ln -sf "$REPO/agents" "$CLAUDE_DIR/agents"
echo "  ✓ agents/"

echo ""
echo "安装完成。运行 doctor.sh 验证："
echo "  $REPO/control/scripts/doctor.sh"
