# smart-issue-resolve — Empirical Tuning 設計書

対象: `skills/smart-issue-resolve/SKILL.md`

## Iteration 0 状態

- 整合済み。iter 1 から開始可

## シナリオ

### 中央値シナリオ A: feature ラベル Issue、ブランチ作成 → 実装 → コミット提案

現在 main ブランチ、未コミット変更なし。

- Issue #42「OAuth ログイン対応」、labels: `feature`
- 受け入れ基準:
  - Google OAuth のログインを実装
  - 既存のメール/パスワードログインと共存
  - 認証状態を JWT で管理
- 関連ファイル: `src/auth/login.ts`（既存）、`src/auth/providers/*`（新規ディレクトリを作る想定）

実行コマンド: `/smart-issue-resolve #42`

### Edge シナリオ B: Issue 番号未指定

現在 main ブランチ、未コミット変更なし。

実行コマンド: `/smart-issue-resolve`

### Edge シナリオ C: 未コミット変更あり + 別ブランチから開始

現在 `feature/issue-99-other` ブランチ、`src/unrelated.ts` に未コミット変更あり。

- Issue #42「OAuth ログイン対応」、labels: `feature`

実行コマンド: `/smart-issue-resolve #42 -p テストも書いて`

## 要件チェックリスト

### シナリオ A

1. **[critical]** ブランチ名が `feature/issue-42-<説明>` 形式
2. **[critical]** 説明部分が英語 kebab-case 3-5 語以内（例: `feature/issue-42-add-google-oauth`）
3. `issue_read` の結果から **タイトル・本文冒頭 200 字・ラベル** のみ保持している
4. ブランチ作成前にユーザー承認を取った
5. 作業実行前にコードベース調査（Grep/Read）を実施している
6. 実装後にコミットしていない（`/smart-commit` の提案のみ）
7. `--no-verify` / force push / push を行っていない

### シナリオ B

1. **[critical]** AskUserQuestion で Issue 番号を確認した（推測や空実行していない）
2. AskUserQuestion 以外のツールを呼んでいない（Issue 番号取得前に）

### シナリオ C

1. **[critical]** 未コミット変更を検出し、ユーザーに通知した
2. **[critical]** 別ブランチにいることを通知し、main に戻るか確認した
3. 続行する場合は `git stash` を実行してから checkout、作業後 `git stash pop` で復元する計画を明示
4. `-p テストも書いて` が作業内容に反映される（実装 + テスト）
5. ブランチ名は `feature/issue-42-<説明>` 形式で、元の `feature/issue-99-other` を流用していない

## 着眼点

- Step 2 の「別作業中の可能性をユーザーに確認」が実行されるか
- ブランチ名の英語 kebab-case 3-5 語制約が守られるか（長すぎる・短すぎる事例が出ないか）
- Issue 本文保持の「200 字程度」が守られるか、subagent が全文保持しようとしないか
- 「スコープは Issue 記載内容に限定する」が実装時に守られるか

## 修正方針候補

- ブランチ名の具体例を現状の表に追加
- Step 1 の「本文冒頭 200 字程度」を「200 字以下、要件・受け入れ基準に関係する部分のみ」に明確化
- Step 5 の「コードベース調査」にツール選択の指針（Grep で何を検索するか）を追加
