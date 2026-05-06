---
name: skill-improver
description: >
  既存の Claude Code スキル（`<skill-dir>/SKILL.md` + `references/` / `assets/` の一式。
  仕様は本プラグイン README の「対象とするスキル定義」を参照）を、
  skill-creator eval 委譲 + 公式ベストプラクティス差分 + 機械的静的チェックで仕上げるスキル。
  TODO / FIXME 残留、参照ファイルのリンク切れ、.sh 構文（bash -n）、
  コンテキスト管理設計（再 Read ルール・中間データ外部化・API レスポンス絞り込み）を
  Grep / Glob / bash で検証し、最新の Claude Code 公式推奨（frontmatter / SKILL.md 規約 /
  動的コンテキスト注入）との差分を取って改善提案を A/B/C カテゴリで出力する。
  「スキルを改善して」「品質チェック」「eval 回して」「500 行超えそう」
  「SKILL.md を見直して」「スキルが効かない」「トリガーされない」「行数オーバー」
  「最新のスキル規約に合わせて」等で起動。
  指示の曖昧さを新規 subagent の実行実測で炙り出したいときは empirical-prompt-tuning を使う
  （本スキルは subagent dispatch は行わない）。
  Claude Code 環境全体のレビューは claude-code-update-review、
  PR / 差分レビューは smart-review、新規スキル作成は skill-creator を使う。
argument-hint: "<skill-directory-path> [-p <prompt>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Skill, Edit, AskUserQuestion, WebSearch, WebFetch
---

# スキル改善スキル

単一スキル（`SKILL.md` + `references/` + `assets/`）を、(1) skill-creator の eval 駆動改善、(2) 最新の Claude Code 公式推奨との差分調査、(3) コンテキスト管理 + 機械的静的チェック の 3 段で仕上げる。

Phase 1（skill-creator 委譲）が本スキルの本体である。Phase 2（公式推奨差分 + 静的チェック）は Phase 1 の補完であり、Phase 1 なしでは実行できない。

**なぜこの順序なのか**: Phase 1 は機能的な問題（指示の曖昧さ、出力品質、トリガー精度）を実際の実行で検出する。Phase 2 は静的解析と公式推奨との照合で、構造・コンテキスト効率・古いパターンの残留を炙り出す。Phase 2 だけでは機能的な問題を見落とすため、Phase 1 を先に実行する。

**Phase 1 が実行できない場合（skill-creator 未インストール、Skill ツールエラー等）、本スキル全体を中止する。**

## オプション

- `-p <プロンプト>`: skill-creator に渡す追加の改善指示（例: `-p コンテキスト管理を重点的に改善して`）

## スコープ定義

**スコープ内**

- 単一スキル（`SKILL.md` + 補助ファイル）の品質改善
- skill-creator による eval 駆動の機能改善（Phase 1）
- SKILL.md 構造と Claude Code 公式推奨（frontmatter / SKILL.md 規約 / 動的コンテキスト注入 / コンテキスト設計）との差分調査
- 参照ファイルのリンク切れ・TODO 残留・`.sh` 構文エラーの静的検出
- コンテキスト管理設計（再 Read ルール、中間データ外部化、API レスポンス絞り込み）の検証
- 改善提案の A/B/C カテゴリ分類と、ユーザー承認後の Edit 適用

**スコープ外**

- Claude Code 環境全体（`settings.json` / `commands/` / `rules/` / `CLAUDE.md` 等）の構成レビュー → `claude-code-update-review`
- PR / ブランチ単位の差分レビュー → `smart-review`
- 指示の曖昧さを新規 subagent の実行実測で炙り出す改善ループ → `empirical-prompt-tuning`
- 新規スキルの作成 → `skill-creator`
- Phase 2 提案の自動適用（必ずユーザー承認を経て個別に Edit する）

## 手順

以下の順序で実行する。ファイルの読み込みや分析は Step 1 より前に行わない。

### Step 0: 引数の解析

`$ARGUMENTS` を以下のルールで解析する:

- `-p` より前の部分 → `{スキルパス}`（対象スキルのディレクトリパス）
- `-p` より後の部分 → `{プロンプト}`（skill-creator に渡す追加の改善指示）
- `-p` がない場合 → `$ARGUMENTS` 全体を `{スキルパス}` とし、`{プロンプト}` は空
- `{スキルパス}` が未指定の場合は `AskUserQuestion` で確認する

### Step 1: skill-creator を呼び出す（Phase 1 — 本体）

対象スキルの読み込みや分析を先に行わず、まず Skill ツールを呼び出す。この呼び出しが skill-creator のインストール確認を兼ねる。

呼び出し先は **skill-creator**（本スキルとは別のスキル）である。skill-improver 自身を Skill ツールで呼び出すのではない。

Skill ツールの呼び出し:
```
skill: "skill-creator:skill-creator"
args: "{スキルパス} を改善したい。eval ループは最大 1 iteration に留めてください。{プロンプト}"
```
（`{プロンプト}` が空の場合は「留めてください。」まで）

**Skill ツールがエラーを返した場合** → `AskUserQuestion` で以下を案内し、**本スキルの実行を中止する**（Phase 2 含め一切進めない）:

```
skill-creator プラグインが必要です。以下でインストールしてください:
/plugin install skill-creator@claude-plugins-official
インストール後に再度 /skill-improver を実行してください。
```

対象スキルが skill-improver 自身であっても、呼び出す先は skill-creator なので再帰にはならない。skill-creator が eval アプローチ（フル eval / 構造分析ベース）をユーザーに確認するため、このスキル側で事前に聞く必要はない。

**コンテキスト予算**: Phase 2 を確実に実行するため、以下の制約を守る:

- skill-creator の eval ループは **最大 1 iteration** に留める。それ以上の iteration が必要な場合は `AskUserQuestion` で続行を確認する
- eval 結果の全文引用は避け、パス/フェイル状態と主要な指摘のみを残す

**完了条件**: skill-creator の完了宣言、ユーザーの満足表明、eval 1 iteration 完了のいずれか。

### Step 1 完了時: Phase 1 レポートの書き出し（必須）

Phase 1 の結果を `/tmp/skill-improver-phase1-{スキル名}.md` に書き出す。このファイルは Phase 2 の開始条件として検証される。

```markdown
# Phase 1 結果: {スキル名}
- 実行日時: {現在日時}
- 改善箇所の要約（5 行以内）
- 検出された問題（あれば）
```

### Step 2: Phase 2（物理ゲートあり）

以下の Bash コマンドを実行し、Phase 1 レポートファイルの存在を確認する:

```bash
cat /tmp/skill-improver-phase1-{スキル名}.md
```

- **成功（ファイル内容が表示された）** → [references/phase2-steps.md](references/phase2-steps.md) を Read し、その指示に従う
- **失敗（No such file）** → Phase 1 が未実行である。**本スキルの実行を中止** し、ユーザーに Phase 1 未実行の旨を報告する。phase2-steps.md を Read してはならない

phase2-steps.md は次の流れで進む（詳細は参照先で展開）:

1. 改善後のスキル一式を読み直す（コンテキスト圧縮対策）
2. **公式ベストプラクティス調査**: `WebSearch` / `WebFetch` で SKILL.md の最新規約・推奨パターンを収集し、対象スキルとの差分を取る
3. コンテキスト管理チェック（[references/context-checklist.md](references/context-checklist.md)）
4. 静的チェック（TODO / リンク切れ / `bash -n`）
5. **A/B/C カテゴリ分類**で `/tmp/skill-improver-report-{スキル名}.md` に書き出し
6. ユーザー確認 → Edit で修正

---

## 完了チェック

以下をすべて満たしていることを確認してからスキル改善の完了を報告する:

- [ ] Step 1 が実行された（skill-creator の Skill ツール呼び出しが成功）
- [ ] Phase 1 レポートが `/tmp/skill-improver-phase1-{スキル名}.md` に書き出された
- [ ] Step 2 の物理ゲート（Bash による Phase 1 レポート確認）をパスした
- [ ] phase2-steps.md の手順が完了し、A/B/C カテゴリのレポートが書き出された

## 注意事項

- 公式ドキュメントにアクセスできない / 検索結果が薄い場合は、既知の情報に基づいて提案し、推測ベースの項目には「未確認」ラベルを付ける
- 現在のスキルが既に最適な場合は、無理に改善提案をしない
- 提案の自動適用は行わない。phase2-steps.md の修正ステップで `AskUserQuestion` を出し、ユーザーが選択したものだけを Edit で適用する
