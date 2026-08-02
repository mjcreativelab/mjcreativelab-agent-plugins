# 実装ノート: レビューループの収束高速化（重大度フロア・軽微指摘フィルタ・発見役 effort high）

- 日付: 2026-08-02（JST）
- Issue: #134
- 対象: `skills/smart-issue-plan/references/agent-orchestration.md`（`sip-plan-review-set`）・`skills/smart-issue-resolve/references/agent-orchestration.md`（雛形 B `sir-claude-review-set`）+ 両 SKILL.md / README / CLAUDE.md マスター同期ノート / 実測台帳

## 背景

VTO PoC での実測（詳細は [docs/empirical-tuning/review-loop-speedup.md](../empirical-tuning/review-loop-speedup.md) の Issue #134 節）で、レビューループの時間の支配要因が「収束しないこと」（Low 指摘の採用による cleanStreak リセット・採用率ほぼ 100%・差分スコープの自己増殖チェーン）と判明したため、P1〜P5 の 5 レバーを実装した。

## 仕様に明記されていなかったため判断した事項

1. **重大度フロアの判定方法 = `FIX_SCHEMA.adopted[].severity` の echo**: fix / plan-editor が採用項目に元指摘の severity を複写し、スクリプトが `severity !== 'Low'` の件数（`adoptedMajor`）で判定する。指摘タイトルの突合（editor がタイトルを変えると壊れる）より頑健。schema `required` に含めたため、欠落時はツールコール層のバリデーションで再試行される
2. **Low のみのラウンドでも fix / plan-editor は起動する**: Low を反映（または不採用判定）した上でクリーン扱いにする。「Low を無視して即クリーン」にはしない（報告された Low の扱いを記録に残すため。採用実務は P3 の規律に従う）
3. **fix / plan-editor の Low 採用規律は resolve / plan で意図的非対称**: resolve = 「局所・無リスクの場合のみ最小修正で採用」/ plan = 「原則不採用」。コードの Low 修正は安価で回帰テストに守られるが、計画への Low 反映は計画本文を太らせ次ラウンドの攻撃面になる（実測 746 の 18 ラウンド連鎖の主因）ため
4. **軽微指摘フィルタの除外条項**: 「列挙・文言の完全性が Issue の成果物そのもの（ドキュメント改訂系 Issue）の場合は指摘対象」を明示した。実測 890/894（ドキュメント整理 Issue）では行番号列挙の完全性が受け入れ基準そのものであり、一律フィルタすると本体の欠陥を落とすため
5. **P5 の適用範囲は発見役（レビュワー / Breaker）のみ**: Judge は #113 で high 済み。fix / plan-editor は編集役（コード修正・テスト・計画編集）のため max を維持。Opus 5 プロンプトガイドの「レビュー精度は低 effort でも維持される」はレビュー作業についての言明であり、編集作業へ外挿しない
6. **cr / cra への非適用**: `code-reviewer` / `code-reviewer-adversarial` は単発レビューでループ収束を持たず、Low 指摘がラウンドコストにならない（ユーザーが読んで取捨できる）ため P1〜P4 は適用せず、effort も max 維持。CLAUDE.md マスター同期ノートに非対称として記録した
7. **雛形 D（`sir-dev-fix`・codex ループの fix）は変更しない**: codex 系の収束判定はオーケストレーター側（SKILL.md 手順 4「採用 0 件で即収束」）で行われ、雛形 B の dry-twice 機構を持たない。Codex 利用制限中でもあり、severity echo の追加は見送った（codex 系に重大度フロアを入れる場合は SKILL.md のループ骨格側の変更が必要）

## トレードオフ

- **採用（P1: クリーン判定を High/Medium ベースに）** vs 却下（Low 指摘の報告自体を全面禁止）: 報告は許容して収束判定から外す方式にした。全面禁止はドキュメント改訂系 Issue で本体の欠陥を落とすリスクがあり、P2 の除外条項と整合しない
- **採用（P4: 追記への詳細要求禁止）** vs 却下（差分スコープ自体の廃止）: 差分スコープは実測で有効（ラウンド 2+ が 5〜13 分に短縮）。禁止するのは「詳細要求」という指摘クラスのみで、追記の事実誤り・矛盾・実欠陥は引き続き指摘可能
- **リスク（P5）**: effort high 化で発見力が下がる可能性は否定できない。台帳の採取予定に recall プロキシ比較を明記し、劣化時は P5 のみ独立に切り戻せる設計（P1〜P4 と結合していない）

## 検証

- 両 orchestration ファイルの全 js ブロック（sip 1 + resolve 5）を `node --check` で構文検証し全て OK（CLAUDE.md 記載の awk 抽出 + wrap 手順）
- grep で `effort: 'max'` の残存箇所が意図どおりであること（雛形 B は dev fix のみ・sip は plan-editor のみ。雛形 A/C/D/E は対象外のため不変）を確認
- 実効果（収束ラウンド数・不採用率・recall プロキシ）は次回 dogfooding で採取する（台帳の採取予定に記載。本 PR 時点では未実測）
