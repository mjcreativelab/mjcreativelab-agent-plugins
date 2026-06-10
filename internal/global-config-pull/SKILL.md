---
name: global-config-pull
description: グローバル Claude 設定（~/.claude/CLAUDE.md・settings.json・statusline-command.sh）をリポジトリの dotfiles/claude/ にコピーして取り込む。「設定を取り込む」「グローバル設定を pull して」と言ったら起動。
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

## 手順

1. **コピー実行:**
   ```bash
   cp ~/.claude/CLAUDE.md dotfiles/claude/CLAUDE.md
   cp ~/.claude/settings.json dotfiles/claude/settings.json
   cp ~/.claude/statusline-command.sh dotfiles/claude/statusline-command.sh
   ```

2. **差分確認:**
   ```bash
   git diff dotfiles/claude/
   git status dotfiles/claude/
   ```

3. 差分サマリをユーザーに日本語で報告する（変更なし／変更ありの場合は変更ファイル名と概要を示す）。

4. コミットはユーザーが明示的に依頼した場合のみ行う（`/smart-commit` を使う）。
