---
name: global-config-push
description: リポジトリの dotfiles/claude/ からグローバル Claude 設定（~/.claude/）へ反映する。「設定を反映する」「グローバル設定を push して」と言ったら起動。既存ファイルはバックアップ後に上書き。
disable-model-invocation: true
metadata:
  internal: true
---

# Global Config Push

`dotfiles/claude/` の設定ファイルを `~/.claude/` に反映（コピー）する。

**対象ファイル:**
- `dotfiles/claude/CLAUDE.md` → `~/.claude/CLAUDE.md`
- `dotfiles/claude/settings.json` → `~/.claude/settings.json`
- `dotfiles/claude/statusline-command.sh` → `~/.claude/statusline-command.sh`

## 手順

1. **差分確認（反映前に必ず実施）:**
   ```bash
   diff dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
   diff dotfiles/claude/settings.json ~/.claude/settings.json
   diff dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh
   ```
   差分サマリを日本語で提示し、ユーザーに反映の意思を確認する（`AskUserQuestion` を使う）。

2. **バックアップ:**
   ```bash
   TS=$(date +%Y%m%d%H%M%S)
   cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak.${TS}
   cp ~/.claude/settings.json ~/.claude/settings.json.bak.${TS}
   cp ~/.claude/statusline-command.sh ~/.claude/statusline-command.sh.bak.${TS} 2>/dev/null || true
   ```

3. **コピー実行:**
   ```bash
   cp dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
   cp dotfiles/claude/settings.json ~/.claude/settings.json
   cp dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh
   ```

4. **確認:**
   ```bash
   diff dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md && echo "CLAUDE.md: OK"
   diff dotfiles/claude/settings.json ~/.claude/settings.json && echo "settings.json: OK"
   diff dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh && echo "statusline-command.sh: OK"
   ```
   結果を日本語で報告する。バックアップパスも提示すること。
