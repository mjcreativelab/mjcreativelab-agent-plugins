# smart-spec-to-pr

「やりたいこと」の要件明確化から PR 作成までを、既存スキルの連鎖で進める薄い **conductor** スキル。
各フェーズの本体（設計・計画・実装・レビュー）は既存スキルが担い、本スキルは**進行管理・受け渡し・ゲート**だけを持ち込む（フェーズロジックを複製しない）。**終点は PR 作成**で、マージ・デプロイはスコープ外。

## フロー

```
Phase 1  要件明確化（AskUserQuestion）→ spec 化 → spec 承認ゲート（唯一のブロッキング承認）
Phase 2  Issue 起票（spec 全文を Issue 本文＝永続正本に）
Phase 3a 設計（software-architect を Skill 起動 → 出力を Issue コメント化）
Phase 3b レビューモード確定（未指定ならレビューループを選択）
Phase 3c/d ハンドオフ（smart-issue-plan / smart-issue-resolve のコマンド + 終点チェックリストを提示）
```

conductor が 1 ターンで制御を保持するのは **Phase 3b まで**。`smart-issue-plan` / `smart-issue-resolve` は `disable-model-invocation` のため Skill 起動できず、Phase 3c/d で**手動ランブック**として提示してターンを終える（半自動ハンドオフ）。ハンドオフ後の分岐・強制はしない。

## 使い方

```
/smart-spec-to-pr
/smart-spec-to-pr 通知設定画面にメール通知のオンオフを追加したい
/smart-spec-to-pr 検索結果のページネーションを直したい --claude-adv-review-loop
```

または「やりたいことから PR まで通して」「要件を固めて実装まで進めて」と伝える。

## オプション

レビューループフラグは検出したものを `smart-issue-resolve` へ**そのまま転送**する（優先順位・自動昇格の解決は `smart-issue-resolve` の責務）。未指定の場合は Phase 3b で選択する。

| フラグ | 別名 | 内容 |
|---|---|---|
| `--claude-review-loop` | `-cldrl` | Claude 標準レビューループ |
| `--claude-adv-review-loop` | `-cldarl` | Claude 敵対的レビューループ |
| `--codex-review-loop` | `-cdxrl` | Codex 標準レビューループ |
| `--codex-advs-review-loop` | `-cdxarl` | Codex 敵対的レビューループ |

## 使い分け

- 要件がまだ言葉になっていない段階から束ねたい → **smart-spec-to-pr**（本スキル）
- 既存 Issue の実装計画だけ作りたい → `/smart-issue-plan #<番号>`
- 既存 Issue から実装に着手したい → `/smart-issue-resolve #<番号>`

## 前提条件

- **Claude 専用** — AskUserQuestion / Skill ツールに依存するため、他エージェント（Codex / Cursor / Gemini）では動作しない
- **GitHub MCP サーバー** — Phase 2 以降の Issue 起票・コメント投稿（`issue_write` / `search_issues` / `add_issue_comment` / `get_me`）に使用
- **連鎖先スキル** — `software-architect`（Skill 起動）、`smart-issue-plan` / `smart-issue-resolve`（ハンドオフで手動実行）
- レビューループのうち Codex 系を選ぶ場合は Codex プラグイン・CLI が必要
