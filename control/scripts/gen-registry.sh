#!/usr/bin/env bash
# gen-registry.sh — 从 control/catalog/commands.csv 生成 commands/registry.csv
# 用法：control/scripts/gen-registry.sh

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO/control/catalog/commands.csv"
REGISTRY="$REPO/commands/registry.csv"

if [ ! -f "$CATALOG" ]; then
  echo "[ERROR] 缺少 $CATALOG" >&2
  exit 2
fi

{
  echo "name,version,status,source_kind,owner"
  while IFS=, read -r name enabled source_kind version _source_rel _profiles _tags; do
    [ "$name" = "name" ] && continue
    [ -z "$name" ] && continue
    status="active"
    [ "$enabled" != "1" ] && status="disabled"
    echo "$name,$version,$status,$source_kind,global"
  done < "$CATALOG"
} > "$REGISTRY"

echo "[INFO] 已生成 $REGISTRY（$(grep -c '' "$REGISTRY") 行）"
