# 実装ノート: claude-md-management プラグインのクロスツール移植（agents-md-improver / agents-md-revise）

日付: 2026-07-25（JST）

## タスク

Anthropic 公式プラグイン [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management)（skill `claude-md-improver` + command `/revise-claude-md`）を、Codex 等でも使えるスキルとして `skills/` に追加する。

## 自分で判断した事項

1. **リネーム（`claude-md-*` → `agents-md-*`）**: 依頼は名前を指定していなかったため、次の理由で改名した。
   - クロスツール配布が目的であり、Codex / Gemini CLI の指示ファイルは CLAUDE.md ではなく AGENTS.md / GEMINI.md。CLAUDE.md 固定の名前は対象を誤って示す（グローバルルール「命名は短さより具体性・対象を明示」）
   - 公式プラグインが本ホストの Claude Code にインストール済みのため、同名だと skill 名が衝突・混同する
2. **対象ファイルの一般化**: CLAUDE.md 専用 → CLAUDE.md / AGENTS.md / GEMINI.md / .claude.local.md に拡張。付随して次を追加した。
   - **symlink 統合**（AGENTS.md → CLAUDE.md を 1 エンティティとして扱い実体側を編集。本リポジトリ自身がこの構成）
   - **別実体間の内容乖離（drift）検出**を品質評価の Red Flags / よくある問題に追加
   - ツール固有 Tips（Claude Code の `#` キー・`~/.claude/CLAUDE.md`、Codex の `~/.codex/AGENTS.md`、Gemini CLI の `~/.gemini/GEMINI.md`）は「実行中のエージェントに該当するもののみ提示」とした
3. **command → skill 変換**: `/revise-claude-md` は command 形式だったため、リポジトリ規約（user-invocable も `skills/` に統一）に従い `disable-model-invocation: true` の skill に変換。`argument-hint` で観点指定（省略可）を受けられるようにした（元 command は引数なし）
4. **`disable-model-invocation` の付与判断**:
   - `agents-md-revise`: **true**。元が command（ユーザー起動限定）であり、書き込み副作用があるため
   - `agents-md-improver`: **付けない**。元 skill がモデル起動可で、書き込み前に品質レポート提示 + ユーザー承認ゲートがワークフロー内に組み込まれているため（「監査して」の自然言語で起動できる価値を優先）
5. **言語**: SKILL.md 本文・README は日本語（リポジトリ既存スキルの規約に整合）。`references/` 3 ファイルは英語のまま一般化に留めた（エージェントが読む参照資料であり、上流との diff 追従を容易にするため。Issue #122 の「エージェント向けは英語・ユーザー向けは日本語」の方向性とも整合）
6. **ライセンス表記**: 移植元は Apache-2.0。両 SKILL.md の frontmatter に `license: Apache-2.0`（Agent Skills 標準フィールド）を付与し、SKILL.md 末尾と README に移植元リンクを明記した

## 仕様から変更・調整した内容

- Discovery の find コマンドに `-not -path "*/node_modules/*" -not -path "*/.git/*"` を追加（元は node_modules 除外なしで、JS プロジェクトでノイズが出るため）
- 元 skill の frontmatter `tools:` フィールドは Agent Skills 標準の `allowed-tools:` に変更
- 元 README の画像（png 2 枚）は移植しない（本リポジトリの per-skill README 形式に合わせテキストで説明）

## 検証

- `mise exec node -- npx skills add ./ --list` で `agents-md-improver` / `agents-md-revise` の 2 件が検出されることを確認済み
- シェルスクリプト assets はなし（`bash -n` 対象なし）
- サブエージェントでの実挙動テスト（writing-skills の TDD プロセス）は未実施: 公式配布済みスキルの移植であり、ロジックの新規考案がないため簡略化した。改修を重ねる場合は `/empirical-prompt-tuning` での検証を推奨
