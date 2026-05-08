#!/usr/bin/env bash
# SessionStart hook — 每次会话开始时注入 using-skills 元 skill
# Claude Code 格式：输出 hookSpecificOutput.additionalContext JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
USING_SKILLS="${CLAUDE_DIR}/commands/using-skills.md"

# 读取 using-skills 内容
if [ ! -f "$USING_SKILLS" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}'
  exit 0
fi

content=$(cat "$USING_SKILLS")

# JSON 转义
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

escaped=$(escape_json "$content")

context="<EXTREMELY_IMPORTANT>\nYou have skills (slash commands) available.\n\n**Below is the full content of your 'using-skills' skill — your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${escaped}\n</EXTREMELY_IMPORTANT>"
context_escaped=$(escape_json "$context")

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$context_escaped"
exit 0
