# mjc-claude-improver-tools

Claude Code のスキル品質改善と環境構成レビューのツール群。

## なぜ skill-creator だけでは足りないのか

Anthropic 公式の [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) は、eval 駆動でスキルの出力品質を改善する強力なツールです。しかし、eval は短いセッションで完結するため、**長い会話で初めて顕在化する問題**を構造的に見落とします。

| 問題の種類 | skill-creator | skill-improver Phase 2 |
|---|---|---|
| 出力品質（結果が正しいか） | eval で検出 | - |
| description の発火精度 | 統計的に最適化 | - |
| コンテキスト圧縮時のデータ消失 | 短い eval では再現しない | 再 Read ルールの有無を静的チェック |
| 参照ファイルの一括読み込みによるコンテキスト浪費 | 「動く」ので eval では問題にならない | 読み込みタイミングの設計を検証 |
| 中間データがコンテキストに残り続ける | 同上 | 外部化設計の有無を検証 |
| API レスポンスの丸ごと取り込み | 同上 | 絞り込みルールの有無を検証 |
| TODO / FIXME の残留 | 出力に影響しなければ素通り | Grep で静的検出 |
| 参照ファイルのリンク切れ | 実行時エラーで発覚するが原因特定が遅い | 事前に存在確認 |
| シェルスクリプトの構文エラー | 実行時エラーで発覚 | `bash -n` で事前検出 |

skill-improver はこのギャップを埋めるために、skill-creator の改善ループ完了後に**コンテキスト管理の設計検証**と**静的チェック**を追加実行します。

## スキル一覧

### skill-improver

スキル定義（SKILL.md）を 2 フェーズで改善する。

#### 対象とするスキル定義

Claude Code のスキル仕様（`SKILL.md` ベース）に従ったディレクトリを対象とする。具体的には以下の構成:

```
<skill-name>/
├── SKILL.md          # frontmatter（name + description 必須）+ 本文（500 行以下推奨）
├── references/       # 参照表・チェックリスト等の読み取り専用情報（任意）
└── assets/           # テンプレート・スクリプト（任意）
```

公式仕様・規約の出典:

- 本リポジトリの [`CLAUDE.md`](../../CLAUDE.md) 「スキルファイル形式」セクション（frontmatter / 文字列置換 / 動的コンテキスト注入）
- Anthropic 公式の [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator)（eval 駆動の改善ループ）

skill-improver の Phase 1 は上記 skill-creator に委譲し、Phase 2 で公式推奨との差分・コンテキスト管理・静的整合性を補完する。

**Phase 1: skill-creator による eval 駆動の改善**

skill-creator を改善モードで呼び出し、以下のループを実行します:

1. テストケース作成（2〜3 個の現実的なプロンプト）
2. 並列評価（スキルあり / なしのサブエージェントを同時実行）
3. HTML ビューアでレビュー + フィードバック
4. SKILL.md の修正
5. description の統計的最適化（should-trigger / should-not-trigger テスト）

**Phase 2: 公式推奨差分 + コンテキスト管理 + 静的チェック**

skill-creator が検出しにくい問題を、最新の Claude Code 公式推奨との差分照合・静的検証で炙り出し、改善提案を **A（即適用可）/ B（設計検討要）/ C（情報提供）** の 3 カテゴリで出力します。

公式ベストプラクティス調査（`WebSearch` / `WebFetch`）の観点:

- 新しい frontmatter フィールド（`context`, `agent`, `model`, `disable-model-invocation`, `user-invocable` 等）の活用
- 動的コンテキスト注入（`` !`command` `` 構文、`${CLAUDE_SKILL_DIR}` / `${CLAUDE_SESSION_ID}`）の活用
- `disable-model-invocation` の設定漏れ
- `references/` への切り出し方針、`assets/` の使い分け
- `description` の発火精度（キーワード列挙・否定形の活用度）
- スキル間呼び出しの最新規約（`plugin:skill` 名前空間）

コンテキスト管理チェック:

| チェック項目 | 確認内容 | 該当条件 |
|---|---|---|
| 読み込みタイミング | 参照ファイルの Read が必要なステップまで遅延されているか | 参照ファイルが存在するスキル |
| 圧縮耐性 | コンテキスト圧縮時の再 Read ルールが明記されているか | 複数ステップを持つタスク型スキル |
| 中間データの外部化 | 処理途中のデータをファイルに書き出す設計があるか | ステップが 5 以上のスキル |
| API レスポンスの絞り込み | 必要フィールドだけを抽出するルールがあるか | API 呼び出しを含むスキル |
| バッチ処理設計 | バッチサイズ・中間保存の設計があるか | リスト・配列を反復処理するスキル |
| サブエージェント委譲 | 渡す情報と返却の範囲が明確か | `context: fork` を使うスキル |
| テンプレート肥大化リスク | 将来の肥大化に対する対策があるか | 参照ファイルが 200 行以上のスキル |

静的チェック:

| チェック項目 | 方法 |
|---|---|
| TODO / FIXME / TBD 残留 | Grep で検索 |
| テンプレート未カスタマイズ | プレースホルダーパターンを Grep で検索 |
| 参照ファイルの存在確認 | SKILL.md 内リンクの参照先を Glob で確認 |
| シェルスクリプト構文 | `bash -n` で構文チェック |

### empirical-prompt-tuning

プロンプト・skill・CLAUDE.md の節などの「指示の明瞭性」を、**バイアスを排した新規 subagent** に実行させて反復改善する skill。書き手自身の読み直しでは見えない曖昧さを、別エージェントの実行結果と自己申告レポートで炙り出す。

主なフロー:

1. 対象プロンプト + 評価シナリオ 2〜3 種 + 要件チェックリスト（`[critical]` タグ必須）を用意
2. Agent ツールで新規 subagent を dispatch（並列可）し、指定の「subagent 起動契約」に従った成果物 + 自己申告レポートを得る
3. 両面評価（自己申告の不明瞭点・裁量補完 + 指示側の `tool_uses` / `duration_ms` / 精度）を記録
4. 1 イテレーション 1 テーマで最小修正を当て、新しい subagent で再実行
5. 連続 2 回「新規不明瞭点ゼロ + 各メトリクスが飽和」で収束

`skill-improver` との使い分け:

| スキル | 対象 | 主な手法 | 検出できる問題 | コスト |
|---|---|---|---|---|
| `skill-improver` | 単一の `SKILL.md` | skill-creator eval 委譲 + 公式推奨差分 + 機械的静的チェック | TODO 残留 / リンク切れ / bash 構文 / コンテキスト管理設計 / 古いパターン残留 | 軽（eval 1 iter + WebSearch + Grep / bash -n） |
| `empirical-prompt-tuning` | テキスト指示全般（skill / slash / CLAUDE.md 節 / コード生成プロンプト） | 新規 subagent を dispatch して両面評価で反復 | 指示の曖昧さ / 裁量補完 / 再試行の発生点 | 重（subagent 複数 dispatch × 複数 iter） |

両者は併用可能（先に `skill-improver` で機械的問題を潰し、重要スキルはさらに `empirical-prompt-tuning` で指示の明瞭性を測る）。

出典: 本スキルは [mizchi/chezmoi-dotfiles](https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md) の `empirical-prompt-tuning` を参考にしている。

### claude-code-update-review

Claude Code のバージョンアップ後に、最新の公式推奨手法と現在の構成
（`settings.json` / `commands/` / `rules/` / `skills/` / `CLAUDE.md` 等）を照合し、改善提案を 3 カテゴリ（即適用可 / 設計検討要 / 情報提供）に分類して出力する。

対象は個別スキルの中身ではなく、**Claude Code 環境全体の設定と構成**。`skill-improver` とスコープは完全に別なので、用途に応じて使い分ける。

| スキル | 対象 | 用途 |
|---|---|---|
| `skill-improver` | 単一の `SKILL.md` | スキル自体の品質改善（eval + 静的チェック） |
| `claude-code-update-review` | Claude Code の環境全体 | バージョンアップ後の構成レビュー |

調査観点: 新しい hook イベント、frontmatter フィールド、settings.json のキー、MCP 連携、Agent/subagent 機能、Plan Mode、パフォーマンス最適化など。

## 使い方

```bash
# スキル品質改善
/mjc-claude-improver-tools:skill-improver <skill-directory-path>
/mjc-claude-improver-tools:skill-improver <skill-directory-path> -p "<prompt>"

# プロンプト / skill の経験的チューニング
/mjc-claude-improver-tools:empirical-prompt-tuning [対象プロンプトの参照]

# Claude Code アップデートレビュー
/mjc-claude-improver-tools:claude-code-update-review
/mjc-claude-improver-tools:claude-code-update-review -p "<prompt>"
```

### 例

```bash
# skill-improver: パスのみ（skill-creator がインタビューで方向性を決める）
/mjc-claude-improver-tools:skill-improver .claude/skills/my-skill

# skill-improver: プロンプト付き（改善の意図を skill-creator に直接伝える）
/mjc-claude-improver-tools:skill-improver packages/mjc-git-workflow-tools/skills/smart-commit -p "コンテキスト管理を重点的に改善して"
/mjc-claude-improver-tools:skill-improver .claude/skills/deploy -p "eval は不要、一緒に対話的に改善したい"

# claude-code-update-review: 基本
/mjc-claude-improver-tools:claude-code-update-review

# claude-code-update-review: 観点指定
/mjc-claude-improver-tools:claude-code-update-review -p "hooks の活用を重点的に"

# empirical-prompt-tuning: 対象を明示
/mjc-claude-improver-tools:empirical-prompt-tuning packages/mjc-git-workflow-tools/skills/smart-commit/SKILL.md

# empirical-prompt-tuning: 対象をフリーテキストで
/mjc-claude-improver-tools:empirical-prompt-tuning CLAUDE.md の「AI Agent Role Assignment」節
```

## 前提条件

`skill-improver` は skill-creator プラグインがインストール済みであること。これは Anthropic 公式マーケットプレイス（`claude-plugins-official`）の**外部プラグイン**であり、本リポジトリの（v2.0.0 で撤去した）旧 marketplace とは無関係。Claude Code でのみ利用する依存。

```bash
/plugin install skill-creator@claude-plugins-official
```

`claude-code-update-review` に追加の依存はない（`WebSearch` / `WebFetch` が利用可能な環境で動作）。

`empirical-prompt-tuning` は `Agent` ツール（新規 subagent の dispatch）が利用可能な環境で動作する。既に subagent として動作中の環境では適用できない（SKILL.md「環境制約」節を参照）。
