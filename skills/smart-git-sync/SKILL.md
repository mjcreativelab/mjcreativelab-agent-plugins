---
name: smart-git-sync
description: デフォルトブランチ（develop or main）にチェックアウトし、fetch/pull してマージ済みブランチを削除する。ユーザーが「同期して」「ブランチ整理」「/smart-git-sync」と言ったら起動する。
disable-model-invocation: true
allowed-tools: Read, Bash
model: claude-sonnet-4-6
---

# Smart Git Sync

[assets/git-sync.sh](assets/git-sync.sh) を読み込んで実行する。

zsh ではインライン実行しないこと（正規表現がグロブ展開されるため）。
一時ファイルに書き出して `bash` で実行するか、`bash /dev/stdin` 経由で渡す。
一時ファイルの明示削除は不要（OS の一時領域に任せる）。

## 出力の解釈と対応

スクリプトは構造化された出力を返す。以下の順序で解釈する:

### 早期終了ケース

1. **`UNCOMMITTED_CHANGES=true`** → ユーザーに未コミット変更の一覧を見せ、続行するか確認する。続行する場合は `SKIP_UNCOMMITTED_CHECK=1` を環境変数に設定してスクリプトを再実行する
2. **`PULL_FAILED=true`** → `PULL_ERROR` の内容を表示し、原因（コンフリクト等）と対処法を案内する。スクリプトの再実行はしない

### 正常完了ケース

3. **`DELETE_CANDIDATES=none`** → 「削除対象のマージ済みブランチはありません」と報告
4. **`DELETE_CANDIDATES`** にブランチ一覧がある場合 → 一覧を表示しユーザーに確認。`WORKTREE_CANDIDATES` に同じブランチ名の `merged|<branch>|<path>` エントリがあれば worktree パスを併記する。承認後、worktree が紐づくブランチは `git worktree remove <path>` → `git branch -d <branch>` の順で、紐づかないブランチは従来どおり `git branch -d <branch>` のみで削除する
5. **`GONE_CANDIDATES`** にブランチ一覧がある場合 → 「リモートで削除済み」として一覧を表示しユーザーに確認。`WORKTREE_CANDIDATES` に同じブランチ名の `gone|<branch>|<path>` エントリがあれば worktree パスを併記する。承認後、worktree が紐づくブランチは `git worktree remove <path>` → `git branch -D <branch>` の順で、紐づかないブランチは従来どおり `git branch -D <branch>` のみで削除する
6. **`SQUASH_CANDIDATES`** にブランチ一覧がある場合 → 「squash マージ済み（未マージ扱い）」として一覧を表示しユーザーに確認。`WORKTREE_CANDIDATES` に同じブランチ名の `squash|<branch>|<path>` エントリがあれば worktree パスを併記する。承認後、worktree が紐づくブランチは `git worktree remove <path>` → `git branch -D <branch>` の順で、紐づかないブランチは従来どおり `git branch -D <branch>` のみで削除する
7. 最後に `BRANCH`, `RECENT_COMMITS`, `REMAINING_BRANCHES` を使って結果を報告する

### 補助情報

- **`SWITCHING_FROM=<branch>`** → 元のブランチ名。報告に含めると親切
- **`ALREADY_ON_DEFAULT=true`** → すでにデフォルトブランチにいた旨を報告
- **`WORKTREE_SKIPPED`** にブランチ一覧がある場合 → 「未コミット変更が残っているため worktree 削除をスキップしたブランチ」として報告に含める（削除はしない）

## 削除時の注意

- マージ済みブランチ (`DELETE_CANDIDATES`) → `git branch -d`（安全な削除）
- リモート削除済み・squash マージ済みブランチ (`GONE_CANDIDATES`, `SQUASH_CANDIDATES`) → `git branch -D`（強制削除）
- 3種類を分けて表示し、それぞれ個別にユーザー確認を取ること
- 一括削除ではなく種類ごとに確認・削除を行う
- worktree が紐づく削除候補は、**先に `git worktree remove <path>` を実行してから** ブランチを削除する（逆順だと worktree で使用中のためブランチ削除が失敗する）
- worktree 内に未コミット変更が残っている場合は `WORKTREE_SKIPPED` として自動的に削除候補から除外されている（`git worktree remove` 自体も未コミット変更があれば失敗するため、tracked/staged な変更に対しては二重に安全）。ただしこの検出は `git status --porcelain` ベースで `.gitignore` されたファイル（`.env` や `node_modules` 等）までは見ていない — そうしたファイルしか無い worktree は「クリーン」と判定され、`git worktree remove` はディレクトリごと削除するためこれらのファイルも失われる（どちらの安全層でもカバーされない）
- main worktree・現在の worktree は候補に含まれない
- `WORKTREE_SKIPPED` に挙がっているブランチ、または `git branch -d`/`-D` が「used by worktree」等のエラーで失敗したブランチは、リトライせずそのブランチの削除だけをスキップする。どのブランチをなぜスキップしたか（worktree の未コミット変更 / 未検出の別 worktree で使用中）をユーザーに報告する
