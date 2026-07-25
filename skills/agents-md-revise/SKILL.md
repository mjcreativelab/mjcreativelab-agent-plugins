---
name: agents-md-revise
description: >
  今回のセッションで得た学び（発見したコマンド・コードパターン・テストアプローチ・環境の癖・注意点）を
  CLAUDE.md / AGENTS.md / GEMINI.md などのエージェント指示ファイルへ反映する。
  セッション終盤に /agents-md-revise で起動。
  コードベース起点の定期監査・品質レポートは agents-md-improver を使う。
argument-hint: "[反映したい観点（省略可）]"
disable-model-invocation: true
allowed-tools: Read, Edit, Glob
license: Apache-2.0
---

# Agents MD Revise（セッションの学びを指示ファイルへ反映）

このセッションを振り返り、このコードベースでエージェントが働くうえでの学びを抽出して、将来のセッションがより効果的になるコンテキストを指示ファイル（CLAUDE.md / AGENTS.md 等）へ追記する。

`$ARGUMENTS` が指定された場合は、その観点を優先して振り返る。

## Step 1: 振り返り

どんなコンテキストが最初からあれば、より効果的に働けたか?

- 使った・発見した Bash コマンド
- 従ったコードスタイル・パターン
- 機能したテストアプローチ
- 環境・設定の癖
- 遭遇した警告・落とし穴

## Step 2: 指示ファイルの特定

```bash
find . \( -name "CLAUDE.md" -o -name "AGENTS.md" -o -name "GEMINI.md" -o -name ".claude.local.md" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -20
```

各追記の行き先を決める:

- `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` — チーム共有（git 管理）。実行中のエージェントが読むファイルを優先する
- `.claude.local.md` — 個人・ローカル限定（gitignore 対象。Claude Code 固有）

**symlink 注意**: `AGENTS.md → CLAUDE.md` のような symlink は実体側を編集する（`ls -l <path>` で確認。二重追記しない）。

## Step 3: 追記案の作成

**簡潔に** — 1 概念 1 行。指示ファイルはプロンプトの一部であり、短さがそのまま価値になる。

フォーマット: `<コマンドまたはパターン>` - `<簡潔な説明>`

避けるもの:

- 冗長な説明
- 自明な情報
- 再発しない一回限りの修正

## Step 4: 変更案の提示

追記ごとに:

```
### 更新: ./CLAUDE.md

**理由:** [一行の理由]

\`\`\`diff
+ [追記内容 — 簡潔に]
\`\`\`
```

## Step 5: 承認後に適用

変更を適用してよいかユーザーに確認する。承認されたファイルのみ編集する。

---

移植元: Anthropic 公式プラグイン [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) の `/revise-claude-md` command（Apache-2.0）。CLAUDE.md 専用だった対象を AGENTS.md / GEMINI.md を含むクロスツール向けに一般化し、command から skill 形式へ変換。
