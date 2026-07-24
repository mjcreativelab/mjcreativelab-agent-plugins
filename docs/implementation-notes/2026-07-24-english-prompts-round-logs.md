# 実装ノート: レビュー系雛形のプロンプト英語化 + 開始日時・ラウンド結果ログ（Issue #122）

日付: 2026-07-24（JST） / 対象 PR: feature/issue-122-english-prompts-round-logs

## 変更概要

- 4 スキル（smart-issue-resolve 雛形 A〜E / smart-issue-plan `sip-plan-review-set` / code-reviewer `cr-isolated-review` / code-reviewer-adversarial `cra-claude-judge`）の Workflow 雛形について、`agent()` プロンプト本文・スキーマ description を英語化
- `nowJst` のフォーマットを `%H:%M` → `%Y-%m-%d %H:%M:%S` に拡張し、`args.startedAt`（オーケストレーター実測）と直近 `nowJst`（`lastJst`）の導出で、セット開始・各ラウンド開始・judge 起動の日時を `log()` 表示
- 各レビューラウンド終了時に指摘 / 裁定の内訳と各指摘タイトル、fix / plan-editor の採用・不採用内訳を `log()` 出力

## 仕様に明記されていなかったため判断した事項

1. **言語境界の線引き**: 依頼は「サブエージェント間のプロンプトは英語に」。プロンプト本文・スキーマ description・レンズ / 観点グループ定義（`aspects`）・経緯 / 差分スコープなど**プロンプトに埋まる文言**を英語化し、ユーザーが読む内容 — 構造化出力の中身（指摘タイトル・detail）・引き継ぎファイル（design.md / impl-notes.md / breaker-round-*.md / plan.md）・`log()`・`meta`（permission ダイアログ表示）— は日本語のままとした（グローバル規約「出力は日本語」との整合）。各プロンプト末尾の共通指示 `TAIL_NOTE`（旧 `TIME_NOTE` を改名）で日本語出力を明示する
2. **カテゴリ enum 値は日本語のまま**: `真の欠陥` / `仕様未定` / `低優先度` / `ノイズ` はスクリプト内の比較（`it.category === '仕様未定'`）・SKILL.md の手順・findings ファイル・完了報告に跨るデータ契約のため変更しない。英語プロンプト内では `真の欠陥 (true defect)` のように英語注釈付きで exact value を指示する。severity（High/Medium/Low）・verified（fail/UNVERIFIED）は元から英語
3. **開始時刻の取得設計**: Workflow スクリプトは `Date.now()` 禁止のため、(a) セット / 雛形の開始日時はオーケストレーターが起動直前に実測して `args.startedAt` で渡す、(b) ラウンド開始・judge 起動など中間時点は直近エージェントの `nowJst`（`lastJst` に保持）から導出する方式にした。専用の時刻取得エージェントを毎ラウンド起動する案は、エージェント 1 体分のコスト・レイテンシ増に対し精度向上が数秒程度のため不採用
4. **startedAt はログ表示専用**: `agent()` プロンプトへ埋め込むと resume（`resumeFromRunId`）の (prompt, opts) キャッシュ一致が壊れ、再開時に全エージェントが再実行される。`log()` のみで使う制約を雛形の前提・args 説明・CLAUDE.md に明記した
5. **結果ログの件数上限**: 指摘タイトルは 10 件 + 「他 N 件」、fix の採用 10 件・不採用 5 件で打ち切り（実測でラウンド 1 指摘は 5〜14 件のため通常は全件表示される。log 洪水の防止）
6. **雛形 A / D / E（実装・fix・最終 QA）にも適用**: 依頼の主対象はレビューラウンドだが、`TAIL_NOTE` / `NOW_JST_FIELD` は雛形単位の共通 const のため、半分だけ旧形式を残すと保守時の混乱を招く。全雛形で英語化 + startedAt 開始ログに統一し、QA 失敗時の指摘・ArchReview の指摘もタイトル行を log 出力するようにした
7. **cr（単発隔離レビュー）の結果ログは追加しない**: レビュー結果は 5 区分 markdown 1 本で、Workflow 完了直後にオーケストレーターがチャットへ全文表示する（SKILL.md 手順 5）。log() への二重出力は冗長のため開始・完了時刻のみとした

## 変更・調整した内容と理由

- `TIME_NOTE` → `TAIL_NOTE` に改名（時刻指示に加えて出力言語指示を含むようになったため）。参照していた各 references の「前提とゲート」・CLAUDE.md の記述も同時更新
- 雛形 B / sip のラウンド開始ログを、`comprehensive`（分割並列か単発か）の算出後に移動し、起動内容（3 レンズ / 3 グループ並列 or 単発 1 体）をログに含めた（挙動不変・ログ情報量の向上）
- fix 完了ログに不採用件数・テスト失敗表示を追加（従来は採用件数のみ）
- 収束時に「クリーン（連続 2 回）→ 収束」の明示ログを追加

## トレードオフ

- **英語化の同期コスト**: 攻撃観点・裁定基準の今後の内容変更は英語表現で 4 スキル同期することになる（CLAUDE.md マスター・各 SKILL.md 同期ノートに明記）。日本語のままより編集者の負担は上がるが、精度向上を優先した
- **ログ増**: 1 ラウンドあたり最大 30 行程度の log() 増。IDE 拡張での可視性を優先し許容（トークンコストは軽微）

## 検証

- 全 8 雛形（resolve A〜E・sip・cr・cra）の js ブロックを抽出し `node --check` で構文検証 → 全て OK
- js ブロック外の prose 差分を旧版と突合し、意図した変更（可視化規約・言語規約・args への `startedAt` 追加・同期ノート追記）のみであることを確認
- `npx skills add ./ --list` で 4 スキルの検出を確認（コミット前に実施）
- 実挙動（英語プロンプトでの recall・ログ表示）は次回 dogfooding で採取予定（`docs/empirical-tuning/review-loop-speedup.md` の Issue #122 節に採取項目を記載）
