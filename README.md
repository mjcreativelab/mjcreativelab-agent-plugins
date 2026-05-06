# mjcreativelab-claude-plugins

Claude Code と Codex 用のプラグイン集。skills, hooks, rules を monorepo で管理し、`skills-sources/` から各エージェント向けに render して配布する。

## パッケージ一覧

| パッケージ | 説明 |
|-----------|------|
| [mjc-git-workflow-tools](packages/mjc-git-workflow-tools/) | Git ワークフロー自動化（smart-issue-resolve, smart-commit, smart-pr, smart-review 等） |
| [mjc-claude-improver-tools](packages/mjc-claude-improver-tools/) | スキル品質改善・環境構成レビュー（skill-improver, empirical-prompt-tuning, claude-code-update-review） |
| [mjc-code-develop-tools](packages/mjc-code-develop-tools/) | コード開発ライフサイクル支援（software-architect, code-reviewer, code-reviewer-adversarial, security-auditor） |

## Claude Code でのインストール

```
# 1. marketplace として登録
/plugin marketplace add mjcreativelab/mjcreativelab-claude-plugins

# 2. プラグインをインストール
/plugin install <package-name>@mjcreativelab-claude-plugins
```

例:

```
/plugin install mjc-git-workflow-tools@mjcreativelab-claude-plugins
/plugin install mjc-claude-improver-tools@mjcreativelab-claude-plugins
/plugin install mjc-code-develop-tools@mjcreativelab-claude-plugins
```

## Codex でのインストール

このリポジトリ自体が Codex プラグイン（`name: mjcreativelab-claude-plugins`）として機能する。`.codex-plugin/plugin.json` がマニフェスト、ルート直下の [skills/](skills/) が skill 配置先。Codex CLI のプラグイン取り込み機能でリポジトリを指定して導入する。

Codex 側はパッケージ階層を平坦化し、Codex target が有効な skill を `skills/<skill>/` 直下に配置する。Claude 専用 skill は Codex 配布から除外される。

## ライセンス

[MIT](LICENSE)
