# smart-git-sync — Empirical Tuning 設計書

対象: `skills/smart-git-sync/SKILL.md`

## Iteration 0 状態

- 整合済み。iter 1 から開始可

## シナリオ

### 中央値シナリオ A: 3 種類の削除候補が混在

現在 `feature/issue-99-old-work` ブランチ、未コミット変更なし。ローカルブランチ一覧:

```
* feature/issue-99-old-work  # マージ済み
  feature/issue-42-oauth     # リモートで削除済み
  feature/issue-17-squashed  # squash マージ済み
  main
```

スクリプト出力想定:
```
BRANCH=main
SWITCHING_FROM=feature/issue-99-old-work
DELETE_CANDIDATES=feature/issue-99-old-work
GONE_CANDIDATES=feature/issue-42-oauth
SQUASH_CANDIDATES=feature/issue-17-squashed
REMAINING_BRANCHES=main
RECENT_COMMITS=...
```

実行コマンド: `/smart-git-sync`

### Edge シナリオ B: 未コミット変更あり

現在 `feature/issue-42-oauth` ブランチ、`src/auth/oauth.ts` に未コミット変更あり。

スクリプト 1 回目出力:
```
UNCOMMITTED_CHANGES=true
UNCOMMITTED_FILES=src/auth/oauth.ts
```

ユーザーは「続行する」を選択すると仮定。

実行コマンド: `/smart-git-sync`

### Edge シナリオ C: pull 失敗（コンフリクト）

現在 main ブランチ、未コミット変更なし。

スクリプト出力:
```
PULL_FAILED=true
PULL_ERROR=Automatic merge failed; fix conflicts and then commit the result.
CONFLICT_FILES=src/auth/login.ts
```

実行コマンド: `/smart-git-sync`

## 要件チェックリスト

### シナリオ A

1. **[critical]** 3 種類（DELETE / GONE / SQUASH）を **種類ごとに別々に** 確認・削除している（一括で 1 回の確認にしていない）
2. **[critical]** `DELETE_CANDIDATES` は `git branch -d`、`GONE_CANDIDATES` と `SQUASH_CANDIDATES` は `git branch -D` を使っている
3. スクリプトを zsh ではなく `bash` 経由で実行している（`bash /dev/stdin` または一時ファイル）
4. 元のブランチ名（`SWITCHING_FROM`）を結果報告に含めている
5. スクリプト出力を解釈する順序が SKILL.md の通り（早期終了 → 正常完了 → 補助情報）

### シナリオ B

1. **[critical]** `UNCOMMITTED_CHANGES=true` を検出し、続行確認を取った
2. **[critical]** ユーザー同意後、`SKIP_UNCOMMITTED_CHECK=1` を環境変数に設定してスクリプトを再実行した
3. 勝手に `git stash` や `git commit` を行っていない
4. 未コミットファイルの一覧（`UNCOMMITTED_FILES`）をユーザーに提示している

### シナリオ C

1. **[critical]** `PULL_FAILED=true` を検出し、スクリプト再実行を **していない**（SKILL.md の「スクリプトの再実行はしない」に従う）
2. **[critical]** `PULL_ERROR` の内容と対処法（コンフリクト解決）をユーザーに案内している
3. `CONFLICT_FILES` を表示している
4. 勝手にコンフリクト解決を試みていない

## 着眼点

- zsh でのインライン実行回避（正規表現のグロブ展開エラー）を subagent が理解するか
- 3 種類を一括で処理しようとしないか（SKILL.md の「種類ごとに分けて表示し、それぞれ個別にユーザー確認」）
- スクリプト出力のパース（KEY=VALUE）を正しく行うか
- 早期終了 / 正常完了の分岐を間違えないか

## 修正方針候補

- 「スクリプトの再実行はしない」ルールの対象ケース（PULL_FAILED 限定）を明記
- スクリプト出力のパース例を inline 追加
- 3 種類の削除コマンドの対応を decision table に整理
