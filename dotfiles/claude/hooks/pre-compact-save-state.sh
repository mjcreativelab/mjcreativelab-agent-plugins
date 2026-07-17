#!/bin/bash
# PreCompact hook: セッション状態を ~/.claude/auto-resume/<session-id>.md に保存
# 発火タイミング: Claude Code がコンテキスト圧縮を行う直前
# 内容: 最終 10 メッセージ要約 + Task List + Resume プロンプト雛形
set -euo pipefail

payload="$(cat)"

session_id="$(echo "$payload" | jq -r '.session_id // empty')"
transcript_path="$(echo "$payload" | jq -r '.transcript_path // empty')"

[ -z "$session_id" ] && exit 0

output_dir="$HOME/.claude/auto-resume"
mkdir -p "$output_dir"
output_file="$output_dir/${session_id}.md"

{
  echo "# Auto-resume snapshot"
  echo ""
  echo "**Session ID**: $session_id"
  echo "**Saved at**: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "**Transcript**: $transcript_path"
  echo ""
  echo "## 最終 10 メッセージ要約"
  echo ""
} > "$output_file"

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  jq -s -r '
    [ .[] | select(.type == "user" or .type == "assistant") ]
    | .[-10:]
    | .[]
    | "### " + .type + " (" + ((.timestamp // "")[0:19]) + ")\n\n"
      + (
          .message.content as $c
          | if ($c | type) == "string" then $c
            elif ($c | type) == "array" then
              ( [ $c[]? | select(.type == "text") | .text ] | join(" ") )
            else ($c | tostring) end
        )[:400]
      + "\n"
  ' "$transcript_path" >> "$output_file" 2>/dev/null || echo "(transcript 読み込み失敗)" >> "$output_file"
fi

{
  echo ""
  echo "## Task List"
  echo ""
} >> "$output_file"

tasks_dir="$HOME/.claude/tasks/$session_id"
if [ -d "$tasks_dir" ] && [ -n "$(ls -A "$tasks_dir" 2>/dev/null)" ]; then
  for f in "$tasks_dir"/*.json; do
    [ -f "$f" ] || continue
    jq -r '"- [\(.status)] #\(.id) \(.subject)"' "$f" 2>/dev/null || true
  done >> "$output_file"
else
  echo "(タスクなし)" >> "$output_file"
fi

{
  echo ""
  echo "## Resume prompt"
  echo ""
  echo '```'
  echo "@$output_file を読んで続きから再開して"
  echo '```'
} >> "$output_file"

exit 0
