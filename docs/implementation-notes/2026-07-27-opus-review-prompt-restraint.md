# Opus レビュー役の過剰処理抑制ノート（RESTRAINT_NOTE）実装ノート

- 日付: 2026-07-27（JST）
- 依頼: smart-issue-** / code-reviewer** のレビュー機能で Opus レビュー役が過剰な処理（サブエージェントの多量起動・テキスト量過多）をする傾向があるため、[Prompting Claude Opus 5 ガイド](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)を参考に Opus へのプロンプトを見直す（英語可）

## 変更内容

4 スキル（smart-issue-resolve / smart-issue-plan / code-reviewer / code-reviewer-adversarial）の Workflow 雛形で、`model: 'opus'` の全 `agent()` プロンプト末尾（`TAIL_NOTE` 直前）に共通の英語抑制ノート `RESTRAINT_NOTE` を追加した（計 18 箇所・const 定義 6 雛形）。内容はガイドの 3 節に対応:

| ノートの指示 | ガイドの根拠節 |
|---|---|
| サブエージェント起動・委任の禁止（検証目的含む） | Controlling subagent spawning |
| 手順に無い追加検証パスの禁止・依頼スコープの維持 | Task scope and over-verification / Self-correction |
| 出力・書き出しファイルの簡潔化（filler・冗長サマリ・boilerplate 禁止） | Written deliverable length / Response length and verbosity |

同期ドキュメント更新: 各 references の同期ノート・3 スキルの SKILL.md 内蔵同期ノート（sip の SKILL.md は言語規約の記載自体が無いため対象外）・CLAUDE.md「スキル改修時の注意」マスター・`docs/empirical-tuning/review-loop-speedup.md` 台帳。

## 仕様に明記されていなかったため判断した事項

1. **適用範囲を「レビュー役のみ」でなく「`model: 'opus'` の全 `agent()`」にした**（resolve 雛形 A の設計・実装・QA 修正役も含む）。ガイドの挙動（subagent 委任・冗長化）はモデル起因でロール非依存であり、「opus のうちレビュー系だけ」という部分適用は同期ルールを複雑化して漏れを生むため。sonnet 役（QA・probe-cleanup・雛形 C の監査役 / Breaker）は対象外（指摘された症状は Opus 固有で、ガイドも Opus 5 専用のため）
2. **ノートは英語**で記述（雛形プロンプトは Issue #122 で英語化済み。依頼でも英語可と明言）。文言は可能な限りガイドの推奨スニペットを逐語採用した
3. **既存の保守的指示（「Prefer a few strong, defensible findings」「report only defects worth fixing」）は変更しない**。ガイドは「レビューで be conservative と指示すると文字通り従い報告が減るので、全件報告して別パスでフィルタせよ」と注意するが、本雛形群は Judge 裁定・fix / plan-editor 採用判定という別パスのフィルタを既に持ち、これらの指示は収束（採用 0 件）駆動のループ設計と一体のため、今回の依頼（過剰処理の抑制）の範囲外と判断した
4. **effort は変更しない**。ガイドは「レビュー精度は低 effort でも維持され effort が主なコストレバー」としており `max` → `high` 降格は有望だが、Issue #111/#113 の実測に基づく判断を実測なしに覆さない（台帳に次の候補レバーとして記録）
5. **resume 互換性**: プロンプト文言が変わるため、変更前の run への `resumeFromRunId` は該当 `agent()` からキャッシュ不一致で再実行になる（安全側。新規セットは通常どおり）

## 変更しなかったもの

- Workflow の構造（レンズ / グループ分割・Judge バッチ並列・dry-twice・diff 正本・model / effort 割り当て）
- 攻撃観点・レビュー観点・4 分類裁定基準の内容（内容同期は発生しない。`RESTRAINT_NOTE` は `TAIL_NOTE` と同種の「全スキル共通の規約ノート」として同期対象に追加）
- 各スキルの README.md（雛形内部のプロンプト規約は記載しておらず、利用者向けの説明に変化がないため）

## 検証

- 4 ファイルの全 ```js ブロックを CLAUDE.md 記載の手順（awk 抽出 → async ラップ → `node --check`）で構文チェックし全ブロック OK
- `RESTRAINT_NOTE` の定義数 / 適用数を grep で確認: resolve 3 定義・10 適用（sonnet 5 役は非適用のまま）/ sip 1・4 / cr 1・1 / cra 1・3
