# mjcreativelab-agent-plugins

Claude Code / Codex / Cursor / Gemini など各種エージェント用のスキル集。`packages/<plugin>/skills/<skill>/` を正本として monorepo で管理し、**Claude Code marketplace** と **`npx skills`（クロスツール）** の 2 経路で配布する（render 工程は持たず、各 skill のディレクトリを直接編集する）。

## パッケージ一覧

| パッケージ | 説明 |
|-----------|------|
| [mjc-git-workflow-tools](packages/mjc-git-workflow-tools/) | Git ワークフロー自動化（smart-issue-resolve, smart-commit, smart-pr, smart-review 等） |
| [mjc-claude-improver-tools](packages/mjc-claude-improver-tools/) | スキル品質改善・環境構成レビュー（skill-improver, empirical-prompt-tuning, claude-code-update-review） |
| [mjc-code-develop-tools](packages/mjc-code-develop-tools/) | コード開発ライフサイクル支援（software-architect, code-reviewer, code-reviewer-adversarial, security-auditor） |
| [mjc-design-tools](packages/mjc-design-tools/) | デザイン領域の専門知識（game-ui-design ほか） |

## Claude Code でのインストール（marketplace）

```
# 1. marketplace として登録
/plugin marketplace add mjcreativelab/mjcreativelab-agent-plugins

# 2. プラグインをインストール
/plugin install <package-name>@mjcreativelab-agent-plugins
```

例:

```
/plugin install mjc-git-workflow-tools@mjcreativelab-agent-plugins
/plugin install mjc-claude-improver-tools@mjcreativelab-agent-plugins
/plugin install mjc-code-develop-tools@mjcreativelab-agent-plugins
/plugin install mjc-design-tools@mjcreativelab-agent-plugins
```

## 他エージェント（Codex / Cursor / Gemini 等）でのインストール（`npx skills`）

[vercel-labs/skills](https://github.com/vercel-labs/skills) の `npx skills` で、skill 単位にクロスツール install できる。skill は `.agents/skills/<skill>/` に配置され、各エージェントへ展開される（Codex / Cursor / Gemini CLI / GitHub Copilot ほか対応）。

```bash
# 利用可能な skill 一覧
npx skills add mjcreativelab/mjcreativelab-agent-plugins --list

# 推奨: グローバル install + タグ pin（更新は npx skills update で完結）
npx skills add mjcreativelab/mjcreativelab-agent-plugins@<tag> --skill smart-commit -g

# エージェント指定（例: Codex）
npx skills add mjcreativelab/mjcreativelab-agent-plugins@<tag> --skill smart-commit -a codex -g

# 更新確認 / 取り込み（global）
npx skills check
npx skills update
```

- 推奨は **グローバル install（`-g`）+ `@<tag>` pin**。プロジェクト install は `npx skills update` の対象外になる場合があるため、更新は再 add で取り込む。
- skill は名前で個別指定する（`--skill <name>`）。`--skill '*'` は本リポジトリ運用用の内部 skill（例: `auto-release`）も含むため、配布対象を絞りたい場合は名前指定を推奨。

## ライセンス

[MIT](LICENSE)
