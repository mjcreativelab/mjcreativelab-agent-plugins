# frontmatter 標準キー定義

生成・整形で使う YAML frontmatter キーの定義。ここにあるキーだけを使い、独自キーを発明しない（表現しきれない情報は `tags` / `related` / 本文で扱う）。キー名・値は小文字・kebab-case。

## 共通キー（全文書タイプ）

| キー | 必須 | 型 | 値域・形式 | 説明 |
|---|---|---|---|---|
| `type` | ✓ | string | `adr` / `design-doc` / `spec` / `runbook` / `postmortem` | 文書タイプ。見出しセットの選択基準。5 タイプに該当しない文書では省略する |
| `status` | ✓ | string | 下表 | 文書の状態。**本文に Status 節は作らない**（frontmatter が唯一の正） |
| `date` | ✓ | string | `YYYY-MM-DD`（JST） | 作成日（ADR は決定日） |
| `updated` | - | string | `YYYY-MM-DD`（JST） | 内容を実質更新した日。構造の整形だけでは更新しない |
| `tags` | - | list | 小文字 kebab-case | 横断検索・フィルタ用 |
| `related` | - | list | 相対パス | 関連文書。関係の理由が重要なら本文でも言及する |
| `owners` | - | list | 名前 or チーム名 | 文書の保守責任者（ADR では代わりに `deciders` を使う） |

## status の値域

| type | 値 | 意味 |
|---|---|---|
| adr | `proposed` | 提案中（未合意） |
| adr | `accepted` | 合意済み・有効 |
| adr | `deprecated` | 非推奨になった（置き換え先の ADR は無い） |
| adr | `superseded` | 新しい ADR に置き換えられた（`superseded_by` 必須） |
| その他 | `draft` | 執筆中・レビュー前 |
| その他 | `active` | 有効（現行の設計・仕様・手順） |
| その他 | `deprecated` | 非推奨・過去の記録 |

## ADR 専用キー

| キー | 必須 | 型 | 説明 |
|---|---|---|---|
| `deciders` | - | list | 決定に関与した人・ロール |
| `supersedes` | - | list | この ADR が置き換える旧 ADR への相対パス |
| `superseded_by` | - | string \| null | この ADR を置き換えた新 ADR への相対パス。`status: superseded` のとき必須 |

## 記入規則

- タイトルは frontmatter に持たない。**H1 が唯一の正**（二重管理は片方の陳腐化を招く）
- リンク（`related` / `supersedes` / `superseded_by`）はその文書からの相対パスで書く
- supersede 関係は必ず双方向に維持する（新 ADR の `supersedes` と、旧 ADR の `superseded_by` + `status: superseded` を同時に更新する）
- frontmatter に置くのは「機械可読にする価値がある情報」だけ。理由・経緯を frontmatter に書き始めたら、それは本文に書くべき内容
