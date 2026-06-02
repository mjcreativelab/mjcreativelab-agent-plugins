# smart-issue-plan — Empirical Tuning 設計書

対象: `skills/smart-issue-plan/SKILL.md`

## Iteration 0 状態

- 整合済み。iter 1 から開始可

## シナリオ

### 中央値シナリオ A: 新規計画作成（既存計画なし）、Issue コメント投稿

Issue #134「ログインフォームの入力検証強化」

- labels: `enhancement`, `auth`
- 受け入れ基準:
  - 空文字・スペースのみの入力を弾く
  - エラーメッセージを日本語で表示
  - 既存ログインフローを壊さない
- コメントなし
- 関連リポジトリに `src/auth/login.ts`, `src/auth/validator.ts`, `tests/auth/*.test.ts` が存在

実行コマンド: `/smart-issue-plan #134`

### Edge シナリオ B: 既存計画あり、更新モード

Issue #42「OAuth ログイン対応」

- 2026-03-01 付けのコメントに「## 実装計画」見出しの既存計画あり（手順 5 つ列挙）
- `git log --oneline --since="2026-03-01"` で 3 コミットあり:
  - `feat(auth): OAuth provider 抽象化を追加`
  - `feat(auth): Google provider を実装`
  - `test(auth): OAuth provider のテストを追加`
- 計画の手順 1, 2 は実装済み相当、手順 3 は部分実装、手順 4, 5 は未着手

実行コマンド: `/smart-issue-plan #42`

### Edge シナリオ C: `-p` で観点追加、新規 Issue として作成

Issue #200「決済フロー全体のリファクタ」

- labels: `refactor`
- 大規模計画になる見込み（複数マイルストーン想定）
- 既存計画なし

実行コマンド: `/smart-issue-plan #200 -p パフォーマンスとトランザクション境界を重視して`

## 要件チェックリスト

### シナリオ A

1. **[critical]** コードベース探索を実施した（Grep / Glob / Read の tool_uses が複数ある）
2. **[critical]** 計画に「エントリポイント特定」「依存グラフ」「既存パターン」「境界条件」の 4 観点が含まれる
3. **[critical]** 出力先確認（Issue コメント or 新規 Issue）を AskUserQuestion で行った
4. `issue_read` の結果から **タイトル・本文・ラベル・直近 5 コメント以内** のみ保持している
5. 実装の詳細コード（関数の具体コード）を書いていない
6. `add_issue_comment` の payload に計画本文を含めた（dry-run 出力）

### シナリオ B

1. **[critical]** 既存計画を `search_issues` または コメント検索で検出し、更新モードに分岐した
2. **[critical]** 実装済み手順に完了マーク（✅）を付けた
3. `git log --since="<計画作成日>"` で計画作成後のコミットを確認している
4. 更新版を「新しいコメント」として投稿する前提で、前回コメントへのリンクを冒頭に入れている
5. 承認を取ってから `add_issue_comment` の payload を出力している

### シナリオ C

1. **[critical]** `-p` のパフォーマンス・トランザクション観点が計画に反映されている
2. **[critical]** 大規模と判断し「新規 Issue として作成」を提案・確認した
3. 新規 Issue タイトルは `[実装計画] 決済フロー全体のリファクタ` 形式
4. 元 Issue #200 への参照リンクを本文冒頭に記載
5. `issue_write` の payload（labels 含む）を出力している

## 着眼点

- コードベース探索を subagent が skip してしまう（Issue 本文だけで計画を書く）傾向がないか
- Step 4 の 4a〜4d サブステップを全て実行するか、一部を省略するか
- 出力先確認を AskUserQuestion で行うか、prose で聞くだけで済ませるか
- `assets/plan-template.md` を subagent が自発的に読むか

## 修正方針候補

- Step 4 の先頭に「本ステップは全てのサブステップを実施する」を明記（現状の「Step 4 の各ステップを確実に実行する」は注意事項に埋もれている）
- 出力先確認は AskUserQuestion 必須を明記
- `assets/plan-template.md` の参照を「必ず Read する」形で明示
