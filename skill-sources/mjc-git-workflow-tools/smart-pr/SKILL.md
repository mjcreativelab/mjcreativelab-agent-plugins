---
name: smart-pr
description: >
  現在のブランチから GitHub Pull Request を作成または更新する。作業内容の自動要約・ラベル付与・関連 Issue 紐づけを行う。
  必要に応じてデフォルトブランチを現在のブランチへマージしてから push する（副作用あり）。
  「PR 作って」「プルリク作成」「PR 更新して」「/smart-pr」と言ったら起動する。
  コミット（smart-commit）やレビュー（smart-review）とは別物。
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep, AskUserQuestion
argument-hint: "[-p <prompt>]"
---

# Smart PR

現在のブランチから PR を作成、または既存 PR を更新する。

## 引数の解析

`$ARGUMENTS` を以下のルールで解析する:

- `-p` がある場合 → `-p` より後の部分を `{プロンプト}` として保持する
- `-p` がない場合 → `{プロンプト}` は空
- `{プロンプト}` は PR のタイトル・本文・ラベル等に関する追加指示として使う

例: `-p ドラフトで作って` / `-p レビュアー向け補足に移行手順を書いて`

## プロジェクト規約

本スキルは以下の規約に従う。詳細は [references/git-conventions.md](references/git-conventions.md) を参照（必要時のみ Read）。プロジェクト側の `CLAUDE.md` / `AGENTS.md` / `README` に独自規約があればそちらを優先する。

- **デフォルトブランチへの直接 push 禁止**。force push もしない。
- **PR / Issue 作成時は作成者を自動アサイン**（`get_me` でログイン名取得 → `issue_write` の `assignees` に渡す）。
- **既存ラベルのみ付与**。新規ラベル作成は提案しない。
- **`issue_write` の `labels` は上書き**のため、既存ラベルを取得して結合する。
- **MCP の `body` パラメータには実改行を含める**（`\n` リテラルは禁止）。

## ツール選択

- GitHub API 操作 → **GitHub MCP ツール**を優先（承認不要・パラメータ明示）。
- git 操作 → Bash。
- `git remote get-url origin` の出力（`git@github.com:owner/repo.git` または `https://github.com/owner/repo.git`）から `owner` / `repo` を抽出して MCP の必須パラメータに渡す。`.git` 拡張子は除去する。

> **MCP ツール名について**: 本 SKILL.md では GitHub MCP サーバーが提供する `list_pull_requests` / `pull_request_read` / `update_pull_request` / `create_pull_request` / `issue_write` / `get_me` / `list_issues` / `search_issues` を short name で記載する。実際の呼び出し時は環境上のフルネーム（例: `mcp__plugin_github_github__list_pull_requests` 等）にマップする。複数 MCP サーバーで名前が衝突する場合はサーバー名を含む完全修飾名を使う。

## 手順

### 1. 状態確認

#### 1-a. ローカル状態の取得（Bash 並列）

```bash
git remote get-url origin && git branch --show-current && git status --short
```

#### 1-b. デフォルトブランチの検出

まず `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'` を試す。空文字列が返ったら以下のフォールバックを使う:

```bash
for name in develop main master; do
  git show-ref --verify --quiet "refs/remotes/origin/$name" && echo "$name" && break
done
```

検出できなければユーザーに確認する。

#### 1-c. MCP 並列呼び出し

- `list_pull_requests`（`owner`, `repo`, `head: "<owner>:<branch>"`, `state: "open"`）で既存 PR を検索
- `get_me` でアサイン用ログイン名を取得

`list_pull_requests` レスポンスからは **`number` / `title` / `body` / `labels`** のみ保持し、他フィールド（タイムスタンプ・ユーザー詳細等）はコンテキストから破棄する。

#### 1-d. 判定

- デフォルトブランチにいる → 「作業ブランチで実行してください」と案内して終了
- デフォルトブランチと差分なし → 「PR にする変更がありません」で終了
- 未コミット変更あり → ユーザーに通知（`/smart-commit` を提案）
- PR が存在する → **更新フロー**（Step 4-U）へ
- PR が存在しない → **新規作成フロー**（Step 4-N）へ

### 2. デフォルトブランチとの同期確認

```bash
git fetch origin
git merge-base --is-ancestor origin/<default-branch> HEAD
```

含まれている場合はスキップ。含まれていない場合は behind しているので以下を実行する。

#### 2-a. behind 件数の確認とユーザー承認

```bash
git rev-list --count HEAD..origin/<default-branch>
```

「`origin/<default-branch>` に対して N コミット behind しています。マージしますか？」とユーザーに提示し、**承認を得てから** `git merge origin/<default-branch>` を実行する。件数が 0 でも提示する。

#### 2-b. 競合発生時

`git merge` が非 0 で終了した場合は競合あり。以下のコマンドで一覧を取得し、ファイル名のみをユーザーに提示する（ファイル内容を全 Read しない）:

```bash
git diff --name-only --diff-filter=U
```

ユーザーに以下の選択肢を提示する:
1. 個別ファイルを指定してもらい、`git diff <file>` で該当箇所のみ Read して解決方針を相談
2. `git merge --abort` で merge を取り消して中断

ユーザーの承認なしに `git add` / `git commit` しない。

### 3. 未プッシュコミットのプッシュ

```bash
git rev-parse --verify origin/<branch> 2>/dev/null
```

- 存在しない（リモート未追跡） → `git push -u origin <branch>`
- 存在する → 未プッシュコミットがあれば `git push`、なければスキップ

push 後、変更概要を取得:

```bash
git log --oneline <default-branch>..HEAD
git diff <default-branch>...HEAD --stat
```

`--stat` の合計行数が 1000 を大きく超える場合は、ファイル単位でサマリを作り、各ファイルは必要に応じて部分 Read に留める（diff 全文をコンテキストに乗せない）。

---

## 既存 PR 更新フロー

### 4-U. 差分特定・分析

`pull_request_read`（`owner`, `repo`, `pullNumber`）で現在の PR を取得し、以下のフィールドのみ保持する:

```json
{
  "number": 45,
  "title": "...",
  "body": "...",
  "labels": ["bug"]
}
```

他フィールド（コミット一覧・コメント・アサイン情報・タイムスタンプ等）はコンテキストから破棄する。`git log <default-branch>..HEAD` の出力と PR の commits との差分から、PR に未反映の新規コミットを特定する。

新規コミットがなければ「更新する変更がありません」で終了。

### 5-U. PR 本文の更新

既存本文を **構造解析**してから新規変更を追記する:

1. 既存本文の Markdown 見出し（`## 概要` / `## 変更内容` / `## レビュアー向け補足` / `## 関連 Issue` 等）を正規表現で抽出する。見出しレベルが `##` でない場合は本文の表記に合わせる。
2. 新規コミット種別と引数 `{プロンプト}` を以下のセクションへ振り分ける:

| 内容 | 振り分け先 |
|------|-----------|
| 機能追加・修正・テスト等のコード変更 | `## 変更内容`（末尾追記） |
| 引数 `{プロンプト}` の指示内容 | `{プロンプト}` で指定されたセクション、未指定なら `## レビュアー向け補足` |
| 設計判断・影響範囲・既知の制約 | `## レビュアー向け補足`（追記） |
| 新規 Issue 紐づけ | `## 関連 Issue`（追記） |
| 方向性が大きく変わる場合のみ | `## 概要`（提案 → 承認後更新） |

3. 既存記述は変更しない（追記のみ）。ラベルも追加のみ・削除しない。タイトルは原則変更しない。

### 6-U. ユーザー確認 → 更新実行

更新後の本文・追加ラベルをユーザーに提示し、承認を得る。

`update_pull_request`（`owner`, `repo`, `pullNumber`, `body`）で本文更新。**`body` パラメータは実改行で渡す**（`\n` リテラル禁止 — プロジェクト規約参照）。

ラベル追加が必要な場合は `issue_write` の `labels` に既存ラベル + 追加ラベルを結合した配列を渡す（上書きされるため）。

最後に PR URL を表示。

---

## 新規 PR 作成フロー

### 4-N. 作業内容の分析

`git log --oneline <default-branch>..HEAD` で全コミットを取得し、`git diff <default-branch>...HEAD --stat` で変更規模を把握する。`--stat` 合計が大きい場合はファイル単位サマリに留め、Claude が必要と判断したファイルのみ `git diff <default-branch>...HEAD -- <file>` で個別 Read する。変更概要・影響コンポーネント・関連 Issue を把握する。

### 5-N. 関連 Issue 探索

優先順位:

1. ブランチ名から `issue-(\d+)` 正規表現で抽出（例: `feature/issue-42-...` → `42`）
2. 1. で抽出できなければコミットメッセージ本文の `#NN` 表記を `git log` で検索
3. 2. でも見つからなければ `search_issues` で候補を探し、ユーザーに紐づけるか確認

`Closes #XX`（自動クローズ）または `Refs #XX`（参照のみ）を本文に記載。

### 6-N. ラベル選定

リポジトリの既存ラベルから変更種別に合致するものを選ぶ。既存ラベル一覧の取得手順:

- `list_issues`（`owner`, `repo`, `state: "all"`, `perPage: 30`）で取得した結果の `labels` フィールドからユニーク化する（MCP に `list_labels` 系がないため）
- プロジェクト側に独自のラベル運用ルール（CLAUDE.md・AGENTS.md・README 等）があればそれを優先する

汎用的な対応指針:

| 変更種別           | 推奨ラベル候補（リポジトリに存在するものを使う） |
| ------------------ | ------------------------------------------------ |
| 新機能・機能追加   | `feature`, `enhancement`                         |
| バグ修正           | `bug`, `fix`                                     |
| ドキュメント       | `documentation`, `docs`                          |
| ビルド・CI・依存   | `infra`, `chore`, `ci`                           |
| リファクタリング   | `refactor`                                       |
| テスト             | `test`                                           |

リポジトリに該当ラベルが存在しない場合はラベル無しでも可。新規ラベル作成は提案しない。

### 7-N. PR タイトル・本文作成

**タイトル**: `<type>(<scope>): <日本語説明>` — 70文字以内（`<type>` は smart-commit と同じ feat/fix/docs/refactor/chore/test/perf/style/build/ci）

タイトルの例:

| 変更概要 | タイトル |
|----------|----------|
| ユーザー検索 API を追加 | `feat(api): ユーザー検索エンドポイントを追加` |
| バリデーションの不具合を修正 | `fix(validation): null 入力時のバリデーション失敗を修正` |
| ログ整形ロジックを抽出 | `refactor(logger): 整形ロジックを util に抽出` |
| README にセットアップ手順を追加 | `docs(readme): ローカル開発のセットアップ手順を追加` |

**本文**: [assets/pr-template.md](assets/pr-template.md) を使用。

### 8-N. ユーザー確認 → 作成実行

タイトル・本文・ラベル・紐づけ Issue・ベースブランチを表示して承認を得る。

承認後:

1. `create_pull_request`（`owner`, `repo`, `title`, `body`, `head`, `base`）で作成。**`body` は実改行で渡す**（`\n` リテラル禁止）。
2. 戻り値の `number` を控える。
3. `issue_write`（`owner`, `repo`, `issueNumber: <PR番号>`, `assignees: [<get_me で取得したログイン>]`, `labels: <選定ラベル配列>`）でアサインとラベルを設定。

最後に PR URL を表示。

- ドラフト PR はユーザーの明示的指示がある場合のみ（`draft: true` を `create_pull_request` に渡す）。
- GitHub Project への自動追加はしない。

## コンテキスト管理

長い会話でコンテキスト圧縮が発生した場合、以下を再取得する:

- `git remote get-url origin` → owner/repo
- `git branch --show-current` → ブランチ名
- デフォルトブランチ名（Step 1-b の手順）

ただし本スキルは新規セッションでの実行を推奨しており（README 参照）、通常は圧縮が発生しない。

## 注意事項

- **MCP ツールの `body` パラメータには実改行を含める**（`\n` リテラルは GitHub 上で 1 行表示になる）。Step 6-U / Step 8-N から本注意を再参照すること。
- `--no-verify` は使わない。
- force push はしない。
- ドラフト PR はユーザーの明示的指示がある場合のみ。
