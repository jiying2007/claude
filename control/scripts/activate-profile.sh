#!/usr/bin/env bash
# activate-profile.sh — 按 profile 激活 commands（未来支持从 vendor/ 复制）
# 用法：activate-profile.sh [profile]
# profile: minimal | solo-dev | team-collab（默认 solo-dev）

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PROFILE="${1:-solo-dev}"

echo "激活 profile: $PROFILE"
echo "（当前版本：commands/ 已包含全量 skills，profile 仅用于 catalog 标注）"
echo ""
echo "如需严格按 profile 过滤 commands，"
echo "运行 doctor.sh 查看哪些 commands 在当前 profile 中启用："
echo "  $REPO/control/scripts/doctor.sh"
echo ""
echo "未来版本将支持从 vendor/ 动态复制对应 profile 的 commands。"
