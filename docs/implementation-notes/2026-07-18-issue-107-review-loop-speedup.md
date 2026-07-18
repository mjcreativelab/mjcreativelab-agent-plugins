# 実装ノート: レビュー雛形の高速化（Issue #107・Phase 1+2）

日付: 2026-07-18（JST）/ ブランチ: `feature/issue-107-review-loop-speedup`

## スコープ

Issue #107 の 3 フェーズのうち **Phase 1（ベースライン記録）+ Phase 2（構造変更・精度中立）のみ**を実装した。Phase 3（effort `max`→`high` の A/B 判定）はユーザー確認のうえ別セッションへ委譲した（empirical-prompt-tuning による長時間の A/B 実測を要するため）。

## 実装した構造変更

1. **Breaker のレンズ分割並列化**（`sir-claude-review-set` / `sip-plan-review-set`）: 単一 Breaker の攻撃観点を S（セキュリティ）/ C（正確性・データ）/ O（運用・保守）の 3 レンズにパーティションし、フラット `parallel` で同時起動。観点の union は従来と同一（内容の追加・削除・改変なし）。一部レンズ失敗は新フラグ `breakerDegraded` で伝播（全レンズ失敗のみ `agent-failed`）
2. **セキュリティ監査役のレンズ S 統合**（同上）: `securityAudit` 初回セット round 1 で、レンズ S の Breaker が「STRIDE 監査 → `security-audit.md` 書き出し → セキュリティ break」を 1 エージェントで実施。独立の前段監査スロット（直列 1 スロット）を削除。レンズ S スキーマに `auditWritten: boolean` を追加し、「監査のみ失敗（break は続行）」を `auditFailed` として従来どおり区別する
3. **差分スコープ化**（同上）: `records[].adoptedItems` に採用修正の title/action を保持し、ラウンド 2+ の Breaker / レビュワーに `fixDelta()` で「直前ラウンドの修正差分とその波及を重点対象にする」指示を注入。ラウンド 1（初回セット）は全 diff / 計画全体の包括レビュー。セット跨ぎは `priorSummary` に前セット最終の採用修正内容を含めて連続させる（args スキーマは拡張しない）
4. **cra-claude-judge の Judge バッチ並列化 + miss-finder 分離**: 単発 Judge（バッチなし・effort max・見落とし探索兼務）を「Judge バッチ（≤4 件/バッチ・effort high・evidence 限定照合）∥ miss-finder（1 体・effort max・diff スコープ・同じ 4 分類で自己分類）」のフラット `parallel` 異種 thunk 群に置換。劣化フラグは `judgeDegraded`（バッチ失敗＝未裁定反例が残る・硬い欠損）と `missSearchFailed`（独立探索のみ喪失・軽い劣化）で区別

## 設計上の重要判断（仕様に明記されていなかった事項）

### `pipeline()` を使わず Tier 1（フラット parallel）を確定実装にした

Issue 本文のレバー 1 は「Judge バッチは `pipeline` で終わったレンズから裁定」を提案していたが、設計調査で次を確認した:

- 実運用で検証済みの並列プリミティブは **フラット `parallel(thunks)` のみ**（Issue #88 実装ノート。no-throw 契約 = agent() は失敗時 null、parallel は reject しない）
- `pipeline` / ネスト合成（parallel thunk 内での逐次 `agent()`）はリポジトリ内に前例ゼロで、`node --check` では実行契約を検証できない
- 本セッションは生ベンチマーク（実 Workflow 起動）を行わない制約のため、新ランタイム契約に依存する設計は検証不能のまま確定してしまう

→ **Tier 1（フラット 2 波: レンズ Breaker 波 → Judge バッチ波）を確定実装**とし、受け入れ基準はすべて Tier 1 で満たす。「終わったレンズから裁定する真のパイプライン」（Tier 2）は追加最適化として、初回 dogfooding でネスト合成の動作を確認できた場合のみ別途上積みする（Judge 待ちの重なり分のみで相対効果は小さい）。

### 未確定事項への採択（設計 design.md の推奨に従った）

| 論点 | 採択 | 理由 |
|---|---|---|
| 差分スコープの強度 | **重点付け（中庸案）**: 高コスト作業（未関連ファイル読込・probe 作成）は差分に絞るが、diff 基準は全体維持で「スコープ外でも明白な重大欠陥は報告可」 | ハードスコープはラウンド 1 の完全性に全依存し recall 制約に触れる。中庸案は再スキャン網を残す |
| レンズ数 | **3（S/C/O）** | セキュリティは監査統合のため独立必須。残りを二分して均衡 |
| 監査役統合の実現形 | **レンズ S へのハードマージ + `auditWritten` フラグ** | 直列スロット消去と literal な「統合」を両立。レンズ S 全死は現行の単一 Breaker 死と同等で NET 後退なし |
| cra の劣化フラグ | **`missSearchFailed` を別フラグ** | バッチ失敗（未裁定反例＝硬い欠損）と探索喪失（軽い劣化）は重さが異なる |
| セット跨ぎの差分引き継ぎ | **既存 `priorSummary` へ内包** | args スキーマ非拡張の最小変更 |
| cra Breaker | **レンズ分割しない** | Issue の対象表で cra 行は Judge 側のみ指示。単発レビューはラウンド往復が無い |
| 雛形 C（codex 系 Breaker） | **現状維持** | Codex 利用制限中。claude/codex 非対称は同期ノートに明記 |

### probe 命名の不変条件（レンズ分割で新設）

並列レンズ Breaker が同一ワークツリーに反例テストを書くため、レンズ固有トークン（`sec-` / `corr-` / `ops-`）を **`.breaker-probe.` の前方外側**に付ける（例: `sec-foo.breaker-probe.test.ts`）。probe-cleanup・QA・fix は `.breaker-probe.` のサブストリング一致で検出しているため（resolve/cra 計 9 箇所で実測）、トークンを間に挟む形式（`.breaker-probe-sec.`）は検出漏れ→使い捨てテスト残留を招く。各レンズには「自レンズの probe のみ実行・競合時は `verified: UNVERIFIED` に落とす」を指示（recall 安全側）。

### effort の扱い（Phase 3 と混同しない）

- Judge バッチ = `high` は Issue #88 で確立済みの構造（作業量有界化によるストール回避）の踏襲であり、Phase 3 の A/B 対象ではない
- cra の miss-finder = `max` 維持は旧単一 Judge の独立探索 effort の保存（構造分離のみで effort は下げない）
- 発見側（breaker / reviewer）の `max` は全レンズで維持（Phase 3 で A/B 後に判断）

## 変更ファイルと同期チェックリスト

| # | ファイル | 変更 | 確認 |
|---|---|---|---|
| 1 | `skills/smart-issue-resolve/references/agent-orchestration.md` | 雛形 B: LENSES / breakerLensPrompt / BREAK_S_SCHEMA / fixDelta / adoptedItems / breakerDegraded / 監査統合。同期ノート更新 | ✅ 構文 PASS |
| 2 | `skills/smart-issue-plan/references/agent-orchestration.md` | `sip-plan-review-set` へ同構造を同期（コード専用機構なし・`scenarios` フィールド名維持） | ✅ 構文 PASS |
| 3 | `skills/code-reviewer-adversarial/references/agent-orchestration.md` | Judge バッチ並列 + miss-finder 分離・劣化フラグ・同期ノート更新 | ✅ 構文 PASS |
| 4 | `skills/code-reviewer/references/agent-orchestration.md` | **変更なし**（Phase 3 のみ対象のため） | ✅ |
| 5 | `skills/smart-issue-resolve/SKILL.md` | 役割表・セキュリティ自動発動節・claude 系実行形態・priorSummary 指示 | ✅ |
| 6 | `skills/smart-issue-plan/SKILL.md` | 同上（plan 版）+ 返却の扱いに `breakerDegraded` 追加 | ✅ |
| 7 | `skills/code-reviewer-adversarial/SKILL.md` | claude-judge モード節（バッチ + miss-finder・劣化フラグ）・同期ノート | ✅ |
| 8 | 3 スキルの README.md | 役割表・敵対モード説明を SKILL.md と整合更新（cr README は変更なし） | ✅ |
| 9 | `CLAUDE.md` | 同期マスターにレンズ分割・cra 構造・probe 命名不変条件・非対称を追記 | ✅ |
| 10 | `docs/empirical-tuning/review-loop-speedup.md` | Phase 1 ベースライン（新規） | ✅ |

雛形 B ↔ sip の構造同期項目（両ファイルの同期ノートに記載）: セット制御 / 収束判定 / null ガード / `auditFailed`・`breakerDegraded`・`judgeDegraded`・`specQuestions` 経路 / Judge バッチ並列化 / レンズ分割（LENSES + フラット parallel） / 監査役レンズ S 統合 / 差分スコープ化（adoptedItems + fixDelta）。意図的差異（plan 側にコード専用機構なし・`scenarios` フィールド名・観点の plan 用文言・差分スコープの読み替え）も両ノートに明記済み。

## 検証結果

- **構文検証**: 4 スキルの orchestration ファイル全 8 js ブロックを CLAUDE.md 標準手順（awk 抽出 + `node --check`・bash スクリプト経由）で確認し全 PASS
- **skill 検出**: `npx skills add ./ --list` で全 skill の検出継続を確認（frontmatter 非破壊）
- **未検証（dogfooding へ委譲）**: 実ウォールクロック短縮の定量実測（目標 30% 減）と既知欠陥 recall の同等性確認は、生ベンチマークを行わない本セッションの制約により未実施。次回の本番レビューループ実行時に `docs/empirical-tuning/review-loop-speedup.md` へ実測を追記する。フラット `parallel` にレンズ Breaker 群という新しい負荷パターンを載せる初回実行時は、no-throw 契約の挙動（一部レンズ null → 続行）をログで確認すること

## 残リスク

- 並列レンズ Breaker の反例テスト同時実行はテストランナーロック・ポート・共有 DB と干渉しうる（プロンプトの「自レンズ probe のみ実行・競合は UNVERIFIED」で緩和。干渉が顕著なプロジェクトではレンズ数 2（S + 残り）への縮約が設計上の選択肢）
- トークン消費はレンズ数分増える（Issue #107 で速度優先として許容済み）
- 差分スコープ化は「毎ラウンド全 diff 再レビュー」の冗長安全網を外す唯一の精度関連変更。ラウンド 1 の包括性が backstop で、diff 基準全体維持 + 「明白な重大欠陥は報告可」の重点付け方式で保全している

## 実装経緯の補足

実装は smart-issue-resolve の Workflow（雛形 A・opus 開発エージェント）で開始したが、`dev:implement` エージェントが 2 回連続で API 接続切断（Connection closed mid-response）により失敗したため、SKILL.md の規定に従い **degraded 実装（メインセッションによる直接実装）へ切り替えた**。エージェントは失敗までに設計（design.md）と 3 つの orchestration ファイルの変更をほぼ完成させており、メインセッションはその検収・残修正（args 説明と priorSummary 指示の 2 箇所）・ドキュメント同期（SKILL.md / README / CLAUDE.md / docs）・検証を実施した。このため雛形 A 内蔵の独立 QA・設計整合レビューは未実施（degraded 実装の制約）。
