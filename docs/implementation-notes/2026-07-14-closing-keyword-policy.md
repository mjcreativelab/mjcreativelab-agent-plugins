# 実装ノート — closing keyword ポリシー更新

- 日付: 2026-07-14 / ブランチ: `docs/closing-keyword-policy-20260714`
- 背景: Issue #88 対応完了報告で「closing keyword 不使用の運用」と述べたところ、ユーザーから「global CLAUDE.md には使用は問題ない旨の記載があるはず。問題は closing 目的ではない地の文で closing keyword が使われ、意図しない closing が起きること」との指摘があった。

## 着手前の検証結果

- global CLAUDE.md（`~/.claude/CLAUDE.md`）に「使用は問題ない」旨の記載は無く、AI Agent Role Assignment 節で project 側の「closing keyword 不使用」規約を引用する 1 文のみだった。
- project CLAUDE.md（本リポジトリ）L49 は無条件の使用禁止で、「地の文限定の注意書き」ではなかった。
- ただし `smart-commit/SKILL.md`・`smart-pr/SKILL.md`・`smart-pr/references/git-conventions.md`・`smart-pr/assets/pr-template.md` は元々 `Closes:`/`Refs:` を通常の選択肢として案内しており、project CLAUDE.md が「4 skill 全てに規則を内蔵済み」と主張する記述と実態が食い違っていた（実際に内蔵済みだったのは `smart-issue-resolve` のみ）。
- ユーザーはこの不整合を AskUserQuestion で確認し、「意図的使用は許可＋誤爆防止の注記を追加」を選択した。

## 変更ファイル

- `CLAUDE.md`（L49-50）: 無条件禁止 → 「完全解決時は意図的使用可・地の文での偶然一致による意図しない auto-close は避ける」「部分対応時は使わず手動クローズ」の 2 行に分割
- `skills/smart-issue-resolve/SKILL.md`（L281）: 埋め込みルールの文言を同期
- `skills/smart-commit/SKILL.md`（L135）: `Refs:`/`Closes:` の使い分け基準（完全解決 vs 参照・部分対応）と地の文での誤爆回避、プロジェクト側規約優先の一文を追記
- `skills/smart-pr/references/git-conventions.md`（L44-49）: 同様の使い分け・誤爆回避を追記（smart-pr の正本のためここを主に更新）
- `skills/smart-pr/SKILL.md`（L195）: git-conventions.md 参照を保ったまま簡潔に要約を同期
- `skills/smart-pr/assets/pr-template.md`: 「## 関連 Issue」セクション直前に、完全解決/部分対応の使い分けと地の文回避のコメントを追加

## 自分で判断した事項

1. **スコープをユーザーが直接言及した2ファイル（CLAUDE.md・smart-issue-resolve/SKILL.md）から拡張した**。リポジトリ全体を grep した結果、smart-commit・smart-pr（SKILL.md 2箇所・git-conventions.md・pr-template.md）も同じ矛盾を抱えていたため、「project CLAUDE.md が『4 skill 全てに内蔵済み』と主張している」という既存記述の正確性を保つ目的で、これらも合わせて更新した。
2. **「Closes: 完全解決時 / Refs: 参照・部分対応時」という使い分け基準を新設した**。ユーザーの指示は「意図的使用は許可＋誤爆防止の注記」のみで Closes/Refs の使い分け基準までは明示されていなかったが、この条件がないと「常に Closes を使ってよい」と誤読されるおそれがあるため、既存の Refs 表記を活用して条件を明確化した。
3. **smart-issue-resolve の自動コミット・PR フロー自体は変更しなかった**（例: 「完全解決前提だから常に Closes を付ける」という挙動の自動化はしていない）。本件は「ポリシー文言の修正」であり、フロー挙動の追加は別スコープと判断し、既存の「プロジェクトの Git 規約に従う」という参照方式を維持した。
4. **smart-issue-plan は対象外と確認した**。リポジトリ全体 grep で closing keyword 関連の記載が無いことを確認済み（同スキルは commit/PR を作らないため該当しない）。
5. **ブランチ名は Issue 非紐付けのため `docs/closing-keyword-policy-20260714`**（CLAUDE.md のタイムスタンプ命名規則に従う）。type は `docs`（実行コードの変更を伴わないドキュメント/ルール文言の修正のため）。

## 検証

- 変更した 3 つの SKILL.md の行数が 500 行以内であることを確認（smart-issue-resolve 320 / smart-commit 143 / smart-pr 262 行）
- `npx skills add ./ --list` で smart-commit・smart-issue-resolve・smart-pr が description 込みで検出継続（frontmatter 非破壊）
- リポジトリ全体を grep して「closing keyword」「Closes #」「Closes:」「Refs #」「Refs:」の全出現箇所を洗い出し、smart-issue-plan 以外の全箇所を更新したことを確認
