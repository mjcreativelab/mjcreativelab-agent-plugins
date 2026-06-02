#!/usr/bin/env bash
set -euo pipefail

# Smart Git Sync
# デフォルトブランチに切り替え、リモート同期し、マージ済み・リモート削除済み・squash マージ済みブランチを一覧表示する。

# --- 1. 未コミット変更チェック ---
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠️  未コミットの変更があります:"
  git status --short
  echo ""
  echo "UNCOMMITTED_CHANGES=true"
  # ここで終了し、Claude がユーザーに続行を確認する。
  # 続行する場合は SKIP_UNCOMMITTED_CHECK=1 を設定して再実行される。
  if [ "${SKIP_UNCOMMITTED_CHECK:-0}" != "1" ]; then
    exit 0
  fi
fi

# --- 2. デフォルトブランチ特定 ---
DEFAULT_BRANCH=""
for candidate in develop main master; do
  if git show-ref --verify --quiet "refs/heads/$candidate"; then
    DEFAULT_BRANCH="$candidate"
    break
  fi
done

if [ -z "$DEFAULT_BRANCH" ]; then
  echo "ERROR: デフォルトブランチ (develop/main/master) が見つかりません"
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- 3. チェックアウト & 同期 ---
if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
  echo "SWITCHING_FROM=$CURRENT_BRANCH"
  git checkout "$DEFAULT_BRANCH"
else
  echo "ALREADY_ON_DEFAULT=true"
fi

git fetch --prune

if ! git pull 2>/tmp/git-sync-pull-err; then
  echo "PULL_FAILED=true"
  echo "PULL_ERROR<<EOF"
  cat /tmp/git-sync-pull-err
  echo "EOF"
  exit 0
fi

# --- 4. マージ済みブランチ一覧 ---
PROTECTED_PATTERN='^\*|^[[:space:]]*(main|master|develop)$|^[[:space:]]*release/|^[[:space:]]*hotfix/'
MERGED_BRANCHES=$(git branch --merged | grep -vE "$PROTECTED_PATTERN" || true)

if [ -z "$MERGED_BRANCHES" ]; then
  echo "DELETE_CANDIDATES=none"
else
  echo "DELETE_CANDIDATES<<EOF"
  echo "$MERGED_BRANCHES"
  echo "EOF"
fi

# --- 5. リモート削除済みブランチ一覧 ---
GONE_BRANCHES=""
while IFS= read -r line; do
  if echo "$line" | grep -q '\[.*: gone\]'; then
    branch=$(echo "$line" | sed 's/^[* ]*//' | awk '{print $1}')
    if echo "$branch" | grep -qE '^(main|master|develop)$|^release/|^hotfix/'; then
      continue
    fi
    if [ -n "$MERGED_BRANCHES" ] && echo "$MERGED_BRANCHES" | grep -qw "$branch"; then
      continue
    fi
    GONE_BRANCHES="${GONE_BRANCHES:+$GONE_BRANCHES
}$branch"
  fi
done <<< "$(git branch -vv)"

if [ -z "$GONE_BRANCHES" ]; then
  echo "GONE_CANDIDATES=none"
else
  echo "GONE_CANDIDATES<<EOF"
  echo "$GONE_BRANCHES"
  echo "EOF"
fi

# --- 6. Squash マージ済みブランチ検出 ---
SQUASH_BRANCHES=""
while IFS= read -r branch; do
  branch=$(echo "$branch" | sed 's/^[* ]*//')
  [ -z "$branch" ] && continue
  if echo "$branch" | grep -qE '^(main|master|develop)$|^release/|^hotfix/'; then
    continue
  fi
  if [ -n "$MERGED_BRANCHES" ] && echo "$MERGED_BRANCHES" | grep -qw "$branch"; then
    continue
  fi
  if [ -n "$GONE_BRANCHES" ] && echo "$GONE_BRANCHES" | grep -qw "$branch"; then
    continue
  fi

  merge_base=$(git merge-base "$DEFAULT_BRANCH" "$branch" 2>/dev/null) || continue
  tree=$(git rev-parse "$branch^{tree}" 2>/dev/null) || continue
  dangling_commit=$(git commit-tree "$tree" -p "$merge_base" -m "temp" 2>/dev/null) || continue
  cherry_result=$(git cherry "$DEFAULT_BRANCH" "$dangling_commit" "$merge_base" 2>/dev/null) || continue

  if [ -n "$cherry_result" ] && ! echo "$cherry_result" | grep -q '^+'; then
    SQUASH_BRANCHES="${SQUASH_BRANCHES:+$SQUASH_BRANCHES
}$branch"
  fi
done <<< "$(git branch | grep -vE "$PROTECTED_PATTERN")"

if [ -z "$SQUASH_BRANCHES" ]; then
  echo "SQUASH_CANDIDATES=none"
else
  echo "SQUASH_CANDIDATES<<EOF"
  echo "$SQUASH_BRANCHES"
  echo "EOF"
fi

# --- 7. 現在の状態 ---
echo ""
echo "BRANCH=$DEFAULT_BRANCH"
echo "RECENT_COMMITS<<EOF"
git log --oneline -5
echo "EOF"
echo "REMAINING_BRANCHES<<EOF"
git branch
echo "EOF"
