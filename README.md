# mjcreativelab-agent-plugins

Claude Code / Codex / Cursor / Gemini など各種エージェント用のスキル集。`skills/<skill>/` を正本として monorepo で管理し、[vercel-labs/skills](https://github.com/vercel-labs/skills) の **`npx skills`** で配布する（クロスツール・単一経路）。

> **v2.0.x で配布経路を `npx skills` に一本化**しました（v2.0.0 で旧 marketplace 撤去、v2.0.1 で skill を npx 標準探索位置 `skills/` へ配置）。旧 Claude Code marketplace（`/plugin install ...@mjcreativelab-agent-plugins`）と旧 Codex 単一プラグイン配布は廃止しています（最終タグ: marketplace 系は各 `<package>@<semver>`、旧 Codex は `mjcreativelab-claude-plugins@1.0.0`）。下記 `npx skills` へ移行してください。

## スキル一覧

| グループ | スキル |
|-----------|------|
| [mjc-git-workflow-tools](packages/mjc-git-workflow-tools/) | smart-issue-resolve, smart-issue-plan, smart-commit, smart-pr, smart-review, smart-review-apply, smart-git-sync |
| [mjc-claude-improver-tools](packages/mjc-claude-improver-tools/) | skill-improver, empirical-prompt-tuning, claude-code-update-review |
| [mjc-code-develop-tools](packages/mjc-code-develop-tools/) | software-architect, code-reviewer, code-reviewer-adversarial, security-auditor |
| [mjc-design-tools](packages/mjc-design-tools/) | game-ui-design |

## インストール（`npx skills`）

skill 単位にクロスツール install できる。skill は `.agents/skills/<skill>/` に配置され、各エージェント（Claude Code / Codex / Cursor / Gemini CLI / GitHub Copilot ほか）へ展開される。

```bash
# 利用可能な skill 一覧
npx skills add mjcreativelab/mjcreativelab-agent-plugins --list

# 推奨: グローバル install + タグ pin（`#v<X.Y.Z>`。zsh ではソースを引用符で囲む）
npx skills add 'mjcreativelab/mjcreativelab-agent-plugins#v2.0.1' --skill smart-commit -g

# エージェント指定（例: Codex）
npx skills add 'mjcreativelab/mjcreativelab-agent-plugins#v2.0.1' --skill smart-commit -a codex -g

# 全 skill を一括（zsh は '*' をクォート）
npx skills add 'mjcreativelab/mjcreativelab-agent-plugins#v2.0.1' --skill '*' -g

# 更新確認 / 取り込み（global）
npx skills check
npx skills update
```

- 推奨は **グローバル install（`-g`）+ タグ pin（`#v<X.Y.Z>`）**。プロジェクト install は `npx skills update` の対象外になる場合があるため、更新は再 add で取り込む。
- **バージョン pin** は fragment 構文 `#v<X.Y.Z>` で指定する（例: `'mjcreativelab/mjcreativelab-agent-plugins#v2.0.1'`）。**`@<名前>` は ref ではなく skill フィルタ**（`owner/repo@smart-commit` = `--skill smart-commit` 相当）。タグ無しは default branch 追従の「お試し」用途。
- pin した install は lock に ref が記録され、`npx skills update` も pin に従う（タグ pin は据え置き）。新しいタグへ上げるときは `#v<新タグ>` で再 add する。
- 内部 skill `auto-release` は `metadata.internal: true` で `npx skills ... --list` の表示からは隠れるが、**`--skill '*'` では install される**（このバージョンの `npx skills` は wildcard から internal を除外しない）。`auto-release` は本リポジトリ専用のため他環境では不要。配布対象だけをクリーンに入れたい場合は `--skill <name>` を列挙する。

### 旧 marketplace からの移行

旧 `/plugin install` は**パッケージ単位**、新 `npx skills` は**skill 単位**。旧パッケージに含まれていた skill を `--skill` で指定し直す:

| 旧（廃止） | 新（`npx skills add 'mjcreativelab/mjcreativelab-agent-plugins#v2.0.1' ... -g`） |
|---|---|
| `/plugin install mjc-git-workflow-tools@…` | `--skill smart-commit --skill smart-pr --skill smart-git-sync --skill smart-issue-resolve --skill smart-issue-plan --skill smart-review --skill smart-review-apply` |
| `/plugin install mjc-claude-improver-tools@…` | `--skill skill-improver --skill empirical-prompt-tuning --skill claude-code-update-review` |
| `/plugin install mjc-code-develop-tools@…` | `--skill software-architect --skill code-reviewer --skill code-reviewer-adversarial --skill security-auditor` |
| `/plugin install mjc-design-tools@…` | `--skill game-ui-design` |

## ライセンス

[MIT](LICENSE)
