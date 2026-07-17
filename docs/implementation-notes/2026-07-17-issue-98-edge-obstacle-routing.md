# 実装ノート: Issue #98 structure-visualize グループ内障害物回避の本格エッジルーティング

日付: 2026-07-17 (JST)
Issue: #98 `structure-visualize: グループ内障害物回避の本格エッジルーティング（Issue #94 の計測で必要と判定）`
ブランチ: `feature/issue-98-edge-obstacle-routing` / diff 基準: `origin/main`(f0a20c3)
前提ノート: `docs/implementation-notes/2026-07-17-issue-94-edge-routing-avoidance.md`（Step 3 で本格ルーティングを要判定）
設計: `design.md`（drawEdge 側の経路後処理・`layoutGraph` 非改変）

## 変更ファイル

- `skills/structure-visualize/assets/diagram-template.html`（f0a20c3 比 **+156 / -0 行**・全体 **917 行**。うち +14 は設計レビュー指摘 1・2 の採用修正）
  - **追加（L362-515 の描画ヘルパ節）**: 障害物回避の後処理器一式（純関数）。
    - `segHitsRect`（L369）: 線分×矩形の Liang-Barsky 判定。ハーネスの交差ゲートと同一ロジック（pad=1 でゲートと一致）。
    - `firstHitSeg`（L386）/ `crossCount`（L397）: 交差する線分の検出とスコアリング用の交差数計算。
    - `boundsOf`（L406）: ブロッカー矩形群の union bbox。
    - `laneOf`（L420）: 迂回レーン y をノード間の垂直チャネル中央に置く（密フレームで隣ノードへ食い込まないため固定マージンでなく中央取り）。
    - `laneDetour`（L437）: `lo..hi` の内部頂点を、U を上下いずれかへ回る水平レーンに置換した点列を返す。
    - `stubTooShort`（L448）: 端点に接する迂回で終端スタブが 8px 未満に縮む候補を弾く（設計 §1-6 の端点保護＝cardinality マーカー配向の安定条件。レビュー指摘 2 で追加）。
    - `routeAroundObstacles`（L460）: 本体。最初に交差する線分のブロッカー union を、ノード交差 0 → 通過枠交差最小 → 偏差最小の順（偏差は [0,1) 正規化で厳密辞書式・レビュー指摘 1）でレーン選定し迂回。交差が消えるか改善が止まるまで反復（上限 8、各反復で交差数を厳密に減らすので必ず停止）。
    - `obstaclesFor`（L497）: 端点 2 ノードを除く全ノード矩形。`framesFor`（L507）: どちらの端点グループにも属さない通過フレーム枠（flow モードは空）。
  - **変更（L550・drawEdge 冒頭 1 行）**: `pts = routeAroundObstacles(pts, obstaclesFor(...), framesFor(...))` を通してから既存処理（`pathThrough` 描画・`edgePaths` 収集・ラベル配置）へ。flow / グループ内 / グループ間の全経路が `drawEdge` を通るため、単一呼び出し点で全経路をカバー。
- **非変更**: `layoutGraph`（L199-348・branch-visualize 共有のレイヤリングエンジン）・areas のスーパーグラフ構築・ポート分散・`__SV_DEBUG__` のキー構造。diff の 2 ハンク（@@ -359 と @@ -392）はいずれも L359 以降で、`layoutGraph`（L199-348）に一切触れていない。

検証は「使い捨てハーネス（fixtures 6 種 + `render.mjs` + `test-layout.mjs` + `label-check.mjs` + `dump-debug.mjs` + `parse-test.mjs`）＋ ヘッドレス Chrome」で実施（非コミット・`mise exec node --` 必須）。

## 受け入れ基準ごとの対応

### 基準 1: 厳格ゲート（`SV_EDGE_GATE=1`）で 4 フィクスチャ全 PASS（ノード交差 9→0）— 達成

- 4 フィクスチャすべて **node-cross=0**（sibling 6・unrelated 1・flow 2 をすべて解消）。gate 4/4 PASS（exit 0）。
- 機構: 全エッジの最終点列に対し、端点以外のノード矩形を障害物とみなし、交差線分を「ブロッカー端の上 or 下の水平レーン」で迂回する後処理を 1 回通す。sibling/unrelated（枠内 first-mile）も flow（2 層跨ぎダミー由来）も、すべて「線分が非端点ノード矩形を貫く」単一の幾何問題に還元され、同一機構で解ける。
  - flow の 2 件（`sessions→users` が `orders` を両セグメントで貫く）は、run 拡張で内部ダミー(443,48) を破棄し、orders 底(168)/products 頂(194) 間のチャネル中央 y=181 へレーンを張って解消。

### 基準 2: 見た目の品質維持（階段状・平行重なり・ラベル可読性の劣化を持ち込まない）— 達成

- ヘッドレス Chrome（1700×700）で 6 フィクスチャの before/after を撮影・目視。
  - infra-areas: `worker→slack_app` が pubsub 直下の水平レーン（y=203）を通り、`worker→partner`/`user→lb` も兄弟ノード直下を回る。ノードを貫く線が消え、滑らかなベジェで階段状の乱れなし。
  - er-flow / er-cardinality: `sessions→users` が orders を貫く弧から、orders/products 間チャネルを通る経路に改善。
  - component-areas: `BookingUsecase→Booking(Repository)` が NotifyService 直下〜infra 枠下の単一水平レーンを通り、`BookingPage→BookingUsecase` は CalendarWidget 直下を回る。
- 迂回で挿入される頂点は同一 y の共線頂点が多く、ベジェは直線に潰れるため階段状・平行重なりは生じない。

### 基準 3: エッジラベルの配置ロジックを新経路に追従 — 達成（追従修正は不要と実測）

- ラベルアンカー（奇数点列での共有ダミー頂点回避＋on-node 退避）は迂回後の `pts` を入力に自動追従する。`label-check.mjs` で **全 6 フィクスチャ on-node=0 維持**。
- component-areas の既知の label-label 近接（#94 残存の「操作」「uses」7px 近接＝collision 1 件）は、迂回で両ラベルが水平レーン上に分離し **collision 1→0 に改善**。他フィクスチャも collision=0。
- したがってアンカー実装のコード修正は不要（新経路形状で再検証し成立を確認）。

### 基準 4: 既存不変条件 4/4 PASS 維持・frame 交差（現 1 件）を増やさない — 達成

- 既存不変条件（ノード非重複・枠内包含・枠非重複・flow 時枠なし）: report-only で **6/6 PASS**。
- frame 交差: **1→1**（component-areas の `booking_uc→booking` が infra 枠を 1 回横切る＝ベースラインと同一。他はすべて 0）。当初、素朴なレーン迂回では infra 枠内の mailer を回るレーンが枠内を走り frame 交差が 1→4 に増えたため、**ルーターに通過枠 awareness を追加**（レーン候補にノード間チャネルに加えて通過枠の外側 y も列挙し、ノード交差 0 →通過枠交差最小→偏差最小でスコア選定）して 1 に戻した。

### 後方互換（er-cardinality / card-fallback）— 維持

- `__SV_DEBUG__` のキー構造（mode/nodes/boxes/size/edges、edge の {from,to,pts}）は before/after で完全一致（`dump-debug.mjs` で 4 フィクスチャ確認。edges の点列値のみ迂回で変化）。
- `parse-test.mjs`（cardinalityEnds）: ALL PASS（valid 10 + invalid 21）。cardinality マーカーのロジックは非改変。
- **cardinality マーカー**: er-cardinality の `sessions→users` は迂回後も終端スタブが長く（全フィクスチャの終端スタブ最小 87.7px ≫ 8px 目安）、`orient="auto-start-reverse"` の向きは安定。スクリーンショットで鳥の足／縦棒／丸付きシンボルが before と同一に描画・配向されることを確認。

## テスト結果（ベースライン比較）

| 項目 | ベースライン（f0a20c3） | 実装後 |
|---|---|---|
| gate 4 フィクスチャ node-cross | 9 (flow=2 sibling=6 unrelated=1) | **0** |
| gate 判定 | 3/4 FAIL（plain-flow のみ PASS） | **4/4 PASS**（exit 0） |
| frame-cross（gate 4 フィクスチャ） | 1（component-areas infra） | **1**（同一） |
| 既存不変条件（report-only 6 種） | 6/6 PASS | 6/6 PASS |
| label on-node（6 種） | 0 | 0 |
| label-label collision（component-areas） | 1（"操作"~"uses" 7px） | **0** |
| `__SV_DEBUG__` キー構造 | mode,nodes,boxes,size,edges | 同一 |
| cardinality parse-test | ALL PASS | ALL PASS |
| 終端スタブ最小 | — | 87.7px（>8px） |
| 構文 `node --check` | OK | OK |
| 行数 | 761 | 917 |

## 自分で判断した事項

1. **通過枠 awareness の追加（設計の想定を実装で具体化）**: 設計は「ノード障害物回避」を主眼とし frame は report-only 監視の想定だったが、実装すると infra 枠内の mailer を回るレーンが枠内を走り frame 交差が 1→4 に増加した（基準 4 違反）。設計 §4-5 のリスクどおり。対処として `framesFor`（通過枠＝端点いずれのグループにも属さない枠）を導入し、レーン候補に「通過枠の外側 y」を加え、スコアを `ノード交差×10000 + 通過枠交差×100 + 偏差` として通過枠交差を最小化（偏差項は後述レビュー指摘 1 で `偏差/(偏差+1)`＝[0,1) 正規化に変更し、加算重みを厳密辞書式に頑健化）。これにより `booking_uc→booking(_repo)` のレーンが infra 枠の下（y=258）へ抜け、frame 交差が 1 に戻った。設計の「drawEdge 側後処理・layoutGraph 非改変」の枠内での拡張であり、方針変更ではない。
2. **検出 pad=1（ゲートと一致）／配置マージンは別（チャネル中央取り）**: 交差検出をゲートと同じ pad=1 にし、ゲートが弾く交差を確実に捕捉。レーン配置は `laneOf` のチャネル中央取り（他障害物が無ければ既定ギャップ 12px、ブロッカー端から最低 3px）で余裕を確保。密フレーム（infra-areas の pubsub 底 199 と oauth/lb 頂 207 の 8px チャネル）でも中央取りで lane=203 となり隣ノードへ食い込まない。
3. **反復の停止保証**: `routeAroundObstacles` は各反復でノード交差数を厳密に減らす候補のみ採用し（`crossCount(best) < before` でなければ break）、上限 8。ゲート解が存在する（本フィクスチャ群で node-cross=0 到達を実測）ため収束する。
4. **run 拡張（内部ダミー破棄）**: ブロッカーの x 帯内にある内部アンカーは x 帯外まで run を広げて置換対象に含める。flow の `sessions→users` で層跨ぎダミー(443,48) を破棄し単一レーンで orders を回避するために必須。
5. **#94 コメントは非改変が正しい**: #94 導入のグループ間ルーティング／ラベルのコメントは「点列の構築方法」を説明しており、障害物回避は `drawEdge` 冒頭の別レイヤ（L362・L536 で明記）として追加したため、既存コメントは依然正確（嘘になっていない）。よって既存コメントは surgical に非改変とした。

## プロジェクト固有基準の確認

- **branch-visualize 系譜（CLAUDE.md「スキル改修時の注意」）**: **該当なし・伝播不要**。本変更は `drawEdge` 冒頭に追加した後処理レイヤ（`segHitsRect`/`routeAroundObstacles` ほか）であり、共有のレイヤリングエンジン（`layoutGraph` 内の sweep/bary/portYs/dummy 配置・`DUMMY_GAP`/`V_GAP`）には一切触れていない（diff は L359 以降のみ）。branch-visualize の template（521 行）は `layoutGraph` 抽出関数・areas・`drawEdge`・障害物回避を持たない単層 flow レイアウトで、本後処理の適用対象そのものが無い。branch-visualize が同種の後処理を将来採り入れる余地はあるが本 Issue のスコープ外（報告のみ）。
- **レイアウトエンジンのレイヤリング／ズーム・パン系不具合の同系譜チェック**: 本変更はレイアウトエンジンの不具合修正ではなく新規の経路後処理のため、branch-visualize 側 diagram-template.html への該当項目なし。
- **自己完結 HTML**: 追加は純 JS ロジックのみ。CDN・外部 API・外部フォント追加なし。
- **`__SV_DEBUG__` 後方互換**: キー構造不変（値のみ迂回反映）。
- **コメント**: 追加ブロックのコメントは最終仕様のみ（履歴・変更理由なし）。既存コメントは実挙動と整合したまま（上記「自分で判断した事項」5）。
- **ドキュメント**: `references/html-guide.md` は入力フォーマット（nodes/edges/groups を渡すだけ）を記述し、経路は内部実装。経路の意味論はユーザー向けに不変のため **更新不要**（設計 §2 と一致）。
- **行数**: 917 行（800 行目安を 117 行超過・設計 §6 予測の 850-900 を上回る。うち +14 は設計レビュー指摘の採用修正）。後処理器は本質的に約 110 行規模（幾何プリミティブ + レーン選定 + 反復）で、各関数は単一用途・デッドコードなし。context 許可どおり最小限に留め、生成スクリプト化・目安改定は本 Issue のスコープ外（報告のみ）。

## 設計レビュー指摘への対応（2 件・いずれも採用）

設計役レビューの 2 件を検証のうえ採用し修正。いずれも 6 フィクスチャ上の退行ではなく「フィクスチャ外入力での頑健性」を高める設計整合修正で、**6 フィクスチャの `__SV_DEBUG__`（edges 含む）は修正前後で byte 一致**（＝退行ゼロを実証）。全体 903→917 行（+14）。

### 指摘 1（Medium・採用）: レーン選定スコアの加算重みが辞書式優先を崩し得る

- 指摘: スコア `crossCount(obs)*10000 + crossCount(frames)*100 + Math.abs(ly-midY)` は偏差項が px で上限がなく、背の高い通過枠では偏差が枠交差 1 件の重み(100)を超え、「通過枠を 1 枚余計に貫くが midY に近いレーン」が「枠クリアだが偏差の大きいレーン」に勝ち、基準 4（frame-cross をベースライン 1 件から増やさない）を退行させ得る。コード自身のコメントが辞書式順序（ノード交差 0 →通過枠交差最小→偏差最小）を宣言しており、加算重みはその頑健でない近似だった。
- 妥当性: **妥当（実証）**。偏差 110px の枠クリア候補(score 110) が偏差 5px の枠貫通候補(score 105) に負け、枠貫通側が選ばれることを数値確認（`scoring-probe.mjs`）。6 フィクスチャは偏差が小さく（レーンはブロッカー近傍）発現しないため退行ではないが、より背の高い通過枠を持つ ER/areas 入力で基準 4 を崩す潜在脆弱性。
- 修正: 偏差項を `dev/(dev+1)`（[0,1) へ単調正規化）に変更（`routeAroundObstacles` L471-472）。通過枠交差 1 件(100) を偏差が飛び越えられず厳密辞書式（ノード交差→通過枠交差→偏差）になる。node-cross×10000 の支配は従来同様「通過枠数 < 100」で保証（実グラフの枠数は数個）。単調変換のため偏差の相対順序（＝タイブレーク）は不変。
- 検証: 6 フィクスチャ edges byte 一致（偏差小でソート順不変）。`scoring-probe.mjs` で新式が枠クリア候補を正しく選ぶことを確認。

### 指摘 2（Low・採用）: 設計 §1-6 の端点スタブ ≥8px 保護が未実装だった

- 指摘: 設計 §1-6 は「最初/最後の線分（端点スタブ）を 8px 超に保ち、ポート近傍(<8px)に迂回頂点を置かない」を回避アルゴリズムの Step 6 として明示し、これは #95 cardinality マーカー（`orient="auto-start-reverse"` が終端接線に追従）の配向安定条件。しかし実装は `lo`/`hi` の run 拡張が端点(0 / length-1)まで到達可能で `laneDetour` が端点直後にレーン頂点を挿入し得るのに終端長ガードが無く、成立根拠が実測（終端スタブ最小 87.7px）のみだった。当初「未検証事項」でスコープ外扱いにしていた。
- 妥当性: **妥当**。設計が定めたアルゴリズム手順の欠落であり、意図的省略として「自分で判断した事項」に記録もしていなかった（実測依存の暗黙ギャップ）。ブロッカーの x 帯がポート近傍に来る ER 入力で終端スタブが 8px 未満に縮みマーカー配向が不安定化し得る（本スキルは任意入力を可視化する汎用ツールのため実害）。fix が安価かつフィクスチャ上 no-op のため採用。
- 修正: `stubTooShort(cand, guardLo, guardHi)`（L448）を追加し、端点に接する迂回（`lo===0` / `hi===末尾`）で終端スタブ長 < 8px になる候補を選定ループで棄却（`routeAroundObstacles` L470）。全候補棄却時は迂回せず原スタブを保つ（配向安定を交差解消より優先＝§1-6 の意図）。
- 検証: 6 フィクスチャ edges byte 一致・終端スタブ最小 87.7px 不変（発火せず）。`guard-probe.mjs` で実 `laneDetour`（ブロッカー x 帯がポートを跨ぐ幾何）が 5px 終端スタブを生み `stubTooShort` が棄却することを確認（幾何単体 6/6 PASS）。

### 系譜（branch-visualize）への影響

本 2 修正は障害物回避の後処理レイヤ（structure-visualize 固有）内。branch-visualize の template（521 行）は `routeAroundObstacles`/`stubTooShort`/`laneDetour`/`crossCount` を 0 件（obstacle-avoidance 層を持たない）— 同期不要（CLAUDE.md 系譜ノートの「レイアウトエンジン不具合」にも非該当）。

## 未検証事項

- インタラクティブ挙動（クリック詳細パネル・hover ハイライト・ズーム/パン）はブラウザドライバ不在のため未検証（本 Issue スコープ外・本変更は非接触）。
- 交差検査は点列（直線スパン）に対する判定で、実描画のベジェは僅かに膨らむ。本フィクスチャの迂回レーンは共線頂点が多く直線に潰れるため乖離は小さいが、厳密一致ではない（視覚の正はスクリーンショット目視）。
- 上抜け/下抜けの選好規則・マージン等は本 6 フィクスチャで検証。フィクスチャ外の任意入力での破綻可能性は保証範囲外（設計 §6 と同じ）。ただし基準 4（frame-cross）と端点スタブ ≥8px（§1-6）はレビュー指摘 1・2 で加算重み正規化・`stubTooShort` を入れ、フィクスチャ外でも構造的に頑健化した。
