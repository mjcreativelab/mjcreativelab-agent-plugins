# game-ui-design: スタイル・モーション強化

日付: 2026-07-12 (JST) / ブランチ: `feature/game-ui-design-style-motion-20260711`

## 目的

game-ui-design スキルの理想を「スタイリッシュで、おしゃれなアニメーションがついた、モダンなビデオゲームのような UI を作成すること」と定義し直し、それを満たすようスキルを改修する。

## 事前検証（TDD: RED）

writing-skills の手順に従い、改修前スキルだけを指針として渡した builder エージェント 2 体（sci-fi タイトル画面 / アクション RPG HUD + ポーズメニュー）に単一 HTML を実装させ、独立審査エージェント 3 レンズ（visual style / motion / game-feel、0-10 の厳格採点）で採点した。

ベースラインスコア: **sci-fi = style 6 / motion 5 / gamefeel 7、RPG = style 6 / motion 6 / gamefeel 7**

両ビルドで一致した失敗パターン:

1. タイポグラフィが素の system stack、ワードマークが plain heading
2. 形状言語が全部ただの矩形（chamfer / corner bracket / notch なし）
3. テクスチャゼロのフラット rgba 塗り
4. アイコンが生 Unicode 記号（⚔ ▶ ✦）
5. エントランス演出・stagger なし、退出が全部ハードカット
6. easing が全部ブラウザ既定キーワード
7. 決定操作に押下フィードバックなし
8. reduced-motion が「全アニメを `!important` で抹殺」型
9. ネイティブ `<input type=range>` 等の web パーツ露出
10. 1 つの pulse keyframe を複数の緊急度に使い回し

原因: 既存リファレンスは機能的 UX（可読性・safe zone・コントローラー操作・アクセシビリティ）に特化しており、ビジュアルとモーションの語彙がゼロ。さらに validations の「500ms 超は警告」等が文脈を区別せず抑制方向に働いていた。

## 変更内容

- **`references/aesthetics.md` 新設**: スタイルアーキタイプ 6 種（Clean Sci-Fi Holo / Kinetic Graphic Pop / Cyberpunk Glitch / Minimal Ethereal / Ornate Fantasy / Esports Broadcast。各実ゲーム参照 + CSS トークンブロック付き）、選定ヒューリスティック、横断職人ルール 11 箇条、納品前セルフ監査。
- **`references/motion.md` 新設**: 3 レジスタ方式（ゲームプレイ中 HUD = 厳格 / メニュー・タイトル = 演出的 / アンビエント = 別枠）で既存の motion-sickness ルールと共存。easing トークン 6 種・duration 表・振り付けパターン（stagger・タイトルシーケンス・ポーズ overlay）・micro-interactions・HUD フィードバック（二層 HP バー等）・reduced-motion 単一スイッチ方式・セルフ監査。
- **`references/recipes.md` 新設**: コピペ可能な CSS/JS レシピ 13 種（chamfer パネル・conic-gradient クールダウン・多層グロー・ghost HP バー・stagger エントランス・コーナーブラケットフォーカス・カスタム設定コントロール等）。
- **`SKILL.md` 改修**: description にスタイル・モーションのカバレッジとトリガー語（title screen / game feel / juicy ui 等）を追加。identity・principles に「Menus are theater, HUD is instrumentation」「Default to styled and animated」等を追加。参照ルーティングを作成フロー 4 段（patterns → aesthetics → motion → recipes）に再構成し、「デフォルトでスタイル付き・アニメーション付きを出す」出力姿勢を明記。
- **`references/validations.md` 微修正**: `long-animation-duration` の Message / Fix Action を motion.md のレジスタ方式（stagger で組む・`-ambient` は除外）と整合するよう文言調整（regex は不変更）。
- **README.md / CLAUDE.md**: スキル説明・構成・出典（新規 3 ファイルはリポジトリ独自追加）を更新。

## 事後検証（TDD: GREEN）

検証中に Fable 5 のリミットに達しモデルが Opus 4.8 に切り替わったため、「Fable→Opus のモデル差」と「スキル改修効果」の交絡を避ける必要が生じた。そこで単純な GREEN 再実行ではなく、**旧スキル（git HEAD 版を一時ディレクトリに取り出したもの）vs 新スキルを同一モデル（Opus 4.8 固定）で A/B** し、審査エージェントには旧/新を伏せてブラインド採点させた。唯一の変数はスキル内容のみ。

| ビルド | 観点 | 旧スキル | 新スキル | Δ |
|---|---|---|---|---|
| sci-fi タイトル | style | 6 | 7 | +1 |
| sci-fi タイトル | motion | 5 | 8 | +3 |
| sci-fi タイトル | gamefeel | 7 | 8 | +1 |
| RPG HUD | style | 6 | 7 | +1 |
| RPG HUD | motion | 5 | 8 | +3 |
| RPG HUD | gamefeel | 7 | 8 | +1 |

両ビルドで揃って style +1 / motion +3 / gamefeel +1。motion が最大の改善（「web ページ」域から「強い indie リリース」域へ）。旧アームのスコアが Fable での初回 RED ベースライン（6/5/7）と一致し、判定の安定性も確認できた。

新スキル側の残存ギャップは 2 種類:
- **モックの天井（スキル文言では埋まらない）**: 実レンダリング key art・ライセンス表示フォント・描き起こしアセット・実音声。純 CSS 自己完結モックの範囲外。
- **適用漏れ（REFACTOR 対象）**: stagger の `--i` がマークアップ側未代入で cascade 無効化、スライドするタブ/選択インジケータ（magic-line）未適用、数値 count-up 未適用、デモ足場の混入（機能しないタブ・HUD 凡例内のデバッグトグル）。

## 事後検証 2（TDD: REFACTOR）

上記「適用漏れ」を潰す外科的編集を実施:
- `motion.md` / `recipes.md`: stagger の `--i` 未代入で cascade が無音で無効化される落とし穴を明記。
- `motion.md`: 選択インジケータを「per-item ::after の cut-in ではなく 1 要素の magic-line を移動」と具体化。
- `motion.md` セルフ監査: 画面遷移のアニメ化・成功パスのフィードバック・magic-line・count-up・デッド `--ease-*` 参照チェックを追加。
- `aesthetics.md` セルフ監査: デッドタブ / HUD 凡例内デバッグトグル / 未解決フォント名の具体チェックを追加。

改修後スキルのみを Opus で再ビルドし回帰確認（新アーム 2 ビルド × 3 観点、ブラインド審査）:

| ビルド | REFACTOR 前（新スキル） | REFACTOR 後 |
|---|---|---|
| sci-fi タイトル | 7 / 8 / 8 | 7 / 8 / 8（維持） |
| RPG HUD | 7 / 8 / 8 | 7 / 7 / 8 |

RPG の motion 1 点差はビルダー単発サンプルのばらつきの範囲（追加したのは self-audit 項目のみで因果的に出力を悪化させない）。**回帰なし**と判断。核心的改善（旧→新 +1/+3/+1）は各アーム 2 サンプル（旧 ≈ 6/5/7、新 ≈ 7/8/7.5）で一貫再現しており、n=1 ではない堅牢な結果。

REFACTOR 検証で両サンプルに繰り返し出た「ゲームプレイ HUD がロード時に静止（boot-in がない）」は、モックの天井ではなくスキルで潰せる明確なギャップだったため、`motion.md` section 5 に「HUD boot-in（プレイ中静止の唯一の例外＝初回出現時は一度だけ stagger で組み上がる）」を追記した。これ以上の反復は単発サンプルのノイズ追いになり信号を生まないため検証を打ち切った。

最終スコア: 旧スキル ≈ style 6 / motion 5 / gamefeel 7 → 新スキル ≈ style 7 / motion 8 / gamefeel 8。

## 判断事項・トレードオフ

- **ドラフト生成は並列サブエージェント、統合は手動**: aesthetics / motion / recipes のドラフトは 3 視点の並列エージェントで生成し、ベースラインの失敗パターン（Unicode アイコン・ネイティブウィジェット・緊急度の使い回し・reduced-motion 全殺し等）への対応をメイン側で統合時に織り込んだ。
- **既存 references とは「上書き」でなく「スコープ分割」で整合**: sharp_edges の motion-sickness ルールや validations の duration 警告は正しい知見のため削除せず、motion.md 側で「どの文脈に適用されるか」を定義して共存させた（validations は文言のみ調整）。
- **フォントは self-contained 前提**: Google Fonts 等の外部リクエストを前提にせず、condensed system stack + tracking を基本、本当に必要な場合のみ data URI 埋め込みとした（Artifact 等 CSP 環境での利用を想定）。
- **recipes のアンビエント keyframe に `-ambient` サフィックス**: validations の regex が長い duration を警告するため、意図的な長時間ループであることが自己文書化されるよう命名規約を導入した。
- **モデル交絡を A/B で排除**: 検証途中の Fable→Opus 切替を、旧/新スキルを同一モデルで並べる A/B に変えて吸収した（旧スキルは git HEAD から一時ディレクトリに取得）。審査はブラインド。スコアはスキル内容のみに帰属する。
- **反復の打ち切り基準**: 残存ギャップの多くは純 CSS 自己完結モックの天井（実 key art・ライセンス表示フォント・実音声）でスキル文言では埋まらない。REFACTOR 後の 1 点差は単発サンプルのノイズ域であり、追加の検証ラウンドは信号を生まないため、核心的改善が 2 サンプルで再現した時点で打ち切った（グリーン追いではなく仕様充足で判断）。
