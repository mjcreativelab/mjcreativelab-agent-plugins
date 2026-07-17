# 実装ノート: tech-doc-structuring スキル追加（Issue #96）

日付: 2026-07-17（JST）

ADR・技術ドキュメントを「YAML frontmatter + 固定見出し + 自然言語の散文」のハイブリッド構造で生成・整形するスキルの新規追加。会話（仕様駆動設計における構造化言語の適用範囲の議論）で確定した方針をスキル化した。

## 自分で判断した事項

- **スキル名 `tech-doc-structuring`**: `adr-authoring` 等の ADR 限定名は、要件に「ADR 以外の技術文書への同原則の適用」が含まれるため却下。ADR の発見性は description のトリガー語（「ADR を書いて」等）で担保する
- **タイトルは H1 が唯一の正**（frontmatter に `title` キーを持たない）: 二重管理は片方の陳腐化を招くため。機械可読性は H1 の grep で十分と判断
- **status は frontmatter が唯一の正**（Nygard 原型にある本文 Status 節を廃止）: 同じく二重管理の回避。整形時は本文の Status 行を frontmatter へ「移動」する
- **見出しはバイリンガル表記**（`## Context（背景）`）: ADR ツール・慣習との grep 互換（`^## Context` が引き続きヒット）と日本語チームの可読性の両立
- **章順は Context → Decision → Alternatives → Consequences**: MADR は Considered Options を Decision の前に置くが、結論ファースト（決定を先に読める）を優先した
- **status 値域**: ADR は `proposed / accepted / deprecated / superseded` の 4 値、その他文書は `draft / active / deprecated` の 3 値に固定。独自キー・独自値の発明を明示的に禁止した
- **`disable-model-invocation: true`**: ファイル書き込みという副作用を持つため、リポジトリの frontmatter 規約（副作用のあるスキルに付与。structure-visualize の前例）に合わせた

## トレードオフの選択

- **採用: メタデータのみ機械可読化のハイブリッド / 却下: 文書全文の JSON・YAML 化**: 全文構造化は横断クエリ・自動チェックには強いが、決定理由・トレードオフの因果的説明力（ADR の本体価値）を失う。会話での検討結果をそのままスキルの 3 原則として明文化した
- **採用: 整形のロスレス原則（移動 OK・削除 NG・文体変換 NG・迷ったら `## 補足` へ退避） / 却下: 構造への完全準拠を優先した積極的な書き換え**: 整形で内容が変わると既存文書への適用が怖くなり使われなくなる。構造の綺麗さより情報保全を優先
- **採用: 該当内容が無い章は見出しごと省略可 / 却下: 全章必須（空でも見出しを置く）**: 空見出しの強制は TODO 汚染を生む。欠落検出は「あるべき章が無い」ことの目視・grep で足りる

## テストと検証

- `mise exec node -- npx skills add ./ --list` で検出確認（21 skills、tech-doc-structuring を含む）
- **整形モードのサブエージェントテスト**: frontmatter なし・独自見出し（経緯 / 結論 / 却下した案 / 備考）・本文埋め込みメタデータ（Status 行・決定日・関連）を持つくずれた ADR サンプルを、新規コンテキストのエージェントに SKILL.md だけを頼りに処理させた。結果: frontmatter 抽出と値正規化（承認済み → `accepted`）・見出しマッピング・「備考」の `## 補足` 退避・散文の逐語維持、いずれも期待どおり
- テストエージェントが指摘した裁量の割れる 2 点を規則へ反映した: ①補足へ退避する節は元見出しを 1 レベル降格して保持（H2 → H3）②整形時の H1 番号はファイル名に既存番号がある場合のみ補完し、新規採番はしない
- writing-skills（superpowers）の完全な RED-GREEN-REFACTOR（baseline 比較・複数プレッシャーシナリオ）は縮約した。理由: 本スキルはフォーマット定義が主体の reference 型で、スキル不在時の失敗（フォーマットが毎回ばらつく）は自明のため、application シナリオ 1 本（GREEN）+ 指摘反映（REFACTOR）に留めた。より厳密な反復検証が必要になったら `/empirical-prompt-tuning` で追加実施できる

## ユーザーが把握しておくべきこと

- 新規作成モードは会話・Issue・diff から内容を収集するが、**事実の創作はしない**（不明項目は `TODO: 未確定` として残す）
- ADR ディレクトリは `docs/adr/` → `docs/adrs/` → `docs/decisions/` → `adr/` の順で自動検出し、既存の規約（ファイル名形式・見出し言語）がスキル標準と異なる場合は既存規約を優先する
- supersede 関係は双方向更新（新 ADR の `supersedes` + 旧 ADR の `status: superseded` / `superseded_by`）をスキルが担う
