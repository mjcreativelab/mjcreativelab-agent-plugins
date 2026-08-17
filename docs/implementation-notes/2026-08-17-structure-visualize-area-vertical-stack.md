# 実装ノート: structure-visualize / branch-visualize — 選択中ハイライト保持 + エリア内縦積み

日付: 2026-08-17 (JST)
起票: Issue なし（会話での直接依頼）
対象: `skills/structure-visualize/assets/diagram-template.html`（917 → 1005 行）、`skills/branch-visualize/assets/diagram-template.html`（521 → 531 行）

依頼は 2 点:

1. 要素をクリックして説明パネルが出ている間は、その要素をホバー時と同じ状態（関連ノードと接続線が見える状態）に保つ
2. エリア（セクション）内のノードが横に並ぶと構成要素が多いときに横へ広がりすぎる。エリア内は極力縦積み、エリア同士は横並びでよい

依頼 2 の参考として `bs-vto-app-event-display/docs/structure-diagrams/component-vto-application-2026-08-17.html` が提示された。このファイルは**テンプレートを手で改変した版**で、`stackVertically()` という縦積み関数が入っている（現行テンプレートは `layoutGraph` のまま）。本実装はこれを正式仕様として取り込み、後述の 1 点を改良した。

## 1. 選択中のハイライト保持

`setFocus(id, on)` は `on=false` で `.hi` を全消ししていたため、パネルを開いたまま要素から離れるとハイライトが消えていた。3 関数に分解して選択状態を尊重する:

- `clearFocus()` — `svg.focus` と全 `.hi` を解除
- `applyFocus(id)` — 対象ノード + 隣接ノード + 接続エッジ / ラベルに `.hi`、`svg` に `.focus`
- `setFocus(id, on)` — `on` なら `applyFocus(id)`、解除時は選択中ノードがあれば `applyFocus(selectedId)`、無ければ `clearFocus()`

`selectNode()` の末尾で `applyFocus(n.id)`、`closePanel()` で `clearFocus()`。状態変数は `selectedG`（要素）を廃し `selectedId` に一本化した（要素は `nodeGs[selectedId]` から引ける）。

### 自分で判断した事項

- **選択中に別ノードをホバーしたときは一時的にそちらへ切り替え、離れたら選択ノードへ戻す**。依頼文は「選択中の要素をホバー相当に見せる」であってホバーの無効化までは求めていないと解釈した。ホバーをロックする実装も可能だが、関連を辿る操作性を殺すため採らなかった
- **branch-visualize にも同じ修正を適用した**（依頼で明示的に指示された）。両テンプレートは同系譜 fork で `setFocus` / `selectNode` / `closePanel` の形が同一

## 2. エリア内の縦積み（areas モードのみ）

### 変更

- **追加**: `stackVertically(ns, es, sizeOf)`（`layoutGraph` 直後・DOM 非依存の純関数）。戻り値は `layoutGraph` と同形（`pos` / `epaths` / `w` / `h`）
- **変更**: `groupLayouts[g.id] = layoutGraph(sub, subEdges, sizeOfStd, { margin: 0, hGap: INNER_H_GAP })` → `stackVertically(sub, subEdges, sizeOfStd)`
- **定数**: `INNER_H_GAP`（唯一の使用箇所が上記のため削除）→ `STACK_GAP = 22` / `STACK_LANE_PAD = 16` / `STACK_LANE_GAP = 18`
- **非変更**: `layoutGraph`（branch-visualize と共有のレイヤリングエンジン）、エリア同士のスーパーグラフ配置、エリア間エッジのルーティング、`routeAroundObstacles`、`__SV_DEBUG__` のキー構造

横広がりの原因は、エリア内の依存連鎖がそのまま `layoutGraph` のカラム数になっていたこと（例: `g_signage` の `a01→a02→a03→a03modal` が 4 カラム = 内側幅 1030px）。`stackVertically` はレイヤリングを行わず入力順に積むため、エリア幅は常に最大ノード幅 + 脇レーン分になる。

### エッジの経路

積み順の距離 `d = order[to] - order[from]` で分岐する:

- `d === 1`（真下）: 下端中央 → 上端中央の 2 点直線
- それ以外（1 つ以上跨ぐ / 下から上へ戻る）: 列の脇レーンへ逃がす 3 点経路（列端 → レーン上の中点 → 列端）。前進の跨ぎは右、戻りは左。`span`（積み順の距離）が小さいものを内側のレーンに置き、同じレーンに複数のエッジが重ならないようにする

レーンは `padFor(k) = k ? STACK_LANE_PAD + (k-1) * STACK_LANE_GAP : 0` の余白を列の左右に確保して収める。最も外側のレーンがちょうど余白の外端に載るため、`res.w` に含めた余白の内側に経路全体が収まる。

### 参考実装から変えた点

参考ファイルの `stackVertically` は**跨ぎエッジも直線**（`d > 1` でも下端 → 上端）で、間のノードを貫通する。実測でも参考ファイルの `a03→vto_pipeline` は `a03modal` を貫いている。本リポジトリには `SV_EDGE_GATE=1` の「エッジのノード交差 0」という不変条件（Issue #98 で達成）があり、これを割るため跨ぎも脇レーン行きにした。結果、実データ 3 件で交差 0 を維持している（後述）。

また参考実装は戻りエッジのレーンを `min(a.x, b.x) - 26`（= `x` 座標 -26）に置いており、エリア枠の外へはみ出す。本実装はレーン分の余白を `res.w` に含め、枠内に収めた。

### 自分で判断した事項

- **積み順は入力順（`nodes` の配列順）のまま**。参考実装と同じで、エッジの無いエリアは従来（バリセンタが効かず入力順の 1 カラム）と同じ並びになる。トポロジカルソートで並べ替える案は、作成者が意図した並び（レイヤー順など）を壊すため採らなかった。代わりに「group のノードは流れの順に並べて渡す」ことを SKILL.md / html-guide.md に明記した
- **`STACK_GAP = 22`** は参考実装の値を踏襲（従来のエリア内縦間隔 `V_GAP = 26` から 4px 詰まる）。ER の `cardinality` 端点シンボルは `markerUnits="userSpaceOnUse"` で 16px 固定のため、areas + cardinality の真下エッジ（22px）では両端シンボルが窮屈になりうる。ER 図は `flow` 推奨（html-guide.md の選択基準）なので実害は小さいと判断し、値は参考実装に合わせた
- **脇レーンの端点を列端（`padL` / `padL + colW`）に揃えた**。`sizeOfStd` はノード幅固定のため現状は各ノードの左右端と同値だが、幅が可変になっても膨らみが揃う
- **branch-visualize へは伝播しない**。areas モード・エリア枠・`groupLayouts` を持たない単層 flow レイアウトのため該当なし（Issue #94 ノートの系譜チェックと同じ結論）

## 3. エッジラベルの配置を実寸ベースへ（2 の随伴修正）

縦積みでラベルの配置環境が変わり（縦 22px の隙間に置かれる・脇レーンのラベルが列の外に出る）、実測でラベルのノード重なりが悪化したため、`drawEdge` のラベル退避を実寸ベースへ直した。

従来の退避判定はアンカー点 `(lx, ly)` と固定許容値（`ly < b.y - 10 || ly > b.y + b.h + 4`）で行っており、次の 2 系統を取りこぼしていた:

- **脇レーンのラベル**: アンカーはノードの矩形外にあるが `text-anchor: middle` のため文字列が列側へ伸びてノードに被る（横方向の見落とし）
- **隙間のラベル**: アンカーは許容値の内側だが、実際の文字列は数 px だけノードへ食い込む（許容値 4/10px と実寸のずれ）

修正は 3 点:

1. 判定を `getBBox()` の実寸矩形 × ノード矩形の重なりに変更（横方向も見る）
2. 退避量を固定値（6 / 12px）からラベル上端・下端までの実測距離 + 2px に変更
3. 中央線分が縦向きのとき（`|dx| < |dy|`）は上方向への 5px 逃がしをやめ、文字列の高さの中央を線分の中点に合わせる（縦積みの 22px の隙間に収めるため）

3 により横向きの線分（`flow`・エリア間）の配置は変わらない。実測でも flow フィクスチャのラベル座標は before/after で完全一致。

## 検証

使い捨てハーネス（非コミット・OS 一時領域）+ ヘッドレス Chrome。フィクスチャは実データ 3 件（`component` / `infra-prd` / `infra-0803` を生成済み HTML から `GRAPH` を抽出）+ flow 2 件（`flow` は ER + cardinality、`flow2` は循環あり）。

Issue #94 / #98 のハーネスはコミットされていないため、`SV_EDGE_GATE` 相当のノード交差チェックは本作業で作り直した（判定ロジックはテンプレート L369 の `segHitsRect` を `pad=1` のまま移植して同値にしてある）。数値は #94 / #98 のノートとフィクスチャが異なるため直接比較できない。以下はすべて**同一フィクスチャでの before（HEAD）/ after 比較**である。

### インタラクション（合成イベント + DOM アサーション）

`mouseenter` / `click` / `mouseleave` を `dispatchEvent` で発火し、`__SV_DEBUG__` ではなく DOM の状態を直接検査する（スクリーンショットでは判別できないため）。structure-visualize / branch-visualize 両方で **14/14 PASS**:

| 検査 | 内容 |
|---|---|
| hover-only clears focus | 未選択時のホバー解除で `.hi` 0 件・`svg.focus` なし（既存挙動の回帰） |
| selected keeps svg.focus / hi set | 選択後の `mouseleave` で `.hi` 集合 = {選択ノード, 隣接, 接続エッジ} を保持 |
| panel visible / selected class | パネル表示・`.selected` 付与 |
| click stopPropagation | ノードクリックが `svg` の `closePanel` に伝播しない |
| hover other overrides / reverts | 選択中の他ノードホバーで一時上書き、離れて復帰 |
| reselect moves hi | 選択の付け替えで `.hi` と `.selected` が移る |
| close clears hi / focus / selected | `closePanel()` で全解除 |
| after close hover is transient | 解除後のホバーは従来どおり一時的 |

### レイアウト不変条件（`__SV_DEBUG__`）

`segHitsRect`（テンプレート L369 と同一ロジック・`pad=1` でゲート一致）をハーネスへ移植し、全エッジ点列 × 非端点ノード矩形で交差を数える。

| フィクスチャ | mode | サイズ before → after | nodeCross | node 重複 | 枠内包含 | 枠重複 |
|---|---|---|---|---|---|---|
| component | areas | 3886×668 → **1958×732** | **2 → 0** | 0 | 0 | 0 |
| infra-prd | areas | 3926×730 → **2296×942** | 0 → 0 | 0 | 0 | 0 |
| infra-0803 | areas | 3646×617 → **2262×605** | 0 → 0 | 0 | 0 | 0 |
| flow | flow | 1186×230 → 1186×230 | 0 → 0 | 0 | 0（枠なし） | 0 |
| flow2 | flow | 1186×274 → 1186×274 | 0 → 0 | 0 | 0（枠なし） | 0 |

- **幅は 40〜50% 縮小**（component は高さもほぼ同等、infra-prd は高さ +29% の縦シフト＝仕様どおりのトレードオフ）
- **既存のノード交差 2 件が解消**（component の `avatar_retry→a02` が `guard_rate` / `a03` を貫いていた）。解消したことは実測、機序は未検証（エリアが細くなり `routeAroundObstacles` の迂回が成立するようになったと推測）
- **flow モードは `__SV_DEBUG__` が before/after でバイト単位一致**（`stackVertically` は areas 分岐からしか到達しないことの実証）
- 枠内包含は所属ノード矩形とエリア内エッジの全点で検査（脇レーンが枠外へ出ていないことの確認）

### エッジラベル

`getBBox()` の実寸矩形で、ノードとの重なり（当該エッジの端点ノード / 非端点ノードを分けて集計）とラベル同士の衝突を数える。テンプレートの退避対象は非端点ノードのみ（端点への重なりは設計上許容）だが、実害の判断のため食い込み深さも測った。

| 指標（5 フィクスチャ合計・ラベル 111 件） | before | after |
|---|---|---|
| 非端点ノードへの重なり（退避すべき対象） | 8 | **2** |
| 端点ノードへの重なり | 6 | **2** |
| ラベル同士の衝突 | 12 | 12 |
| 縦の食い込み **> 8px**（実質判読不能） | 10 | **4** |
| 縦の食い込み 3〜8px | 3 | 1 |
| 縦の食い込み ≤ 3px（かすり） | 8 | **0** |

- flow フィクスチャのラベル座標は before/after で完全一致（横向き線分の扱いを変えていないことの実証）
- 残る非端点 2 件はいずれも component のエリア間の長いラベル（`【主経路】全スロットを一括実行（同時実行 4）` 等）で、before から残っている既存事象。縦積みで新たに生じたものではない

### その他

- 構文チェック: 両テンプレートの `<script>` を抽出して `node --check` OK
- 目視: ヘッドレス Chrome で component / infra-prd を撮影し、参考ファイルと同等の「細い縦カラムが横に並ぶ」構成になっていること、跨ぎエッジが列の脇を回っていることを確認

## 未対応・残件

- エリア内の縦積みは高さ方向に伸びる。エリア数が少なく 1 エリアのノードが極端に多い図では縦長になる（`infra-prd` で高さ +29%）。折り返し（2 カラム化）の閾値は導入していない — 実データで問題が出てから検討する
- `STACK_GAP = 22` と `cardinality` 端点シンボル（16px 固定）の窮屈さは上記のとおり未対応
