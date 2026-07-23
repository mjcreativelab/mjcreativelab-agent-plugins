# 実装ノート: Issue #119 smart-spec-to-pr conductor スキル

作成日: 2026-07-23 (JST)
ブランチ: feature/issue-119-spec-to-pr-conductor

## 概要

「やりたいこと」の要件明確化から PR 作成までを既存スキル連鎖で進める薄い conductor スキル `smart-spec-to-pr` を新設した。conductor が持つのは進行管理・受け渡し・ゲートのみで、フェーズロジック（設計・計画・実装・レビュー）は既存スキルに委ねる。実装方式は計画どおり「半自動ハンドオフ方式」。

## 変更ファイル

| ファイル | 種別 | 内容 |
|---|---|---|
| `skills/smart-spec-to-pr/SKILL.md` | 新規 | Phase 1（要件明確化 → spec 化 → 承認ゲート）本体 + 引数解析 + 制御の実態 + 物理ゲート |
| `skills/smart-spec-to-pr/references/pipeline.md` | 新規 | Phase 2（Issue 起票）〜Phase 3（設計 / レビューモード確定 / ハンドオフ）+ 終点チェックリスト |
| `skills/smart-spec-to-pr/assets/spec-template.md` | 新規 | spec テンプレート（概要 / 用語 / 機能要求 / 非機能要求 / 制約 / 受け入れ基準） |
| `skills/smart-spec-to-pr/README.md` | 新規 | 説明・フロー・使い方・オプション・前提条件 |
| `CLAUDE.md` | 変更 | リポジトリ構造「Git ワークフロー系」に追記 + フラグ名結合のマスター登録を「スキル改修時の注意」に追加 |
| `README.md` | 変更 | スキル一覧表（Git ワークフローグループ）に追記 |

## 受け入れ基準への対応

1. **SKILL.md（frontmatter）+ README.md 追加** → `name` / `description` / `argument-hint` / `disable-model-invocation: true` を設定（`allowed-tools: Read, Write, Bash, AskUserQuestion, Skill`）。README.md も作成
2. **フロー定義・フェーズロジック複製なし** → SKILL.md「制御の実態」の Phase 表と pipeline.md で 5 フェーズを定義。レビュー観点・優先順位解決・実装フローは連鎖先に委ね複製しない
3. **spec 承認ゲートが物理的に機能** → Phase 2 以降の詳細手順を references/pipeline.md へ切り出し、「`{作業Dir}/spec.md` に `## Phase 1 確定` が存在しない状態で pipeline.md を Read しない」物理ゲートを設置（business-ideation 型）
4. **CLAUDE.md 構造 + ルート README.md 追記** → 両方に追記済み
5. **`npx skills add ./ --list` で検出** → 検証済み（Found 22 skills・smart-spec-to-pr 認識）

## 自分で判断した事項（仕様に明記が無かった点）

- **リポジトリ構造・一覧表での配置位置**: `smart-spec-to-pr` を `smart-issue-plan` の直後に置いた（issue フローの前段 conductor として隣接させるため）。計画は「Git ワークフロー系に追記」とだけ指定していたため配置は判断。
- **フラグ名結合ノートの挿入位置**: CLAUDE.md「スキル改修時の注意」の「レビュープロンプトの二重化と同期（マスター）」ブロック直後に新規 bullet として追加（フラグ語彙という同期関連トピックの近接配置）。「フル同期対象ではなく名前の結合のみ」と明記し、レビュープロンプト二重化と混同されないようにした。
- **spec-template.md の自己完結ガイド**: テンプレート冒頭に HTML コメントで「この spec が Issue 本文の逐語正本になる／自己完結で書く／design.md 命名の想定」を記載。Phase 2 で本文が逐語コピーされる設計を、テンプレート利用時点で利用者へ伝えるため。
- **引数の曖昧トークン確認**: 単独トークンのフラグ名が説明の地の文として言及されただけと疑われる場合、そのトークンをフラグ扱いせず `{やりたいこと}` に残し（説明シードを欠損させない）、レビューモードも勝手に固定せず Phase 3b の確定時にユーザーへ 1 度確認する、と記述。計画の「トークン境界でフラグ識別」を実装レベルで補足し、フラグ誤識別時の説明シード欠損とレビューモード誤固定の両方を塞いだもの。

## トレードオフ・設計判断

- **allowed-tools に GitHub MCP ツールを列挙しない**: Phase 2 以降で `issue_write` 等を使うが、既存スキル（smart-issue-resolve 等）も MCP ツールを allowed-tools に列挙していない（MCP は個別の許可経路）。既存パターンに合わせ計画どおり `Read, Write, Bash, AskUserQuestion, Skill` のみとした。
- **到達不能記述の回避**: ハンドオフ後の「結果分岐 / ゲート強制 / orphan Issue 追跡」は Skill 起動にリターン意味論が無いため到達不能。pipeline.md では終点チェックリストを「conductor は強制できないため印字で提示」「自動クローズ・ロールバックはしない」と明示し、ユーザー側手動確認として枠づけた。
- **spec を `docs/specs/` へ直接書かない**: working tree を汚すと下流 smart-issue-resolve の未コミット変更検出と衝突するため、spec の作業正本は `{作業Dir}` 一時領域のみ。docs/specs の完全版は実行のたびにユーザーが Issue 本文（永続正本）から手動追補する運用（ユーザー受け入れ済み）。

## テスト結果（ベースライン比較）

コードを持たないドキュメント系スキルのため自動テストは無い。計画で確定済みの静的検証を実行:

- **ベースライン**（実装前）: `npx skills add ./ --list` → Found 21 skills（smart-spec-to-pr 未存在）。既存の失敗なし
- **実装後**:
  1. `npx skills add ./ --list` → Found 22 skills・smart-spec-to-pr 検出（description 正常表示）✓
  2. `head -5 SKILL.md` → frontmatter（name / description）正常 ✓
  3. `grep disable-model-invocation` → smart-issue-plan:13・smart-issue-resolve:16 の frontmatter に `true`、software-architect にヒットなし（= Skill 起動可）✓
  4. コマンド 2 の `-p` 引用文字列にレビューループフラグ語なし・フラグは `-p` 外の末尾プレースホルダ（Python 検証 PASS）✓
  5. pipeline.md Phase 2 に既存 Issue 上書き前の明示確認ゲート存在 ✓
  6. `wc -l SKILL.md` → 104 行（≤500）✓
  7. `git status` → 変更は CLAUDE.md / README.md / 新規 skills/smart-spec-to-pr/ に限定（回帰なし）✓

既存テストの壊れなし（既存ファイルは CLAUDE.md / README.md の追記のみで、既存スキルの動作に影響する変更はない）。
