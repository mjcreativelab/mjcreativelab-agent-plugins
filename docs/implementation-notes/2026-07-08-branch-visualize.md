# 実装ノート: branch-visualize スキル

日付: 2026-07-08 (JST)
仕様: `docs/superpowers/specs/2026-07-08-branch-visualize-design.md`（gitignore 対象のローカル文書）

## 仕様に明記されておらず実装時に判断した事項

| 判断 | 内容 | 理由 |
|---|---|---|
| `unchanged` 状態の追加 | 仕様の中間表現は added / modified / removed の 3 状態だったが、4 状態目として `unchanged`（⚪ 関連・未変更）を追加した | 仕様が要求する「直接の関連範囲（呼び出し元・呼び出し先）」は未変更コードであり、図に含める際の視覚状態が必要 |
| 配色 | GitHub の diff 配色系（緑 `#dafbe1`/`#1a7f37`、黄 `#fff8c5`/`#9a6700`、赤 `#ffebe9`/`#cf222e`）を採用 | レビュアーが GitHub の diff 表示で見慣れた色対応と揃え、凡例なしでも直感的に読めるようにするため |
| HTML のレイアウト方式 | レイアウトエンジンを同梱せず、生成側が type 別カラム（library=40 / module・component=380 / model=720、y=40+i×90、15 ノード超で +190 折り返し）で静的座標を計算して JSON に埋め込む | 外部 CDN 禁止の制約下で汎用レイアウトライブラリを同梱すると テンプレートが肥大化する。ノード数 40 超程度なら列レイアウトで十分読める |
| プレースホルダ置換方式 | テンプレートは `__TITLE__` / `__GRAPH_JSON__` の 2 箇所置換のみ。SVG 要素は実行時に JS がデータから生成する | スキル側の生成処理を「JSON を作って 2 箇所置換」に単純化するため（SVG マークアップをスキルが直接組み立てない） |
| D2 の構文検証 | format-guide の D2 雛形は `classes` マップ + `class:` 割り当て（d2 v0.6+ 構文） | v0.7.1 で実コンパイルし構文が通ることを確認済み |

## 検証結果（このセッションで実行・確認済み）

- **HTML テンプレート**: 埋め込み JS を抽出し `node --check` で構文 OK。サンプル 5 ノード + 実ブランチ 7 ノードの 2 データで headless Chrome レンダリングし、状態別配色・破線・凡例・矢印エッジを目視確認。合成イベント（MouseEvent / WheelEvent）でクリック→詳細パネル表示・選択強調・ホイールズーム・ドラッグパンの全動作を確認（`panel:block|panel-has-dl:true|selected:true|zoomed:true|panned:true`）
- **Mermaid**: 生成レポートのダイアグラムを mermaid v11（CDN・検証時のみ使用）+ headless Chrome で `mermaid.parse()` → `mermaid.run()` し、パース・SVG 生成とも成功
- **E2E（自ブランチ）**: `feature/add-branch-visualize-skill` vs `main` に SKILL.md 手順 1〜8 を手動トレース。base 自動解決（`origin/HEAD` → main）、diff 取得（6 ファイル +554/−1）、ノード数 7 → mermaid 自動選定、出力先作成の AskUserQuestion ゲート、レポート生成まで仕様どおり動作
- **`--format html` 分岐**: 実ブランチデータでテンプレート置換 → 描画確認済み
- **`--format d2` 分岐**: `.d2` ソース生成 + d2 CLI 不在時の「ソースのみ保存」パスを確認。その後 mise 経由の d2 v0.7.1 で同ソースをコンパイルし SVG 生成も成功（構文の裏取り）
- **配布検出**: `npx skills add ./ --list` で `branch-visualize` を検出。SKILL.md は 147 行（500 行制限内）、frontmatter `name` はディレクトリ名と一致

## 未検証事項

- 他エージェント（Codex / Cursor / Gemini CLI）へ npx install した場合の動作（AskUserQuestion のテキスト degrade を含む）
- GitHub MCP 経由の open PR base 自動解決（このセッションでは PR 未作成のため経路を通していない）
- GitHub 上での Mermaid レンダリング（push 後にブランチの blob 表示で確認可能）
- Skill ツール経由の起動（本リポジトリでは `.claude/skills/` 未配置のため手動トレースで代替。ローカル install 後の実利用時に確認する）

## 検証生成物の扱い

`docs/branch-diagrams/feature-add-branch-visualize-skill-2026-07-08.{md,html,d2}` は E2E 検証の生成物。スキル仕様（生成物はコミットしない）に合わせて未追跡のまま残している。リポジトリに残すかどうかはレビュー時に判断する。
