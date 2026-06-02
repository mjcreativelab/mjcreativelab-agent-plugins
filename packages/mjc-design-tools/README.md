# mjc-design-tools

デザイン領域（UI / UX / 視覚表現）の専門知識を Claude にロードするスキル群。実装フェーズで必要となる「この領域特有のお作法・落とし穴・検証観点」を会話コンテキストに持ち込むことを目的とする。

## スキル一覧

### game-ui-design

ゲーム UI / HUD / ゲームメニュー / コントローラーナビゲーション / 没入型インターフェース等のデザイン観点を提供する。AAA タイトルからインディーまでの実践知（Nintendo の明快さ、Dead Space の diegetic UI、esports タイトルの可読性原則など）をベースに、以下の 3 領域に分解した参照ファイルで構成する。

- `references/patterns.md` — 採用すべきデザインパターン（実装方針）
- `references/sharp_edges.md` — クリティカルな失敗例と「なぜ起きるか」
- `references/validations.md` — 検証ルール・制約（レビュー観点）

主な利用シーン:

- ゲーム HUD / メニュー / インベントリ画面の設計レビュー
- コントローラー / ゲームパッド前提のナビゲーション設計
- TV 表示の safe zone / オーバースキャン対応
- ハンドヘルド / モバイル / 4K まで含めたスケーラブルな UI 設計
- 没入を壊さない diegetic UI 実装の妥当性チェック

## 使い方

```bash
# ゲーム UI 設計の専門観点をロード
/mjc-design-tools:game-ui-design
```

スキルはユーザーの依頼テキスト中に "game ui", "HUD", "controller ui", "diegetic" などのキーワードが含まれていれば自動的にトリガーされる。

## 出典

`game-ui-design` スキルは [omer-metin/skills-for-antigravity](https://github.com/omer-metin/skills-for-antigravity) の同名スキル（MIT License）をベースに作成した。
