# game-ui-design

ゲーム UI 設計（HUD・メニュー・コントローラーナビゲーション・diegetic interface・safe zone 等）の専門知識に加えて、**ビジュアルスタイル（アートディレクション）とモーションデザイン**を会話コンテキストにロードするスキル。機能的に正しいだけでなく、「スタイリッシュで、おしゃれなアニメーションがついた、モダンなビデオゲームのような UI」を出力することを目的とする。

## トリガー例

ユーザーの依頼に次のような語が含まれているとき自動的にトリガーされる:

- "game ui", "HUD", "heads up display", "game menu", "inventory ui"
- "title screen", "main menu", "pause menu", "ゲームっぽいUI"
- "health bar", "stamina bar", "minimap", "crosshair"
- "controller ui", "gamepad navigation", "button prompt"
- "diegetic interface", "in-world ui", "quest tracker"
- "radial menu", "cooldown indicator", "damage numbers"
- "game feel", "juicy ui", "game animation"

明示的にスキル名を呼ぶ場合は `/game-ui-design`。

## 構成

```
game-ui-design/
├── SKILL.md            # アイデンティティ・原則・参照ファイルの使い分け
└── references/
    ├── patterns.md     # 採用すべき機能パターン（設計時: 構造・UX）
    ├── aesthetics.md   # アートディレクション（設計時: スタイルアーキタイプ 6 種 + 職人ルール）
    ├── motion.md       # モーションデザイン（設計時: レジスタ別の演出・easing・振り付け）
    ├── recipes.md      # 実装レシピ（設計時: コピペ可能な CSS/JS スニペット 13 種）
    ├── sharp_edges.md  # クリティカルな失敗と理由（診断時）
    └── validations.md  # 自動検証可能な制約（レビュー時）
```

作成フローは patterns（構造）→ aesthetics（スタイル: アーキタイプを 1 つ選び宣言）→ motion（動き: HUD は厳格 / メニューは演出的の 2 レジスタ + アンビエント）→ recipes(実装)の順。`SKILL.md` 本体は短く保ち、領域知識は `references/` に分割している。Claude は必要な参照ファイルだけを読み込む。

## 出典・ライセンス

このスキルは [omer-metin/skills-for-antigravity](https://github.com/omer-metin/skills-for-antigravity) リポジトリの `skills/game-ui-design/`（MIT License）をベースに作成した。`patterns.md` / `sharp_edges.md` / `validations.md` は元データを踏襲している（validations.md の long-animation-duration は motion.md と整合するよう文言を調整）。`aesthetics.md` / `motion.md` / `recipes.md` は本リポジトリ独自の追加（ベースライン検証で「機能的には正しいがビジュアル・モーションが弱い」出力傾向を確認した上で、その失敗パターンに対応する形で作成）。
