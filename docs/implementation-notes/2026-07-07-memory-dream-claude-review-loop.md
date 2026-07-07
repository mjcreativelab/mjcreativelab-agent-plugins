# memory-dream への --claude-review-loop（-cldrl）追加

日付: 2026-07-07（JST） / ブランチ: `feature/memory-dream-claude-review-loop`

smart-issue-plan の `--claude-review-loop` と同様の claude 系レビューループを memory-dream に追加した。依頼: 「memory-dream スキルに、smart-issue-plan スキルと同じように --claude-review-loop（-cldrl）オプションを実装して」。

## 仕様に明記されていなかったため判断した事項

1. **standard のみ追加（敵対的 `-cldarl` は追加しない）** — 依頼が `-cldrl` のみだったため。memory-dream には codex 系も standard しかなく（敵対的モード自体が存在しない）、系統追加のみでモード体系は変えないのが最小実装
2. **採用判定・修正 commit はオーケストレーター（レビュイー）のまま** — smart-issue-plan の claude 系は plan-editor エージェントが `plan.md` を編集するが、memory-dream の修正は「記憶階層リポジトリへの commit」であり、既存 codex ループの不変則（「採用 / 不採用の判定は、レビュイーである Claude が行う」）をそのまま維持した。隔離するのはレビュワーのみ
3. **雛形は 1 起動 = 1 ラウンド**（`md-dream-review`・レビュワー 1 体） — 修正がラウンド間にオーケストレーター側で発生するため、smart-issue-plan のような「1 Workflow = 3 ラウンド 1 セット」構造は取れない（Workflow 内から本体セッションに修正を挟めない）。ループ制御・収束判定・3 ラウンドごとの上限チェックは SKILL.md の既存骨格（codex 系と共通）に置いた
4. **レビュー観点は codex 系テンプレートと同一の 7 観点** — 系統によってレビュー品質基準が変わらないよう、`assets/codex-review-prompt.md` の観点を逐語で雛形プロンプトに移植し、両ファイルに同期ノートを付けた
5. **両フラグ併用時は codex 優先** — smart-issue-plan と同じ判断基準（別系統モデルの独立性がより高い）+ 1 行通知
6. **codex 系フォールバックで claude 系へ自動切替しない** — smart-issue-plan と同じ（codex フラグ明示 = ユーザーが別系統モデルを選んでいる。`-cldrl` での再実行を案内するに留める）。memory-dream にはセキュリティ自動発動が無いため、自動切替が正当化されるケースも無い
7. **args シム（`typeof args === 'string' ? JSON.parse(args) : ...`）を雛形に内蔵** — 「Workflow の args が JSON 文字列で届く環境がある」既知問題（#76）への対応。既存雛形は起動時にシムを挿入する運用だが、新規作成分は最初から内蔵した（JSON 値で届く環境でも無害）

## CLAUDE.md「レビュープロンプトの二重化と同期」マスターリストに追加しなかった理由

マスターリストの対象は「敵対レビューの Breaker / Judge プロンプト（攻撃観点・4 分類裁定基準）と標準レビュー観点の骨格」（コードレビュー系）。memory-dream のレビュー観点は記憶 consolidation 専用（hallucination 混入・誤削除・日付変換・レイヤ重複など）で、この骨格とは別物。同期はスキル内（codex テンプレート ↔ claude 雛形）で閉じるため、両ファイルの同期ノートで管理する。

## 検証

- 雛形 js ブロックの構文チェック（CLAUDE.md 記載の awk + `node --check`）: OK
- `npx skills add ./ --list`: memory-dream が更新後 description で検出されること: OK
- Workflow スモークテスト: ダミー記憶リポジトリに欠陥 2 件（相対日付の誤変換・出典のない新事実）を仕込んだ dream 差分を作り、雛形をそのまま起動してレビュー結果（FINDINGS_SCHEMA 準拠）を確認
- 実運用フロー（実際の dream → ループ収束）での end-to-end 検証は未実施（必要なら empirical-prompt-tuning で別途チューニングする）

## その他

- Codex による最終レビューはユーザー指示により省略した
