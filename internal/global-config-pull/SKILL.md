---
name: global-config-pull
description: グローバル Claude 設定（~/.claude/CLAUDE.md・settings.json・statusline-command.sh・rules/）をリポジトリの dotfiles/claude/ にコピーして取り込む。「設定を取り込む」「グローバル設定を pull して」と言ったら起動。
disable-model-invocation: true
metadata:
  internal: true
---

# Global Config Pull

`~/.claude/` の設定ファイルを `dotfiles/claude/` にコピーして Git 管理下に取り込む。

**対象ファイル:**
- `~/.claude/CLAUDE.md` → `dotfiles/claude/CLAUDE.md`
- `~/.claude/settings.json` → `dotfiles/claude/settings.json`
- `~/.claude/statusline-command.sh` → `dotfiles/claude/statusline-command.sh`
- `~/.claude/rules/*.md` → `dotfiles/claude/rules/`（CLAUDE.md から条件読み込みされる外部参照ルール一式）

## 手順

1. **コピー実行:**
   ```bash
   cp ~/.claude/CLAUDE.md dotfiles/claude/CLAUDE.md
   cp ~/.claude/settings.json dotfiles/claude/settings.json
   cp ~/.claude/statusline-command.sh dotfiles/claude/statusline-command.sh
   mkdir -p dotfiles/claude/rules && cp ~/.claude/rules/*.md dotfiles/claude/rules/
   ```

2. **パス正規化（記述ルール準拠）:** 実体の settings.json には許可承認の蓄積でユーザー名入りの絶対パスが混入するため、ミラーでは `~` 表記に正規化する:
   ```bash
   sed -i '' "s|${HOME}|~|g" dotfiles/claude/CLAUDE.md dotfiles/claude/settings.json dotfiles/claude/statusline-command.sh dotfiles/claude/rules/*.md
   grep -rn "/Users/" dotfiles/claude/ || echo "OK: ユーザー名パスなし"
   ```
   grep がヒットした場合は該当箇所を確認し、`~` 表記へ手動で直してから進める。

3. **差分確認:**
   ```bash
   git diff dotfiles/claude/
   git status dotfiles/claude/
   ```

4. 差分サマリをユーザーに日本語で報告する（変更なし／変更ありの場合は変更ファイル名と概要を示す）。

5. コミットはユーザーが明示的に依頼した場合のみ行う（`/smart-commit` を使う）。
