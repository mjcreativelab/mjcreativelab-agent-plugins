---
name: global-config-pull
description: グローバル Claude 設定（~/.claude/ の CLAUDE.md・settings.json・statusline-command.sh・rules/・hooks/・agents/・commands/・keybindings.json・.mcp.json）をリポジトリの dotfiles/claude/ にコピーして取り込む。「設定を取り込む」「グローバル設定を pull して」と言ったら起動。
disable-model-invocation: true
metadata:
  internal: true
---

# Global Config Pull

`~/.claude/` の設定ファイルを `dotfiles/claude/` にコピーして Git 管理下に取り込む。

## 同期対象

**ファイル（存在するもののみ）:** `CLAUDE.md`・`settings.json`・`statusline-command.sh`・`keybindings.json`・`.mcp.json`

**ディレクトリ（存在するもののみ・ミラー同期＝ソース側での削除も反映）:**

| ディレクトリ | 内容 |
|---|---|
| `rules/` | CLAUDE.md から条件読み込みされる外部参照ルール |
| `hooks/` | settings.json の hooks から呼ばれるスクリプト |
| `agents/` | カスタムエージェント定義 |
| `commands/` | カスタムスラッシュコマンド（レガシー） |

**除外（同期しない）:**

- 秘密情報: `.credentials.json`・`remote-settings.json`（認証情報・リモート管理設定。リポジトリに置かない）
- 配布物: `skills/`（npx skills / plugin marketplace の install 先。手書き設定ではなく各配布元リポジトリが正本）
- 状態・キャッシュ: `projects/`・`plugins/`・`backups/`・`cache/`・`debug/`・`downloads/`・`file-history/`・`ide/`・`paste-cache/`・`session-env/`・`sessions/`・`shell-snapshots/`・`tasks/`・`telemetry/`・`auto-resume/`・`security/`・`.cc-writes/`・`history.jsonl`・`stats-cache.json`・`security_warnings_state_*.json`・`mcp-needs-auth-cache.json`・`.last-*`・`*.bak.*`・`.DS_Store`

## 手順

リポジトリルートで実行する。

1. **コピー実行**（存在チェック付き。ディレクトリは rsync でミラー同期）:
   ```bash
   for f in CLAUDE.md settings.json statusline-command.sh keybindings.json .mcp.json; do
     [ -f ~/.claude/"$f" ] && cp ~/.claude/"$f" dotfiles/claude/"$f"
   done
   for d in rules hooks agents commands; do
     [ -d ~/.claude/"$d" ] && rsync -a --delete --exclude '.DS_Store' --exclude '*.bak.*' ~/.claude/"$d"/ dotfiles/claude/"$d"/
   done
   ```

2. **パス正規化（記述ルール準拠）:** 実体の設定には許可承認の蓄積などでユーザー名入りの絶対パスが混入するため、ミラーでは `~` 表記に正規化する:
   ```bash
   find dotfiles/claude -type f -exec sed -i '' "s|${HOME}|~|g" {} +
   grep -rn "/Users/" dotfiles/claude/ || echo "OK: ユーザー名パスなし"
   ```
   grep がヒットした場合は該当箇所を確認し、`~` 表記へ手動で直してから進める。

3. **秘密情報チェック（Security ルール準拠）:** ミラーに実トークン・API キー等の値が混入していないか確認する:
   ```bash
   grep -rniE '(api[_-]?key|token|secret|password|credential)' dotfiles/claude/ || echo "OK: 秘密情報らしき語なし"
   ```
   ヒット行は必ず目視で判断する（キー名の参照・許可ルール・ドキュメント記述は問題ない。実際の値が入っていたら該当ファイルをミラーから外し、除外リストへの追加を検討する）。

4. **新しい同期候補の探索:** `~/.claude/` 直下に、同期対象にも既知の除外にも該当しない項目が増えていないか確認する（`sed` は `ls` が `-F` エイリアスの環境でも完全一致が効くよう末尾スラッシュを除去する）:
   ```bash
   ls -A ~/.claude | sed 's:/*$::' \
     | grep -vE '^(CLAUDE\.md|settings\.json|statusline-command\.sh|keybindings\.json|\.mcp\.json|rules|hooks|agents|commands)$' \
     | grep -vE '^(skills|projects|plugins|backups|cache|debug|downloads|file-history|ide|paste-cache|session-env|sessions|shell-snapshots|tasks|telemetry|auto-resume|security|\.cc-writes|\.credentials\.json|remote-settings\.json|history\.jsonl|stats-cache\.json|mcp-needs-auth-cache\.json|\.DS_Store)$' \
     | grep -vE '^(security_warnings_state_.*|\.last-.*|.*\.bak\..*)$' \
     || echo "新しい同期候補なし"
   ```
   ヒットした項目は「手書きのグローバル設定か / 状態・キャッシュか」を判断し、設定なら本 SKILL.md と global-config-push の対象リストに追加してから再実行、状態・キャッシュなら両スキルの除外リストと本コマンドの除外パターンに追記する。

5. **差分確認:**
   ```bash
   git status --short dotfiles/claude/
   git diff dotfiles/claude/
   ```

6. 差分サマリをユーザーに日本語で報告する（変更なし／変更ありの場合は変更ファイル名と概要を示す）。

7. コミットはユーザーが明示的に依頼した場合のみ行う（`/smart-commit` を使う）。
