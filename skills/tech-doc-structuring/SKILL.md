---
name: tech-doc-structuring
description: >
  ADR（Architecture Decision Record）や設計書・仕様書・Runbook・ポストモーテムなどの技術ドキュメントを、
  「YAML frontmatter（メタデータ）+ 固定見出し（章構成）+ 自然言語の散文（本文）」のハイブリッド構造で
  新規作成・整形する。メタデータだけを機械可読にして横断検索・フィルタに使い、
  決定理由・トレードオフの散文は JSON 等の構造化言語へ潰さない。
  設計内容そのものの考案は software-architect が担当（本スキルは文書のフォーマットと整理を担う）。
  「ADR を書いて」「この決定を ADR に記録して」「ドキュメントを整形してメタデータを付けて」
  「仕様書を構造化して」「/tech-doc-structuring」で起動する。
argument-hint: "[対象パス | 内容の説明] [--type adr|design-doc|spec|runbook|postmortem]"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Write, Edit, AskUserQuestion
---

# Tech Doc Structuring

ADR をはじめとする技術ドキュメントを、次の 3 原則に基づくハイブリッド構造で生成・整形する。文書を機械可読にしたいが全文の JSON / YAML 化は説明力を壊す — その中間解を標準形として自動化するスキル。

## 3 原則（このスキルの核）

1. **メタデータは YAML frontmatter** — status・date・tags・文書間リンクなど、横断検索・フィルタ・自動チェックに使う情報だけを機械可読にする
2. **章構成は文書タイプ別の固定見出し** — 構造の強制は見出しテンプレートで行う。必須章の欠落が「見出しの欠落」として目視・grep で検出できる
3. **本文は自然言語の散文** — 決定の理由・因果・トレードオフ（検討したが却下した案と却下理由）は文章のまま書く。キーバリューや箇条書きへ機械的に圧縮しない

してはいけないこと: 文書全文の JSON / YAML / 表形式化、本文散文の箇条書きへの一括変換、「なぜ」の接続（〜のため・〜を優先して）を落とす要約。

## 引数の解析

`$ARGUMENTS` を以下のルールで解析する:

- `--type <値>` がある場合 → 文書タイプ（`adr` / `design-doc` / `spec` / `runbook` / `postmortem`）として保持する。ない場合は内容・ファイル名から自動判定する（判定表: [references/doc-types.md](references/doc-types.md)）
- 残りのトークンのうち存在するファイル / ディレクトリのパス → **整形モード**の対象（ディレクトリは直下の `.md` を対象）
- パス以外のテキスト → **新規作成モード**の内容説明
- 引数なし → 直近の会話に文書化すべき決定・設計があればそれを対象に新規作成する。なければ AskUserQuestion で対象を確認する（使えないエージェントではテキストで確認する。以降の AskUserQuestion も同様）

## 手順

### 1. モード・タイプの確定とゲート表示

対象と文書タイプを確定し、作業前に以下のブロックを 1 回表示する:

```
モード: <新規作成 / 整形>
文書タイプ: <adr / design-doc / spec / runbook / postmortem / その他>
対象: <生成先パス or 整形対象パス>
```

- 整形モードで対象が複数ファイルの場合は一覧を提示し、処理対象をユーザーに確認してから進める
- 日付は `TZ=Asia/Tokyo date +%Y-%m-%d` で取得する（JST）

### 2A. 新規作成モード

1. **内容の収集**: 会話・引数の説明・参照された Issue / diff から「決定（または文書の主題）・背景・検討した代替案・影響」を洗い出す。不足があれば AskUserQuestion で確認する。確認手段がない環境では、不明項目を `TODO: 未確定` として本文に明記した上で生成する（事実を創作して埋めない）
2. **配置先の決定**（ADR の場合）: `docs/adr/`・`docs/adrs/`・`docs/decisions/`・`adr/` の順で既存ディレクトリを Glob で探す。見つかった場所の既存規約（ファイル名形式・見出し言語）が本スキルの標準と異なる場合は既存規約を優先する。どれも無ければ `docs/adr/` の新設を AskUserQuestion で確認する
   - ADR 以外は既存の類似文書と同じディレクトリ（無ければ `docs/` 配下）に置き、生成前にパスを提示する
3. **採番**（ADR の場合）: 既存ファイルの最大番号 + 1（`NNNN` 4 桁ゼロ埋め、ファイル名 `NNNN-<英語kebab-caseスラグ>.md`）。書き込み直前に再度 Glob で番号の重複がないことを確認する
4. **生成**: テンプレート（ADR: [assets/adr-template.md](assets/adr-template.md) / その他: [assets/tech-doc-template.md](assets/tech-doc-template.md)）と文書タイプ別見出しセット（references/doc-types.md）に従って作成する
5. **リンクの整合**（ADR の場合）: 旧 ADR を置き換える決定なら、新 ADR の `supersedes` に旧 ADR を記載し、旧 ADR 側も `status: superseded` と `superseded_by` を更新する（双方向を同時に維持する）

### 2B. 整形モード

既存文書を 3 原則の構造へ **ロスレスで** 正規化する。

1. **全文 Read**: 対象を読まずに変更しない。frontmatter の有無・既存見出し・本文中に埋まったメタデータ（`Status: Accepted` 行・日付行など）を把握する
2. **タイプ判定**: `--type` 指定 > frontmatter の `type` > 内容からの判定（references/doc-types.md の判定表）
3. **変換**（詳細規則: [references/restructuring-rules.md](references/restructuring-rules.md)）:
   - 本文中のメタデータ → frontmatter へ**移動**する（移動であって削除ではない。本文側の重複行のみ除去する）
   - 既存見出し → 標準見出しへマッピングする（例: 「なぜ」「Motivation」→ Context）。どの標準見出しにも対応しない節は `## 補足` の下へ原文のまま残す
   - 本文の散文はそのまま維持する。文体変換（散文⇔箇条書き）・要約・削除・追記をしない
4. **書き込み**: 変更箇所を洗い出してから 1 ファイル 1 回の Edit / Write で完結させる
5. **差分要約**: frontmatter へ移動した項目・見出しのマッピング結果・`## 補足` へ退避した節を報告する

### 3. 完了報告

- 生成 / 変更したファイルのパスを表示する
- 新規作成では、埋められなかった項目（TODO のまま残した箇所）を明示する
- 生成物のコミットはしない（コミットするかどうかはユーザーの判断に委ねる）

## frontmatter 標準キー（要約）

| キー | 対象 | 値 |
|---|---|---|
| `type` | 共通 | `adr` / `design-doc` / `spec` / `runbook` / `postmortem` |
| `status` | 共通 | ADR: `proposed` / `accepted` / `deprecated` / `superseded`。その他: `draft` / `active` / `deprecated` |
| `date` | 共通 | 作成日・決定日（JST・`YYYY-MM-DD`） |
| `tags` / `related` | 共通 | 横断検索用タグ・関連文書への相対パス |
| `supersedes` / `superseded_by` | ADR | 置き換え関係（相対パス。双方向に維持する） |

完全な定義（任意キー・値域・記入規則）: [references/frontmatter-keys.md](references/frontmatter-keys.md)

タイトルは frontmatter に持たず **H1 を唯一の正**とする（ADR は `# ADR-NNNN: <タイトル>`。整形時、番号はファイル名に既存の番号がある場合のみ H1 へ補完し、無ければ H1 は原文のままにする — 新規採番は整形の範囲外）。status は frontmatter を唯一の正とし、本文に Status 節を作らない（二重管理を避ける）。

## エラーハンドリング

| ケース | 挙動 |
|---|---|
| 指定パスが存在しない | エラーを表示して終了 |
| 対象が特定できない（引数なし・会話にも決定の言及なし） | AskUserQuestion で対象を確認 |
| ADR ディレクトリが無い | AskUserQuestion で `docs/adr/` 新設を確認 |
| 既存 frontmatter のキーが標準キーと矛盾（`state:` と `status:` の併存など） | ユーザーに確認してからマージ |
| 整形対象が既に標準構造 | 変更せず「整形不要」と報告 |

## やらないこと

- 設計内容そのものの考案・レビュー（→ /software-architect、/code-reviewer）
- 文書全文の構造化言語（JSON / YAML / XML）への変換
- 整形時の内容の要約・削除・追記（構造の正規化のみ。内容の追加は新規作成モードでユーザーの入力に基づいて行う）
- ADR 番号の振り直し・ファイルのリネーム（既存の採番を変えない）
- 生成物の自動コミット
