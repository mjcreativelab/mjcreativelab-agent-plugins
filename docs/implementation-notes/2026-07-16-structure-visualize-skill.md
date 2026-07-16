# 実装ノート: structure-visualize スキル追加

日付: 2026-07-16 (JST)
スペック: `docs/specs/2026-07-16-structure-visualize-design.md`

## スペックから変更・具体化した点

- **パレットの塗り方式**: スペックのカテゴリ配色表（1. カテゴリ配色（8 色パレット））は固定 HEX の暗い塗り
  （例: blue 系統 `#101a2b`）を規定していたが、テンプレートは fork 元（branch-visualize）テンプレートの
  流儀に合わせ、塗りを rgba タント（例: blue 系統 `rgba(77,142,219,.10)`）で実装した。枠色・文字色は
  スペックの HEX 値をそのまま採用している（`#4d8edb` / `#9ecbff` 等）。ダーク背景での見え方はスペック案と
  同等であることを実機スクリーンショットで確認済み
- **ノード塗り・ラベル色のバグ修正**（Task 2 レビュー・Opus が検出）: ノードの塗りとラベル色を SVG
  presentation attribute（`rect.setAttribute("fill", ...)` / `label.setAttribute("fill", ...)`）で
  設定していたため、CSS ルール（`.node rect { fill: var(--node-fill) }` 等）に負けてカテゴリ配色が
  描画されず、凡例チップと実際のノード色が一致しないバグがあった。inline style 代入
  （`rect.style.fill` / `label.style.fill`）に修正した（commit `2b9addf`）
- **エッジラベルの重なり調整**（Task 3 実ブラウザ検証）: ヘッドレス Chrome スクリーンショットによる
  4 フィクスチャの目視確認で、グループ間エッジ（直線経路）のラベルが src/dst 中点に固定配置されており、
  経路上の無関係なノードと重なる箇所を計 4 件検出した（infra-areas 3 件・component-areas 1 件）。
  `drawEdge` に近傍ノード検出によるラベル退避（衝突時に上下へ最大 12px オフセット）を追加した
  （commit `6f55794`）。計画段階のサンプルコミットメッセージ「配色・余白の微調整」は、この実際の変更内容
  （ラベル位置調整）に合わせて文言を変更している

## スペックに明記されていなかったため判断した点

- **グループ間エッジのポート選択**: 「相手ノードの相対位置で左右辺を選択」する簡易方式を採用した
  （`srcRight = dp.x + dp.w/2 >= sp.x + sp.w/2` で判定）。ポートの上下分散はグループ内エッジのポート
  分散（`portYs`）とは独立にノード単位で行う。まれに近接しうるが v1 として許容する
- **ダミーノードのみのカラムの幅**: 幅 0（`{ dummy: true, w: 0, h: 0 }`）として詰める
- **検証ハーネスの扱い**: DOM スタブ + `window.__SV_DEBUG__` を用いた不変条件検査（ノード非重複・エリア枠内
  包含・エリア枠非重複・flow モード時は枠なし）はセッションの一時領域で運用し、リポジトリにはコミットしない
  （テスト基盤を持たない現行方針のため）。テンプレートは `window.__SV_DEBUG__ = { mode, nodes, boxes, size }`
  （`skills/structure-visualize/assets/diagram-template.html:594`）を恒久的に公開しており、同型のハーネスを
  再作成すれば回帰検証できる

## トレードオフ

- **グループ間エッジのルーティング**: 直接ベジェ（ダミー中継なし）で描画するため、ノードやエリア枠と
  交差しうる（採用: 実装の単純さ・参照画像も枠をまたぐ直線的表現 / 却下: クラスタ対応の完全ルーティング
  = 過剰）。実測では component-areas サンプルで 2 本がインフラ層の枠を横切るが、文字は判読可能な範囲に
  収まっている（許容範囲・将来のルーティング改善候補）
- **ラベル衝突回避のアルゴリズム**: single-pass 方式。同一カラム内のノードは `V_GAP=26` で分離されており、
  最大退避 12px では隣接ノード枠に到達しない、という現行レイアウト定数の関係に暗黙に依存している
  （レイアウト定数を変更する際は再検証が必要）

## 検証結果

spec の検証方法 1〜4 を本タスクで再実行した（すべてこのセッションで実行・確認済み）。

1. `npx skills add ./ --list`（mise 経由 node で実行）: 検出された 20 skills の一覧に `structure-visualize`
   を確認（OK）
2. `head -5 skills/structure-visualize/SKILL.md`: frontmatter（`name: structure-visualize` +
   `description`）を確認（OK）
3. レイアウトハーネス（セッションの一時領域の `test-layout.mjs` + フィクスチャ 4 種。spec 検証方法の
   3〜4 に対応）を `skills/structure-visualize/assets/diagram-template.html` に対して実行:
   `infra-areas.json` / `er-flow.json` / `component-areas.json` / `plain-flow.json` の 4 件すべて
   `PASS`（ノード非重複・エリア枠内包含・エリア枠非重複・flow モード時は枠なし、の不変条件）
- 行数: `skills/structure-visualize/SKILL.md` 93 行（500 行制限内）、
  `skills/structure-visualize/assets/diagram-template.html` 711 行（別ファイルのため制限対象外）
- `node --check`: テンプレート内の埋め込み `<script>` を現在のコミット内容から抽出し直して構文チェックし、
  OK を確認（620 行）
- 実ブラウザ確認（Task 3 で実施済み）: ヘッドレス Chrome スクリーンショット（1600×1000）で 4 サンプル
  （infra-areas / er-flow / component-areas / plain-flow）を目視確認し、エリア枠・凡例・カテゴリ配色・
  エリア外ノードの中立色・flow モードのフォールバック表示が意図どおりであることを確認した

### 未検証事項

インタラクティブ項目（ノードクリックの詳細パネル表示・hover ハイライト・ズーム/パン操作）はブラウザ
ドライバ不在のため未検証。fork 元テンプレート（branch-visualize）から継承したコードパスであり、今回は
静的レビューのみ実施した。PR レビュー時に手元ブラウザでの動作確認を推奨する。
