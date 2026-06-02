# smart-commit — Empirical Tuning 設計書

対象: `skills/smart-commit/SKILL.md`

## Iteration 0 状態

- description は「ブランチ切替の副作用あり」を明記済み
- body は変更なし
- iter 1 から開始可

## シナリオ

### 中央値シナリオ A: 機能追加 + テスト + ドキュメント混在

feature ブランチ `feature/issue-42-add-oauth` にいる。以下の変更が working tree にある:

```
M  src/auth/oauth.ts          # OAuth 実装本体（新機能）
M  src/auth/oauth.test.ts     # 上記のテスト
M  docs/auth.md               # 認証ドキュメントの更新
M  README.md                  # README の legal セクションの typo 修正（機能と無関係）
?? .env.local                 # ローカル環境変数（untracked・機密疑いあり）
```

Issue #42 は「OAuth ログイン対応」。CLAUDE.md に `refactor` scope の定義はないが `auth` scope は暗黙的に使われている。

実行コマンド: `/smart-commit`

### Edge シナリオ B: main にいるまま変更を加えた

現在 `main` ブランチ。以下の変更が working tree にある:

```
M  src/cart/checkout.ts       # 決済ロジック修正
M  src/cart/checkout.test.ts
```

直近のブランチ一覧:
```
  feature/issue-99-cart-fix
  feature/issue-42-add-oauth
* main
```

実行コマンド: `/smart-commit`

### Edge シナリオ C: `-p` でフィルタ指示（ブランチ連動と競合）

feature ブランチ `feature/issue-42-add-oauth` にいる。以下の変更:

```
M  src/auth/oauth.ts          # OAuth 実装
M  src/billing/invoice.ts     # 請求まわり（ブランチ目的外）
M  e2e/auth.spec.ts           # E2E テスト
```

実行コマンド: `/smart-commit -p e2e の変更だけ`

## 要件チェックリスト

### シナリオ A

1. **[critical]** コミットが機能単位で分割されている（最低 2 単位、目安 3 単位: OAuth 実装 + テスト同梱 / docs 更新 / README typo）
2. **[critical]** メッセージが `<emoji> <type>(<scope>): <日本語 subject>` 形式で、subject は 50 文字以下・末尾ピリオドなし
3. `.env.local` を `.gitignore` 追加提案している（コミット対象に含めていない）
4. `git add` に `.` や `-A` ではなくファイル名を明示している
5. コミット実行前に「コミット計画」をユーザーに提示し承認を取った
6. `Co-Authored-By` トレーラーを付けていない
7. `--no-verify` / `push` を実行していない

### シナリオ B

1. **[critical]** main にいることを検出し、ブランチ切替 or 新規作成を提案した（勝手に commit していない）
2. **[critical]** ブランチ切替先を提案する際、ユーザー承認を取ってから実行する前提を明示した
3. 提案するブランチ名は ASCII 英数字 + ハイフン + スラッシュで、日本語を含まない
4. 既存ブランチ（feature/issue-99-cart-fix など）を流用するか新規作成するかを選択肢として提示した
5. stash → checkout → stash pop の順序を明示した

### シナリオ C

1. **[critical]** `-p e2e の変更だけ` を解釈し、e2e ファイルのみコミット対象に含めた
2. **[critical]** `-p` の指示をブランチ連動フィルタより優先している（src/billing/invoice.ts を除外、src/auth/oauth.ts も今回の対象外として working tree に残す明示）
3. コミット計画提示時に「除外したファイル」を明示している
4. コミット scope は e2e の内容に応じて決定している（`test` or `e2e` など妥当な scope）

## 着眼点

- スキル本体が 500 行以下に収まっているか
- Step 4「フィルタリング + コミット単位の分割」の指示が曖昧で subagent の解釈ブレを招いていないか
- Step 7 の HEREDOC 構文が書かれているが、ファイル名指定の `git add` 手順が具体的でないため subagent が `git add .` に戻ることがないか
- ブランチ切替フロー（stash → checkout → stash pop）が手順化されているか、subagent が stash 忘れ等をしないか

## 修正方針候補（iter 2 以降で subagent の不明瞭点に応じて選ぶ）

- Step 4 の分割基準に「どのレベルの違いがあれば別コミットにするか」の具体例を追加
- Step 7 に「git add のファイル名指定例」を inline 追加
- Step 2 のブランチ判定ロジックを decision table で明示化
