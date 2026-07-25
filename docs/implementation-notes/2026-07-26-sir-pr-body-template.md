# smart-issue-resolve の自動 PR 本文を smart-pr のテンプレート形式に揃える

日付: 2026-07-26（JST）

## 背景

`smart-issue-resolve` はレビューループフラグ（`-cldrl` など）明示時に収束後の PR 作成まで自動実行する。
`smart-commit` / `smart-pr` は `disable-model-invocation` のため Skill ツールから呼べず、PR は GitHub MCP（不在時 `gh`）で直接作成している。
このとき PR 本文の形式が未規定で、手動 `/smart-pr` 経路（`smart-pr/assets/pr-template.md`）と見た目が揃っていなかった。

## 判断した事項

| 観点 | 採用 | 却下 | 理由 |
|---|---|---|---|
| テンプレートの参照方法 | `smart-pr/assets/pr-template.md` を `smart-issue-resolve/assets/` へ複製 | `smart-pr` 側のファイルを相対パス参照 | skill は `npx skills add --skill <name>` で個別 install されるため、他 skill のファイルは配布先に存在しない保証がない（レビュープロンプトの二重化と同じ制約） |
| 構成選択ルール（標準 / 簡易） | `smart-issue-resolve` SKILL.md に同内容を再掲 | テンプレート冒頭コメントだけに任せる | 選択判断は SKILL.md の手順として読ませる必要がある（`smart-pr` も同様に SKILL.md 側に表を持つ） |
| 複製の差異 | 冒頭コメントの参照先行のみ変更（本体は逐語一致） | 完全逐語コピー | `SKILL.md 7-N` は `smart-pr` の節番号で resolve 側には存在しないため。`diff` で本体一致を検証できる状態は維持 |
| レビュー済み表記の記載先 | 標準構成 → `## 備考` / 簡易構成 → `## レビュアー向け補足` | テンプレートに専用セクションを追加 | 既存テンプレートの構成を変えず、両構成に存在する自由記述セクションへ収めた（resolve 固有の指定なので同期対象外と明記） |

## 変更点

- 追加: `skills/smart-issue-resolve/assets/pr-template.md`（`smart-pr` の複製）
- `skills/smart-issue-resolve/SKILL.md` — 「収束後のコミット・PR 作成」に小節「PR タイトル・本文」を追加（タイトル形式・構成選択表・`body` は実改行・Closes/Refs の扱い・同期ノート）。手順 3 の文面をテンプレート参照に更新
- `skills/smart-pr/SKILL.md` — 7-N に同期ノートを追加
- `skills/smart-issue-resolve/README.md` — PR 本文形式の説明を追記
- `CLAUDE.md` — 「スキル改修時の注意」に PR 本文テンプレートの同期対象を追加

## 検証

- `diff` でテンプレート本体（冒頭コメント行を除く）が `smart-pr` 版と一致することを確認
- `npx skills add ./ --list` で `smart-issue-resolve` / `smart-pr` の検出を確認
- `skills/smart-issue-resolve/SKILL.md` は 352 行（500 行目安内）
