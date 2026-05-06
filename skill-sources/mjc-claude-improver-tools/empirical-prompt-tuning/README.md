# empirical-prompt-tuning

agent 向けテキスト指示（skill / slash command / タスクプロンプト / `CLAUDE.md` の節 / コード生成プロンプト）の「指示の曖昧さ」を、**バイアスを排した新規 subagent に dispatch して実際に動かしてもらい**、両面（実行者の自己申告 + 指示側メトリクス）で評価して反復改善するスキル。

## どんなケースで使うか

- skill / slash command / タスクプロンプトを **新規作成・大幅改訂した直後**
- エージェントが期待通り動かず、原因を指示側の曖昧さに求めたいとき
- 重要度の高い指示（頻繁に使うスキル、自動化の中核プロンプト）を堅牢化したいとき

使わない場面:

- 一回限りの使い捨てプロンプト（評価コストが割に合わない）
- 書き手の主観的好みを反映したいだけの場合
- `TODO` 残留・リンク切れ・`bash` 構文など **機械的な静的チェック** → `skill-improver` を使う

## 使い方

```
/empirical-prompt-tuning [対象プロンプトの参照]
```

対象は **ファイルパス** でも **フリーテキスト** でも指定できる。

### 例

```
/empirical-prompt-tuning packages/mjc-git-workflow-tools/skills/smart-commit/SKILL.md
/empirical-prompt-tuning CLAUDE.md の「AI Agent Role Assignment」節
```

## ワークフロー（概要）

1. **Iteration 0 — 静的整合チェック**: frontmatter `description` と本文のカバー範囲に乖離があれば先に揃える
2. **ベースライン準備**: 評価シナリオ 2〜3 種（中央値 1 + edge 1〜2）、要件チェックリスト（`[critical]` タグ必須）
3. **バイアス排除読み**: 新規 subagent を `Agent` ツールで dispatch（並列可）
4. **両面評価**: 自己申告（不明瞭点・裁量補完）+ 指示側メトリクス（成功/失敗・精度・`tool_uses`・`duration_ms`・再試行回数）を記録
5. **差分適用**: 1 イテレーション 1 テーマで最小修正を当てる
6. **再評価**: 新しい subagent で再度 3→5 を回す（同じ subagent は再利用しない）
7. **収束判定**: 連続 2 回「新規不明瞭点ゼロ + メトリクス改善が飽和」で停止

## 前提条件

`Agent` ツール（新規 subagent の dispatch）が利用可能な環境が必要。既に subagent として動作している環境や `Task` tool が無効化されている環境では適用できない。

## skill-improver との使い分け

| スキル                     | 対象                                                     | 主な手法                                              | コスト                              |
| -------------------------- | -------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------- |
| `skill-improver`           | 単一の `SKILL.md`                                        | skill-creator eval 委譲 + 機械的静的チェック          | 軽（eval 1 iter + Grep / `bash -n`）|
| `empirical-prompt-tuning`  | テキスト指示全般（skill / slash / `CLAUDE.md` / プロンプト）| 新規 subagent を dispatch して両面評価で反復         | 重（subagent 複数 dispatch × 複数 iter）|

両者は併用可能。先に `skill-improver` で機械的問題を潰し、重要スキルはさらに `empirical-prompt-tuning` で指示の明瞭性を測るのが効率的。

## 元になったスキル

本スキルは [mizchi/chezmoi-dotfiles](https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md) の `empirical-prompt-tuning` を参考にしている。

## 推奨: 新規セッションで実行する

このスキルは **新規セッションで実行する** ことを推奨する。

- 対象プロンプトを書いた直後のセッションで実行すると、書き手自身のバイアスと読み直しで改善判断が曇る
- 新規セッションであれば、対象プロンプトと評価シナリオだけが読み込まれるため subagent dispatch のトークン効率も良い
- **プロンプト / スキルを書き終えたら、新規セッションで `/empirical-prompt-tuning <対象>` を実行するのがベスト**
