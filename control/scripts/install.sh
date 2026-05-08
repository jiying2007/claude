#!/usr/bin/env bash
# install.sh — 新机器首次安装 / 迁移到新路径
#
# 用法：
#   control/scripts/install.sh                  # 默认 profile=team-collab
#   control/scripts/install.sh [profile]        # 指定 profile
#
# 功能：
#   1. 链接激活层到 ~/.claude（CLAUDE.md / settings.json / commands/ / agents/）
#   2. 激活指定 profile 的 command symlinks
#   3. 运行体检（doctor.sh）
#   4. 输出下一步操作提示

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PROFILE="${1:-team-collab}"
CLAUDE_DIR="$HOME/.claude"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "用法: $(basename "$0") [profile]"
  echo "  profile  激活的配置 profile（默认：team-collab）"
  echo ""
  echo "可用 profiles:"
  awk -F, 'NR>1 && $1!="" {printf "  %-16s %s\n", $1, $2}' "$REPO/control/catalog/profiles.csv"
  exit 0
fi

echo "================================================"
echo "  Claude Framework Install"
echo "  REPO    : $REPO"
echo "  TARGET  : $CLAUDE_DIR"
echo "  PROFILE : $PROFILE"
echo "================================================"
echo ""

# ---- 1. 确保 ~/.claude/ 存在 ----
mkdir -p "$CLAUDE_DIR"

# 链接 CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_DIR/CLAUDE.md" ]; then
  mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
  echo "[INFO] 备份已有 CLAUDE.md → CLAUDE.md.bak"
fi
ln -sf "$REPO/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "[OK] CLAUDE.md"

# 链接 settings.json（仅当不存在时）
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
  ln -sf "$REPO/settings.json" "$CLAUDE_DIR/settings.json"
  echo "[OK] settings.json"
else
  echo "[INFO] settings.json 已存在，跳过（请手动合并 hooks 配置）"
  echo "       参考：$REPO/settings.json"
fi

# 链接 commands/
if [ -d "$CLAUDE_DIR/commands" ] && [ ! -L "$CLAUDE_DIR/commands" ]; then
  mv "$CLAUDE_DIR/commands" "$CLAUDE_DIR/commands.bak"
  echo "[INFO] 备份已有 commands/ → commands.bak"
fi
ln -sf "$REPO/commands" "$CLAUDE_DIR/commands"
echo "[OK] commands/"

# 链接 agents/
if [ -d "$CLAUDE_DIR/agents" ] && [ ! -L "$CLAUDE_DIR/agents" ]; then
  mv "$CLAUDE_DIR/agents" "$CLAUDE_DIR/agents.bak"
  echo "[INFO] 备份已有 agents/ → agents.bak"
fi
ln -sf "$REPO/agents" "$CLAUDE_DIR/agents"
echo "[OK] agents/"
echo ""

# ---- 2. 激活 profile ----
echo "[INFO] 激活 profile: $PROFILE ..."
"$REPO/control/scripts/activate-profile.sh" "$PROFILE"
echo ""

# ---- 3. 体检 ----
echo "[INFO] 执行体检 ..."
if "$REPO/control/scripts/doctor.sh"; then
  echo ""
  echo "================================================"
  echo "  安装成功！"
  echo "================================================"
else
  echo ""
  echo "================================================"
  echo "  安装完成，但体检有错误，请检查上方输出"
  echo "================================================"
fi

echo ""
echo "下一步建议："
echo "  切换 profile    : $REPO/control/scripts/activate-profile.sh <profile>"
echo "  体检            : $REPO/control/scripts/doctor.sh"
echo "  可用 profiles   : $(awk -F, 'NR>1 && $1!="" {printf "%s ", $1}' "$REPO/control/catalog/profiles.csv")"
