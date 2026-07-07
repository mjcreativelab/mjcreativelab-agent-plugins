# 実装ノート — Issue #72 フォローアップ（レビュー用プロンプトの点検と改修）

- 日付: 2026-07-07 / ブランチ: `fix/review-prompt-sync-20260707`（PR #75）

## 変更ファイル

- `skills/smart-issue-resolve/references/agent-orchestration.md`（4 行変更）
  - 雛形 B `breakerPrompt` のセキュリティ攻撃観点行に `Confused Deputy` を追加
  - 雛形 C（`sir-codex-breaker`）Breaker のセキュリティ攻撃観点行に `Confused Deputy` を追加
- `skills/code-reviewer-adversarial/references/agent-orchestration.md`（4 行変更）
  - `cra-claude-judge` Breaker のデータ整合性・性能攻撃観点行に `再入可能性` を追加
  - `cra-claude-judge` Judge の「真の欠陥」4 分類カテゴリ列挙に `テストカバレッジ不足` を追加
- `skills/smart-issue-plan/references/agent-orchestration.md`（1 行変更・QA フォローアップで追加）
  - `sip-plan-review-set` の `breakerPrompt` データ整合性・性能攻撃観点行（L166）に `再入可能性` を追加

差分は計 9 行（すべて JS 文字列リテラル＝プロンプト本文の語句差し替え）。SKILL.md・README・codex 系 assets・CLAUDE.md・code-reviewer の references は変更なし。

## 要件対応（受け入れ基準ごと）

### 基準 1: 同期ノート対象 4 ファイルの共通骨格に意図しない差分がないこと（あれば全対象を同期修正）

点検方法: 4 ファイルの Breaker 攻撃観点ブロック（6 バレット）・Judge 4 分類カテゴリ・「4 点に答えられる」防御基準を正規化（末尾の丸括弧注記と `${...}` 変数を除去）して突き合わせた。移植履歴（#68 resolve → #71 plan → #73 code-reviewer / code-reviewer-adversarial）を `git log -S` で確認し、片側だけに入った項目を drift 候補として抽出した。

検出した「片側だけの欠落」＝ drift（すべて共通骨格 ＝ 攻撃観点 / 4 分類。identity 差ではない）と、その修正:

1. **`Confused Deputy`（セキュリティ攻撃観点）**: `cra-claude-judge` にのみ存在（v2.0.1 #51 の breaker-personas 由来で #73 の references へ引き継がれた）。resolve 雛形 B/C に欠落 → **resolve 雛形 B/C に追加**して収束。plan は security 行が STRIDE 語彙の意図的差分のため対象外（後述）。
2. **`再入可能性`（データ整合性・性能攻撃観点）**: resolve 雛形 B/C にのみ存在（#68 由来）。`cra-claude-judge` と plan の Breaker データ整合性行に欠落 → **cra と plan の両方に追加**して収束（QA フォローアップで plan を追補。後述の「QA フォローアップ」節）。
3. **`テストカバレッジ不足`（Judge「真の欠陥」カテゴリ）**: resolve・plan の Judge には存在、`cra-claude-judge` に欠落 → **cra に追加**して収束。可読性系ではなく欠陥カテゴリなので cra の identity（標準レビュー観点は対象外）とは無関係の drift と判断。

修正後、resolve 雛形 B / 雛形 C / cra-claude-judge / plan の Breaker データ整合性攻撃観点の項目集合・順序が一致（`再入可能性` の挿入位置は既存順「…部分失敗・再入可能性・不可逆な状態変更…」に統一）。Breaker セキュリティ攻撃観点は resolve 雛形 B / 雛形 C / cra で `Confused Deputy` を含む集合＋順序が一致。Judge「真の欠陥」カテゴリは resolve・plan・cra で `テストカバレッジ不足` を含む。

意図的差分として同期しなかったもの（誤同質化しないよう保持）:
- **plan（`sip-plan-review-set`）の Breaker セキュリティ観点行**: plan の同期ノートが「レビュー観点は diff 用と文言が異なる」と明記。plan の Breaker セキュリティ行（L163）は STRIDE ベース（`STRIDE（なりすまし…）・信頼境界・認可漏れ・PII / 秘密情報の露出・注入面`）で resolve/cra の `認可逸脱・インジェクション・秘密情報漏洩・TOCTOU・PII 露出` とは語彙が異なる適応済み変種。よって `Confused Deputy` の機械追加は意図的差分の破壊になるため対象外。
- **plan の reviewerPrompt データ整合性観点行（L147）**: `冪等性（二重実行防止）・並行更新の整合性・…・計算量への配慮を欠いていないか` と、疑問形・plan 固有語彙に適応された観点であり、resolve の diff レビュー観点とは文言が異なる（同期ノートの「文言が異なる」はこの reviewer 観点を指す）。同期対象外。
- **cra の `プロジェクト固有基準` / `security-audit.md` 参照の欠如**: cra-claude-judge は単発・context.md 非依存（移植ノートに明記）。Breaker の `プロジェクト固有基準` バレット・`security-audit.md` 参照注記・Judge の `プロジェクト固有基準違反` カテゴリが無いのは identity 差であり drift ではない。保持。
- **`cr-isolated-review`（code-reviewer 標準）**: 6 観点（可読性含む）・5 区分出力の別構造で Breaker 攻撃観点ブロックを持たない。今回の 3 項目の対象外。

### 基準 2: レビュープロンプト内の欠陥（矛盾・陳腐化・スキーマ齟齬・変数埋め込み漏れ）の修正 or 非欠陥としての不採用記録

二次点検（codex 系 assets: resolve / plan の codex-review-prompt.md・codex-judge-prompt.md、code-reviewer-adversarial の judge-prompt.md・breaker-personas.md）を実施。スキーマとプロンプト出力の齟齬・変数埋め込み漏れ（`securityReason` 型ギャップの類例）・陳腐化した記述は検出されなかった。codex 系 assets は同期マスター対象外のため、上記 3 項目の骨格差は強制同期しない（コンテキスト手順 3 の方針どおり）。

#### 観測された欠陥候補（context.md「実測された欠陥候補」）の判定

**候補修正 1（args 防御的正規化シム: `const $a = typeof args === 'string' ? JSON.parse(args) : (args||{})`）→ 不採用（別 Issue 化を推奨）**
- 理由 1（未検証の環境依存が主因）: args が JSON 文字列で届く挙動は、本オーケストレーション・セッションのプローブでの観測であり、配布先環境での再現は本タスクで検証していない（context.md 自身も「ツールバージョン差の可能性」と留保）。雛形は「args は JSON 値として渡す」契約を既に明記済み。未確認の環境症状を根拠に配布物へコード変更を入れるのは検証前主張に当たる。これが不採用の主たる根拠。
- 理由 2（スコープ外・非外科的の再評価）: 本 Issue はレビュープロンプトの点検であって Workflow 起動の堅牢化ではない。なお当初ここに「シム採用は数十箇所（resolve 64・plan 16・code-reviewer 4・cra 6 の `args.` 参照）を `$a.` へ書き換える大規模変更になる」と記していたが、これは事実誤認だったため訂正する。雛形は `const ctx = args.workDir + '/context.md'` 等でトップレベルから `args` を参照しているため、各スクリプト冒頭に `args = typeof args === 'string' ? JSON.parse(args) : (args || {})` を 1 行入れて `args` 自身を再代入すれば、既存の全 `args.` 参照は無改変で通る（`$a` への rename は不要）。よって「非外科的だから不採用」という前提は成立しない。それでも本タスクで採らないのは理由 1（未検証）とスコープの 2 点による。
- 別 Issue で扱う際の正しい前提: 「配布先での文字列到達が再現確認できること」を前提に、上記の 1 行シム（全雛形の冒頭で `args` を再代入・呼び出し元は無改変）を全同期対象雛形へ一貫適用する。blast radius は「各雛形冒頭 1 行」であって呼び出し元の大量書き換えではない。
- 補足: `args.workDir` 等の直接参照が文字列 args で `undefined` 化し `Issue #undefined` / `undefined/context.md` を生む因果連鎖はコード上確認済み（実害は実測どおり）。ただし修正の是非は上記のとおり別対応が妥当。

**候補修正 2（「前提とゲート」の注意書きに文字列到達の旨と正規化シムの存在を反映）→ 不採用**
- 理由: 既存の注意書き「`args` は JSON 値として渡す（文字列化した JSON を渡さない）」は既に正しい契約を述べている。ここに「一部環境では文字列で届く」という未検証の環境主張を 4 つの配布 references に書き足すのは、検証前主張の記述化に当たる。候補修正 1 を採らない以上「正規化シムの存在」を参照する記述も不整合になる。契約は現状で十分と判断。

## 自分で判断した事項

- **同期の方向**: マスターは resolve 雛形 B だが、各項目は正当な攻撃観点 / 欠陥カテゴリの和集合として全経路へ適用する方針を採った（`Confused Deputy` は resolve へ、`再入可能性` は cra・plan へ、`テストカバレッジ不足` は cra へ）。どれも特定スキルの identity を担う語ではなく、cra 同期ノートが「攻撃観点・4 分類裁定基準は resolve 雛形 B と共通」と明言しているため、和集合での一致が正しい解釈。
- **`Confused Deputy` の挿入位置**: cra の既存順（`…TOCTOU・PII 露出・Confused Deputy`）に合わせ、resolve 側を末尾挿入に統一（集合だけでなく順序も一致させた）。
- **`再入可能性` の挿入位置**: resolve 既存順（`…部分失敗・再入可能性・不可逆な状態変更…`）に合わせ、cra・plan を同位置挿入に統一。
- **plan の security 行・reviewer 観点行を対象外にした判断**: plan 同期ノートの「レビュー観点は diff 用と文言が異なる」という明示的な意図的差分宣言を優先。ただしこの宣言が及ぶのは (a) reviewerPrompt の観点文言 と (b) STRIDE 語彙に適応された Breaker セキュリティ行 であり、**verbatim 共通の Breaker データ整合性行（L166）には及ばない**（QA フォローアップで補正。次節参照）。
- **SKILL.md 更新不要の確認**: 変更した攻撃観点バレットの逐語リストを埋め込む SKILL.md は存在しない（`code-reviewer-adversarial/SKILL.md:74` の Security persona 要約は既に `Confused Deputy` を含み整合。`smart-issue-plan/SKILL.md:252` の Breaker 観点要約はデータ整合性を `トランザクション境界・冪等性・並行更新・部分失敗・不可逆な状態変更・N+1 や過剰 I/O` と抽象記述しており、`再入可能性` の追加で陳腐化しない）。CLAUDE.md マスター一覧も雛形の増減がないため変更不要。

## QA フォローアップ（独立 QA 指摘への対応）

独立 QA から 3 点の指摘を受け、検証のうえ以下のとおり対応した。

### 指摘 1: implementation-notes.md がプロジェクトルートに存在しない → 対応（本ファイルを作成）
- 検証: `git status` および `ls` でプロジェクトルートに `implementation-notes.md` が不在、記録は tmp 側にのみ存在することを確認。CLAUDE.md「Implementation Notes」ルールおよび受け入れ基準 3（修正あり時）はルート作成・提示を要求している。
- 対応: 本ファイルをプロジェクトルートに作成（当時は未追跡・コミット対象外の運用。その後 docs/implementation-notes/ アーカイブ方式の導入に伴い本パスへ移動してコミット）。

### 指摘 3: smart-issue-plan Breaker データ整合性行に `再入可能性` が未追加 → 対応（追加。指摘は妥当）
- 検証: origin/main（修正前）で 4 ファイルの Breaker データ整合性行を突き合わせた結果、`再入可能性` は resolve 雛形 B/C にのみ存在し、cra（L91）と plan（L166）の両方に欠落していた。plan の Breaker データ整合性行（L166 `…部分失敗・不可逆な状態変更・N+1 や過剰 I/O・計算量`）は resolve/cra の当該行と **verbatim 同一の共通バレット**であり、reviewerPrompt のデータ整合性行（L147 `…計算量への配慮を欠いていないか`／plan 固有の疑問形・語彙）とは別物である。
- 当初判断の誤り: 当初は plan 同期ノートの「レビュー観点は diff 用と文言が異なる」を根拠に plan 全体を対象外とした。しかしこの宣言が及ぶのは reviewer 観点（L147）と STRIDE 適応済みの Breaker セキュリティ行（L163）であって、verbatim 共通の Breaker データ整合性行（L166）には及ばない。cra に適用した和集合ドリフト解消は同じ論拠で plan L166 にも適用されるべきだった。
- 対応: plan L166 に `再入可能性` を resolve/cra と同位置（`部分失敗・再入可能性・不可逆な状態変更`）で追加。これで resolve 雛形 B/C・cra・plan の 4 経路の Breaker データ整合性攻撃観点が集合・順序ともに一致。

### 指摘 2: 変更が unstaged のままコミットされていない → 不採用（本タスクの制約による期待状態）
- 検証: working tree に 3 ファイルの変更が存在し、`fix/review-prompt-sync-20260707` は origin/main と同一 SHA。指摘の事実認識は正確。
- 判断: 本フォローアップタスクの明示的制約が「コミット・push はしない」であり、レビュー / QA ハンドオフ前に変更が working tree に留まるのは期待される中間状態である。コミットは開発者の別ステップ（`/smart-commit` 等）の担当でスコープ外。よって欠陥としては不採用とし、事実は記録に留める。

## テスト結果（ベースライン比較 + QA フォローアップ再実行）

テスト方針（context.md）に従い実行。QA フォローアップで plan を変更したため、plan の JS 構文チェックとスキル検出を再実行した。

| 検証 | ベースライン（変更前） | 変更後（QA フォローアップ含む） |
|---|---|---|
| JS 構文チェック `smart-issue-resolve`（5 ブロック） | all OK | all OK |
| JS 構文チェック `code-reviewer-adversarial`（1 ブロック） | OK | OK |
| JS 構文チェック `smart-issue-plan`（1 ブロック・今回変更） | OK | OK |
| JS 構文チェック `code-reviewer`（1 ブロック・未変更） | OK | OK |
| `npx skills add ./ --list` | 17 スキル検出・error / internal 漏れなし | 17 スキル検出・error / internal 漏れなし |
| SKILL.md 行数（変更スキル） | すべて ≤500 | 変更なし（≤500 維持。SKILL.md は未変更） |

- ベースラインからの回帰なし。変更は Markdown 内の JS 文字列リテラル（プロンプト本文）の語句差し替えのみで、コードの構造・スキーマには触れていない。
- assets/*.sh は変更していないため `bash -n` は対象外。
