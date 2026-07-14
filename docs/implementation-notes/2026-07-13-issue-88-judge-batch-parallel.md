# 実装ノート — Issue #88（敵対レビューの単一 Judge をバッチ並列化）

- 日付: 2026-07-13 / ブランチ: `fix/issue-88-judge-batch-parallel`
- 目的: claude 系敵対レビューループの単一 Judge が「多数シナリオ × 無限定な全サービス横断照合 × effort: 'max'」で harness の 180s/step 無進捗ウォッチドッグにストールする問題を、Breaker 出力を ≤4 件/バッチに分割した並列 Judge へ置き換えて構造的に解消する（Issue 本文の案 A・実セッション検証済み）。

## 変更ファイル

- `skills/smart-issue-resolve/references/agent-orchestration.md`（雛形 B `sir-claude-review-set`）
  - `judgePrompt(round, breaker)` → `judgeBatchPrompt(round, batch, batchNum, batchTotal)` へ置換（単一呼び出し用の旧 `judgePrompt` は dead code のため削除）
  - ループ内の単一 Judge 呼び出しを、`breaker.counterexamples` を ≤4 件/バッチに分割し `parallel` で並列裁定するバッチ block へ置換
  - 部分バッチ失敗の劣化フラグ `judgeDegraded` を追加（宣言・部分失敗ブランチで set・返却・返却の扱いに「収束時も自動コミット前にユーザー確認」を明記）。設計整合レビュー指摘 1 の反映（後述の判断事項 8）
  - 同期ノート: 「両者で同期する構造」に敵対モード Judge のバッチ並列化と `judgeDegraded` の伝播を追記。プロンプト移植リストの `judgePrompt` 表記を `judgeBatchPrompt` に更新（裁定基準不変のため単体スキルへの同期は不要である旨も明記）
- `skills/smart-issue-plan/references/agent-orchestration.md`（雛形 `sip-plan-review-set`）
  - `judgePrompt` → `judgeBatchPrompt` へ置換（計画用の「実コード＋計画本文照合」「反例テスト無し」の差分は維持）
  - 単一 Judge 呼び出しを、`breaker.scenarios` を ≤4 件/バッチに分割する同型バッチ block へ置換
  - 部分バッチ失敗の劣化フラグ `judgeDegraded` を追加（返却・返却の扱い・完了報告・SKILL.md の返却の扱いに反映。`plan.md` 投稿前のユーザー確認を明記）
  - 同期ノートの「同期する構造」リストにバッチ並列 Judge と `judgeDegraded` の伝播を追記（Breaker フィールド名だけ意図的に異なる旨も明記: resolve=`counterexamples` / plan=`scenarios`）
- `skills/smart-issue-resolve/SKILL.md`（4 箇所・effort/構造の最小更新）
  - 役割表の「Breaker / Judge（敵対）」行を `sonnet / max・high`（Breaker=max / Judge=high・バッチ並列）に更新
  - レビューループ節の「(effort max) がレビュー・裁定を担う」一般記述に、敵対 Judge のバッチ並列 high を注記
  - claude 系敵対モード説明の Judge を `effort max` → `effort high`・バッチ並列に更新（ストール防止の意図を 1 文追記）
  - 「収束後のコミット・PR 作成」の最終 QA ゲートに `judgeDegraded: true` 時のユーザー確認を明記（判断事項 9）
- `skills/smart-issue-resolve/README.md`（2 箇所）
  - 役割表の該当行に「claude 敵対 Judge のみ high・≤4 件/バッチ並列裁定」を注記
  - claude 敵対の説明を Breaker=max / Judge=high・バッチ並列に更新
- `skills/smart-issue-plan/SKILL.md`（3 箇所）
  - レビューループ節の「(effort max)」一般記述に敵対 Judge のバッチ並列 high を注記（resolve SKILL.md と同文の箇所・後述の判断参照）
  - claude 系敵対モード説明の Judge を effort high・バッチ並列に更新
  - Workflow 返却の扱いに `judgeDegraded: true`（一部シナリオ未裁定 → 投稿前にユーザー確認）を追記（設計整合レビュー指摘 1）
- `skills/smart-issue-plan/README.md`（1 箇所）
  - claude 敵対の説明の Judge を effort high・バッチ並列に更新
- `CLAUDE.md`（1 箇所・設計整合レビュー指摘 3）
  - 「スキル改修時の注意 → レビュープロンプトの二重化と同期」マスターの resolve エントリの識別子表記 `judgePrompt` → `judgeBatchPrompt`
- `docs/implementation-notes/2026-07-13-issue-88-judge-batch-parallel.md`（本ファイル・同 PR）

裁定基準（4 分類・「4 点に答えられるものだけを真の欠陥とする」防御基準・items/dismissed 振り分け）・標準モード reviewer・Breaker・codex 系（雛形 C / codex-judge-prompt.md）・QA 系は一切変更なし。

## 要件対応（受け入れ基準ごと）

### 完了条件 1: Breaker が 10 件以上出しても Judge がストールせず裁定を完走する構造

達成。各バッチの作業量が有界になるよう次の 3 点で担保した:

1. バッチサイズ上限 `BATCH = 4`。Breaker が N 件出すと ⌈N/4⌉ 個の Judge が **並列**起動し、各 Judge が扱うのは最大 4 件のみ（10 件 → 3 並列、14 件 → 4 並列）。
2. `judgeBatchPrompt` に「裁定対象はインラインの当バッチのみ・他バッチや `breaker-round-<N>.md` の他項目は読まない」「照合は各シナリオの `evidence` が指すファイル/行に限定・無関係な広域 grep / 全サービス横断探索を禁止」を明示（観測されたストール直接原因への対策）。
3. 呼び出し側 `effort: 'max'` → `'high'`、プロンプトに「3 分以内に着実に tool を進める」を明示。

### 完了条件 2: plan / resolve 両テンプレートに反映され構造同期が保たれる

達成。両ファイルに同型のバッチ block（`scen` → `batches` 分割 → `parallel` → `filter(Boolean)` → `flatMap` 集約）と `judgeBatchPrompt` を入れた。意図的な差分は Breaker フィールド名のみ（resolve=`counterexamples` / plan=`scenarios`）。両ファイルの同期ノートにバッチ並列化を追記し、構造同期の対象であることを明文化した。

## 自分で判断した事項

1. **バッチ block は Issue / design の検証済みスニペットを逐語採用**（`parallel(thunks)` を `Promise.all` 等へ書き換えない）。design の未確定事項 1（`parallel` の runtime 契約）に従い、独断で書き換えず検証済みの形を保持した。
2. **agent-failed 経路の担い手**: バッチ版では `findings` は常にオブジェクト（`{items, dismissed}`）になるため、既存の `if (findings === null)` は adversarial では発火しない。Judge 全滅の検知は `batches.length > 0 && ok.length === 0` チェックが担う。部分失敗（一部バッチのみ null）は `log` して部分裁定で続行する。0 件（`batches.length === 0`）は `agent-failed` にせず `findings = {items:[], dismissed:[]}` → 既存の収束判定（`items.length === 0`）に載る。この 3 経路が下流（specQuestions 抽出・records 記録・収束判定・standard 分岐）と無改修で互換であることをコード上で確認した。
3. **SKILL/README の役割表は「行分割」ではなく「注記」を採用**（design 未確定事項 2）。既存の表構造を保ち effort 列に併記する最小変更に留めた（過剰なリストラクチャを避ける）。
4. **plan SKILL.md の一般記述（「(effort max) がレビュー・裁定を担う」）も更新**。design の SKILL 更新リストには resolve 側（L213 相当）のみ挙がっていたが、plan SKILL.md にも同文の一般記述が存在し、更新しないと plan/resolve 間で記述の正確性が乖離する。本 Issue の主眼が plan/resolve 構造同期であることから、同文箇所は両方更新して整合を保った（effort/構造記述の最小更新の範囲内）。
5. **同期ノートの単体スキル同期は不要と明記**。context/design の指示どおり、裁定基準を変えない構造変更のため `code-reviewer`（`cr-isolated-review`）・`code-reviewer-adversarial`（`cra-claude-judge`）への同期はしない。resolve 同期ノートの 2 段落目にその旨を 1 節追記した。
6. **実装ノートのファイル名は design 指定の `2026-07-13-...` を採用**。作業中に日付が JST で 2026-07-14 に変わったが、design.md が成果物として明示的に命名した `2026-07-13-issue-88-judge-batch-parallel.md` に合わせ、参照整合を優先した。
7. **CLAUDE.md「スキル改修時の注意」マスターの同期対象一覧の識別子表記を更新**（設計整合レビュー指摘 3 を採用）。初期実装では scope 尊重で未変更としフォローアップ候補に回したが、レビューで「リネーム元 PR で直すのが最小コスト・マスター同期マップの grep 正確性は repo の明示的価値」と判断し、resolve エントリの `judgePrompt` を `judgeBatchPrompt` に更新した（1 語）。単体スキル `code-reviewer-adversarial` は自身の単一 Judge `judgePrompt` を正当に保持するため触れない（移植元表記は下記フォローアップ候補）。
8. **部分バッチ失敗の劣化伝播 `judgeDegraded` を追加**（設計整合レビュー指摘 1 を採用）。バッチ版は `findings` が常にオブジェクトのため `if (findings === null)` が発火せず、一部の Judge バッチが null（ストール）で生存バッチの真の欠陥 0 件だと収束扱いになる。このとき未裁定の反例（最大 4 件/バッチ）が残るが、初期実装ではログ 1 行のみで返却に伝播していなかった。既存 `auditFailed` と同型に劣化フラグを立てて返却し、返却の扱いで「収束時も自動コミット/`plan.md` 投稿前にユーザー確認」を明記。resolve/plan 両テンプレートに同期。`finalQa` はテスト・受け入れ基準の検証で、敵対レビューが対象とする設計・保守・可用性クラスの未裁定欠陥はバックストップしないため、劣化の可視化に意味がある。
9. **resolve SKILL.md の「収束後のコミット・PR 作成」最終 QA ゲートにも `judgeDegraded` を明記**（本 PR のレビューループ最終 QA が pass 付帯で推奨した plan/resolve 非対称の解消）。plan SKILL.md は返却の扱い箇条書きに `judgeDegraded` を記載済みだが、resolve SKILL.md で自動コミット手順を規定する当該節のステップ 1 は `finalQa.pass` のみに言及していた。resolve は git commit / push / PR 作成という不可逆な副作用を自動実行する経路のため、この節単独でもゲートが読み取れるよう references の「返却の扱い」と同内容の 1 文を追記した。

## テスト結果（ベースライン比較）

このリポジトリはスキル（Markdown テンプレート）集でユニットテストは無い。context.md のテスト方針に沿って 3 点を実行:

1. **Workflow 雛形の JS 構文チェック**（CLAUDE.md 標準・bash スクリプト経由）:
   - ベースライン（変更前）: resolve 5 block・plan 1 block すべて `OK`
   - 変更後: resolve 5 block・plan 1 block すべて `OK`（回帰なし）
   - 注意: `node --check` は未定義グローバルを検出しないため、この検査は `parallel` の runtime 存在・契約を保証しない（下記リスク 1）。
2. **skill 検出**: `npx skills add ./ --list` で 19 skills 検出、`smart-issue-plan` / `smart-issue-resolve` とも description 込みで検出継続（frontmatter 非破壊）。
3. **構造レビュー（手動）**: バッチ境界（0 件→0 バッチ・4 件→1・5 件→2・14 件→4）、部分失敗時の続行ログ、`ok.length === 0` の agent-failed 経路、`findings` の形（`{items, dismissed}`）が下流（specQuestions 抽出・records 記録・収束判定・standard 分岐）と互換であること、plan/resolve 間の構造同期を、両ファイルのループ実コードを読んで確認した。

## リスク・トレードオフ

1. **`parallel` プリミティブ（最重要）**: 既存テンプレートは `agent()`/`log()` のみ使用し、`parallel` は本リポジトリに前例が無い（docs 記載なし）。Workflow runtime が `parallel(thunk配列)` を提供し入力順で結果を返す契約に依存する。Issue が plan 側実セッションで検証済みと明記しているため経験的には確認済みだが、静的検査では実行性を保証できない。実運用（Workflow 実行）での初回検証が残課題。加えて、劣化時の部分裁定続行は「`agent()` が throw せず null を返し、`parallel` が個別失敗で reject せず null-or-object 配列で解決する」no-throw 契約（データフロー節）に依存し、バッチ block は `await parallel(...)` を try/catch で囲まない。契約が崩れる（`agent()` が throw / `parallel` が reject）と Workflow 全体が未捕捉例外で落ちる。この load-bearing 前提も初回実行で検証する（設計整合レビュー指摘 2 の採用部分。逐語スニペット採用のためコード変更はしない）。
2. **独立 Judge レビューの喪失**: バッチ版では旧裁定タスク 2（Breaker が見落とした欠陥の独立探索）を行わない（クロスバッチ重複回避）。claude 敵対の Judge 独立探索が無くなるトレードオフ。標準 reviewer・codex Judge の独立探索は維持されるため、根治（ストール解消）とのバランスで許容。
3. **並列度の上限**: シナリオ N 件で ⌈N/4⌉ Judge が同時起動。現実の Breaker 産出は ~10-15 件想定で実害は低いが、極端な件数での同時実行上限は留意。

## フォローアップ候補（本 Issue スコープ外）

1. **`cra-claude-judge`（code-reviewer-adversarial）の同型ストールリスク**: 同じ単一 Judge 構造でストールし得るが、裁定基準を変えない本修正のスコープ外（context 指示どおり変更せず記録）。単体スキルの敵対レビューでも多数シナリオが出る場面では同じバッチ並列化が有効と考えられる。別 Issue 化を推奨。
2. **`code-reviewer-adversarial` の移植元表記**: SKILL.md / references の「雛形 B の `judgePrompt` からの移植」表記は、resolve のリネーム後わずかに不正確（移植元は現在 `judgeBatchPrompt`）。ただし cra の裁定基準の系譜を指す記述で、cra 自身の単一 Judge は `judgePrompt` のまま正当に残る。機械的にリネームすると cra がバッチ化を採用したと誤読させうるため据え置き、将来判断とする（CLAUDE.md マスターの当該行は本 PR で修正済み）。
