---
name: global-config-push
description: リポジトリの dotfiles/claude/ からグローバル Claude 設定（~/.claude/ の CLAUDE.md・settings.json・statusline-command.sh・rules/・hooks/・agents/・commands/・keybindings.json・.mcp.json）へ反映する。「設定を反映する」「グローバル設定を push して」と言ったら起動。既存ファイルはバックアップ後に上書き。
disable-model-invocation: true
metadata:
  internal: true
---

# Global Config Push

`dotfiles/claude/` の設定ファイルを `~/.claude/` に反映（コピー）する。

## 同期対象

pull（global-config-pull）と同一。ミラー側に存在するものだけを反映する:

- ファイル: `CLAUDE.md`・`settings.json`・`statusline-command.sh`・`keybindings.json`・`.mcp.json`
- ディレクトリ: `rules/`・`hooks/`・`agents/`・`commands/`

push は追加・上書きのみ行い、`~/.claude/` 側にしかないファイルは削除しない（ローカル限定ファイルの保護。削除の反映＝ミラー同期は pull 側のみ）。

## 手順

リポジトリルートで実行する。

1. **差分確認（反映前に必ず実施）:**
   ```bash
   for f in CLAUDE.md settings.json statusline-command.sh keybindings.json .mcp.json; do
     [ -f dotfiles/claude/"$f" ] && { echo "--- $f"; diff dotfiles/claude/"$f" ~/.claude/"$f"; }
   done
   for d in rules hooks agents commands; do
     [ -d dotfiles/claude/"$d" ] && { echo "--- $d/"; diff -r dotfiles/claude/"$d" ~/.claude/"$d"; }
   done
   ```
   差分サマリを日本語で提示し、ユーザーに反映の意思を確認する（`AskUserQuestion` を使う）。

2. **バックアップ:**
   ```bash
   TS=$(date +%Y%m%d%H%M%S)
   for f in CLAUDE.md settings.json statusline-command.sh keybindings.json .mcp.json; do
     [ -f ~/.claude/"$f" ] && cp ~/.claude/"$f" ~/.claude/"$f".bak.${TS}
   done
   for d in rules hooks agents commands; do
     [ -d ~/.claude/"$d" ] && cp -R ~/.claude/"$d" ~/.claude/"$d".bak.${TS}
   done
   ```

3. **コピー実行（追加・上書きのみ。削除はしない）:**
   ```bash
   for f in CLAUDE.md settings.json statusline-command.sh keybindings.json .mcp.json; do
     [ -f dotfiles/claude/"$f" ] && cp dotfiles/claude/"$f" ~/.claude/"$f"
   done
   for d in rules hooks agents commands; do
     [ -d dotfiles/claude/"$d" ] && { mkdir -p ~/.claude/"$d" && cp -R dotfiles/claude/"$d"/. ~/.claude/"$d"/; }
   done
   chmod +x ~/.claude/hooks/*.sh ~/.claude/statusline-command.sh 2>/dev/null || true
   ```

4. **確認:**
   ```bash
   for f in CLAUDE.md settings.json statusline-command.sh keybindings.json .mcp.json; do
     [ -f dotfiles/claude/"$f" ] && { diff dotfiles/claude/"$f" ~/.claude/"$f" >/dev/null && echo "$f: OK" || echo "$f: 差分あり（要確認）"; }
   done
   for d in rules hooks agents commands; do
     [ -d dotfiles/claude/"$d" ] && { echo "--- $d/"; diff -r dotfiles/claude/"$d" ~/.claude/"$d"; }
   done
   ```
   結果を日本語で報告する。バックアップパスも提示すること。ディレクトリの diff で `Only in ~/.claude/...` が出た場合は、ミラー対象外（ローカル限定）のファイルを示すだけなので、ミラー側ファイルが一致していれば反映は成功と判断してよい。
