# smart-review — Empirical Tuning 設計書

対象: `skills/smart-review/SKILL.md`

## Iteration 0 状態

- `disable-model-invocation: true` を追加済み
- `allowed-tools` に `Write` を追加済み
- body は変更なし。iter 1 から開始可

## シナリオ

### 中央値シナリオ A: Issue 番号あり、5 ファイル変更

feature ブランチ `feature/issue-134-login-validation` にいる。

- `main` と比較して 3 コミット ahead
- 変更ファイル:
  ```
  src/auth/validator.ts        +45 -12   # 入力バリデーション追加
  src/auth/validator.test.ts   +80  -0   # テスト追加
  src/auth/login.ts            +10  -3   # validator 呼び出し追加
  docs/auth.md                  +5  -0
  src/auth/errors.ts           +15  -0   # 新規エラー型
  ```
- Issue #134: 「ログインフォームの入力検証強化」
  - 受け入れ基準: 空文字・スペースのみの入力を弾く / エラーメッセージを日本語で表示 / 既存ログインフローを壊さない

実行コマンド: `/smart-review #134`

### Edge シナリオ B: 20 ファイル超の大規模変更、Issue なし

feature ブランチ `refactor/extract-utils-20260415` にいる。

- 変更ファイル 25 個
  - ビジネスロジック（src/payment/*.ts 等）: 8 個
  - ユーティリティ抽出（src/utils/*.ts）: 10 個
  - テスト: 5 個
  - 自動生成ファイル（openapi.d.ts 等）: 2 個
- ブランチ名から Issue 番号抽出不可
- 引数なし

実行コマンド: `/smart-review`

### Edge シナリオ C: `-o` でファイル出力 + `-p` で観点追加

feature ブランチ `feature/issue-42-add-oauth` にいる。シナリオ A と同じ規模の変更。

実行コマンド: `/smart-review -p セキュリティを重点的に -o reviews/oauth.md`

## 要件チェックリスト

### シナリオ A

1. **[critical]** Issue #134 の受け入れ基準（空文字弾く / 日本語メッセージ / 既存フロー維持）それぞれに対して適合判定がある
2. **[critical]** 指摘に重要度マーカー（🔴/🟡/🟢）が付いている
3. **[critical]** 指摘にファイル名と行番号が含まれる
4. 主観的スタイル指摘（命名好みなど）がない
5. 🟡 指摘は最大 5 件
6. 🟢 指摘は 1-3 個
7. 差分対象外のコードへの指摘が混入していない
8. レビュー結果は日本語で記述されている

### シナリオ B

1. **[critical]** `--stat` から高優先度ファイル（src/payment/*.ts 等ビジネスロジック）を優先して Read している
2. 自動生成ファイル（openapi.d.ts 等）を深追いしていない
3. 変更された utils の呼び出し元を Grep で確認している（影響範囲判定）
4. 低優先度ファイル（テスト、自動生成）で stat が異常に大きい場合のみ踏み込む
5. Issue 番号なしなので「要件適合」観点は追加されていない
6. 指摘が 20 個超のノイズにならない（🟡 は 5 件以内）

### シナリオ C

1. **[critical]** `-p` のセキュリティ重点指示が反映され、認可・機密情報・入力バリデーション観点で掘り下げがある
2. **[critical]** `reviews/oauth.md` に同じ内容が出力されている（空ファイルではない）
3. 会話内にも同じ内容が出力されている
4. 既存の必須観点（バグリスク、コード品質、テスト）も維持されている

## 着眼点

- Step 4 の「コンテキスト圧縮時の diff 再実行」が subagent に認知されるか
- 指摘数の目安（🔴: 全件、🟡: 5 件まで、🟢: 1-3 個）が実際に守られるか
- 高優先度ファイル分類が decision-tree として機能するか
- `references/review-format.md` を subagent が自発的に読むか（`tool_uses` での参照）

## 修正方針候補

- Step 4 の 🔴/🟡/🟢 判定基準を具体例付きで補強
- Step 3 の「差分が大きい場合」の 20 ファイル閾値を数値のまま維持するか、ファイル数ではなく diff 行数で判定するか検討
- `-o` 出力時のファイルパス相対/絶対の扱いを明記（現状は曖昧）
