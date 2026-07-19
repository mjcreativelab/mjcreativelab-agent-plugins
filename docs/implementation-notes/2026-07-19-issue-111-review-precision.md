# Issue #111 — レビュー雛形の精度向上（速度より優先）

対象: 標準レビュワー観点分割並列化・レビュー役 opus 化・dry-twice 収束・敵対 Judge の effort max 化。分析時点 SHA `06e801d`（= 実装着手時の origin/main HEAD）。

## 背景

Issue #107 Phase 1+2（PR #110）導入後の 2026-07-19 dogfooding で、レビュー時間の支配要因が雛形構造ではなくランタイム層のストール（約 16 分無応答 → 打ち切り → 直列リトライ）と判明した。方針を速度優先から精度優先へ転換し、recall・裁定品質を引き上げる（詳細は `docs/empirical-tuning/review-loop-speedup.md`「Phase 2 dogfooding 実測」）。

## 変更ファイル

- `skills/smart-issue-resolve/references/agent-orchestration.md` — 雛形 B: `REVIEWER_GROUPS`（G1/G2/G3）分割・reviewerGroupPrompt 新設・標準分岐の parallel 化、Breaker レンズ/Judge バッチ/標準グループの opus 化、Judge バッチ effort max 化、dry-twice 収束（`cleanStreak`）、`args`/返却拡張、同期ノート更新
- `skills/smart-issue-plan/references/agent-orchestration.md` — sip: 雛形 B と同じ 6 変更を計画レビュー用に移植（G1/G2/G3 は意味的対応で再定義）、同期ノート更新
- `skills/code-reviewer-adversarial/references/agent-orchestration.md` — cra: Breaker/Judge バッチ/miss-finder の opus 化、Judge バッチ effort high→max、同期ノート更新
- `skills/code-reviewer/references/agent-orchestration.md` — cr: `cr-isolated-review` の opus 化
- `skills/smart-issue-resolve/SKILL.md` / `README.md`、`skills/smart-issue-plan/SKILL.md` / `README.md`、`skills/code-reviewer-adversarial/SKILL.md` / `README.md`、`skills/code-reviewer/SKILL.md` / `README.md` — model/effort 表記の Opus 化（claude 系のみ）・グループ分割 / dry-twice の説明追記・レビュー済み表記・劣化フラグ（`reviewerDegraded`）追記
- `CLAUDE.md` — マスター同期ノートに reviewerGroupPrompt・標準レビュワーグループ分割・dry-twice・opus 化 + Judge effort max 化を構造同期対象として追記
- `docs/empirical-tuning/review-loop-speedup.md` — 2026-07-19 dogfooding 実測を追記、Phase 3（effort A/B）を取り下げに更新

## 受け入れ基準ごとの対応

- **dogfooding 実測の追記**: `review-loop-speedup.md` に「## Phase 2 dogfooding 実測（2026-07-19）」を新設（ストール統計表・標準モード非発動・収束 8 ラウンドの事実・含意・Issue #111 での対応）
- **標準レビュワー観点分割（B / sip）+ union 照合**: 雛形 B / sip とも `reviewerPrompt`（単発 9 観点）を `REVIEWER_GROUPS`（G1/G2/G3）+ `reviewerGroupPrompt` に置換。旧 9 観点行が新グループ内に逐語で過不足なく揃うことを git HEAD との照合で確認（sir/sip とも total=9・欠落 0・重複 0）
- **レビュー役のモデル引き上げ（B / sip / cra / cr）**: 標準レビュワー各グループ・Breaker レンズ（S 含む）・Judge バッチ（B/sip/cra）・miss-finder（cra）・単発レビュワー（cr）を `model: 'opus'` に。対象外の QA・probe-cleanup・雛形 C（codex 系）・fix/dev（既に opus）は不変
- **連続 2 クリーン収束のセット境界跨ぎ**: `cleanStreak`（`args` 省略時 0 / 返却で伝播）を導入。1 回目クリーン後は差分スコープ解除（`delta = ''`）の確認ラウンド、`cleanStreak >= 2` で収束。SKILL.md の返却処理（続行時の `cleanStreak` 引き継ぎ・上限チェックの連続クリーン確認待ち注記）も更新
- **敵対 Judge の effort max 化（B / sip / cra）**: judgeBatchPrompt の `agent()` 呼び出しの `effort: 'high'` → `'max'`
- **全編集 js ブロックの構文チェック PASS**: 4 references の全 js ブロック（sir 5・sip 1・cra 1・cr 1）を CLAUDE.md の awk + `node --check` で PASS 確認
- **B ↔ sip 同期ノート・SKILL.md / README / CLAUDE.md・レビュー済み表記の同期**: 両 references 末尾の同期ノート、両 SKILL.md、4 README、CLAUDE.md マスター同期ノート、レビュー済みバッジを更新。残存 `Sonnet`/`sonnet` は codex 系（雛形 C）・QA・probe-cleanup のみであることを grep 横断で確認

## 自分で判断した事項

- **実装ノートのファイル名**: plan.md / context.md が明示的に `2026-07-19-issue-111-review-precision.md`（分析日 = dogfooding 日）を指定していたため、実行日（2026-07-20 JST）ではなくその名前を採用した。
- **セキュリティ監査役の model 表記（役割テーブル）**: claude 系の監査はレンズ S の Breaker に統合済み（opus 化）で、codex 系のみ独立エージェント（雛形 C・sonnet）のため、sir SKILL.md / README の役割テーブルを `opus / max（codex 系〔雛形 C〕のみ sonnet / max）` に更新した（plan の明示行外だが、SKILL.md↔README 整合と grep ゲート〔残存 Sonnet は codex/QA のみ〕を満たすため）。
- **標準レビュワーのグループ命名**: `REVIEWER_GROUPS` の `id` は `g1/g2/g3`、`label` は観点の短縮列挙とし、Breaker の `LENSES`（S/C/O）と同型の構造にした。probe 命名の不変条件は Breaker レンズ固有で、標準レビュワーは反例テストを書かないためグループ側に probe トークン規約は持ち込まない。
- **標準レビュワーの `dismissed` 集約**: 標準レビュワーは `dismissed` を出さないが、敵対レンズ集約と対称にするため `dismissed: okGroups.flatMap((r) => r.dismissed || [])`（= 空配列）を付けた。下流の `(findings.dismissed || []).length` は 0 で従来と一致。
- **確認ラウンドのフルスコープ強制**: `isConfirmRound = cleanStreak === 1` を各ラウンド冒頭で判定し、真なら `delta = ''`（`fixDelta` を呼ばない）。fresh エージェントは `agent()` 呼び出しごとに自動保証されるため追加処理は不要。
- **cra の同期ノート更新**: Judge バッチの `effort: 'high'` 記述を `'max'` に修正し、旧「Phase 3（effort 変更）には踏み込まない」の一文を「opus 化・Judge effort max 化は Issue #111」に置換した（前提が Issue #111 で変わったため）。miss-finder の effort は元から max のまま維持。

## dry-twice のセット跨ぎ引き継ぎ設計

`cleanStreak` はセット内 `let` 変数だが、`args.cleanStreak`（初期値）と返却値の両方に載せることでセット境界を跨ぐ。設計上のエッジケース: セット末尾ラウンドが最初のクリーン（`cleanStreak: 1`）だった場合、残指摘が空でも `converged: false` で返る。続行時にオーケストレーターが `cleanStreak: 1` を次セットの `args` へ引き継ぐと、次セット round 1 が `isConfirmRound=true`（差分スコープ解除）となり dry-twice が成立する。引き継がないと確認ラウンドが失われ収束が 1 クリーンに退化する — この注意は両 SKILL.md の上限チェック節に `>` 注記として明記した。

## sip の G1/G2/G3 対応付け（ユーザー確認済み）

plan.md（承認済み計画）で確定した計画レビュー用の意味的対応:

- G1: 実現可能性 + 手順の妥当性 + テストカバレッジ
- G2: 影響範囲の抜け + リスクの見落とし + データ整合性・性能
- G3: 運用・保守・可用性 + アーキテクチャ境界 + プロジェクト固有基準（sir と同一）

sir（コード diff レビュー）の G1/G2/G3 とは観点の内容が異なる（計画レビュー固有の文言）が、「3 観点/グループ・3 グループ」の構造は sir と同期。union は sip の従来 9 観点で不変。

## テスト結果（ベースライン比較）

- **ベースライン**（実装前）: 4 references の全 js ブロック PASS（sir 5・sip 1・cra 1・cr 1）
- **実装後**: 同 4 references の全 js ブロック PASS（変化なし・壊れなし）
- **union 照合**: sir/sip とも旧 9 観点が新 `REVIEWER_GROUPS` に逐語で過不足なく存在（total=9・MISSING 0・DUP 0）
- **SKILL.md 行数**: sir 322 / sip 324 / cr 181 / cra 276 行（すべて 500 行以下を維持）
- **grep 横断**: 残存 `Sonnet`/`sonnet` はすべて codex 系（雛形 C）・独立 QA（sonnet/high）・probe-cleanup（sonnet/low）で、claude 系レビュー役の残存なし
- 自動テストは無い（Workflow スクリプトの js ブロックのみ）。実地の recall・収束ラウンド数・ストール率は次回 dogfooding で採取し `review-loop-speedup.md` へ追記する申し送り（本 PR スコープ外）
