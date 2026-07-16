# structure-visualize スキル設計スペック

作成日: 2026-07-16 (JST)
ステータス: ユーザー承認済み設計（実装前）

## 背景・目的

branch-visualize は「git ブランチ差分」を構成図として可視化するスキルだが、差分に紐づかない
「指定された内容の構造」（インフラ設計、ER 図、コンポーネント設計など開発に関する静的構造）を
可視化する手段がない。branch-visualize の出力体験（自己完結 HTML・ダークテーマ・詳細パネル・
ズーム/パン）をベースに、構造スナップショットの可視化スキル `structure-visualize` を新設する。

## 決定事項（ユーザー確認済み）

| 論点 | 決定 |
|---|---|
| 入力ソース | 会話 + ファイル（設計ドキュメント）+ コード解析（IaC / スキーマ / ソース）の 3 系統を混在可 |
| ノードの色分け | カテゴリ別配色（diff 状態配色は廃止） |
| グルーピング表現 | カテゴリ色 + レーン帯（レイアウト拡張）。group なし入力は従来の依存フロー配置 |
| 出力ファイル | HTML 単体（md レポートは生成しない） |
| スキル名 / 出力先 | `structure-visualize` / `docs/structure-diagrams/` |

## スコープ

### 対象

- 静的な開発構造の可視化: インフラ構成、ER 図、コンポーネント設計、クラス構成、モジュール依存、その他ノード + エッジで表現できる構造
- 入力 3 系統:
  1. 会話コンテキストで説明された設計
  2. 指定された設計ドキュメント（md 等）
  3. リポジトリ内実体の解析（Terraform 等 IaC / migration・ORM スキーマ / ソースコード）

### 対象外（やらないこと）

- 振る舞い・時系列の図（シーケンス図・フローチャート・状態遷移図）— 静的構造のみ
- git 差分の可視化（→ `/branch-visualize`）
- 指定スコープ外の無差別リポジトリスキャン（広大な対象は集約 + 明記）
- 生成物の自動コミット
- 外部レンダリング API・CDN への依存（自己完結 HTML・オフライン動作）
- mermaid / d2 出力（HTML のみ。フォーマット自動選定は持たない）

## ディレクトリ構成

```
skills/structure-visualize/
├── SKILL.md                       # メイン指示（500 行以下）
├── README.md                      # 説明・使用例・前提条件（npx install で配布される）
├── assets/
│   └── diagram-template.html      # branch-visualize テンプレートの fork（カテゴリ配色 + レーン対応）
└── references/
    └── html-guide.md              # GRAPH JSON スキーマ・図種別の作図指針・エスケープ規則
```

## 起動仕様

### frontmatter

```yaml
name: structure-visualize
description: >
  指定された開発構造（インフラ構成、ER 図、コンポーネント設計、クラス構成、モジュール依存など）を
  自己完結 HTML の構成図として docs/structure-diagrams/ に出力する。入力は会話で説明された設計・
  設計ドキュメント・リポジトリ内の実体（IaC / DB スキーマ / ソースコード）のいずれでもよい。
  カテゴリ別配色とレーン帯（レイヤー・所属）、ノード詳細パネル・ズーム/パン付き。
  git ブランチ差分の可視化は /branch-visualize（本スキルは指定内容のスナップショット構造を描く）。
  ユーザーが「構造を可視化して」「構成図にして」「/structure-visualize」と言ったら起動する。
argument-hint: "[対象の説明 | ファイル/ディレクトリパス...]"
disable-model-invocation: true
allowed-tools: Read, Bash, Grep, Glob, Write, AskUserQuestion
```

- `disable-model-invocation: true`: docs/ への書き込みという副作用があるため（branch-visualize と同基準）
- git リポジトリであることを**要求しない**（branch-visualize との差異）
- AskUserQuestion が使えないエージェントではテキストで確認する（base と同じ注記を SKILL.md に入れる）

### 引数

`$ARGUMENTS` 全体を「可視化対象の指定」として解釈する（自由文・パス混在可）。フラグは持たない。

- 引数なし → 直近の会話コンテキストから対象を推定。推定できなければ AskUserQuestion
- パスを含む → 存在確認（無ければエラー表示して終了）

## 手順（5 ステップ）

### 1. 対象確定・ゲート表示

- 入力種別（会話 / ドキュメント / コード解析。組み合わせ可）と図種
  （infra / er / component / class / module / 汎用）を判定する
- 確定後、以下のブロックを 1 回表示する:

```
対象: <説明 or パス>
入力種別: <会話 / ドキュメント / コード解析>
図種: <インフラ構成 / ER / コンポーネント / クラス / モジュール依存 / 汎用>
```

### 2. 構造の抽出

- 会話: 会話中の設計記述から要素と関係を抽出する
- ドキュメント: 指定ファイルを読み、要素と関係を抽出する
- コード解析（図種に応じた読み方）:
  - IaC: resource / module ブロックと参照関係
  - DB: migration / DDL / ORM スキーマからテーブル・カラム・FK
  - コンポーネント / クラス: 定義 + import / 継承 / 実装 / 参照
- Grep での関係追跡は指定スコープ内に限定する（スコープ外へ 2 ホップ以上辿らない）

### 3. 構造化（中間表現）

分析結果を GRAPH JSON（後述）に整理する。

- ノード数 80 超が見込まれる場合はディレクトリ / リソース種別単位に集約し、
  集約・省略した内容を完了報告に明記する（無言の切り詰めをしない）
- members（カラム・フィールド・属性）は 1 ノード 10 行を目安とし、超過分は
  「…他 N 件」の行を置く（無言で切り詰めない）

### 4. HTML 生成

- 出力先 `docs/structure-diagrams/` が無ければ AskUserQuestion で作成可否を確認する
  （拒否されたら出力先ディレクトリを尋ねる）
- ファイル名: `<図種プレフィックス>-<対象スラグ>-<日付>.html`
  （図種プレフィックス: `infra` / `er` / `component` / `class` / `module` / `structure`〔汎用〕。
  例: `infra-payment-system-2026-07-16.html`。日付は `TZ=Asia/Tokyo date +%Y-%m-%d`）
- `assets/diagram-template.html` を読み、`__TITLE__` / `__GRAPH_JSON__` を置換して生成する
- エスケープ: JSON 文字列中に `</script>` 相当の並びを出現させない（`</` → `<\/`）

### 5. 完了報告

- 生成ファイルのパスを表示する
- 図の要点（主要な要素と関係）を 2〜3 文で添える
- 集約・省略があれば明記する
- 生成物のコミットはしない

## GRAPH JSON スキーマ（branch-visualize からの一般化）

```json
{
  "title": "決済システム インフラ構成",
  "subtitle": "入力: terraform/",
  "layout": "lanes",
  "groups": [
    { "id": "net", "label": "ネットワーク" },
    { "id": "app", "label": "コンピュート" },
    { "id": "data", "label": "データ" }
  ],
  "nodes": [
    {
      "id": "n1", "label": "payment-api", "type": "ECS Service", "group": "app",
      "members": [ { "name": "cpu", "type": "512" } ],
      "detail": { "source": "terraform/ecs.tf", "description": "決済 API 本体" }
    }
  ],
  "edges": [ { "from": "n1", "to": "n2", "label": "SQL" } ]
}
```

### base からの意味論変更

| 項目 | branch-visualize | structure-visualize |
|---|---|---|
| `status` | added/modified/removed/unchanged（必須） | **廃止** |
| `type` | 8 種の列挙 | **自由文字列**（インフラのリソース種を列挙しきれないため。ノードカードにそのまま表示） |
| `group` | なし | カテゴリ / レイヤー / 所属。**配色とレーンを駆動**（任意） |
| `groups` | なし | レーン・凡例の表示順を制御する配列（任意。省略時は nodes の初出順） |
| `summary` | diff 統計（files/insertions/deletions） | **廃止**。ノード / エッジ数はテンプレートが自動計算。`subtitle`（自由文・任意）を併記 |
| `members[].status` | あり（差分マーカー） | **廃止**。`name` / `type` のみ（PK・FK 等は type 文字列に含める。例: `{ "name": "id", "type": "uuid PK" }`） |
| `detail` | path / description / lines | **source**（出典: ファイルパス or 「会話」）/ description |
| `layout` | なし（常に依存フロー） | `"lanes"` \| `"flow"`（任意。省略時: group を持つノードがあれば lanes、なければ flow） |
| `edges[].type` | calls/imports/depends_on | **廃止**（`label` に統合。関係種別・カルディナリティを自由記述） |

## テンプレート改変仕様（fork 方針）

branch-visualize の `assets/diagram-template.html`（Sugiyama 系レイアウト・hover ハイライト・
クリック詳細パネル・ズーム/パン内蔵・自己完結）を fork し、以下を変更する。単一ファイル・
外部依存なしを維持し、目安 700 行以下に収める。

### 1. カテゴリ配色（8 色パレット）

ダークネイビー背景（`#0b0f16`）と「暗い塗り + 低輝度の色付き枠 + 明るめ文字」のトーンを維持し、
group の並び順にパレットを自動割当する（8 超は循環）。group なしノードは中立色。

| # | 系統 | 塗り | 枠 | 文字 |
|---|---|---|---|---|
| 1 | blue | `#101a2b` | `#4d8edb` | `#9ecbff` |
| 2 | green | `#12261c` | `#3fb950` | `#7ee2a8` |
| 3 | amber | `#2a2012` | `#d29922` | `#e8c06d` |
| 4 | purple | `#1f1630` | `#a371f7` | `#d2b6ff` |
| 5 | cyan | `#0e2429` | `#39c5cf` | `#9ae8ef` |
| 6 | pink | `#2b1420` | `#db61a2` | `#ffadd6` |
| 7 | orange | `#2b1a10` | `#e8734a` | `#ffb491` |
| 8 | teal | `#10261f` | `#2ea28d` | `#8fe3c9` |
| - | 中立（group なし） | `#161b26` | `#3d4654` | `#9aa7b8` |

（実装時に視認性を実機確認のうえ微調整可）

### 2. 凡例

固定 4 状態の凡例を廃止し、groups から動的生成する（色チップ + グループ名）。
group が 1 つも無い場合は凡例を表示しない。

### 3. レーンレイアウト（layout = "lanes"）

- **X（カラム）**: flow モードと同じ最長パス法レイヤリングを流用（循環除去も流用）
- **レーン順**: `groups` 配列順（省略時は nodes 初出順）。group なしノードは末尾の「その他」レーン
- **セル内配置**: (レーン × カラム) セル内で縦積み。並びはバリセンタ法
  （直接隣接ノードの y 平均）で数スイープ
- **レーン高**: `laneHeight[g] = max over columns of セル積み上げ高`。セル内容はレーン内で中央寄せ
- **レーン描画**: コンテンツ全幅の半透明帯 + 左端にグループ名ラベル（グループ色のアクセント）+ 区切り線
- **エッジ**: lanes モードではダミーノード（長エッジの中継点）を作らず、ポート間を直接ベジェで結ぶ
  - 既知のトレードオフ: 長いエッジがノードと交差しうる（hover ハイライトで緩和）。v1 で許容する
- **flow モード**: 既存の Sugiyama 配置（ダミーノード含む）をそのまま使用。
  group があっても `layout: "flow"` 指定時は配色・凡例のみ group 準拠で配置は従来型

### 4. ヘッダー・詳細パネル

- ヘッダー: `title` + 「ノード N / エッジ M」（テンプレートが自動計算）+ `subtitle`（任意）
- 詳細パネル: 種別（type そのまま）/ グループ / 出典（detail.source）/ 概要（detail.description）+ members 一覧
- ノードカード: type ラベル（自由文字列・トランケート）+ label + members 行（差分プレフィックスなしの `name: type` 表示）

### 5. 維持する機能

ズーム / パン、hover での接続エッジ・隣接ノードハイライト、クリック詳細パネル、fit-to-view、
エッジラベル、ラベルのトランケート、`prefers-reduced-motion` 対応、
存在しないノード ID 参照・自己参照エッジの除外、循環依存の自動処理。

## references/html-guide.md の内容

- GRAPH JSON スキーマ全定義とエスケープ規則（`</` → `<\/`）
- `layout` の選択基準: レイヤー・所属が主題（インフラの層、レイヤードアーキテクチャ）→ lanes /
  依存の流れ・ER が主題 → flow（group による配色は両モード共通）
- 図種別の作図指針:
  - **インフラ構成**: group = 層（ネットワーク / コンピュート / データ等）または VPC・サブネット、
    members = 主要属性（CIDR・インスタンスサイズ等）、edges = 通信 / 依存
  - **ER 図**: type = table、members = カラム（PK / FK / 型を表記）、edges = FK（label にカルディナリティ `1..n` 等）
  - **コンポーネント / クラス**: group = レイヤー・ドメイン、edges = 依存 / 継承 / 実装 / 参照（label で種別）
- members 上限（10 行目安 + 「…他 N 件」）とノード数集約指針（80 目安）

## エラーハンドリング

| ケース | 挙動 |
|---|---|
| 指定パスが存在しない | エラーを表示して終了 |
| 対象が特定できない（引数なし・会話にも設計言及なし） | AskUserQuestion で対象を確認 |
| `docs/structure-diagrams/` が無い | AskUserQuestion で作成可否を確認（拒否時は出力先を尋ねる） |
| 対象が広大（ノード数 80 超見込み） | 集約して描画し、完了報告に集約内容を明記 |
| git リポジトリでない | エラーにしない（本スキルは git 不要） |

## リポジトリ更新一覧

1. 新規: `skills/structure-visualize/`（SKILL.md / README.md / assets / references）
2. `CLAUDE.md` リポジトリ構造セクションに 1 行追記（branch-visualize の下）
3. `CLAUDE.md` 「スキル改修時の注意」にテンプレート系譜の相互確認を 1 行追記（下記）
4. ルート `README.md` のスキル一覧表に追記
5. 実装ノート: `docs/implementation-notes/2026-07-16-structure-visualize-skill.md`（実装時の判断を記録し同 PR に含める）

## 二重化・同期方針

- HTML テンプレートは branch-visualize からの**意図的な fork**（npx 配布ではスキル間ファイル参照が
  できないため独立コピーが必須）
- 配色（diff 状態 → カテゴリ）とレーンで意味論が分岐するため**逐語同期の義務は設けない**
- ただしレイアウトエンジン（レイヤリング・交差削減・ポート分散・ズーム/パン）は同系譜のため、
  **片方でレイアウト系の不具合を修正したらもう片方にも該当するか確認する**
  （CLAUDE.md「スキル改修時の注意」に 1 行追記する）

## 検証方法（実装完了の定義）

1. `npx skills add ./ --list` に `structure-visualize` が検出される
2. frontmatter 確認: `head -5 skills/structure-visualize/SKILL.md`
3. サンプル GRAPH JSON 3 種でテンプレートをレンダリングし確認する:
   - インフラ構成（groups + lanes・members に属性）
   - ER 図（flow・members にカラム・エッジラベルにカルディナリティ）
   - コンポーネント設計（lanes・group = レイヤー）
   - 確認内容: `<script>` 部を抽出して `mise exec node -- node --check` で構文確認 +
     実ブラウザ表示（レーン帯・凡例・配色・詳細パネル・ズーム/パン・hover）
4. group なし JSON で flow レイアウト（従来配置）にフォールバックすることを確認する
