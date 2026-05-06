---
name: claude-code-update-review
description: >
  Claude Code のバージョンアップ後に、最新の公式推奨手法と現在の構成
  （settings.json / commands / rules / skills / CLAUDE.md 等）を照合して改善提案を行う。
  「Claude Code の最新機能」「アップデートレビュー」「設定見直し」「ベストプラクティス確認」
  「/claude-code-update-review」で起動。
  単一スキルの品質改善 (skill-improver) や PR/差分レビュー (smart-review) とは別物。
argument-hint: "[-p <prompt>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, WebSearch, WebFetch, AskUserQuestion
---

# Claude Code アップデートレビュー

Claude Code のバージョンが上がった際に、最新の公式推奨手法を調査し、ユーザーの現在の構成に合う改善を提案する。

## オプション

- `-p <プロンプト>`: 調査・提案の観点を追加指定（例: `-p hooks の活用を重点的に`）

## スコープ定義

**スコープ内**

- Claude Code の最新機能・設定・ベストプラクティスの調査
- 現在の `settings.json`（hooks / permissions / model / statusLine 等）との差分分析
- `commands/` `rules/` `skills/` の frontmatter 活用状況の確認
- `CLAUDE.md` / `AGENTS.md` の構成改善提案
- シンボリックリンク構成の最新推奨との照合

**スコープ外**

- Codex / Cursor / Gemini CLI 固有の機能調査（別途対応）
- 提案の自動実装（ユーザー承認後に個別実行）
- Claude Code 以外のツール・サービスの調査

## 手順

### Step 0: 引数の解析

`$ARGUMENTS` を以下のルールで解析する:

- `-p` より後の部分 → `{プロンプト}`（調査観点の追加指示）
- `-p` がない場合 → `{プロンプト}` は空

### Step 1: 現在のバージョンと構成の確認

以下を並列で収集する:

- `claude --version` で現在のバージョンを取得
- `~/.claude/settings.json`（ユーザー）と `./.claude/settings.json`（プロジェクト）両方の `hooks` / `permissions` / `model` / `statusLine` 構成を Read
- `~/.claude/commands/` および `./.claude/commands/` 配下の frontmatter 一覧（`allowed-tools`, `model`, `output`, `plan-mode` 等）を Grep で集計
- `~/.claude/rules/` および `./.claude/rules/` 配下の harness 補助セクションの有無を Grep で確認
- `~/.claude/skills/` および `./.claude/skills/` 配下のスキル定義を Glob で一覧化

設定ファイルやディレクトリが存在しない場合は「未設定」として記録し、次へ進む。

### Step 2: 最新の公式推奨手法の調査

以下のソースから情報を収集する:

- `claude --help` の出力から利用可能なサブコマンド・オプションを確認
- `WebSearch` で「Claude Code changelog」「Claude Code best practices」「Claude Code hooks」「Claude Code release notes」を検索
- 公式ドキュメント・リリースノートの URL が特定できたら `WebFetch` で本文を取得

**調査観点**:

- **新しい hook イベント**: `PreToolUse` / `PostToolUse` / `Stop` 以外の新イベントがあるか
- **新しい frontmatter フィールド**: `allowed-tools` / `model` / `output` 以外の公式サポートフィールド
- **settings.json の新しいキー**: `permissions` / `hooks` 以外の設定項目
- **MCP 連携の改善**: 新しい接続方法・サーバー・認証方式
- **Agent / subagent の新機能**: 新しい `subagent_type` や並列実行の改善
- **Plan Mode の改善**: `EnterPlanMode` / `ExitPlanMode` の新パラメータ
- **パフォーマンス最適化**: コンテキストウィンドウ管理、コスト削減の新手法

`{プロンプト}` が指定されている場合は、その観点を調査の重点に加える。

### Step 3: 差分分析

Step 1 の現状と Step 2 の最新推奨を突き合わせ、以下の 3 カテゴリに分類する:

#### A. 即座に適用できる改善

- 既存の構成を変更するだけで効果がある項目
- リスクが低く、ロールバックも容易

#### B. 設計検討が必要な改善

- 新機能の導入で構成変更が必要な項目
- `commands/` / `rules/` / `skills/` の追加・変更を伴う

#### C. 情報提供のみ

- 現在の構成では不要だが、将来的に有用な可能性がある項目
- 知っておくと判断材料になる新機能

### Step 4: 提案の出力

以下のフォーマットで会話内に出力する:

```
## Claude Code アップデートレビュー

**バージョン**: {現在のバージョン}
**調査日**: {日付}

### A. 即座に適用できる改善

| # | 項目 | 現状 | 提案 | 効果 |
|---|------|------|------|------|
| 1 | ... | ... | ... | ... |

### B. 設計検討が必要な改善

| # | 項目 | 概要 | 検討ポイント |
|---|------|------|--------------|
| 1 | ... | ... | ... |

### C. 情報提供

- ...

### 推奨する次のアクション

1. {最も効果が高い A カテゴリの項目}
2. ...
```

### Step 5: ユーザーとの対話

`AskUserQuestion` で、A カテゴリのどの項目を実装するかユーザーに選択してもらう。選択された項目は本スキルを抜けてから個別に実装を進める。

## 注意事項

- 公式ドキュメントにアクセスできない場合は、`claude --help` と既知の情報に基づいて提案する
- 推測ベースの提案には「未確認」ラベルを付け、ユーザーに検証を促す
- 現在の構成が既に最適な場合は、無理に改善提案をしない
- Claude Code の「バージョン」は Claude モデル自身のバージョン（Opus/Sonnet/Haiku のリリース）ではなく、CLI `claude` のバージョンを指す
