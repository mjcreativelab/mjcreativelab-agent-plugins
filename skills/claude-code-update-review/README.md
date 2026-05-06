# claude-code-update-review

Claude Code のバージョンアップ後に、最新の公式推奨手法と現在の構成（`settings.json` / `commands/` / `rules/` / `skills/` / `CLAUDE.md` 等）を照合し、改善提案を出すスキル。

## どんなケースで使うか

- `claude update` で CLI を更新したあと、最新機能を取り込めていないか確認したい
- Claude Code のベストプラクティスが変わっていないか棚卸ししたい
- hooks / frontmatter フィールド / `settings.json` の新キーなど、見逃している機能を洗い出したい
- 新しいメンバーに渡す前に環境構成をレビューしたい

使わない場面:

- 個別スキルの品質改善 → `skill-improver`
- PR / 差分のコードレビュー → `/code-reviewer`
- Codex / Cursor / Gemini CLI 固有の機能調査（本スキルのスコープ外）

## 使い方

```
/claude-code-update-review
/claude-code-update-review -p <調査観点>
```

### 例

```
/claude-code-update-review
/claude-code-update-review -p hooks の活用を重点的に
/claude-code-update-review -p MCP 連携の最新機能を中心に
```

## オプション

| オプション        | 説明                               |
| ----------------- | ---------------------------------- |
| `-p <プロンプト>` | 調査・提案の観点を追加指定する     |

## フロー

1. **現状確認** — `claude --version` / `settings.json` / `commands/` / `rules/` / `skills/` / `CLAUDE.md` を並列収集
2. **最新推奨の調査** — `claude --help`・公式 changelog・ベストプラクティスを `WebSearch` / `WebFetch` で収集
3. **差分分析** — 以下 3 カテゴリに分類
   - **A. 即座に適用できる改善**（低リスク・ロールバック容易）
   - **B. 設計検討が必要な改善**（構成変更を伴う）
   - **C. 情報提供のみ**（現状不要だが知っておくと有用）
4. **提案出力** — テーブル形式でチャットに出す
5. **対話** — `AskUserQuestion` で A カテゴリのどれを実装するか選んでもらう（実装はスキルを抜けてから個別に進める）

## 調査観点

- 新しい hook イベント（`PreToolUse` / `PostToolUse` / `Stop` 以外）
- frontmatter の新規サポートフィールド
- `settings.json` の新キー
- MCP 連携（接続方法・認証方式）の改善
- Agent / subagent の新機能
- Plan Mode の新パラメータ
- コンテキスト管理・コスト削減の新手法

`-p` が指定されていれば、その観点を調査の重点に加える。

## 注意事項

- 公式ドキュメントにアクセスできない場合は `claude --help` と既知の情報に基づいて提案する
- 推測ベースの提案には「未確認」ラベルを付け、ユーザーに検証を促す
- 現在の構成が既に最適な場合は無理に改善提案をしない
- Claude Code の「バージョン」は Claude モデル（Opus / Sonnet / Haiku）ではなく CLI `claude` のバージョンを指す

## 元になったスキル

特定のスキルをベースにしたものではなく、本リポジトリ独自のツールとして設計した。Claude Code のバージョンアップごとに公式 changelog を追いかける作業を半自動化することを目的にしている。

## 推奨: 新規セッションで実行する

このスキルは **作業セッションとは別の新規セッションで実行する** ことを推奨する。

- 設定ファイル・ドキュメントの Read と Web 検索で一定のトークンを消費するため、作業履歴が蓄積したセッションでは効率が落ちる
- **`claude update` 直後、または月次の環境見直しのタイミングで新規セッションを立ち上げて `/claude-code-update-review` を実行するのがベスト**
