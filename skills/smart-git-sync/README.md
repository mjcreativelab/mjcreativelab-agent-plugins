# smart-git-sync

デフォルトブランチ（develop or main）にチェックアウトし、fetch/pull してマージ済みブランチを削除するスキル。

## 使い方

```
/smart-git-sync
```

または「同期して」「ブランチ整理」と伝える。

## 動作内容

1. 未コミット変更がある場合は警告して確認（続行 or 中止を選択可能）
2. デフォルトブランチ（develop > main > master の優先順）にチェックアウト
3. `git fetch --prune` と `git pull` でリモートと同期
4. 以下の3種類のブランチを検出し、種類ごとに確認後に削除
   - **マージ済みブランチ** — `git branch --merged` で検出、`-d` で安全に削除
   - **リモート削除済みブランチ** — upstream が `gone` のブランチを検出、`-D` で強制削除
   - **squash マージ済みブランチ** — `git commit-tree` + `git cherry` 方式で検出、`-D` で強制削除
5. 上記3種類の候補ブランチが git worktree で checkout されている場合、対応する worktree パスを一覧に併記する
   - worktree 内に未コミット変更がなければ削除候補に含める（承認後 `git worktree remove` → ブランチ削除の順で削除）
   - 未コミット変更が残っている worktree は自動的に削除候補から除外し、別途一覧報告する

## 安全性

- 未コミットの変更がある場合はスクリプトが早期終了し、ユーザー確認後にのみ続行
- `git pull` がコンフリクト等で失敗した場合はエラー内容を表示して停止
- `main`, `master`, `develop`, `release/*`, `hotfix/*` は削除対象外
- 3種類のブランチを分けて表示し、それぞれ個別にユーザー確認を取る
- マージ済みブランチは `git branch -d` で安全に削除
- リモート削除済み・squash マージ済みブランチのみ `git branch -D` を使用（検出ロジックで確認済みのもののみ）
- worktree 内に未コミット変更が残っている場合は自動的に削除候補から除外し、削除しない
- main worktree・現在作業中の worktree は削除候補に含めない
- worktree の削除は対応ブランチの削除より必ず先に行う

## 前提条件

- **git** のみ（GitHub MCP サーバーは不要）
