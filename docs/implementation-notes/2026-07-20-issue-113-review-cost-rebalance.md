# Issue #113: レビュー雛形の時間・トークン効率の再バランス — 実装ノート

日付: 2026-07-20（JST）
対象 Issue: #113（起点は Issue #111 / PR #112 の実使用フィードバック: 時間増・エージェント数増・トークン効率悪化）

## 自分で判断した事項

- **単発ラウンドの観点定義を分割定義の結合で生成**: `REVIEWER_ALL` / `LENS_ALL` の `aspects` を `REVIEWER_GROUPS` / `LENSES` の `aspects` の `join('\n')` で生成した。観点 union の不変（#111 の受け入れ基準）を、文言の二重管理ではなく構造で保証するため。今後グループ / レンズの観点を変更すると単発ラウンドへ自動反映される
- **単発判定 `comprehensive` の条件**: `args.startRound === 1 && i === 0 && !isConfirmRound`。継続セット（startRound 4, 7, …）の round 1 は差分スコープ（`fixDelta` が前セットの採用修正を参照する）ため分割しない。`!isConfirmRound` は「startRound 1 + cleanStreak 1」という契約外の args に対する防御
- **監査ラウンドの防御**: `securityAudit` は初回セットのみ true（SKILL.md 契約）で監査ラウンドは常に包括ラウンド＝レンズ分割側だが、契約外の args で単発ラウンドに落ちた場合に旧コード（`lensResults[LENSES.findIndex(...)]`）が `lensResults[-1]` → `undefined.auditWritten` で TypeError になるため、`sIdx >= 0` ガードに変更した（該当時は `auditFailed: true` として安全側に倒れる）
- **単発 Breaker の probe トークンは `all-`**: レンズ並列の衝突回避が目的のトークン機構をそのまま流用し、命名規則を一様に保つ（`.breaker-probe.` サブストリング検出は不変）。単発ラウンドではプロンプトから「他レンズと同時実行」の注意書きを条件分岐（`lens.solo`）で除去した
- **cra の Judge バッチも high へ戻す**: ユーザーの複雑さ指摘はループ経路（sir / sip）だが、「≤4 件/バッチの有界作業量に max は過剰」という根拠は cra にも同一に当てはまるため、effort ポリシーの一貫性を優先した。miss-finder は #111 以前から max（独立探索の広さが根拠）で変更しない
- **cr（`cr-isolated-review`）は変更なし**: 単発 1 体でエージェント数・トークンの問題が構造的に生じないため

## 採用しなかった代替案

- **opus → sonnet への引き下げ**: #111 の精度意図（発見・裁定品質）を直接損なう。トークン総量はエージェント数の削減（3 → 1 体/ラウンド）で抑える方を採った
- **dry-twice の廃止・条件付き化**: ラウンド 7 まで新規指摘が出続けた実測（2026-07-19 dogfooding）が機構の根拠として強く、廃止しない。確認ラウンドのコストは単発 1 体化で 1/3 に抑えた
- **確認ラウンドでの分割維持**: 確認ラウンドの目的は「揺らぎ由来の見逃しを拾うバックストップ」であり、一次発見（包括ラウンド）と同コストを毎ループ支払う必要はないと判断した

## トレードオフ

- 差分スコープラウンド・確認ラウンドの recall は分割 3 体時代よりレンズ集中度が下がる（1 体が全観点を横断）。対象が狭い（差分スコープ）・目的がバックストップ（確認ラウンド）ことから限界効用が小さいという判断で、次回 dogfooding で単発ラウンドの追加検出有無を採取して検証する（`docs/empirical-tuning/review-loop-speedup.md` の「次回 dogfooding で採取するもの」）

## 検証

- 編集した 3 ファイル（sir / sip / cra の `references/agent-orchestration.md`）の全 js ブロックを awk + `node --check` で構文チェック PASS（本 PR のコミット前に実施）
- 観点 union: `REVIEWER_ALL` / `LENS_ALL` は分割定義の結合のため構造的に一致（目視照合不要）
