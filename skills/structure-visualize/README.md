# structure-visualize

指定された開発構造（インフラ構成 / ER 図 / コンポーネント設計 / クラス構成 / モジュール依存など）を、自己完結 HTML の構成図として `docs/structure-diagrams/` に出力するスキル。

## どんなケースで使うか

- 会話で詰めたアーキテクチャ設計を、**エリア枠付きの図**にして共有したい
- 設計ドキュメント（md 等）の構造を図で俯瞰したい
- Terraform / migration / ソースコードから**現状の構造**をスナップショットとして描きたい

使わない場面:

- git ブランチ差分の可視化 → `/branch-visualize`（本スキルは差分ではなく指定内容のスナップショットを描く）
- シーケンス図・フローチャート・状態遷移図（時系列・振る舞いは対象外。静的構造のみ）
- 設計そのものの言語化 → `/software-architect`

## 使い方

```
/structure-visualize この会話で決めたインフラ構成
/structure-visualize docs/design/booking.md
/structure-visualize terraform/ のインフラ構成
/structure-visualize db/migrations/ の ER 図
/structure-visualize src/features/booking/ のコンポーネント設計
```

引数は自然文とパスの混在可。引数なしなら直近の会話から対象を推定する。

## 図の表現

- **カテゴリ別配色**: group（レイヤー・所属・プロバイダ等）ごとにダークトーン 8 色を自動割当し、凡例に表示
- **エリア枠**: 所属・境界が主題の図では、グループごとの囲み枠（左上ラベル + 同系色）でノード群を括る（1 階層。入れ子なし）
- **依存フロー配置**: 依存の流れ・ER が主題の図では枠なしの階層配置
- **ノード詳細**: members（カラム・フィールド・属性）行、クリックで種別 / グループ / 出典 / 概要のパネル、hover ハイライト、ズーム / パン

## 出力ファイル

- `docs/structure-diagrams/<図種>-<対象スラグ>-<日付>.html`（例: `infra-payment-system-2026-07-16.html`）
- 自己完結 HTML（外部 CDN・API 不使用。オフラインでブラウザ表示可能）
- 生成物のコミットは行わない（ユーザーの判断に委ねる）

## 前提条件

- git リポジトリでなくてもよい
- コード内容を外部レンダリング API に送信しない
- AskUserQuestion 非対応のエージェントではテキストで確認する
