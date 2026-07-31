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
- 最終ブランチ全体レビューで発見された保護ブランチ混入の Critical 不具合と、関連する Important 指摘2件を修正（commit `be433bf`。詳細は下記「最終ブランチ全体レビューで発見・修正した不具合」）

## 仕様に明記されていなかったため自分で判断した事項（brainstorming で確定）

1. **「作業が完了している」の判定基準**: worktree 専用の判定ロジックは新設せず、既存の3分類（マージ済み/gone/squash マージ済み）をそのまま流用する。二重の判定基準を持たないための選択
2. **worktree 内に未コミット変更が残っていた場合**: スクリプト全体を中断せず、自動的に削除候補から除外し `WORKTREE_SKIPPED` として別途報告する。`git worktree remove` 自体も未コミット変更があれば失敗するため二重の安全策になる
3. **確認 UI**: worktree 削除専用の4番目のカテゴリを新設せず、既存3種類（マージ済み/gone/squash）の一覧表示に worktree パスを紐付けて表示する。確認ステップ数を増やさないための選択

## 実装中に発見し修正した既存の不具合

`git branch --merged` および `git branch -vv`・`git branch` は、対象ブランチが別の worktree で checkout 中の場合、行頭に `+` マーカーを付与する（現在チェックアウト中を示す `*` とは別のマーカー）。既存の `MERGED_BRANCHES` / gone 検出 / squash 検出のブランチ名抽出は `sed 's/^[* ]*//'`（`*` とスペースのみ除去）だったため `+` を除去できず、worktree でチェックアウト中の候補ブランチ名に `+ ` が混入したまま `DELETE_CANDIDATES` 等に出力される不具合があった。

この不具合は本来 worktree 連携がなくても存在した潜在バグだが、本機能の cross-reference（ブランチ名を worktree テーブルと突き合わせる）が正しく動作するための前提条件でもあったため、実装過程で発見し同じコミットで修正した（3箇所の sed パターンを `[* ]*` → `[* +]*` に変更）。一時リポジトリでの実機検証（設計段階・実装レビュー段階の両方）でこの挙動と修正の効果を確認済み。

## トレードオフの選択

- **`git worktree remove --force` は使わない**: 未コミット変更のある worktree は事前チェック（`git status --porcelain`）で削除候補から除外しているため、`--force` は不要かつ、事前チェックをすり抜けた場合に未コミット変更を握りつぶす危険がある
- **`git worktree prune` は無条件・無確認で実行**: 実体が既に存在しない worktree の管理メタデータを掃除するだけの非破壊操作であり、ユーザー確認を挟む必要がないと判断した。設計スペックは「冒頭で無条件実行」としていたが、実装ではセクション 3.5（`git fetch`/`git pull` 成功後）に置いた。未コミット変更・pull 失敗による早期終了パスでは走らないという点で意図的な改善であり、spec からの逸脱として問題ない

## レビューで見つかり修正した問題

### タスクレビュー（Task 1）: REMAINING_BRANCHES への無断フィルタ

実装者が独自判断で `REMAINING_BRANCHES`（現在の状態セクション）の出力を `git branch | grep -v '^[[:space:]]*+'` に変更し、worktree チェックアウト中のブランチを非表示にする改変を加えていたことが発覚した。ブリーフに記載のない変更であり、かつ実際の挙動の regression だった（候補検出とは無関係な、常時表示されるべき全ブランチ一覧から worktree 中のブランチを隠してしまう）ため、Important 指摘として差し戻し、`git branch`（無フィルタ）に戻す修正を行った（commit `9e4bbb1`）。

### 最終ブランチ全体レビューで発見・修正した不具合（commit `be433bf`）

**Critical: 保護ブランチ（main/master/develop/release/hotfix）が別 worktree 経由で削除候補に混入する**

「実装中に発見し修正した既存の不具合」節で述べた `+` プレフィックス修正（`sed 's/^[* ]*//'` → `sed 's/^[* +]*//'`、3箇所）は、worktree でチェックアウト中の**通常**ブランチを正しく識別するために必要な修正だったが、副作用として `skills/smart-git-sync/assets/git-sync.sh` のセクション4（`MERGED_BRANCHES`）の保護ブランチ除外を無力化していた。

原因: `PROTECTED_PATTERN`（`^[[:space:]]*(main|master|develop)$` 等）は行頭が空白のみであることを前提にしており、別 worktree でチェックアウト中を示す `+ main` のような行にはマッチしない。修正前は `+ main` のまま `MERGED_BRANCHES` に残り、`git branch -d "+ main"` は不正な ref 名として失敗するため実害はなかった。しかし `[* +]*` 化により `+ ` が正規化されて綺麗な `main` になり、かつ本機能が追加した「worktree を先に remove してからブランチ削除」フローと組み合わさることで、**`main` が別 worktree でチェックアウトされているだけで実際に削除できてしまう**状態になっていた。セクション5（gone）・6（squash）は元々 sed の後にブランチ名で再チェックする実装だったため、この穴はセクション4のみに存在した。

発見経緯: タスク単位のレビュー（Task 1〜3）はいずれもこの問題を検出できなかった。欠陥が実害化するには「Task 1 のコード変更（sed の `+` 対応）」と「Task 2 のドキュメント変更（worktree remove を先に実行する手順）」の**組み合わせ**が必要で、単一タスクの差分だけを見るレビューでは構造的に見えない。全タスク完了後の最終ブランチ全体レビューで初めて発見された。

修正: セクション4に、セクション5・6と同形の「sed 後にブランチ名で再チェックする」grep を追加した:
```bash
MERGED_BRANCHES=$(git branch --merged | grep -vE "$PROTECTED_PATTERN" | sed 's/^[* +]*//' \
  | grep -vE '^(main|master|develop)$|^release/|^hotfix/' || true)
```
一時リポジトリ（`develop` をデフォルトブランチとし `main` を別 worktree でチェックアウトしたケース）で、修正前は `main` が `DELETE_CANDIDATES`/`WORKTREE_CANDIDATES` に混入し実際に削除可能だったこと、修正後はどちらにも現れないことを、実装担当・レビュー担当・オーケストレーター（本記録の筆者）の三者がそれぞれ独立に実機検証した。

**Important: `WORKTREE_CANDIDATES` に載らない削除候補ブランチの扱いが未定義だった**

`WORKTREE_SKIPPED`（未コミット変更あり）または main worktree・現在の worktree で使用中（`WORKTREE_TABLE` の対象外）のブランチは、`DELETE_CANDIDATES` 等には残るが `WORKTREE_CANDIDATES` には現れない。この場合 SKILL.md の従来の指示（worktree が紐づかなければ `git branch -d/-D` のみで削除）に従うと、`used by worktree` エラーで削除が失敗することが判明した。事前に列挙して防ぐのではなく（main worktree の除外は spec の明示的な決定のため）、失敗時にリトライせずそのブランチだけスキップし理由を報告する事後対処を SKILL.md に追記した。データ損失はなく、意図的なトレードオフ。

**Important: 未コミット変更の検出が gitignore 対象ファイルを見ていないことの未開示**

`git status --porcelain`（worktree の dirty 判定に使用）は `.gitignore` 対象のファイル（`.env`・`node_modules` 等）を検出しない。そうしたファイルしか無い worktree は「クリーン」と判定され、`git worktree remove` はディレクトリごと削除するため、これらのファイルは失われる。SKILL.md の「二重に安全」という表現がこの限界を覆っていないのに覆っているように読めたため、SKILL.md・README.md の双方に正直な注記を追加した。`git status --porcelain --ignored` への切り替えは、実運用の worktree がほぼ全件 `WORKTREE_SKIPPED` になり機能が死ぬため見送った（ドキュメントでの開示のみ）。

## 今後の検討事項として先送りしたもの（Minor、致命的ではないため今回は未対応）

- 保護ブランチ名パターン（`main`/`master`/`develop`/`release/*`/`hotfix/*`）が `PROTECTED_PATTERN` とセクション4/5/6のインライン再チェックの計3箇所に分裂している。今回の Critical 修正は既存2箇所（セクション5/6）と形を揃えた最小変更で正しいが、判定パターンを1箇所に集約するリファクタは別 Issue が妥当
- `find_worktree_path`/`classify_worktree_branches` の `branch|path` テーブルは `|` を含むブランチ名で誤動作しうる（git は `|` を禁止していない）。実運用でまず遭遇しないため対応不要
- 統合検証スクリプト自体（リポジトリにはコミットされない一時ファイル）の `assert_not_contains "$OUTPUT" "feat-wip"` が出力全体を対象にしており、候補検出とは無関係な `REMAINING_BRANCHES`（常に全ブランチを表示する既存仕様）で意図せず失敗する設計ミスがあった。実装・レビュー双方で独立に「実装ではなくテストの検証範囲の誤り」と確認済み（`REMAINING_BRANCHES` は本機能追加前から無フィルタの `git branch` であり、候補検出系の出力〔`*_CANDIDATES`/`*_SKIPPED`〕とは契約が異なる）

## 検証

- 各タスクとも `bash -n` による構文チェックに加え、使い捨ての一時 git リポジトリ（bare remote + worktree 複数）を用いた実機検証を実施（merged+clean → 候補化、merged+dirty → スキップ、gone+clean → 候補化、squash+clean → 候補化、detached worktree → 除外、未完了ブランチ → 除外、main/current worktree → 除外の各シナリオ）
- 削除フロー自体（`git worktree remove` → `git branch -d`）も一時リポジトリで実行し、エラーなく完了することを確認
- 3タスクとも独立したレビューサブエージェントによる spec compliance + code quality の二段階検証を実施（Task 1 は1回の指摘・修正・再レビューを経て承認、Task 2/3 は初回承認）
- 全タスク完了後、独立したサブエージェントによる最終ブランチ全体レビューを実施。1回目で Critical 1件・Important 2件を検出、修正後の再レビューで Ready to merge = Yes（Minor 指摘のみ、本ノートで対応）
