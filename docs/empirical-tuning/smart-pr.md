# smart-pr — Empirical Tuning 設計書

対象: `skills/smart-pr/SKILL.md`

## Iteration 0 状態

- description に「デフォルトブランチを merge する副作用」を追記済み
- iter 1 から開始可

## シナリオ

### 中央値シナリオ A: 新規 PR（Issue 紐づけあり）

feature ブランチ `feature/issue-42-add-oauth` にいる。

- リモートには既にブランチあり、最新 commit は push 済み
- デフォルトブランチ `main` と比較して 3 コミット ahead、0 コミット behind（同期済み）
- 既存 PR なし（`list_pull_requests` が空）
- Issue #42 はオープン、タイトル「OAuth ログイン対応」、labels: `feature`
- コミットメッセージに「refs #42」記載あり
- CLAUDE.md の PR ルール: 作成者を自動アサイン、適切なラベル付与

実行コマンド: `/smart-pr`

### Edge シナリオ B: 既存 PR を更新（新規コミット追加）

feature ブランチ `feature/issue-42-add-oauth` にいる。

- 既存 PR #100 がオープン。タイトル「feat(auth): OAuth ログイン対応」、labels: `feature`, `wip`
- 既存 PR 本文:
  ```
  ## 概要
  OAuth ログイン機能を追加

  ## 変更内容
  - OAuth プロバイダーの実装
  - ログインフローの統合

  ## 関連 Issue
  Refs #42
  ```
- ローカルに 2 コミット新規追加（テスト追加、エラーハンドリング改善）→ まだ push していない
- `main` と比較して behind なし

実行コマンド: `/smart-pr`

### Edge シナリオ C: デフォルトブランチが先行（merge 必要）

feature ブランチ `feature/issue-42-add-oauth` にいる。

- ローカルは push 済み
- `main` に新規コミットが 5 本入っている（behind=5）
- 既存 PR なし
- merge の結果、コンフリクトなし

実行コマンド: `/smart-pr`

## 要件チェックリスト

### シナリオ A

1. **[critical]** 新規作成フロー（Step 4-N）に分岐している
2. **[critical]** PR タイトルが `<type>(<scope>): <日本語>` 形式で 70 文字以内
3. **[critical]** PR body の改行が `\n` リテラルではなく実際の改行文字で MCP に渡す想定になっている
4. Issue #42 との紐づけ（`Closes #42` or `Refs #42`）が含まれる
5. ラベルが `feature` で選定されている
6. 作成者を自動アサインする前提（`get_me` で取得したユーザー名）を明示
7. 作成前に「タイトル・本文・ラベル・紐づけ Issue・ベースブランチ」を提示して承認を得た
8. `create_pull_request` の payload を出力した（dry-run）

### シナリオ B

1. **[critical]** 更新フロー（Step 4-U）に分岐している（`create_pull_request` を呼ばない）
2. **[critical]** 既存本文を破壊せず、新規変更分を末尾に追記している
3. `pull_request_read` の結果から **タイトル・本文・ラベル・番号のみ** をコンテキストに保持している旨を明示
4. ラベルは追加のみ（既存 `feature`, `wip` を削除しない）
5. タイトルは原則変更していない
6. push 未実施のコミットは Step 3 で push してから Step 4-U に進む
7. 承認を取ってから `update_pull_request` の payload を出力した

### シナリオ C

1. **[critical]** Step 2 でデフォルトブランチとの乖離を検出し、merge を提案した
2. **[critical]** merge 実行前にユーザーへ状況を提示している（勝手に merge していない前提、またはコンフリクト時のみ提示でも可）
3. merge 後に push し、その後 PR 作成フローへ進んでいる
4. 競合がない場合はスムーズに進む（余計な確認ループがない）

## 着眼点

- Step 1 の Bash 連結コマンドを subagent が正しく解釈できるか
- `symbolic-ref` 失敗時のフォールバック（develop → main → master）が使われるか
- MCP `body` の改行文字注意書き（注意事項）が遵守されるか（`\n` リテラルでない）
- 既存 PR ラベル保持ロジック（「上書きのため既存を取得して結合」）が遵守されるか

## 修正方針候補

- Step 2 の「merge 実行前にユーザー確認が必要か」の判定を明示化（コンフリクトなしなら自動でよいか？）
- 作成前承認の必須項目リストを明示
- MCP body の改行例を、「注意事項」に埋もれさせずフロー内に移動
