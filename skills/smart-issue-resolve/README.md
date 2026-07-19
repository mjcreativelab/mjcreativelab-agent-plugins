# smart-issue-resolve

GitHub Issue ID を受け取り、Issue を読み込んでブランチを作成・チェックアウトし、役割別エージェントのオーケストレーションで実装するスキル。メインセッションはオーケストレーター（対話・進行制御）に徹し、実装・レビューは model / effort を固定した専任エージェントが担う。

## 使い方

```
/smart-issue-resolve #134
/smart-issue-resolve #134 -p テストも書いて
/smart-issue-resolve #134 --codex-review-loop     # または -cdxrl
/smart-issue-resolve #134 --codex-advs-review-loop # または -cdxarl（敵対的レビュー・Judge=Codex）
/smart-issue-resolve #134 --claude-review-loop     # または -cldrl（Opus レビュワー・観点3グループ並列）
/smart-issue-resolve #134 --claude-adv-review-loop # または -cldarl（敵対的レビュー・独立 Opus×Opus）
```

または「Issue #134 やって」「#42 に取り掛かる」と伝える。

## オプション

| オプション        | 説明                                     |
| ----------------- | ---------------------------------------- |
| `-p <プロンプト>` | 作業に関する追加指示（実装方針・制約等） |
| `--codex-review-loop`（`-cdxrl`） | 実装後に Codex 標準レビューループを実施し、収束後にコミット・PR 作成まで自動で行う（Codex プラグイン前提） |
| `--codex-advs-review-loop`（`-cdxarl`） | Breaker（独立 Sonnet）× Codex=Judge の敵対的レビューループ。収束後の自動コミット・PR は標準と同じ |
| `--claude-review-loop`（`-cldrl`） | Opus レビュワーエージェント（観点を G1/G2/G3 の 3 グループに分割し並列起動）による標準レビューループ（Codex 不要）。収束後の自動コミット・PR は codex 系と同じ |
| `--claude-adv-review-loop`（`-cldarl`） | 独立 Opus の Breaker × Judge による敵対的レビューループ（Codex 不要）。収束後の自動コミット・PR は同上 |

> 複数指定時は adversarial > standard。モード同格で codex 系と claude 系が競合した場合は codex を優先する（別系統モデルの独立性がより高い）。認証・個人情報・決済などセキュリティ影響を検出した場合は、フラグ未指定でも敵対的レビューを自動発動する（Codex 不在環境では claude 系で代替。このときレビューは実施するが、コミット・PR の自動実行は行わない）。旧 `-codex-loop` は `--codex-review-loop` にリネームされ、使用できなくなった。

## 役割とモデル

| 役割 | model / effort | 責務 |
|------|----------------|------|
| オーケストレーター | メインセッション | Issue 読取り・計画確認・ブランチ操作・context.md 作成・Workflow 起動・ループ制御・コミット/PR |
| 設計役 | opus / max | 計画が無い/粗い場合の設計方針確定 + 実装後の設計整合・保守性・可用性レビュー（兼任） |
| 開発者 | opus / max | 実装（調査→ベースライン→実装→動作確認）とレビュー指摘の採用判定・修正（レビュイー） |
| 独立 QA | sonnet / high | 自己申告に依存しないテスト・lint の独立実行、受け入れ基準検証、自動コミット前の最終ゲート |
| レビュワー / Judge（claude 系）・Breaker（両系統の敵対） | opus / max（codex 敵対 Breaker〔雛形 C〕のみ sonnet / max） | コンテキスト隔離での diff レビュー / 裁定 / 反例生成（Breaker は codex 敵対モードでも使う。claude 標準レビュワーは観点を G1/G2/G3 の 3 グループに、claude 敵対 Breaker は攻撃観点を S/C/O の 3 レンズに分割して並列起動、Judge は反例を ≤4 件/バッチに分割し並列裁定） |
| セキュリティ監査役 | opus / max（codex 系〔雛形 C〕のみ sonnet / max） | セキュリティ自動発動時に STRIDE・認可・データフロー観点を敵対的レビューへ注入（claude 系はレンズ S の Breaker に統合・codex 系は独立エージェント） |
| レビュワー / Judge（codex 系） | Codex（別系統モデル） | `codex:rescue` 経由のレビュー・裁定（従来どおり） |

model はエイリアス指定（環境で利用可能な最新の同系統モデルに解決）。effort を指定できるのは Workflow ツールの `agent()` のみのため、エージェント起動はすべて Workflow ツールで行う。

## フロー

1. Issue を読み取り、内容を把握する
2. 既存の実装計画（`/smart-issue-plan` が作成したコメント or `[実装計画]` Issue）があれば参照し、計画記録の分析時点 SHA と最新デフォルトブランチの差分から陳腐化を検出する（古ければ計画更新を提案）
3. 作業ツリーの状態を確認する（未コミット変更は識別可能なメッセージ付きで stash）
4. Issue に基づいたブランチを作成・チェックアウトする
5. プロジェクト固有基準を収集し、一時作業ディレクトリに context.md（要件・計画・テスト方針・基準）を書き出す
6. 実装 Workflow を起動する: 設計役（計画が無い/粗い場合）→ 開発者（ベースライン→実装→動作確認）→ 独立 QA（不合格なら開発者が修正、最大 2 回）→ 設計役の事後レビュー（設計整合・保守性・可用性）→ 反映 → QA 再確認
7. レビューループ指定時（またはセキュリティ自動発動時）はレビューループへ。それ以外は変更サマリを提示して `/smart-commit` の使用を提案する（勝手にコミット・push しない）

## レビューループ（codex 系 / claude 系）

いずれのフラグでも、採用すべき指摘がなくなるまで「レビュー取得 → 妥当性判定（過剰対応チェック） → 修正 → テスト再実行」をループする（3 ラウンドごとに続行/打ち切り/中止をユーザーに確認）。**返ってきた指摘を採用するか（過剰対応でないか）の判定は、どのモードでもレビュイーの開発者エージェントが行う**。

- **codex 標準（`-cdxrl`）**: Codex（`codex:rescue` 経由）が単独で diff をレビューする
- **codex 敵対（`-cdxarl`）**: Breaker（独立 Sonnet エージェント。実装文脈から隔離）× Codex=Judge（真の欠陥かノイズかを裁定）の二者構造。Workflow が使えない環境ではメインセッションが Breaker を代行する（従来動作）
- **claude 標準（`-cldrl`）**: Opus（effort max）のレビュワーエージェントが diff をレビューする（観点は codex 標準と同一・union 不変）。単発 1 体で 9 観点を横断する代わりに、観点を G1（仕様充足 / バグ / テストカバレッジ）/ G2（回帰 / データ整合性・性能 / 実装レベルの危険箇所）/ G3（運用・保守・可用性 / アーキテクチャ境界 / プロジェクト固有基準）の 3 グループに分割した並列レビュワーとして起動する（敵対 Breaker のレンズ分割と同型。一部グループ失敗は `reviewerDegraded` フラグで伝播）
- **claude 敵対（`-cldarl`）**: Breaker × Judge を**別々の** Opus エージェントが担う。Breaker は攻撃観点を S（セキュリティ）/ C（正確性・データ）/ O（運用・保守）の 3 レンズに分割した並列エージェント（各 effort max。観点の union は従来の単一 Breaker と同一）、Judge は全レンズの反例を ≤4 件/バッチに分割し並列裁定（effort max。単一 Judge が多数シナリオの照合で無進捗ウォッチドッグにストールするのを防ぐ）。収束は dry-twice（連続 2 クリーンラウンド）。ラウンド 2 以降は直前ラウンドの採用修正差分に重点付けする（差分スコープ化）。裁定基準は codex Judge と同等。独立性はコンテキスト隔離 + 役割分離で担保（別系統モデルではないため、認証・決済・データスキーマ・外部 API などの重要変更には codex 系を推奨）
- **セキュリティ自動発動**: 認証・個人情報・決済などセキュリティ影響を Issue や変更ファイルから検出したら、フラグ未指定でも敵対的レビューを自動で有効化する（発動理由を明示。Codex 不在なら claude 系で代替）。ただしこの自動発動のみのケースでは**コミット・PR は自動実行せず**、従来の完了案内に切り替える（外部副作用の自動化は明示オプトイン時のみ）
- claude 系は 1 セット（最大 3 ラウンド）を 1 つの Workflow で実行し、3 ラウンドごとの続行確認はセット間にオーケストレーターが行う（サブエージェントはユーザーに質問できないため）
- 敵対モードの裁定「仕様未定」（仕様が曖昧で要確認の指摘）は、対話できないエージェントに握り潰させず、オーケストレーターが AskUserQuestion でユーザーに確認して確定内容を context.md に反映する
- 収束後の自動コミット・PR（フラグ明示時のみ）の前に、**独立 QA の最終ゲート**を通す（不合格なら自動コミットを中止して相談）。`smart-commit` / `smart-pr` は `disable-model-invocation` のため、コミット・push は `git`、PR 作成は GitHub MCP（不在時は `gh`）で直接実行する。機密ファイル警告・pre-commit hook・behind 時のマージ確認などの安全系は維持する
- PR 本文のレビュアー向け補足に `🤖 Codex レビュー済み（…）` / `🤖 Claude レビュー済み（…）` / `🤖 Claude 敵対的レビュー済み（Breaker×Judge=独立 Opus…）` を記載する
- `codex:rescue` が使えない環境では Claude がレビュー・裁定を代行せず、従来の完了案内（コミット・PR は手動）にフォールバックする（レビュー済み表記なし）。ただしセキュリティ自動発動のケースに限り claude 敵対レビューで代替する。claude 系が使えない（Workflow なし）場合も同様に代行せずフォールバックする
- 実装とは独立に敵対的レビューだけ行いたい場合は `/code-reviewer-adversarial` を直接使う
- claude 系レビューのレビュワー・Breaker・Judge プロンプトは `code-reviewer`（`--isolated`）・`code-reviewer-adversarial`（`--claude-judge`）へも移植されている（`smart-issue-plan` の `sip-plan-review-set` も同骨格の変種）。観点・裁定基準を変えるときは CLAUDE.md「スキル改修時の注意」の同期対象一覧（4 スキル）をすべて同期する

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
- **Workflow ツール（Claude Code 本体機能）** — 役割別エージェントのオーケストレーションと claude 系レビューループに必須。model / effort の明示指定（開発者 = opus/max、claude 系レビュワー = opus/max、独立 QA = sonnet/high 等）は Workflow の `agent()` でのみ可能。利用できない環境ではメインセッションの単一セッション実装に degrade する（claude 系レビューループは利用不可）
- **Codex プラグイン（`codex:rescue` スキル）** — `--codex-review-loop` / `--codex-advs-review-loop` 使用時に必須。セキュリティ自動発動時は第一候補（不在なら claude 系で代替）
- **git + GitHub MCP（または gh）** — レビューループ収束後の自動コミット・PR 作成に使用（コミット・push は git、PR 作成は GitHub MCP を優先。`smart-commit` / `smart-pr` は `disable-model-invocation` のため自動呼び出し不可。手動起動は従来どおり可能）
- **AskUserQuestion** — Issue 番号未指定時の確認、およびレビューループ 3 ラウンドごとの続行/打ち切り/中止の確認に使用（Claude Code 拡張。他エージェントではテキスト確認にフォールバック）
