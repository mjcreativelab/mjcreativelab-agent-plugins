# レビュー雛形高速化（Issue #107）— Phase 1 ベースライン記録

対象: claude 系レビューループ（`sir-claude-review-set` / `sip-plan-review-set`）と単発敵対レビュー（`cra-claude-judge`）の構造並列化・差分スコープ化（Phase 2）に対する、変更前ベースラインの記録。

記録日: 2026-07-18（Issue #107 Phase 1）

## 計測方法と制約

- 過去セッションの Workflow 実行記録（journal.jsonl / エージェント transcript の mtime）を走査した。`sir-claude-review-set` の実行記録は 1 件（2026-07-14・Issue #88 セッション・**標準モード**）のみで、敵対モードのクリーンな実測は存在しなかった
- 見つかった標準モード実行はレビュワー r1 エージェントが 06:43 開始 → 09:00 終了（約 2 時間 17 分。API リトライ・キュー待ちを含むためステージ純所要時間としてはノイズが大きい）。**発見フェーズ（レビュワー / Breaker）が長極**であることの傍証にはなるが、定量ベースラインとしては採用しない
- したがって Phase 1 ベースラインは**直列スロット数・ステージ構造の定性比較**で記録し、実ウォールクロック短縮の定量実測（受け入れ基準の「目標 30% 減」）は**次回の本番レビューループ実行（dogfooding）に委譲する**。dogfooding 時は各ステージの `[HH:MM JST]` ログと journal.jsonl からステージ別所要時間を採取し、本ファイルに追記する

## 構造ベースライン（変更前）

敵対モード 1 セット（ラウンド 2 収束の典型ケース）の逐次チェーン:

```
audit → breaker r1 → judges r1(バッチ並列) → fix r1 → breaker r2 → judges r2 → probe-cleanup → 最終QA
```

- **直列スロット数: 8**（audit はループ前に直列 1 スロット）
- 最重量スロットは Breaker（effort max・6〜7 攻撃観点を単独で横断 + 反例テスト作成・実行）。ラウンドごとにフル攻撃面を走査する
- Judge のバッチ並列化（≤4 件/バッチ・`parallel`・effort high）は Issue #88 で導入済み（このスロットは既に「最も遅いバッチ」時間）
- `cra-claude-judge`（単発）: breaker → judge の直列 2 スロット。judge は「バッチ裁定 + Breaker 見落とし探索」を 1 体で兼務（effort max）し、Issue #88 でストール要因と特定された広域探索を含む

## 変更後の構造（Phase 2 実装。2026-07-18）

```
[breaker r1: レンズ S ∥ C ∥ O]（S は監査を内蔵） → judges r1(バッチ並列) → fix r1
  → [breaker r2: レンズ S ∥ C ∥ O・差分スコープ] → judges r2 → probe-cleanup → 最終QA
```

- **直列スロット数: 7**（独立 audit スロットをレンズ S に統合して消去）
- Breaker スロットの所要時間は「全観点の合計」→「最も遅いレンズ（観点 1/3 ずつ）」に変わる
- ラウンド 2+ の Breaker / レビュワーは直前ラウンドの採用修正差分に重点付け（差分スコープ化。ラウンド 1 の包括レビューが recall の backstop）
- `cra-claude-judge`: breaker → [judge バッチ群 ∥ miss-finder] の 2 スロット構造は維持しつつ、第 2 スロットが「バッチ裁定 + 見落とし探索の合計」→「max(最も遅いバッチ, miss-finder)」に変わる。miss-finder は diff スコープで有界化

### 期待される短縮の内訳（定性）

| レバー | 対象 | 期待効果 |
|---|---|---|
| レンズ分割並列化 | 雛形 B / sip の敵対 Breaker（全ラウンド） | 最重量ステージが並列化（効果大） |
| 監査役のレンズ S 統合 | securityAudit 時の初回セット | 直列 1 スロット消去（効果中・条件付き） |
| 差分スコープ化 | ラウンド 2+ の Breaker / レビュワー | 読込・probe 作成の対象縮小（効果大・r2+ のみ） |
| Judge バッチ + miss-finder 分離 | cra の第 2 スロット | 兼務の直列和 → 並列 max（効果中） |

## recall 比較の基準（A/B・dogfooding 用）

- 既知欠陥リスト: 初回 dogfooding 対象の diff に対する変更前雛形の確定指摘（真の欠陥）を基準セットとし、変更後雛形が同一 diff で同じ欠陥を検出することを確認する（Issue #107 受け入れ基準「既知欠陥の欠落なし」）
- 本セッションでは生ベンチマーク（実レビューループの新旧 2 回実行）を行わないため、基準セットは未採取。**dogfooding 初回実行時にここへ記録する**

## Phase 3（effort A/B）状況

未着手（本 Issue の Phase 1+2 スコープ外として別セッションへ委譲）。対象: 発見側（breaker / reviewer）の `max` → `high`、`cra-claude-judge` の Judge effort、`cr-isolated-review` の effort。empirical-prompt-tuning で同一対象に新旧変種を実行し、確定指摘の一致率と所要時間で採否を判定する。
