#!/usr/bin/env bash
# activate-profile.sh — 按 profile 激活 commands（创建 symlinks → vendor）
# 用法：activate-profile.sh [profile]
# profile: minimal | solo-dev | team-collab（默认 team-collab）

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PROFILE="${1:-team-collab}"
CATALOG="$REPO/control/catalog/commands.csv"
COMMANDS_DIR="$REPO/commands"
STATE_FILE="$REPO/control/state/active-profile.env"

if [ ! -f "$CATALOG" ]; then
  echo "[ERROR] 缺少 $CATALOG" >&2
  exit 2
fi

has_profile() {
  local field="$1" profile="$2" token
  IFS='|' read -r -a parts <<< "$field"
  for token in "${parts[@]}"; do
    [ "$token" = "$profile" ] && return 0
  done
  return 1
}

echo "激活 profile: $PROFILE"
activated=0
skipped=0

while IFS=, read -r name enabled source_kind _version source_rel profiles _tags; do
  [ "$name" = "name" ] && continue
  [ -z "$name" ] && continue
  [ "$enabled" != "1" ] && continue

  target="$COMMANDS_DIR/${name}.md"

  if ! has_profile "$profiles" "$PROFILE"; then
    # 此 profile 不包含的 command：移除 symlink（若存在）
    if [ -L "$target" ]; then
      rm "$target"
      echo "  [DEL] $name（不在 $PROFILE）"
    fi
    continue
  fi

  if [ "$source_kind" = "local" ]; then
    # local 命令：源文件即 target，无需 symlink
    if [ -f "$REPO/$source_rel" ]; then
      echo "  [OK ] $name (local)"
      activated=$((activated + 1))
    else
      echo "  [ERR] local 源不存在: $source_rel"
    fi
    continue
  fi

  # vendor 命令：创建 symlink
  source_abs="$REPO/$source_rel"
  if [ ! -f "$source_abs" ]; then
    echo "  [ERR] vendor 源不存在: $source_rel"
    continue
  fi

  ln -sf "$source_abs" "$target"
  echo "  [OK ] $name -> $source_rel"
  activated=$((activated + 1))
done < "$CATALOG"

# 保存激活的 profile
mkdir -p "$(dirname "$STATE_FILE")"
echo "PROFILE=$PROFILE" > "$STATE_FILE"

echo ""
echo "[INFO] activated=$activated skipped=$skipped profile=$PROFILE"
