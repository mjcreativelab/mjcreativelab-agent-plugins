#!/bin/bash
# レビュー正本 diff.md（レビュー対象変更のスナップショット）を生成する。
#
# 使い方: bash {作業Dir}/gen-diff.sh <base-ref> <対象ラウンド>
#   例:     bash {作業Dir}/gen-diff.sh origin/main 1
#
# 出力先は本スクリプトと同じディレクトリの diff.md（= {作業Dir}/diff.md）。
# 呼び出し元はリポジトリの作業ツリー内で実行すること（git のカレントリポジトリを対象にする）。
#
# 硬い制約:
# - git は読み取り専用コマンドのみ使う（インデックス・作業ツリーを変更しない ＝ レビュー対象を汚さない）
# - base ref を先に検証し、解決できなければ非ゼロ終了して既存の diff.md を書き換えない
# - 一時ファイルへ書いてから mv する（途中失敗で「新しいスタンプ付きの不完全な diff.md」を残さない）
# - diff 本文をコードフェンスで囲まない（diff に ``` が含まれると入れ子が破綻するため BEGIN/END マーカーで区切る）
set -eu

# 変数展開は必ず ${VAR} 形式で書く（macOS の bash 3.2 は "$VAR（" のように全角文字が直後に来ると
# 変数名の切れ目を誤認して unbound variable になる）
BASE_REF="${1:-}"
ROUND="${2:-}"
if [ -z "${BASE_REF}" ] || [ -z "${ROUND}" ]; then
  echo "usage: bash gen-diff.sh <base-ref> <対象ラウンド>" >&2
  exit 2
fi

WORK_DIR=$(cd "$(dirname "$0")" && pwd)
OUT="${WORK_DIR}/diff.md"
TMP="${WORK_DIR}/.diff.md.tmp"

if ! git rev-parse --verify --quiet "${BASE_REF}" >/dev/null; then
  echo "gen-diff.sh: base ref '${BASE_REF}' を解決できない（diff.md は更新しない）" >&2
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_SHA=$(git rev-parse HEAD)

{
  echo "# diff スナップショット"
  echo
  echo "- 対象ラウンド: ${ROUND}"
  echo "- ブランチ: ${BRANCH}"
  echo "- 差分基準: ${BASE_REF}...HEAD + 未コミット変更（staged / unstaged / 未追跡）"
  echo "- HEAD: ${HEAD_SHA}（診断用。ループ中はエージェントがコミットしないため通常不変）"
  echo "- 注記: このファイルは長くなる。Read が truncate されたら offset を進めて続きを読む（どこまで読むかは依頼元プロンプトの「読み方」に従う）"
  echo
  echo "## 変更ファイル（コミット済み: --stat）"
  echo
  git --no-pager diff --stat "${BASE_REF}...HEAD"
  echo
  echo "## 変更ファイル（未コミット・tracked: --stat）"
  echo
  git --no-pager diff --stat HEAD
  echo
  echo "## 未追跡ファイル（一覧のみ。内容はリポジトリから直接 Read する）"
  echo
  git --no-pager status --porcelain --untracked-files=all | sed -n 's/^?? //p'
  echo
  echo "===== BEGIN COMMITTED DIFF ====="
  git --no-pager diff "${BASE_REF}...HEAD"
  echo "===== END COMMITTED DIFF ====="
  echo
  echo "===== BEGIN UNCOMMITTED DIFF ====="
  git --no-pager diff HEAD
  echo "===== END UNCOMMITTED DIFF ====="
} >"${TMP}"

mv "${TMP}" "${OUT}"
echo "gen-diff.sh: ${OUT} を生成した（対象ラウンド: ${ROUND}）"
