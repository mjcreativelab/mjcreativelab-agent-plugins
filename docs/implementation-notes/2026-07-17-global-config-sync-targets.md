# global-config-pull/push 同期対象の全面拡張 + verify-before-claim Stop hook

日付: 2026-07-17 (JST)

## 背景

グローバル設定に Stop hook（`~/.claude/hooks/verify-before-claim.sh`）を追加した際、global-config-pull の同期対象に `hooks/` が含まれておらず、ミラーから漏れることが判明した。同期対象をグローバル設定ファイル全般に拡張し、将来の取りこぼしを検出する仕組みを設けた。

## 判断事項

- **同期対象**: ファイルは `CLAUDE.md` / `settings.json` / `statusline-command.sh` / `keybindings.json` / `.mcp.json`（存在するもののみ）、ディレクトリは `rules/` / `hooks/` / `agents/` / `commands/`
- **`skills/` は除外**: npx skills / plugin marketplace の install 先＝配布物であり、正本は各配布元リポジトリ。ミラーすると二重管理になる
- **`.credentials.json` / `remote-settings.json` は除外**: 認証情報・リモート管理設定はリポジトリに置かない。`.mcp.json` は対象に含めるが、pull 手順に秘密情報チェックを新設した（現状の中身は URL のみで実値なしを確認済み）
- **pull はミラー同期・push は片方向**: pull は `rsync -a --delete`（ソース側の削除も反映）、push は追加・上書きのみ（ローカル限定ファイルの保護）+ hooks スクリプトへの `chmod +x`
- **新規同期候補の探索ステップを pull に新設**: `~/.claude/` 直下を既知の対象＋既知の除外と突き合わせ、どちらにも該当しない項目を候補として報告し、対象/除外リストの更新を促す
- **検証中に発見したバグ**: `ls` が `-F` 相当にエイリアスされた環境では末尾 `/` により完全一致の除外が効かない。`sed 's:/*$::'` の正規化を挟んで修正

## dotfiles ミラーに入った主な実体変更（本 PR 同梱）

- `hooks/verify-before-claim.sh`（新規）: コード編集後、検証コマンドの実行記録なしに「完了・修正済み」を主張して終了するターンを差し戻す Stop hook。`settings.json` の `hooks.Stop` に登録。合成 transcript による 10 シナリオテストで検証済み（ブロック 3 / 許可 7）
- `rules/fable-engineering-judgment.md`: 9 規律を短文命令形に再構成（Opus / Sonnet 向けの遵守率改善目的）
- `rules/claude-behavior-guidelines.md`: モデル一覧と knowledge cutoff をバージョン固定表記から「各ファミリーの最新版＋環境コンテキスト参照」に変更（陳腐化防止。cutoff はモデルごとに異なるため固定日付は誤りだった）
- `CLAUDE.md`（グローバル）: 「検証強制 Hook / 思考深度」セクションを追加。`MAX_THINKING_TOKENS` は現行モデル（Fable 5 / Sonnet 5 / Opus 4.7 以降・CLI v2.1.111 以降）には無効で、思考深度は `effortLevel`（設定済み "max"）が制御するため env 追加はしない判断

## 検証

- 新しい pull 手順を実行し、`hooks/`（2 スクリプト）・`agents/`（2 定義）・`.mcp.json` がミラーされ、パス正規化後に `/Users/` が残らないことを確認
- 探索ステップは修正後に「新しい同期候補なし」を返すことを確認
- 更新した両スキルを `mise exec node -- npx skills add ./internal/<skill> --skill <skill> -g` で再 install し、配置先とリポジトリ版の一致を diff で確認
