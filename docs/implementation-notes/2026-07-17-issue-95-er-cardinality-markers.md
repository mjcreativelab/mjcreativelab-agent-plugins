# 実装ノート: Issue #95 structure-visualize ER カルディナリティ端点マーカー

日付: 2026-07-17 (JST)
Issue: #95 `structure-visualize: ER 図のカルディナリティを端点マーカー（鳥の足記法）で表現する`
ブランチ: `feature/issue-95-er-cardinality-markers` / diff 基準: `origin/main`(f0cd755)
前提ノート: `docs/implementation-notes/2026-07-17-issue-94-edge-routing-avoidance.md`（PR #99・折れ線迂回込み 729 行テンプレート）

## 結論

`edges[].cardinality`（`"<from>..<to>"` 形式・端点 ∈ `1`/`n`/`0..1`/`0..n`）を新設し、両端に IE 記法（鳥の足）の SVG マーカーを描画。矢じり競合は **(a) 矢じりをマーカーに差し替え** を採用。色追従は `stroke="context-stroke"` で既存 hover 機構に自動追従（シンボルごと単一マーカー定義）。cardinality 無しエッジは `__SV_DEBUG__` バイト単位一致で従来と完全同一。受け入れ基準 7 項目すべて充足。

## 変更ファイル（2 ファイル・無関係変更なし）

- `skills/structure-visualize/assets/diagram-template.html`（+32 行・729→761 行、800 行目安内）
  - **defs**: カルディナリティ端点マーカー 4 種（`card-one` 縦棒 / `card-many` 鳥の足 / `card-zero-one` 丸+縦棒 / `card-zero-many` 丸+鳥の足）を追加。`orient="auto-start-reverse"`・`markerUnits="userSpaceOnUse"`・`stroke="context-stroke"`。
  - **JS ヘルパ**: `cardinalityEnds(spec)`（+ `CARD_MARKER` マップ）。正規表現 `/^(0\.\.)?([1n])\.\.(0\.\.)?([1n])$/` で `"<from>..<to>"` を各端点シンボル ID へ対応づけ、不正・未知値は `null`。
  - **`drawEdge`**: `cardinalityEnds(edge.cardinality)` が非 null のとき `path.style.markerStart/markerEnd` に該当マーカーを設定（矢じりを差し替え）。null は従来の CSS 既定（`marker-end: url(#arrow)`）のまま。
- `skills/structure-visualize/references/html-guide.md`（+5/-2 行）
  - スキーマ表: `edges[]` 行の label 説明から「カルディナリティ」を削除し、`edges[].cardinality` 行を新設（形式・値域・シンボル・フォールバックを記載）。
  - ER 図の作図指針: 「label にカルディナリティ」→「`cardinality` で多重度（鳥の足シンボル）、`label` は関係名」に更新。

## 受け入れ基準ごとの対応

1. **GRAPH JSON 拡張（完全後方互換）**: `edges[].cardinality` を新設。パーサ `cardinalityEnds` が正規表現で厳密検証し、不正・未知値・非文字列・区切り不足はすべて `null`（マーカー無し＝従来の矢じり描画にフォールバック。console 出力なし）。ユニットテストで有効 10 種 + 無効 21 種を検証（後述）。
2. **端点シンボルの描画**: 4 マーカーで `1`=縦棒 / `n`=鳥の足 / `0..1`=丸+縦棒 / `0..n`=丸+鳥の足 を実装。視覚確認で全 4 種が正しい形・向き（鳥の足はノード側に開き feet がノード境界、丸は max シンボルより外側）で描画されることを確認。
3. **label と cardinality の併用**: `drawEdge` は既存の label 描画ブロックを変更せず、マーカー設定を追加しただけ。フィクスチャ `er-cardinality`（`places`/`line of` ラベル + cardinality）で両立を視覚確認。
4. **cardinality 無しエッジは現状と完全一致**: マーカー設定は cardinality が有効なときだけ実行。`__SV_DEBUG__`（mode/nodes/boxes/size/edges）が 4 フィクスチャすべてで baseline とバイト単位一致（レイアウト・経路不変）。フォールバック視覚確認で矢じり（塗り三角）が従来通り描画。
5. **矢じり競合解決 — (a) を採用**: 下記「(a) vs (b) の比較と選択理由」。
6. **hover 色追従**: `stroke="context-stroke"` により、マーカーが参照元 path の計算済み stroke 色を継承。既存の `svg.focus path.edge.hi { stroke: var(--accent) }` が stroke を変えると、context-stroke マーカーが自動でアクセント色に追従する（`#arrow`/`#arrow-hi` の二重定義と同じ効果を単一マーカーで達成）。検証方法と結論は下記。
7. **html-guide.md 更新**: 上記のとおりスキーマ表に cardinality 行追加 + ER 作図指針を更新。

## (a) vs (b) の比較と選択理由（受け入れ基準 5）

- **(a) 矢じりをマーカーに差し替え（SVG marker）** ← 採用
- **(b) 経路接線から手動グリフ描画**

(a) を採用。理由:

1. **オーケストレーター指示（#98 前方互換）への適合**: SVG marker の `orient="auto-start-reverse"` はパス終端の接線に自動追従する。曲がったパスでも端点シンボルが接線角に沿うことを de-risk・本描画の両方で確認済み。後続 Issue #98（グループ内障害物回避＝経路形状の再変更）に手戻りなく追従する。(b) は pts 配列から接線角を手計算するため、経路生成が変わるたび呼び出し箇所の追従が要る。
2. **hover 色追従を既存機構で達成**: `context-stroke` により hover 時の stroke 変更へ自動追従（受け入れ基準 6）。(b) の手動グリフでも同様は可能だが、`.hi` 時の再描画/色切替を自前で管理する必要があり複雑。
3. **外科的・最小コード**: 既存の `#arrow`/`#arrow-hi` マーカーパターンをそのまま踏襲。追加は defs 4 マーカー + パーサ 8 行 + `drawEdge` 4 行のみ（+32 行）。(b) は各端点セグメントの角度計算・回転 transform・座標変換を drawEdge に持ち込み、行数と分岐が増える。

(a) の唯一の留意点（矢じりとの併存）は、cardinality 有効エッジで `path.style.markerStart/End` をインライン設定することで解決。インラインスタイルは CSS の `.hi` ルール（`marker-end: url(#arrow-hi)`）より優先されるため、ハイライト時も card マーカーが維持され、stroke 変更経由で色だけ追従する。cardinality 無しエッジはインライン設定しないため `#arrow`/`#arrow-hi` の従来挙動が完全に保たれる。

## hover 色追従の検証方法と結論（受け入れ基準 6）

ブラウザドライバ不在のため、(i) コードリーディング + (ii) 強制 hi 描画の 2 系統で検証:

- **(i) コードリーディング**: マーカー内の glyph は `stroke="context-stroke"`。SVG2 の context-stroke は「マーカーを参照する図形要素の計算済み stroke」を継承する。`path.edge` の stroke は通常 `var(--edge)`、`svg.focus path.edge.hi` で `var(--accent)` に変わる（stroke はインライン未設定なので `.hi` ルールが適用される）。よってマーカー色は既存 hover の stroke 変更に追従する。`-hi` 版マーカーは不要。
- **(ii) 強制 hi 描画（実証）**: 描画済み HTML に全エッジへ `.hi` + svg に `.focus` を付与するスクリプトを注入して撮影。エッジ線とともに端点シンボル（鳥の足・縦棒・丸+縦棒）がすべてアクセント青（#79c0ff）に変わることを確認（非 hi 時はグレー #4a566a）。→ context-stroke による色追従が end-to-end で成立。

de-risk 段でも、同一マーカーを参照する 2 本の path に別 stroke 色（グレー/青）を与えるとマーカー色が個別に追従することを確認済み（context-stroke の Chrome 対応の実測）。

## 自分で判断した事項

1. **cardinality 文字列の文法と曖昧性解消（正規表現）**: 仕様は `"<from>..<to>"` 形式・各端点 ∈ `1`/`n`/`0..1`/`0..n`・例 `"n..1"`。区切りが `..` で端点自身に `..` を含む（`0..1`）ため単純 split は曖昧。正規表現 `^(0\.\.)?([1n])\.\.(0\.\.)?([1n])$` で「各端点＝任意の `0..` 接頭 + `1|n`、端点間は `..`」と解釈し一意にパース（例: `"0..n..1"`=from `0..n`/to `1`、`"1..0..n"`=from `1`/to `0..n`）。ユニットテストで全 10 組合せ + 無効 21 種を検証。
2. **矢じり差し替えを「単一マーカー + context-stroke」で実装**: 受け入れ基準 6 が求める hover 色追従を、`#arrow`/`#arrow-hi` の 2 重定義ではなく context-stroke による自動継承で実現。マーカー定義数を 8（4 シンボル×2 色）から 4 に削減し、色切替ロジックを持たない。
3. **マーカーのサイズ基準 `markerUnits="userSpaceOnUse"`**: 既定（strokeWidth 単位）だと hover 時に stroke-width が 1.3→1.8 に増えマーカーも肥大する。userSpaceOnUse で固定 16 ユーザー単位とし、hover では色のみ変わり大きさは不変（基準 6 は色追従のみ要求）。ズームには viewport transform 経由で図全体と一緒にスケールする。
4. **マーカー配置**: refX=14（=ノード境界）に feet/縦棒側を置き、apex/丸を図中央側（低 x）に配置。IE 記法の慣習（max シンボル＝縦棒/鳥の足はエンティティ側、min シンボル＝丸はより外側）に一致。座標は視覚確認で判読可能と確認（微調整の必要なし）。
5. **html-guide.md の JSON 例（infra 構成）は無変更**: cardinality は ER 専用のためインフラ例の SQL エッジに付けると誤解を招く。スキーマ表の cardinality 行（形式 + 例 `"n..1"`）と ER 作図指針で文書化し、基準 7 を満たしつつ例文は据え置き。
6. **フィクスチャ設計**: `er-cardinality`（4 エッジで 4 シンボル全網羅 + 2 エッジに関係名ラベル）で基準 2/3、`card-fallback`（有効 + 無効 `"bogus"` + 欠落）で基準 1/4 のフォールバックを視覚実証。元 `er-flow` は後方互換テスト用に無変更。
7. **恒久実装ノートの作成**: リポジトリ規約（CLAUDE.md）と Issue #94 の先例に倣い `docs/implementation-notes/2026-07-17-issue-95-er-cardinality-markers.md` を作成（本ファイルと同内容）。オーケストレーターのコミットに含める想定。

## テスト結果（ベースライン比較）

検証方式は Issue #94 で確立した「使い捨てハーネス（fixtures + `render.mjs` + `test-layout.mjs` + `label-check.mjs`）+ ヘッドレス Chrome」。ハーネスはリポジトリにコミットしない。Node 実行は `mise exec node`。

### ベースライン（変更前テンプレート = 現 HEAD f0cd755 の 729 行）

- 既存不変条件（report-only）: **4/4 PASS**。
- エッジ交差: `node-cross=9 (flow=2 sibling=6 unrelated=1) frame-cross=1`（infra=3 / er-flow=2 / component=4+1frame / plain=0）。Issue #94 実装ノートの記録と完全一致。
- 厳格ゲート（`SV_EDGE_GATE=1`）: 3/4 FAIL（既存状態・Issue #94 でスコープ外と決定済み。本 Issue 非関与）。

### 変更後（761 行）

- **既存不変条件（元 4 フィクスチャ・report-only）: 4/4 PASS（回帰なし）**。
- **エッジ交差（元 4 フィクスチャ）: `node-cross=9 (flow=2 sibling=6 unrelated=1) frame-cross=1` — baseline と完全一致**（マーカーは経路を変えない＝回帰なしの根拠）。
- **`__SV_DEBUG__` 形状: 4 フィクスチャすべてで baseline とバイト単位一致**（keys/mode/nodes/boxes/size/edges 不変。cardinality キーの追加なし）。
- **新フィクスチャ `er-cardinality`: PASS**。交差 `node-cross=2 (flow=2)` は同一トポロジの er-flow と同値。`__SV_DEBUG__` も er-flow と一致 → **cardinality フィールドはレイアウトに非影響**。
- **パーサ・ユニットテスト**: `cardinalityEnds` を実テンプレートから抽出し、有効 10 種（全端点組合せ）→ 正しいマーカー ID、無効 21 種（`"bogus"`/`"1..2"`/`"0..0"`/`"1"`/空/非文字列/`null` 等）→ `null`。**ALL PASS**。
- **ラベル退避（label-check）**: 元 4 フィクスチャで baseline と同値（component-areas の 7px 近接 `"操作"~"uses"` は Issue #94 由来の既知事項・本変更非関与）。
- **視覚確認（ヘッドレス Chrome 1600×1000）**:
  - `er-cardinality`: 縦棒 / 鳥の足 / 丸+縦棒 / 丸+鳥の足 の 4 種が正しい形・向き（鳥の足がノード側に開く・丸が外側）で描画。ラベルと併存、矢じり無し。
  - `card-fallback`: 有効 `"n..1"` は端点シンボル、無効 `"bogus"` と cardinality 欠落は従来の矢じり（塗り三角）。混在で正しくフォールバック。
  - 強制 hi 描画: 端点シンボルがエッジ線とともにアクセント青に追従（基準 6 実証）。
- **構文 `node --check`: OK** / **行数: 761（≤800）**。

## branch-visualize 系譜チェック（CLAUDE.md「スキル改修時の注意」）

**結論: cardinality マーカーは branch-visualize の `--models`（HTML 形式）にも概念的に該当する。ただし本 Issue ではスコープ外（報告のみ）で、レイアウトエンジン修正ではないため必須同期の対象外**。

- branch-visualize は `--models` モードでクラス図 / ER 図を描画し（`type: table/class/...`）、`format-guide.md:131` で `edges[].label` にカルディナリティ（`1..n` 等）を書く設計。その HTML 出力テンプレート（`assets/diagram-template.html`）は structure-visualize と同系譜 fork。→ 同じ端点マーカー拡張が **branch-visualize の HTML 形式 ER/クラス図にも適用可能**。
- 一方 branch-visualize は Mermaid / D2 出力も持ち、それらは native のカルディナリティ記法（Mermaid `USER ||--o{ ORDER` = `format-guide.md:205`）を既に使う。マーカー拡張が必要なのは HTML 形式のみ。
- CLAUDE.md の系譜同期ルールは「**レイアウトエンジン（レイヤリング・交差削減・ポート分散・ズーム/パン）の不具合修正**」を片方で行ったらもう片方に該当を確認、というもの。本変更は新規描画機能（defs マーカー + `drawEdge` へのマーカー設定 + パーサ）で共通レイアウトエンジンに非接触のため、**必須同期の対象外**。
- 実装移植性: 追加要素（defs 4 マーカー・`cardinalityEnds`・`drawEdge` の 4 行）は自己完結で、branch-visualize の drawEdge へも小さな適応で移植可能。**推奨: branch-visualize の HTML 形式 ER 出力に端点マーカーを入れるなら別 Issue 化**（本 Issue はスコープ外のため未着手）。

## プロジェクト固有基準の確認

- **自己完結 HTML**: 追加は SVG marker 定義（インライン）と JS ロジックのみ。CDN・外部 API・外部フォント追加なし。context-stroke（SVG2 context paint）のマーカー内容での対応は Chrome/Edge 124（2024-04）・Safari・Firefox（2024–2025）と比較的新しく、テンプレート内の他機能（backdrop-filter 等・2022 年頃までに普及）より最小ブラウザ要件を一段引き上げる。未対応の古いブラウザでは端点シンボルが不可視になりエッジ線のみになる（矢じりのハードコード塗りとは非対称のサイレント劣化）。ローカルの現行版ヘッドレス Chrome（150・context paint 対応）で描画・色追従を実測。未対応ブラウザの挙動は web 参照（MDN `<marker>` / Chrome 124 リリースノート / Mozilla bug 752638）に基づき、ローカルでは未再現。
- **`__SV_DEBUG__` は恒久検証ハンドル**: 既存キー不変・cardinality の追加公開なし（レイアウト非影響のため）。before/after バイト単位一致で確認。
- **コードコメントは最終仕様のみ**: 追加コメント（マーカー defs・パーサ）は最終仕様のみ記述。履歴・変更理由なし。
- **行数**: 761 行（800 行目安内）。`node --check` OK。

## レビュー指摘の対応: context-stroke 依存による端点シンボルの劣化（Low）

設計レビューで「端点シンボル 4 種は `fill="none"` + `stroke="context-stroke"` のため、SVG context paint 非対応レンダラでシンボルが不可視になる（矢じりのハードコード塗りと非対称のサイレント劣化）。impl-notes の『Chrome 97+』表記も過小」との指摘を受けた。

**判定: 採用（文書対応で解決。コード変更＝二重マーカー化は不採用）。**

- **事実の訂正（採用）**: 最小ブラウザ要件を web で検証したところ、マーカー内容での context paint 対応は Chrome/Edge 124（2024-04）・Safari・Firefox（2024–2025）で、impl-notes の『Chrome 97+』も指摘の『105+』もいずれも誤り。正しい値（124 / 2024-04）へ「プロジェクト固有基準の確認」節を訂正し、`html-guide.md` の ER 図節に描画要件の注記を追加した。
- **劣化の非対称性（採用・受容）**: 指摘のとおり非対応レンダラでは端点シンボルが不可視になりエッジ線のみになる（矢じりは常に描画）。ただし 2026 時点で主要ブラウザの現行版はすべて対応済みで、対象は約 2 年以上前のバージョン。自己完結 HTML は生成者が現行ブラウザで閲覧する用途が主で、スキルの描画・検証もヘッドレス Chrome（現行版）のため実運用リスクは Low。意識的なトレードオフとして受容し、要件（`html-guide.md`）と本ノートに明記する方針を採る。
- **コード変更（不採用・オーバーエンジニアリング）**: 指摘の選択肢 (b)「二重マーカー（ハードコード塗り + normal/hi 色切替）」は普遍描画を回復するが、(1) マーカー定義を 4→8 に倍増し、(2) hover 色追従を context-stroke の自動継承ではなく、インラインで設定した markerStart/markerEnd を `.hi` 時に -hi 版へ差し替える JS を新設する必要があり、受け入れ基準 6 を満たす現行の単一マーカー設計（「自分で判断した事項」2 で意図的に選択）を後退させる。Low severity かつ縮小中の対象に不釣り合いのため不採用。CSS フォールバック（`stroke: #4a566a; stroke: context-stroke;`）も検討したが、非対応ブラウザでフォールバックが効くかは手元の現行 Chrome では検証不能（未対応レンダラが無い）なため、未検証の複雑性追加は避けた。

本対応はドキュメントのみの変更（`html-guide.md` + 本ノート）で、テンプレート（生成 HTML）は不変。よって既存のレンダリング / ハーネス検証結果はそのまま有効で、機能面の再テストは不要（`git status` でテンプレートに変更なしを確認）。

## 未検証事項

- 実マウス操作の hover（ブラウザドライバ不在）は未実施。代替として (i) コードリーディング + (ii) 強制 hi 描画で色追従を実証済み。クリック詳細パネル・ズーム/パンは本変更非接触（drawEdge のマーカー設定のみ追加）。
- 交差検査は点列（直線スパン）判定で実描画ベジェとは厳密一致しない（Issue #94 と同じ既知の限界）。視覚の正はスクリーンショット目視。
