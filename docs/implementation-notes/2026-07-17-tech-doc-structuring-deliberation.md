# 実装ノート: tech-doc-structuring に決定経緯（Deliberation）の記録を追加

日付: 2026-07-17（JST）

## 要件

ADR 生成時に「いつ、だれとだれが、どのような内容のやりとりをして、その決定に至ったか」（DesignDoc 的な協議プロセスの記録）も残せるようにする。情報の持ち方は「別文書 + 参照」でもよく、トークン効率が良い方を実装者が選ぶ（ユーザー指示）。

## 採用した設計: インラインダイジェスト + 長大時のみ別文書切り出し

ADR 本文に `## Deliberation（決定に至る経緯）` 節を常設し、要点の時系列（`- YYYY-MM-DD 参加者: 要点と帰結`）だけを書く。経緯が長大（目安: 15 行超）な場合や詳細記録を求められた場合のみ、同ディレクトリの `NNNN-<スラグ>-deliberation.md` へ全文を切り出し、ADR 側は 3 行以内の要約に留めて双方の `related` で相互リンクする。

### トークン効率の分析（選択理由）

- ADR は高頻度で読まれる hot path（`software-architect` の手順 2「既存設計との整合確認」、ADR digest 用サブエージェント等）。経緯の詳細は「なぜそう決めたか深掘りする」ときだけ読む cold path
- ダイジェストは 1 ADR あたり 100 トークン程度で、hot path への影響は無視できる。逆に「常に別文書」方式だと「いつ・誰が」の基本情報にすら毎回追加 Read（ファイル 1 往復）が必要になり、全ケースにファイル管理コストが乗る
- 「全文インライン」方式は hot path を経緯ログで肥大させ、digest 用途と相反する
- → 頻度の非対称性に合わせたハイブリッドが最小コスト

### 却下した代替案

| 案 | 却下理由 |
|---|---|
| 常に別文書（design doc）+ ADR から参照のみ | 基本情報（いつ・誰が）の取得にも毎回追加 Read が必要。数行で済む経緯が大半のケースでファイル管理コストが過剰 |
| ADR に全文インライン | hot path（横断検索・digest）を肥大させる |
| frontmatter に新キー `discussion` を追加 | 機械可読価値が薄い（節の有無は `## Deliberation` の grep で検出可能 = スキル原則 2 で代替）。既存の `related` で相互リンクを表現できる |
| 新文書タイプ `deliberation` を追加 | type 値域・見出しセット・判定表の拡張が必要になり、まれな切り出しケースのために機構が重い。既存の「5 タイプに該当しない文書」の軽量整形扱いで足りる |

## 仕様に明記がなく自分で判断した事項

- **節の配置は末尾**（Consequences の後）: 決定本体（Context / Decision / Alternatives / Consequences)を前置し、部分読み・digest で決定内容が先に得られるようにする。MADR の「More Information」を末尾に置く慣行とも整合。整形モードの `## 補足` は従来どおり絶対末尾
- **切り出し閾値は「目安 15 行超」**: 厳密な行数ルールではなく判断の目安として記載
- **sidecar 命名は `NNNN-<スラグ>-deliberation.md`**（対象 ADR と同番号・同ディレクトリ）: ADR の隣にソートされ発見しやすい。採番ロジック（既存ファイルの最大番号 + 1）は番号の最大値を変えないため乱さない
- **整形モードのマッピング追加**: 「検討の経緯 / 決定の経緯 / 議論 / 議事メモ / Discussion / Deliberation」→ Deliberation 節。既存の「経緯」→ Context とあいまいになるため、「経緯」単体は内容で判定する規則（課題の発生史 → Context / 議論の記録 → Deliberation）を明記
- **経緯が会話・素材から読み取れない場合**: 既存機構をそのまま使う（不足時は AskUserQuestion、確認不能環境では `TODO: 未確定`、該当内容が本当に無い場合は見出しセットの「該当する内容が無い章は見出しごと省略してよい」規則で省略）。新しい escape hatch は追加していない

## 変更ファイル

- `skills/tech-doc-structuring/assets/adr-template.md` — Deliberation 節を追加
- `skills/tech-doc-structuring/SKILL.md` — description・内容の収集（手順 2A-1）・生成（手順 2A-4）に経緯の収集と切り出しルールを追加
- `skills/tech-doc-structuring/references/doc-types.md` — adr 見出しセットに Deliberation 行を追加
- `skills/tech-doc-structuring/references/restructuring-rules.md` — 見出しマッピングに Deliberation 行と「経緯」判定規則を追加
- `skills/tech-doc-structuring/README.md` — 新規作成モードの説明・使用例に経緯の記録を追記

## 検証

- `wc -l skills/tech-doc-structuring/SKILL.md` → 113 行（500 行制限内）
- `mise exec node -- npx skills add ./ --list` → tech-doc-structuring を検出、更新後 description が反映されていることを確認

## 追記（2026-07-17）: 経緯素材の外部取得（Slack / Gmail / Confluence）

やり取りの想定情報源が Slack / Gmail / Confluence であるとユーザーから指定された（claude.ai コネクタで MCP 連携済み）。取得手順を `references/deliberation-sources.md` として追加し、SKILL.md 手順 2A-1 から参照させた。

判断事項:

- **取得は加速手段、貼り付けが標準経路**: 本スキルは npx skills でクロスツール配布されるため、MCP コネクタを前提にできない。未接続環境・他エージェントでも機能が完結する設計を維持（コネクタは差し込み式の高速化）
- **ツール名をハードコードしない**: コネクタのツール名は環境依存のため、ToolSearch でロードする手順として記述（`mcp__claude_ai_Slack__*` 等は例示のみ）
- **ユーザーが指した対象のみ取得**: 経緯探しの横断検索・探索的検索を禁止（無関係な私的情報の混入防止・トークン効率）
- **Gmail の出典は「件名 + 日付」**: メールの URL は他者と共有できないため、リンクではなく特定可能な記述で残す
- **メール・DM 由来は記載可否を確認**: 私的なやり取りを git 履歴に永続するリポジトリ文書へ書く前に、実名・引用の粒度をユーザーに確認する規律を明記
- **検証の限界**: 実装セッションではコネクタ連携直後のためツールが未出現（ToolSearch で Slack / Gmail / Atlassian とも 0 件）。実フェッチの動作確認は次セッション以降で行う（未検証）
