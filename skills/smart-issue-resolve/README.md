# smart-issue-resolve

GitHub Issue ID を受け取り、Issue を読み込んでブランチを作成・チェックアウトし、作業を開始するスキル。

## 使い方

```
/smart-issue-resolve #134
/smart-issue-resolve #134 -p テストも書いて
/smart-issue-resolve #134 --codex-review-loop   # または -cdxrl
/smart-issue-resolve #134 --codex-advs-review-loop   # または -cdxarl（敵対的レビュー）
```

または「Issue #134 やって」「#42 に取り掛かる」と伝える。

## オプション

| オプション        | 説明                                     |
| ----------------- | ---------------------------------------- |
| `-p <プロンプト>` | 作業に関する追加指示（実装方針・制約等） |
| `--codex-review-loop`（`-cdxrl`） | 実装後に Codex 標準レビューループを実施し、収束後にコミット・PR 作成まで自動で行う（Claude Code + Codex プラグイン環境前提） |
| `--codex-advs-review-loop`（`-cdxarl`） | 実装後に Claude=Breaker × Codex=Judge の敵対的レビューループを実施する。収束後の自動コミット・PR は標準と同じ |

> 認証・個人情報・決済などセキュリティ影響を検出した場合は、フラグ未指定でも敵対的レビューを自動発動する（このときレビューは実施するが、コミット・PR の自動実行は行わない — 従来の完了案内に切り替える）。旧 `-codex-loop` は `--codex-review-loop` にリネームされ、使用できなくなった。

## フロー

1. Issue を読み取り、内容を把握する
2. 既存の実装計画（`/smart-issue-plan` が作成したコメント or `[実装計画]` Issue）があれば参照し、計画記録の分析時点 SHA と最新デフォルトブランチの差分から陳腐化を検出する（古ければ計画更新を提案）
3. 作業ツリーの状態を確認する（未コミット変更は識別可能なメッセージ付きで stash）
4. Issue に基づいたブランチを作成・チェックアウトする
5. 関連領域のテストをベースラインとして実行してから実装する
6. 作業完了後、変更サマリを提示して `/smart-commit` の使用を提案する（勝手にコミット・push しない）

## Codex レビューループ

いずれのフラグでも、採用すべき指摘がなくなるまで「レビュー取得 → 妥当性判定（過剰対応チェック） → 修正 → テスト再実行」をループする（3 ラウンドごとに続行/打ち切り/中止をユーザーに確認）。**返ってきた指摘を採用するか（過剰対応でないか）の判定は、どのモードでもレビュイーの Claude が行う**。

- **標準（`--codex-review-loop` / `-cdxrl`）**: Codex（`codex:rescue` 経由）が単独で diff をレビューする
- **敵対的（`--codex-advs-review-loop` / `-cdxarl`）**: Claude=Breaker（反例・攻撃シナリオの生成、可能なら failing テスト実行）× Codex=Judge（真の欠陥かノイズかを裁定）の二者構造。`code-reviewer-adversarial` スキルは `disable-model-invocation` のため直接委譲できないので、その二者構造をループ内にインライン再現している
- **セキュリティ自動発動**: 認証・個人情報・決済などセキュリティ影響を Issue や変更ファイルから検出したら、フラグ未指定でも敵対的レビューを自動で有効化する（発動理由を明示）。ただしこの自動発動のみのケースでは**コミット・PR は自動実行せず**、従来の完了案内に切り替える（外部副作用の自動化は明示オプトイン時のみ）
- 収束後の自動コミット・PR（フラグ明示時のみ）は `smart-commit` / `smart-pr` が `disable-model-invocation` のため、`git` / `gh`（または GitHub MCP）で直接実行する。機密ファイル警告・pre-commit hook・behind 時のマージ確認などの安全系は維持する
- PR 本文のレビュアー向け補足に `🤖 Codex レビュー済み（標準…）` / `🤖 Codex 敵対的レビュー済み（Breaker×Judge…）` を記載する
- `codex:rescue` が使えない環境では Claude がレビュー・裁定を代行せず、従来の完了案内（コミット・PR は手動）にフォールバックする（レビュー済み表記なし）
- 実装とは独立に敵対的レビューだけ行いたい場合は `/code-reviewer-adversarial` を直接使う

## 関連スキル

- `/smart-issue-plan` — 実装計画のみ作成する。計画を先に立てたいときに使う
- `/smart-commit` — 本スキル完了後のコミット作成（レビューループのフラグ明示時は自動で git/gh 直呼びに切り替わるため、手動起動は非フラグ時の経路）
- `/smart-pr` — PR の作成・更新（同上）
- `/code-reviewer-adversarial` — 実装から独立して敵対的レビューだけ回したいときに直接使う
- `/codex:adversarial-review` — Codex 単独の敵対レビューをコード diff に単発でかけたいときに直接使う（Codex プラグイン付属。対象は git diff のみで計画テキストは対象外。本スキルのループには `disable-model-invocation` のため組み込めない）

## 推奨: 新規セッションで実行する

このスキルは **新規セッションで実行する** ことを推奨する。

- Issue の読み取り → ブランチ作成 → 実装まで一貫して行うため、クリーンなコンテキストで開始するのが効率的
- **新しいタスクに取り掛かるとき、新規セッションで `/smart-issue-resolve #123` を実行するのがベスト**

## 前提条件

- **git** — ブランチ作成・チェックアウトに使用
- **GitHub MCP サーバー** — Issue の読み取りに必須（[GitHub MCP plugin](https://github.com/anthropics/claude-code-plugins/tree/main/github)）
- **Codex プラグイン（`codex:rescue` スキル）** — `--codex-review-loop` / `--codex-advs-review-loop` 使用時、およびセキュリティ自動発動時のみ必須
- **git / gh（または GitHub MCP）** — レビューループ収束後の自動コミット・PR 作成に使用（`smart-commit` / `smart-pr` は `disable-model-invocation` のため自動呼び出し不可。手動起動は従来どおり可能）
