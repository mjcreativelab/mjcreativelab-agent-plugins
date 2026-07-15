---
name: branch-visualize
description: >
  git ブランチ単位で実装内容を可視化する。対象ブランチとマージ先ブランチの差分を分析し、
  変更モジュール・ライブラリ増減・データ/ドメインモデルと直接の関連範囲を
  Mermaid / D2 / HTML（ノード数で自動選定、--format で明示指定可）の構成図として
  docs/branch-diagrams/ に出力する。--models でモデルの内部構造（クラス図/ER 図・
  メンバー単位の差分マーカー付き）も描ける。対象はブランチ名のほか PR 番号（#123）
  でも指定できる。レビュー準備・作業内容の俯瞰に使う。
  リポジトリ全体のアーキテクチャ図は作らない（変更箇所と直接関連範囲に限定）。
  ユーザーが「ブランチを可視化して」「変更内容を図にして」「/branch-visualize」と言ったら起動する。
argument-hint: "[<branch> | #<pr-number>] [--base <branch>] [--format mermaid|d2|html] [--models]"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Write, AskUserQuestion
---

# Branch Visualize

対象ブランチとマージ先ブランチの差分を「変更箇所 + 直接の関連範囲」に絞った構成図として可視化する。人によるレビューの補助と、作業者自身の変更範囲の俯瞰が目的。リポジトリ全体のアーキテクチャ図は作らない。

## 引数の解析

`$ARGUMENTS` を解析する（トークンはすべて位置不問。該当トークンは除去する）:

- `--format mermaid|d2|html` → `{フォーマット}`。これ以外の値が指定されたら AskUserQuestion で確認する（使えないエージェントではテキストで確認する。以降の AskUserQuestion も同様）。無ければ `{フォーマット}` = auto
- `--base <branch>` → `{比較先}`
- `--models` → `{モデル詳細}` = true（モジュール依存図の代わりにクラス図/ER 図を生成する）
- `#<数字>`（例: `#100`）→ `{PR番号}`。GitHub MCP の `pull_request_read`（method: get）で PR を取得し、head ブランチを `{対象ブランチ}`、base ブランチを `{比較先}` とする（`--base` 指定があればそちらを優先）。MCP 未接続、または PR が存在しない場合はエラーを表示して終了する
- 残りの最初の位置引数 → `{対象ブランチ}`。`{PR番号}` と両方指定された場合は AskUserQuestion でどちらを対象にするか確認する。どちらも無ければ `git rev-parse --abbrev-ref HEAD` の結果

`{比較先}` が未指定の場合、次の順で解決する:

1. GitHub MCP ツールが使えるなら `list_pull_requests`（`head: <対象ブランチ>`, `state: "open"`）で open PR を検索する。1 件 → その PR の base。複数 → AskUserQuestion で選択。0 件または MCP 未接続 → 次へ（エラーにしない）
2. `git symbolic-ref refs/remotes/origin/HEAD` からデフォルトブランチを解決する。失敗したら `main` → `master` の順で存在するもの（`git rev-parse --verify`）を採用する

## 手順

### 1. 対象確定・ゲート表示

- `git rev-parse --git-dir` が失敗する（git リポジトリでない）→ エラーを表示して終了
- `{対象ブランチ}` がローカルにも `origin/` にも存在しない（`git rev-parse --verify <branch>` / `origin/<branch>` とも失敗）→ エラーを表示して終了
- 確定後、以下のブロックを 1 回表示する:

```
対象: <対象ブランチ>
比較先: <比較先ブランチ>
フォーマット: <auto | mermaid | d2 | html>
```

`{PR番号}` 指定時は「対象」行に `（PR #<番号>）` を併記する。

### 2. 差分取得

- `git diff <比較先>...<対象ブランチ> --stat` で変更ファイル一覧・追加/削除行数を取得する
- 差分が空 → 「差分なし」と表示して終了（ファイルは生成しない）
- 変更ファイル数が 50 を超える → `{巨大差分}` = true

### 3. 依存関係の差分抽出

- リポジトリに存在するパッケージマニフェスト（`package.json` / `requirements.txt` / `pyproject.toml` / `go.mod` / `pom.xml` / `build.gradle` / `Cargo.toml` / `Gemfile` 等）それぞれについて `git diff <比較先>...<対象ブランチ> -- <manifest>` を取り、ライブラリの追加・削除・バージョン変更を抽出する
- lock ファイル（`package-lock.json` / `pnpm-lock.yaml` / `poetry.lock` 等）は見ない
- マニフェストの無い言語では、変更ファイル中の import / require の diff から新規ライブラリ使用を拾ってよい

### 4. 変更内容の分析

- **ノード化するのは開発コードとその依存のみ**（モジュール / コンポーネント / データモデル / ライブラリ）。ドキュメント（`*.md` 等）・CI / ビルド設定・画像などの非コード資産はノードにせず、レポートの「その他の変更」節に一覧する（無言で落とさない）
- 変更ファイルを読み、モジュール / コンポーネント / データモデル（エンティティ・DTO・スキーマ・クラス構造）を識別する
- **直接の関連範囲**: 変更箇所の呼び出し元・呼び出し先を Grep で特定し、図の理解に必要なファイルだけ追加で読む。2 ホップ以上は辿らない
- `{巨大差分}` = true の場合: 全ファイルは読まず、ディレクトリ / パッケージ単位でグルーピングして 1 ノードにまとめる。詳細読み込みを省略したファイル数と対象ディレクトリを記録し、レポートに明記する（無言の切り詰めをしない）
- `{モデル詳細}` = true の場合: モジュール依存の分析の代わりに、変更ファイル中のモデル定義（クラス / interface / enum / テーブル定義）を対象として、メンバー（フィールド・メソッド・カラム）単位の差分と、モデル間の関係（継承 / 実装 / 参照 / FK）を diff から抽出する。関連範囲の未変更モデルは名前のみ拾う（メンバーは読まない）

### 5. 構造化

分析結果を次の中間表現に整理する（作業メモ。ファイル保存は不要）:

```
nodes: [{ id, label, type: module|library|model|component,   # {モデル詳細} 時は class|interface|enum|table
          status: added|modified|removed|unchanged,
          members: [{ name, type, status }],                  # {モデル詳細} 時のみ
          detail: { path, description, lines } }]
edges: [{ from, to, type: calls|imports|depends_on,           # {モデル詳細} 時は inherits|implements|composes|references|fk
          label }]                                            # 任意: 関係種別・カルディナリティ（"1..n" 等）
```

- 関連範囲として図に含める未変更要素は `status: unchanged` とする
- ノード数 = nodes の件数（次の手順の自動判定に使う）

### 6. フォーマット判定

`{フォーマット}` が明示指定ならそれに従う。auto の場合:

| 条件 | フォーマット |
|---|---|
| ノード数 ≤ 15 | mermaid（GitHub 上でネイティブ表示できる） |
| ノード数 16〜40、または階層・サブグラフ構造が複雑 | d2 |
| ノード数 > 40 | html（クリック詳細・ズーム・パンで探索できる） |

### 7. 図とレポートの生成

- 出力先 `docs/branch-diagrams/` が無ければ AskUserQuestion で作成可否を確認する（拒否されたら出力先ディレクトリを尋ねる）
- ファイル名: `<branch-slug>-<date>`。`<branch-slug>` はブランチ名の `/` を `-` に置換したもの、`<date>` は `TZ=Asia/Tokyo date +%Y-%m-%d`
- 色・雛形・生成方法は [references/format-guide.md](references/format-guide.md) に従う。`{モデル詳細}` = true の場合は同ガイドの「モデル詳細図（--models）」節に従い、クラス図 / ER 図の種別をモデルの出自で判定する（混在時は併記）:
  - **mermaid** → レポート本文にコードブロックとして埋め込む
  - **d2** → `<branch-slug>-<date>.d2` を生成する。`command -v d2` が成功したら `d2 <file>.d2 <file>.svg` で SVG も生成する。無ければソースのみ保存し、レポートに「ローカルで `d2` CLI を実行すれば図化できる」旨を書く（外部レンダリング API は使わない）
  - **html** → [assets/diagram-template.html](assets/diagram-template.html) を読み、`__TITLE__` と `__GRAPH_JSON__` を置換して `<branch-slug>-<date>.html` を生成する（GRAPH JSON スキーマ・エスケープ規則は format-guide.md 参照。配色・レイアウトはテンプレートが内蔵しており生成側の座標計算は不要）
- レポート本体 `<branch-slug>-<date>.md` を以下の構成で生成する:

```markdown
# ブランチ可視化: <対象ブランチ> vs <比較先ブランチ>

生成日: YYYY-MM-DD (JST)

## 差分サマリ
- 変更ファイル数 / 追加行数 / 削除行数

## 凡例
🟢 追加 / 🟡 変更 / 🔴 削除（破線枠）/ ⚪ 関連（未変更）
（{モデル詳細} = true のときは追記: メンバー `[+]` 追加 / `[-]` 削除 / `[*]` 変更）

## 構成図
（mermaid はここに埋め込み。d2 / html は相対リンク + 図の要点 2〜3 文）

## ライブラリの増減
| ライブラリ | 変更 | 備考 |
|---|---|---|
（増減が無ければ「変更なし」と 1 行書く）

## データ / ドメインモデル
| モデル | 状態 | 概要 |
|---|---|---|
（該当が無ければ「該当なし」と 1 行書く）

## その他の変更（図の対象外）
（ドキュメント・CI / ビルド設定など非コードの変更ファイルを 1 行ずつ。該当が無ければ節ごと省略）

## 省略した範囲
（{巨大差分} = true のときのみ: 省略したファイル数・対象ディレクトリ）
```

### 8. 完了報告

- 生成したファイルのパス一覧を表示する
- 図の要点（主要な変更モジュールとその関係）を 2〜3 文で添える
- 生成物のコミットはしない（コミットするかどうかはユーザーの判断に委ねる）

## エラーハンドリング

| ケース | 挙動 |
|---|---|
| git リポジトリでない / 対象ブランチが存在しない | エラーを表示して終了 |
| 比較先との diff が空 | 「差分なし」と表示して終了（ファイルを生成しない） |
| `--base` 省略時に open PR が複数 | AskUserQuestion で対象を選ばせる |
| GitHub MCP 未接続（`--base` 省略時の自動解決） | PR 解決をスキップしデフォルトブランチ解決へ（エラーにしない） |
| `#<番号>` 指定だが GitHub MCP 未接続 / PR が存在しない | エラーを表示して終了 |
| `#<番号>` とブランチ名の両方が指定された | AskUserQuestion でどちらを対象にするか確認する |
| `d2` CLI が無い（d2 選定時） | `.d2` ソースのみ保存し、レポートに案内を書く |
| `docs/branch-diagrams/` が無い | AskUserQuestion で作成可否を確認する |

## やらないこと

- リポジトリ全体のアーキテクチャ図（変更箇所と直接関連範囲に限定する）
- 生成物の自動コミット・PR への自動添付
- コード内容の外部送信（D2 の SVG 化はローカル CLI のみ。kroki.io 等の外部レンダリング API を使わない）
