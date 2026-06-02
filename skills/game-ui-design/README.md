# game-ui-design

ゲーム UI 設計（HUD・メニュー・コントローラーナビゲーション・diegetic interface・safe zone 等）の専門知識を会話コンテキストにロードするスキル。

## トリガー例

ユーザーの依頼に次のような語が含まれているとき自動的にトリガーされる:

- "game ui", "HUD", "heads up display", "game menu", "inventory ui"
- "health bar", "stamina bar", "minimap", "crosshair", "reticle"
- "controller ui", "gamepad navigation", "button prompt"
- "diegetic interface", "in-world ui", "quest tracker"
- "radial menu", "cooldown indicator", "damage numbers"

明示的にスキル名を呼ぶ場合は `/game-ui-design`。

## 構成

```
game-ui-design/
├── SKILL.md           # アイデンティティ・原則・参照ファイルの使い分け
└── references/
    ├── patterns.md     # 採用すべきデザインパターン（設計時）
    ├── sharp_edges.md  # クリティカルな失敗と理由（診断時）
    └── validations.md  # 自動検証可能な制約（レビュー時）
```

`SKILL.md` 本体は短く保ち、領域知識は `references/` に分割している。Claude は必要な参照ファイルだけを読み込む。

## 出典・ライセンス

このスキルは [omer-metin/skills-for-antigravity](https://github.com/omer-metin/skills-for-antigravity) リポジトリの `skills/game-ui-design/`（MIT License）をベースに作成した。`SKILL.md` は本リポジトリの規約に合わせて若干調整しているが、`references/*.md` の内容は元データを踏襲している。
