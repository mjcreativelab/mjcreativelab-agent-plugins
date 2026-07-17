# HTML 構成図 生成ガイド

structure-visualize の手順 3（構造化）・手順 4（HTML 生成）から参照される。GRAPH JSON のスキーマと、図種別の作図指針を定義する。

## 生成方法

[assets/diagram-template.html](../assets/diagram-template.html) を読み、次の 2 つのプレースホルダを置換して出力する:

| プレースホルダ | 置換内容 |
|---|---|
| `__TITLE__` | 図のタイトル（`<title>` タグ内の 1 箇所） |
| `__GRAPH_JSON__` | 下記スキーマの JSON（`<script>` 内の 1 箇所） |

テンプレートはダークテーマ・カテゴリ配色・エリア枠・レイアウトエンジンを内蔵している。**生成側は nodes / edges / groups を渡すだけでよく、座標・色の計算は不要**。

- **エスケープ**: JSON 文字列中に `</script>` 相当の並びを出現させない（`</` は `<\/` にエスケープする）
- タイトル（`__TITLE__` 置換文字列）にも `</` を含めない（`<title>` タグ内に展開されるため）
- 存在しないノード ID を参照するエッジ・自己参照エッジは描画されない（テンプレート側で除外）。循環依存はあってもよい（グループ内・グループ間とも自動処理される）

## GRAPH JSON スキーマ

```json
{
  "title": "決済システム インフラ構成",
  "subtitle": "入力: terraform/",
  "layout": "areas",
  "groups": [
    { "id": "net", "label": "ネットワーク" },
    { "id": "app", "label": "コンピュート" }
  ],
  "nodes": [
    {
      "id": "n1", "label": "payment-api", "type": "ECS Service", "group": "app",
      "members": [ { "name": "cpu", "type": "512" } ],
      "detail": { "source": "terraform/ecs.tf", "description": "決済 API 本体" }
    },
    {
      "id": "n2", "label": "payments-db", "type": "RDS",
      "detail": { "source": "terraform/rds.tf", "description": "決済 DB" }
    }
  ],
  "edges": [ { "from": "n1", "to": "n2", "label": "SQL" } ]
}
```

| フィールド | 必須 | 説明 |
|---|---|---|
| `title` | ✓ | ヘッダーとタブタイトルに表示 |
| `subtitle` | - | ヘッダーのノード / エッジ数（自動計算）の後に併記する自由文（入力元など） |
| `layout` | - | `"areas"` \| `"flow"`。省略時: group を持つノードがあれば areas、なければ flow |
| `groups[]` | - | `{ id, label }`。エリア・凡例の表示順を制御。省略時は nodes の初出順。ノードを持たないエントリは無視される |
| `nodes[].id` | ✓ | 一意な ID（英数字とアンダースコア推奨） |
| `nodes[].label` | ✓ | 表示名（ノードカードは全角 12 文字相当で省略表示。詳細はパネルで見える） |
| `nodes[].type` | - | 自由文字列の種別（例: `ECS Service` / `table` / `component`）。カード上部の小ラベルとパネルに表示 |
| `nodes[].group` | - | 所属グループ ID。配色とエリア枠を駆動。無しは中立色・エリア外配置 |
| `nodes[].members[]` | - | `{ name, type? }`。カラム・フィールド・属性の行。指定するとノードが可変高になる |
| `nodes[].detail` | - | `{ source?, description? }`。出典（ファイルパスや「会話」）と概要。クリックパネルに表示 |
| `edges[]` | - | `{ from, to, label?, cardinality? }`。from が to に依存する向き（レイアウトは from が左）。label は関係種別（`implements` / `uses` 等） |
| `edges[].cardinality` | - | ER 図の多重度。`"<from>..<to>"` 形式で各端点 ∈ `1` / `n` / `0..1` / `0..n`（例: `"n..1"`）。両端に IE 記法（鳥の足）の端点シンボルを描画（`1`=縦棒 / `n`=鳥の足 / `0` 含みは丸付き）。矢じりの代わりに表示され、`label` と併用可。省略・不正値は従来の矢じり描画 |

## layout の選択基準

| 主題 | layout |
|---|---|
| 所属・境界（クラウドプロバイダ / 外部システム連携 / VPC / レイヤードアーキテクチャ） | `areas`（グループごとの囲み枠） |
| 依存の流れ・ER のリレーション | `flow`（group があれば配色のみ group 準拠） |

グループが 1 つしか無い場合（全ノード同一所属）は枠の意味が無いため `flow` を選ぶ。エリア枠が有効なのは 2〜8 グループ程度。

## 図種別の作図指針

### インフラ構成

- `group` = **最も伝えたい大きな括り**（プロバイダ / 環境 / 層 / VPC など）。group は 1 階層のみ。
  多段構造（VPC ⊃ subnet ⊃ EC2）は上位を group にし、下位区分は `type`（例: `private subnet / EC2`）や label で表現する
- `members` = 主要属性（CIDR・インスタンスサイズ・メモリ等）
- `edges` = 通信 / 依存。label にプロトコルや経路の説明

### ER 図

- `type` = `table`、`members` = カラム（`name` = カラム名、`type` = `uuid PK` / `varchar(255)` / `uuid FK` のように型 + 制約）
- `edges` = FK 参照（子 → 親の向き）。多重度は `cardinality`（`"n..1"` 等・両端に鳥の足シンボル）で表し、`label` は関係名（任意）に使う
- 端点シンボルは SVG の context paint（`context-stroke`）でエッジ色を継承するため、これに対応したブラウザ（Chrome/Edge・Safari・Firefox とも概ね 2024 年以降）で表示される。未対応の古いブラウザでは端点シンボルが描画されずエッジ線のみになる（矢じりと違い黙って消えるため注意）
- スキーマ・ドメインで色分けしたい場合のみ `groups` を付け、`layout: "flow"` を明示する

### コンポーネント / クラス設計

- `group` = レイヤーやドメイン（UI 層 / アプリケーション層 / ドメイン層 / インフラ層 等）
- `members` = 主要メソッド・フィールド（`name` = 名前、`type` = シグネチャや型）
- `edges` = 依存 / 継承 / 実装 / 参照。label で種別（`implements` / `extends` / `uses`）

## サイズの目安（無言の切り詰め禁止）

- ノード数はおおよそ **80 まで**。超えそうな場合はディレクトリ / リソース種別単位に集約し、集約内容を完了報告に明記する
- `members` は 1 ノード **10 行目安**。超過分は `{ "name": "…他 N 件" }` の行で示す（黙って落とさない）
- ラベルはカード上で自動省略される（全文はクリックパネルに出るため `detail` を活用する）
