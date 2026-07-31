# smart-git-sync: 完了済み worktree のクリーンアップ機能 設計

- 日付: 2026-07-31
- 対象スキル: `skills/smart-git-sync/`
- 背景: `smart-git-sync` は現在、マージ済み・リモート削除済み(gone)・squash マージ済みの3種類のブランチを検出し種類ごとに確認の上で削除する。これらの候補ブランチが git worktree で checkout されている場合、`git branch -d/-D` は「branch is checked out at ...」で失敗する。ユーザー要望は「作業が完了している worktree があれば、対応ブランチと一緒に削除する」。

## 決定事項（ユーザー確認済み）

1. **「完了」の判定基準**: 既存の3分類（マージ済み / gone / squash マージ済み）をそのまま流用する。worktree 専用の判定ロジックは新設しない。
2. **worktree 内に未コミット変更が残っていた場合**: 自動的に削除候補から除外し、「未コミット変更のためスキップした worktree」として別途一覧報告する。スクリプト全体は中断しない。
3. **確認 UI**: 新しい4番目のカテゴリを作らず、既存3種類の一覧表示に worktree パスを紐付けて表示する。承認フローは既存の「種類ごとに確認」のままとする。

## 変更内容

### `assets/git-sync.sh`

1. **冒頭で `git worktree prune` を無条件実行**
   実体が既に存在しない worktree の管理メタデータを掃除するだけの非破壊操作。確認不要。

2. **worktree テーブルの構築**
   `git worktree list --porcelain` をパースし、`branch|path` 形式のテキストテーブルを作る（bash 3.2 互換のため連想配列は使わない。macOS 標準 `/bin/bash` が 3.2 のため）。
   - 先頭エントリ（main worktree）は除外
   - スクリプト実行時点の `git rev-parse --show-toplevel`（現在の worktree）は除外
   - `detached` スタンザ（ブランチなし）は照合対象外

3. **既存の MERGED_BRANCHES / GONE_BRANCHES / SQUASH_BRANCHES 算出後にクロス参照**
   各候補ブランチが worktree テーブルに存在するか照合する。
   - 該当し、かつ `git -C <path> status --porcelain` が空（クリーン）→ `WORKTREE_CANDIDATES` に `category|branch|path` の行として出力（category は `merged`/`gone`/`squash`）
   - 該当するが未コミット変更あり → `WORKTREE_SKIPPED` に `branch|path` の行として出力（削除候補には含めない）
   - 該当しない → 何もしない（既存の挙動のまま）

4. **出力ブロック追加**
   ```
   WORKTREE_CANDIDATES<<EOF
   merged|feature/foo|/path/to/worktree-foo
   gone|feature/bar|/path/to/worktree-bar
   EOF
   ```
   （候補なしの場合は `WORKTREE_CANDIDATES=none`）
   ```
   WORKTREE_SKIPPED<<EOF
   feature/baz|/path/to/worktree-baz
   EOF
   ```
   （なしの場合は `WORKTREE_SKIPPED=none`）

### `SKILL.md`

- 「出力の解釈と対応」の各カテゴリ（`DELETE_CANDIDATES` / `GONE_CANDIDATES` / `SQUASH_CANDIDATES`）の説明に追記:
  - 一覧表示時、`WORKTREE_CANDIDATES` に紐付くブランチがあれば worktree パスを併記する
  - 承認後の削除順序は **`git worktree remove <path>` → `git branch -d/-D <branch>`**（worktree 削除が先。ブランチが worktree で使用中のままだと削除に失敗するため）
- 「補助情報」に `WORKTREE_SKIPPED` を追加: 未コミット変更のため自動スキップした worktree の一覧として報告に含める（削除はしない）
- 「削除時の注意」に worktree 絡みの安全策を追記:
  - 未コミット変更のある worktree は自動スキップ（`git worktree remove` 自体も未コミット変更があれば失敗するため二重の安全策）
  - main worktree・現在の worktree は候補から常に除外
  - `git worktree prune` は非破壊操作のため確認なしで実行してよい

### `README.md`

- 「動作内容」に worktree クリーンアップのステップを追記
- 「安全性」に worktree 関連の安全策（未コミット変更スキップ・main/current worktree 除外）を追記

## 非スコープ

- worktree 専用の「完了」判定ロジック（既存3分類以外の基準）は追加しない
- `git worktree remove --force` は使わない（未コミット変更のチェックで事前に除外するため、force は不要かつ危険）
- worktree の新規作成・命名規則（`using-git-worktrees` 等）はこのスキルの対象外

## 検証方法

- `bash -n skills/smart-git-sync/assets/git-sync.sh` で構文チェック
- ローカルで実際に worktree を作成し（`git worktree add ../tmp-wt -b test/wt-cleanup`）、対象ブランチをマージ済み状態にしてからスクリプトを実行し、`WORKTREE_CANDIDATES` に正しく出現することを確認
- 未コミット変更を残した worktree では `WORKTREE_SKIPPED` に出現し `WORKTREE_CANDIDATES` には出現しないことを確認
- 現在の worktree・main worktree が候補から除外されることを確認
