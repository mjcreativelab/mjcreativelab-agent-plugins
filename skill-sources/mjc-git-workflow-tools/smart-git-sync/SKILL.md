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
4. **`DELETE_CANDIDATES`** にブランチ一覧がある場合 → 一覧を表示しユーザーに確認。承認後 `git branch -d <branch>` で各ブランチを削除
5. **`GONE_CANDIDATES`** にブランチ一覧がある場合 → 「リモートで削除済み」として一覧を表示しユーザーに確認。承認後 `git branch -D <branch>` で削除
6. **`SQUASH_CANDIDATES`** にブランチ一覧がある場合 → 「squash マージ済み（未マージ扱い）」として一覧を表示しユーザーに確認。承認後 `git branch -D <branch>` で削除
7. 最後に `BRANCH`, `RECENT_COMMITS`, `REMAINING_BRANCHES` を使って結果を報告する

### 補助情報

- **`SWITCHING_FROM=<branch>`** → 元のブランチ名。報告に含めると親切
- **`ALREADY_ON_DEFAULT=true`** → すでにデフォルトブランチにいた旨を報告

## 削除時の注意

- マージ済みブランチ (`DELETE_CANDIDATES`) → `git branch -d`（安全な削除）
- リモート削除済み・squash マージ済みブランチ (`GONE_CANDIDATES`, `SQUASH_CANDIDATES`) → `git branch -D`（強制削除）
- 3種類を分けて表示し、それぞれ個別にユーザー確認を取ること
- 一括削除ではなく種類ごとに確認・削除を行う
