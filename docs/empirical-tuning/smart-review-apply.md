# smart-review-apply — Empirical Tuning 設計書

対象: `skills/smart-review-apply/SKILL.md`

## Iteration 0 状態

- `allowed-tools` を追加済み（Read, Bash, Glob, Grep, Edit, Write, AskUserQuestion）
- body は変更なし。iter 1 から開始可

## シナリオ

### 中央値シナリオ A: PR レビューコメント 4 件の適用

feature ブランチ `feature/issue-42-add-oauth` にいる。現在のブランチに PR #100 があり、以下のレビューコメントが付いている:

1. **🔴 バグ**: `src/auth/oauth.ts:42` — `null` チェックがなく実行時エラーになる可能性
2. **🔴 セキュリティ**: `src/auth/oauth.ts:78` — CSRF トークンが検証されていない
3. **🟡 提案**: `src/auth/login.ts:15` — エラーハンドリングを try/catch で統一したほうが保守性が高い
4. **💬 質問**: `src/auth/oauth.ts:120` — このリトライロジックの意図は？（3 回リトライ）

実行コマンド: `/smart-review-apply`

### Edge シナリオ B: `-f` でローカルファイル + `-p` でフィルタ

feature ブランチ `feature/issue-42-add-oauth` にいる。PR なし。`reviews/oauth.md` に以下の指摘がある:

1. 🔴 セキュリティ: CSRF 未検証（`src/auth/oauth.ts:78`）
2. 🔴 バグ: null チェック漏れ（`src/auth/oauth.ts:42`）
3. 🟡 提案: try/catch 統一（`src/auth/login.ts:15`）
4. 🟢 良い点: OAuth provider 抽象化が綺麗

実行コマンド: `/smart-review-apply -f reviews/oauth.md -p セキュリティ指摘のみ対応して`

### Edge シナリオ C: 会話コンテキストから読み取り

直前に `/smart-review` で以下が会話内に出力されている:

```
🔴 src/auth/oauth.ts:78 — CSRF 検証欠落
🟡 src/auth/login.ts:15 — try/catch 統一推奨
```

PR もレビューファイルも指定しない。

実行コマンド: `/smart-review-apply`

## 要件チェックリスト

### シナリオ A

1. **[critical]** フィードバック元特定で PR レビューコメントが選ばれた（Step 1 の優先順位通り）
2. **[critical]** 各フィードバックが 🔴/🟡/💬/✅ に分類されている
3. **[critical]** 対応方針を提示してユーザー承認を取った（勝手に修正していない前提の dry-run 出力）
4. 💬 質問には「コードで回答」または「返信で回答」の方針を選んでいる
5. `add_reply_to_pull_request_comment` の payload が各コメントに対応付けで用意されている（dry-run）
6. レビュー対象外のリファクタリングを含んでいない
7. 完了サマリー（対応件数の表）が含まれる

### シナリオ B

1. **[critical]** `-p セキュリティ指摘のみ対応して` が反映され、セキュリティ以外（バグ、提案）は触れていない or 明示的にスキップされている
2. **[critical]** `-f reviews/oauth.md` から正しく読み込み（ユーザーに「どこから読むか」を再確認していない）
3. スキップした指摘は理由付きで完了サマリーに含まれる
4. 🟢 良い点は「✅ 対応不要」として扱われている

### シナリオ C

1. **[critical]** 会話コンテキストのレビュー結果を優先順位 2 番目として検出している
2. PR があるか確認し、無ければ会話コンテキストに落ちている（順序通り）
3. AskUserQuestion で「どこから読むか」を聞き返していない（自動判定できるケース）

## 着眼点

- Step 1 の優先順位（PR → 会話 → ローカルファイル）が subagent に正しく伝わっているか
- `-f` 指定時は優先順位を飛ばすルールが遵守されているか
- `add_reply_to_pull_request_comment` の API パラメータ（comment_id, body）の生成が正しいか
- 変更はフィードバック箇所のみに限定されているか（スコープ逸脱しない）

## 修正方針候補

- Step 1 の優先順位に「`-f` 指定時はこのルールをバイパス」を明記
- Step 2 の分類テーブルに判定例を追加（subagent が 🟡 と 💬 を混同しないよう）
- Step 5 の返信フォーマット例を inline 追加（現在は外部例として参照）
