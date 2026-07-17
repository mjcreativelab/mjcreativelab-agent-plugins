#!/usr/bin/env bash
# Stop hook: コード編集後、検証コマンドの実行記録なしに「完了・修正済み」を主張して
# ターンを終えようとした場合に差し戻す（fable-engineering-judgment 規律 3 の機械的検査）。
# 判定できない状況ではすべて許可側に倒す（jq 不在・transcript 不在・パース失敗 = exit 0）。
set -u

command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)

# Stop hook による継続中の再ブロックはしない（無限ループ防止・強制は 1 stop につき 1 回）
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

# 最終メッセージは transcript ではなく last_assistant_message を使う（transcript は非同期書き込みでラグがある）
MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null)
[ -n "$MSG" ] || exit 0

# 完了・修正済みの主張がなければ対象外
CLAIM_RE='(完了しました|対応しました|修正しました|実装しました|直しました|解決しました|修正済み|対応済み|実装済み|完了です|テスト(は|が|も)通り|tests (now )?pass)'
printf '%s' "$MSG" | grep -qE "$CLAIM_RE" || exit 0

# 「未検証」の明記があれば通す（規律上の正しいもう一方の出口）
DISCLAIM_RE='(未検証|未確認|検証していません|検証はしていない|動作確認はして|not (yet )?verified|unverified)'
printf '%s' "$MSG" | grep -qE "$DISCLAIM_RE" && exit 0

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# transcript 末尾からツール実行イベントを時系列で抽出（EDIT: ファイル編集 / BASH: コマンド / VERIFY: 診断系）
EVENTS=$(tail -n 4000 "$TRANSCRIPT" 2>/dev/null | jq -R -r '
  fromjson? // empty
  | select(.type=="assistant")
  | .message.content[]?
  | select(.type=="tool_use")
  | if (.name | test("^(Edit|Write|NotebookEdit)$"))
      then "EDIT\t" + (.input.file_path // .input.notebook_path // "")
    elif (.name | test("^mcp__plugin_serena_serena__(replace_content|replace_symbol_body|insert_after_symbol|insert_before_symbol|rename_symbol)$"))
      then "EDIT\t" + (.input.relative_path // "")
    elif .name == "Bash"
      then "BASH\t" + ((.input.command // "") | gsub("[\\n\\t]"; " ") | .[0:400])
    elif (.name | test("^(mcp__ide__executeCode|mcp__plugin_serena_serena__get_diagnostics_for_file)$"))
      then "VERIFY\t-"
    else empty end
' 2>/dev/null) || exit 0
[ -n "$EVENTS" ] || exit 0

# コード拡張子（docs/設定ファイルの編集は対象外）と、検証とみなすコマンドのパターン
CODE_EXT_RE='\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|kt|kts|swift|rb|php|c|cc|cpp|h|hpp|cs|sh|bash|zsh|sql|dart|scala|vue|svelte|ipynb)$'
VERIFY_CMD_RE='(test|spec|lint|build|compile|check|verify|pytest|jest|vitest|playwright|tsc|eslint|biome|ruff|flake8|mypy|xcodebuild|gradle|mvn|cargo |go vet|go run|flutter|dart |swift |bash -n|node |npx |python|deno |ruby |php |mise exec)'

LAST_EDIT=0
LAST_VERIFY=0
i=0
while IFS=$'\t' read -r kind payload; do
  i=$((i + 1))
  case "$kind" in
    EDIT)   printf '%s' "$payload" | grep -qE "$CODE_EXT_RE" && LAST_EDIT=$i ;;
    BASH)   printf '%s' "$payload" | grep -qE "$VERIFY_CMD_RE" && LAST_VERIFY=$i ;;
    VERIFY) LAST_VERIFY=$i ;;
  esac
done <<EOF
$EVENTS
EOF

# コード編集がないターン（回答のみ・docs 等）は対象外
[ "$LAST_EDIT" -eq 0 ] && exit 0
# 最後のコード編集より後に検証実行があれば通す
[ "$LAST_VERIFY" -gt "$LAST_EDIT" ] && exit 0

jq -n '{
  decision: "block",
  reason: "[verify-before-claim hook] 完了・修正済みの主張を検出しましたが、最後のコード編集より後に検証コマンド（テスト・ビルド・lint・実行）の記録がありません。次のいずれかで報告し直してください: (1) 検証を実行し、その出力を根拠に完了を報告する。(2) このセッションで検証できない場合は「未検証」と明記し、何を実行すれば確認できるかを添える。"
}'
exit 0
