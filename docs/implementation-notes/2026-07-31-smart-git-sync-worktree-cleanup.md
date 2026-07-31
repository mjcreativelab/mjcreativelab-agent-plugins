# smart-git-sync: 完了済み worktree のクリーンアップ機能 実装ノート

- 日付: 2026-07-31（JST）
- 依頼: smart-git-sync に機能を追加し、作業が完了している worktree があれば対応ブランチと一緒に削除できるようにする
- 設計スペック: [docs/specs/2026-07-31-smart-git-sync-worktree-cleanup-design.md](../specs/2026-07-31-smart-git-sync-worktree-cleanup-design.md)
- 実装計画: `docs/superpowers/plans/2026-07-31-smart-git-sync-worktree-cleanup.md`（gitignore 対象・作業用ドキュメントのため本リポジトリには残らない）
- 実行方法: superpowers:subagent-driven-development（タスクごとに新規サブエージェントを起動し実装 → 独立コンテキストでのタスクレビューを都度実施）

## 変更内容

- `skills/smart-git-sync/assets/git-sync.sh`: `git worktree list --porcelain` から worktree テーブルを構築し、既存の3分類（マージ済み/gone/squash マージ済み）検出結果とクロスリファレンスして `WORKTREE_CANDIDATES`（`category|branch|path`）・`WORKTREE_SKIPPED`（`branch|path`）を新たに出力する（commit `9b5c2bc`, `9e4bbb1`）
- `skills/smart-git-sync/SKILL.md`: 上記出力の解釈と、worktree が紐づく候補の削除順序（`git worktree remove <path>` → `git branch -d/-D <branch>`）を追記（commit `0fafc02`）
- `skills/smart-git-sync/README.md`: 利用者向けに動作概要・安全性の説明を追記（commit `f82aab7`）

## 仕様に明記されていなかったため自分で判断した事項（brainstorming で確定）

1. **「作業が完了している」の判定基準**: worktree 専用の判定ロジックは新設せず、既存の3分類（マージ済み/gone/squash マージ済み）をそのまま流用する。二重の判定基準を持たないための選択
2. **worktree 内に未コミット変更が残っていた場合**: スクリプト全体を中断せず、自動的に削除候補から除外し `WORKTREE_SKIPPED` として別途報告する。`git worktree remove` 自体も未コミット変更があれば失敗するため二重の安全策になる
3. **確認 UI**: worktree 削除専用の4番目のカテゴリを新設せず、既存3種類（マージ済み/gone/squash）の一覧表示に worktree パスを紐付けて表示する。確認ステップ数を増やさないための選択

## 実装中に発見し修正した既存の不具合

`git branch --merged` および `git branch -vv`・`git branch` は、対象ブランチが別の worktree で checkout 中の場合、行頭に `+` マーカーを付与する（現在チェックアウト中を示す `*` とは別のマーカー）。既存の `MERGED_BRANCHES` / gone 検出 / squash 検出のブランチ名抽出は `sed 's/^[* ]*//'`（`*` とスペースのみ除去）だったため `+` を除去できず、worktree でチェックアウト中の候補ブランチ名に `+ ` が混入したまま `DELETE_CANDIDATES` 等に出力される不具合があった。

この不具合は本来 worktree 連携がなくても存在した潜在バグだが、本機能の cross-reference（ブランチ名を worktree テーブルと突き合わせる）が正しく動作するための前提条件でもあったため、実装過程で発見し同じコミットで修正した（3箇所の sed パターンを `[* ]*` → `[* +]*` に変更）。一時リポジトリでの実機検証（設計段階・実装レビュー段階の両方）でこの挙動と修正の効果を確認済み。

## トレードオフの選択

- **`git worktree remove --force` は使わない**: 未コミット変更のある worktree は事前チェック（`git status --porcelain`）で削除候補から除外しているため、`--force` は不要かつ、事前チェックをすり抜けた場合に未コミット変更を握りつぶす危険がある
- **`git worktree prune` は無条件・無確認で実行**: 実体が既に存在しない worktree の管理メタデータを掃除するだけの非破壊操作であり、ユーザー確認を挟む必要がないと判断した

## レビューで見つかり修正した問題

タスクレビュー（Task 1）で、実装者が独自判断で `REMAINING_BRANCHES`（現在の状態セクション）の出力を `git branch | grep -v '^[[:space:]]*+'` に変更し、worktree チェックアウト中のブランチを非表示にする改変を加えていたことが発覚した。ブリーフに記載のない変更であり、かつ実際の挙動の regression だった（候補検出とは無関係な、常時表示されるべき全ブランチ一覧から worktree 中のブランチを隠してしまう）ため、Important 指摘として差し戻し、`git branch`（無フィルタ）に戻す修正を行った（commit `9e4bbb1`）。

## 今後の検討事項として先送りしたもの（Minor、致命的ではないため今回は未対応）

- `classify_worktree_branches` 内の `while IFS= read -r branch` のループ変数 `branch` に `local` 宣言がなくグローバルスコープに漏れる（同関数内の他の変数は `local` 宣言済み）。現状ダウンストリームで読まれることはなく機能上の影響はない
- 統合検証スクリプトが squash カテゴリを worktree ありで直接テストしていない（`classify_worktree_branches` は merged/gone/squash で共通の単一実装のため、merged/gone のテストで同じコードパスは検証済み）
- 統合検証スクリプト自体（リポジトリにはコミットされない一時ファイル）の `assert_not_contains "$OUTPUT" "feat-wip"` が出力全体を対象にしており、候補検出とは無関係な `REMAINING_BRANCHES`（常に全ブランチを表示する既存仕様）で意図せず失敗する設計ミスがあった。実装・レビュー双方で独立に「実装ではなくテストの検証範囲の誤り」と確認済み（`REMAINING_BRANCHES` は本機能追加前から無フィルタの `git branch` であり、候補検出系の出力〔`*_CANDIDATES`/`*_SKIPPED`〕とは契約が異なる）

## 検証

- 各タスクとも `bash -n` による構文チェックに加え、使い捨ての一時 git リポジトリ（bare remote + worktree 複数）を用いた実機検証を実施（merged+clean → 候補化、merged+dirty → スキップ、gone+clean → 候補化、detached worktree → 除外、未完了ブランチ → 除外、main/current worktree → 除外の各シナリオ）
- 削除フロー自体（`git worktree remove` → `git branch -d`）も一時リポジトリで実行し、エラーなく完了することを確認
- 3タスクとも独立したレビューサブエージェントによる spec compliance + code quality の二段階検証を実施（Task 1 は1回の指摘・修正・再レビューを経て承認、Task 2/3 は初回承認）
