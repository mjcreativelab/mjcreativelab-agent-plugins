# tech-doc-structuring

ADR（Architecture Decision Record）や設計書・仕様書・Runbook・ポストモーテムなどの技術ドキュメントを、「YAML frontmatter（メタデータ）+ 固定見出し（章構成）+ 自然言語の散文（本文）」のハイブリッド構造で新規作成・整形するスキル。

## 設計思想

技術文書を機械可読にしたい（横断検索・フィルタ・欠落チェック）というニーズに対し、文書全体を JSON / YAML で書くと「なぜその決定に至ったか」という因果・トレードオフの説明力が失われる。そこで役割を層で分割する:

| 層 | 目的 | 形式 |
|---|---|---|
| メタデータ（status・date・tags・文書間リンク） | 機械可読（検索・フィルタ・自動チェック） | YAML frontmatter |
| 章構成（必須項目の欠落検出） | テンプレートによる構造の強制 | 文書タイプ別の固定見出し |
| 理由・因果・トレードオフ | 人間への説明力 | 自然言語の散文 |

## 使用例

```
# 会話中の決定を ADR 化
/tech-doc-structuring 会話で決めた DB 移行方針を ADR にして

# 決定に至る経緯（いつ・誰と・どのようなやり取りか）も含めて ADR 化
/tech-doc-structuring この議論を経緯込みで ADR にして

# 既存文書の整形（frontmatter 付与・見出し正規化。本文はロスレス）
/tech-doc-structuring docs/adr/0003-cache-strategy.md

# タイプ指定で新規作成
/tech-doc-structuring 決済サービスの設計 --type design-doc

# ディレクトリ一括整形（処理対象の確認あり）
/tech-doc-structuring docs/adr/
```

## モード

- **新規作成**: 会話・引数の説明から内容を集め、テンプレートに沿って生成する。ADR は既存ディレクトリ・採番規約を自動検出し、supersede 関係を双方向に維持する。決定に至る経緯（いつ・誰と誰が・どのようなやり取りか）は `Deliberation` 節に時系列で記録し、長大な場合は別文書 `NNNN-<スラグ>-deliberation.md` へ切り出して `related` で相互リンクする（ADR 本体を高頻度読み込みに耐える分量に保つ）
- **整形**: 既存文書をロスレスで正規化する。本文中のメタデータ（Status 行・日付行など）を frontmatter へ移動し、見出しを標準セットへマッピングする。本文の散文は変更しない

## 対応文書タイプ

`adr` / `design-doc` / `spec` / `runbook` / `postmortem`（それ以外は frontmatter 付与のみの軽量整形）

## 前提条件

- 特になし（git リポジトリであることも不要。整形時の日付補完に git 履歴があると精度が上がる程度）
- 設計内容そのものの考案・レビューは対象外（`/software-architect`・`/code-reviewer` を使う）
