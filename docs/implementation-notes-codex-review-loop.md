# implementation-notes: レビューループのリネーム + 敵対的モード + セキュリティ自動発動

> 対象: `smart-issue-resolve` / `smart-issue-plan`（2026-07-01）
> 原初 `-codex-loop` 実装は [implementation-notes-codex-loop.md](implementation-notes-codex-loop.md)（PR #60）を参照。

## 仕様（ユーザー要求 + AskUserQuestion での確定事項）

1. `-codex-loop` を `--codex-review-loop`（ショートハンド `-cdxrl`）にリネーム
2. Codex 敵対的レビュー用のフラグ `--codex-advs-review-loop`（`-cdxarl`）を追加
3. 認証・個人情報など**セキュアな設計・実装が求められるケースでは敵対的レビューを実施**する。レビュイーの Claude が「レビュー内容が過剰対応か」を判定する不変則は、どのレビューパターンでも変わらない
4. Codex レビュー（標準・敵対的とも）に **運用・保守・可用性** の観点を追加する（両スキル。標準は `codex-review-prompt.md` のレビュー観点、敵対的は SKILL.md の Breaker 観点 + `codex-judge-prompt.md` の裁定範囲に反映）

AskUserQuestion で確定した設計方針:

- **敵対的レビュー方式**: 二者構造（Claude=Breaker × Codex=Judge）で統一
- **セキュリティ時の発動**: 検出したら自動発動

## 仕様に明記がなく自分で判断した事項

- **両フラグ同時指定 → `adversarial` を優先**（より強いレビュー）。相互排他ではなく昇格関係として扱う。
- **`{レビューモード}`（off / standard / adversarial）と `{ループ明示}` の 2 状態で管理**:
  - `{ループ明示}` = フラグが明示指定されたか。外部副作用の自動化（resolve のコミット・PR / plan の承認ゲートスキップ投稿）の可否に使う。
  - セキュリティ自動発動は `{レビューモード}` を昇格させるが `{ループ明示}` は立てない。→ **レビューは実施するが、外部副作用の自動化はしない**（resolve は通常の完了案内、plan は承認ゲート維持）。外部への push・PR・投稿の自動化は明示オプトイン時のみ、という原則を保った。
- **セキュリティ検出ヒューリスティック**: Issue のラベル/タイトル/本文のキーワード（認証・認可・ログイン・パスワード・トークン/JWT・セッション・暗号・PII・決済・秘密情報/API キー・OAuth/SSO）と、（resolve のみ）変更ファイルのパス/内容。判断に迷う場合はセキュア側に倒す（secure-by-default）。
- **plan の敵対的モードはテストがない**ため、反例テストの代わりに「設計への攻撃シナリオ（STRIDE・信頼境界・欠落コントロール）」を Breaker が生成し Codex が裁定する二者構造にした。
- **レビュイー Claude の過剰対応判定は敵対的モードでも維持**: Judge（Codex）が「真の欠陥」と裁定した指摘でも、修正が過剰対応になるなら Claude が不採用にしてよい（要求3後段の不変則）。

## 仕様から変更・調整した内容とその理由

- **`code-reviewer-adversarial` スキルへの委譲を断念しインライン再現に変更**（重要）:
  - AskUserQuestion の選択肢説明では「resolve は既存 `/code-reviewer-adversarial` に委譲」と記載していたが、同スキルは `disable-model-invocation: true` のため **Skill ツール（モデル発火）から呼び出せない**（`cannot be used with Skill tool due to disable-model-invocation` で失敗）。
  - ユーザーの意図（二者構造で統一）を実現するため、Breaker（Claude インライン）× Judge（`codex:rescue`）の二者構造を**各スキル内にインライン再現**した。別スキル依存がなくなり、npx クロスツール配布でも成立する副次的メリットもある。
  - 実装から独立して敵対的レビューだけ回したい場合は、ユーザーが `/code-reviewer-adversarial` を直接起動する経路を README で案内。
- **収束後のコミット・PR を「smart-commit/smart-pr の Skill 呼び出し」から「git/gh 直呼び」へ**:
  - `smart-commit` / `smart-pr` も `disable-model-invocation` のため Skill ツールから自動呼び出しできない（グローバル CLAUDE.md の運用注記に既出）。旧 SKILL.md の「Skill ツールで smart-commit を呼ぶ」は現状動かない記述だったため、この機会に整合させた。
  - 手動起動（ユーザーが `/smart-commit` `/smart-pr` を打つ）は従来どおり有効。

## トレードオフ

- **インライン再現 vs 委譲**: 委譲できれば DRY だが技術制約（disable-model-invocation）で不可。インライン再現はコード重複ではなく手順記述の重複に留まり、SKILL.md は 243 / 251 行（500 行以下推奨に収まる）。
- **自動発動 vs opt-in**: 要求の「実施する」に忠実な自動発動を採用しつつ、外部副作用（push/PR/投稿）だけは明示オプトインに限定することで、「勝手に外部へ書き込まない」原則との両立を図った。

## ユーザーが把握しておくべき決定事項

- 旧 `-codex-loop` は**使用不可**（ハードリネーム。後方互換エイリアスは追加していないが、旧フラグ検出時に新フラグを案内して停止する分岐は追加した）。
- グローバル `~/.claude/CLAUDE.md`（個人設定・全プロジェクト共有）の `smart-issue-resolve -codex-loop` 言及は新フラグ名に更新済み（2026-07-01）。dotfiles コピーには当該 bullet がなく編集不要だった。
- 変更ファイル: 両スキルの `SKILL.md` / `README.md` / `assets/codex-review-prompt.md`（pointer 追記）、新規 `assets/codex-judge-prompt.md`（各スキル）、`docs/`（本ファイル + 旧ノートに pointer）。

## Codex レビュー記録（2026-07-01）

companion 直呼び（`codex-companion.mjs task`）で未コミット差分をレビュー。3 件（すべて Medium）を指摘され、妥当性を検証のうえ 3 件とも採用・修正:

1. **plan 手順 5 の遷移が矛盾** — 「手順 7 へ進む」と「手順 6 の承認ゲート維持」が同一文で衝突。→ `{ループ明示}` の true/false で手順 6 スキップ / 承認ゲート経由を明示分岐に書き換え。上限チェックの「打ち切って投稿」にもゲート注記を追加。
2. **旧 `-codex-loop` 検出が引数解析で未定義** — ハードリネーム後、旧フラグが Issue 番号に混入し不明瞭に失敗しうる。→ 両スキルの引数解析に「旧フラグ検出 → 新フラグ案内して停止」分岐を追加（エイリアス復活ではない）。
3. **Breaker 反例テストの後始末が未定義** — 未採用/破棄した検証用テストがコミットに混入しうる。→ 反例テストは使い捨て・採用欠陥の回帰テストのみ残す旨を Breaker 手順に明記し、コミット手順に `git status` 確認を追加（`rm -f` は使わない方針を維持）。

## 改善ラウンド 2（2026-07-01・外部利用フィードバック起点）

`smart-issue-plan` を基に別リポジトリ（st-tech/new-product-claude-cookbook PR #132 の `jira-issue-plan`）でスキル化した際のレビュー指摘を、参照元の本 2 スキルにも還流した。

### 適用した改善

1. **ループ再構成（上限チェック到達不能バグの解消）** — 旧: 手順 4（収束判定）で採用 1 件以上なら**直接手順 1 へ戻る** → 手順 5（上限チェック）が到達不能だった（参照元 PR #132 が「高」で指摘。本 2 スキルにも同じ穴があった）。新: 手順 4 は**必ず手順 5 を経由**し、手順 5 で「3 の倍数ラウンド未達 → +1 / 到達 → AskUserQuestion」に分岐。resolve / plan 両方に適用。
2. **プロジェクト固有ルールの汎用注入** — 新サブセクション「レビュー基準の収集（プロジェクト固有ルール）」を追加。CLAUDE.md / AGENTS.md・リポジトリ内 `**/rules/*.md` 等を Glob で収集し、標準テンプレの「プロジェクト固有基準」欄・Breaker 観点・Judge 照合対象へ注入（規約不在なら汎用観点のみ＝ degradation）。参照元の backend 固有ルール（`plugins/coding/rules/*.md`）参照パターンの一般化。特定プラグイン構造（`${CLAUDE_PLUGIN_ROOT}` 等）にはハードコードしない。
3. **汎用レビュー観点の拡充** — データ整合性/トランザクション/冪等性・性能（N+1）・テストカバレッジ・アーキテクチャ境界（層責務逸脱）を標準テンプレ・Breaker・Judge に一貫追加。参照元指摘「backend 固有事項が薄い」の汎用化。

### 検証（多観点＋別系統モデル）

Claude 多観点ワークフロー（loop-logic / consistency-refs / generality-degradation / bloat-redundancy の 4 レンズ × 敵対的 verify）と Codex 別系統レビューを実施。両者が収束した 1 件＋ Codex 単独 1 件を採用・修正:

1. **周期的再確認の分岐条件化** — 手順 5 のガードが絶対値 2 分岐だったため「続行」後（ラウンド 4 以降）が未定義だった。→「3 の倍数（3, 6, 9, …）で確認 / それ以外は +1」の周期条件に書き換え（参照元 PR #132 にも残っていた曖昧さ）。両スキル。
2. **plan 打ち切り分岐の承認ゲート先** — 更新モードでは 8c が承認ゲートなのに手順 6 のみを参照していた。→「手順 6〔新規投稿〕または 8c〔更新〕」に修正。
