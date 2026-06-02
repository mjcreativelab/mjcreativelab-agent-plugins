# mjc-git-workflow-tools

Git ワークフローを自動化する Claude Code プラグインパッケージ。

## Skills

### smart-commit

変更内容を分析し、作業単位ごとに分割してコミットする。
コミットメッセージは GitMoji + Conventional Commits 形式で、subject を日本語で記述する（例: `✨ feat(auth): ログイン機能を追加`）。
現在のブランチが変更内容に合わない場合は、適切なブランチへの切り替えや新規作成も行う。
`-p` オプションでコミット対象の選別やコミットメッセージに関する追加指示を渡すことができる。

```
/smart-commit
/smart-commit -p e2e の変更だけコミットして
```

### smart-pr

現在のブランチから GitHub Pull Request を作成・更新する。
作業内容の自動要約・ラベル付与・関連 Issue 紐づけを行う。
PR 作成/更新前にデフォルトブランチを現在のブランチへマージする（必要な場合のみ）。
既存の PR がある場合は、追加コミットの内容を分析して PR の説明・ラベル・関連 Issue を自動更新する。
`-p` オプションで PR の内容に関する追加指示を渡すことができる。

```
/smart-pr
/smart-pr -p レビュアー向け補足にパフォーマンスの懸念を書いて
```

### smart-issue-resolve

GitHub Issue を起点に作業を開始する。
Issue の内容を読み取り、適切なブランチを作成してチェックアウトし、要件に基づいて実装を行う。
作業完了後は `/smart-commit` の使用を提案する（勝手にコミットしない）。
`-p` オプションで作業に関する追加指示を渡すことができる。

```
/smart-issue-resolve #134
/smart-issue-resolve #134 -p テストも書いて
```

### smart-issue-plan

GitHub Issue の実装計画を作成・更新する。
コードベースを探索し、影響範囲・実装手順・リスク・テスト方針を整理する。
計画は Issue コメントとして投稿するか、新規 Issue「[実装計画]」として作成できる。
既存の計画がある場合は更新モードで差分を反映する。
`-p` オプションで計画の観点・制約に関する追加指示を渡すことができる。

```
/smart-issue-plan #123
/smart-issue-plan #123 -p パフォーマンスを重視して
```

### smart-review

ローカルブランチの変更をデフォルトブランチと比較してセルフレビューする。
コード品質・バグリスク・セキュリティの観点でレビューし、Issue 番号があれば要件適合もチェックする。
レビュー結果は会話内に出力し、`-o` オプションでファイルにも保存できる。

```
/smart-review
/smart-review #123
/smart-review -p セキュリティを重点的に
/smart-review -o reviews/review.md
```

### smart-git-sync

デフォルトブランチ（develop or main）にチェックアウトし、fetch/pull してマージ済みブランチを削除する。
マージ済み・リモート削除済み・squash マージ済みの3種類を検出し、種類ごとにユーザー確認後に削除する。

```
/smart-git-sync
```

### smart-review-apply

PR レビューコメント・ローカルファイル・会話内のレビュー結果からフィードバックを読み取り、コードに反映する。
各フィードバックを分類し、対応方針をユーザーに提示してから修正を行う。
PR レビュー元の場合はコメントへの返信も行う。

```
/smart-review-apply
/smart-review-apply -f reviews/review.md
/smart-review-apply -p セキュリティ指摘のみ対応して
```

## 前提条件

このプラグインの使用には、以下のインストールが必要です。

- **git** — diff, commit, push 等の操作に使用
- **GitHub MCP サーバー** — PR 作成・更新、Issue 連携に使用（[GitHub MCP plugin](https://github.com/anthropics/claude-code-plugins/tree/main/github)）

## インストール

`npx skills`（[vercel-labs/skills](https://github.com/vercel-labs/skills)）で skill 単位に install する（旧 Claude marketplace は v2.0.0 で廃止）。

```bash
# 一覧
npx skills add mjcreativelab/mjcreativelab-agent-plugins --list

# 個別 install（推奨: グローバル + タグ pin）
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.0.0 --skill smart-commit -g
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.0.0 --skill smart-pr -g
```
