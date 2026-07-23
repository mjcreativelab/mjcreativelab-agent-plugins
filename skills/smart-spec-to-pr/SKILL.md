---
name: smart-spec-to-pr
description: >
  「やりたいこと」を起点に、要件明確化 → spec 承認ゲート → Issue 起票 →
  既存スキル連鎖（software-architect → smart-issue-plan → smart-issue-resolve）→ PR 作成
  の順で進行を管理する薄い conductor スキル（副作用あり: GitHub Issue 起票・コメント投稿）。
  各フェーズの中身（設計・計画・実装・レビュー）は既存スキルが持ち、本スキルは進行・受け渡し・
  ゲートのみを担う（フェーズロジックを複製しない）。終点は PR 作成で、マージ・デプロイはスコープ外。
  AskUserQuestion / Skill ツールに依存する Claude 専用スキル（他エージェントでは動作しない）。
  ユーザーが「やりたいことから PR まで通して」「要件を固めて実装まで進めて」「/smart-spec-to-pr」と言ったら起動する。
  計画だけなら smart-issue-plan、Issue から実装なら smart-issue-resolve を直接使う（本スキルはその前段の要件明確化から束ねる）。
disable-model-invocation: true
argument-hint: "[やりたいことの説明] [--claude-review-loop|-cldrl] [--claude-adv-review-loop|-cldarl] [--codex-review-loop|-cdxrl] [--codex-advs-review-loop|-cdxarl]"
allowed-tools: Read, Write, Bash, AskUserQuestion, Skill
---

# smart-spec-to-pr — 要件明確化から PR 作成までの conductor

「やりたいこと」を起点に、**要件明確化 → spec 承認 → Issue 起票 → 既存スキル連鎖 → PR 作成**までの進行を管理する。
各フェーズの本体（設計・計画・実装・レビュー）は既存スキルが担い、本スキルが持ち込むのは**進行管理・受け渡し・ゲート**だけである（フェーズロジックは複製しない）。

**終点は PR 作成**。マージ・デプロイはスコープ外。

## 制御の実態（半自動ハンドオフ）

conductor が 1 ターンで制御を保持できるのは **Phase 1 〜 3b** まで。理由:

- `smart-issue-plan` / `smart-issue-resolve` は `disable-model-invocation: true` のため、conductor（モデル実行）が Skill ツールで起動できない。**Skill 起動できる連鎖先は `software-architect` のみ**（Phase 3a）
- Skill 起動にはコールスタック・リターンの意味論が無い。conductor がハンドオフ用コマンドを印字した時点でターンが終わり、ユーザーの手動実行後に制御が conductor へ戻る機構は無い
- したがって Phase 3c/d では、次段コマンドと終点チェックリストを**ユーザー向け手動ランブック**として一括提示してターンを終える。**「ハンドオフ後に結果で分岐する / ゲートを強制する / 起票済み Issue を追跡・後始末する」記述は書かない**（到達不能なため）

| Phase | 担い手 | 内容 | conductor の制御 |
|---|---|---|---|
| 1 要件明確化 → spec 承認 | conductor（本ファイル） | AskUserQuestion で掘り下げ → spec 化 → 承認ゲート | 保持 |
| 2 Issue 起票 | conductor（pipeline.md） | `issue_write` で spec 全文を Issue 本文に | 保持 |
| 3a 設計 | conductor（pipeline.md） | Skill で `software-architect` 起動 → 出力を Issue コメント化 | 保持 |
| 3b レビューモード確定 | conductor（pipeline.md） | 未指定ならレビューループを AskUserQuestion で確定 | 保持 |
| 3c/d ハンドオフ | ユーザー手動 | plan / resolve コマンド + 終点チェックリストを提示してターン終了 | 手放す |

Phase 2 以降の詳細手順は [references/pipeline.md](references/pipeline.md) にある。**Phase 1 の承認ゲートを通過するまで読み込まない**（下記「物理ゲート」）。

## 引数の解析

`$ARGUMENTS` を次のルールで解析する:

- **レビューループフラグの検出**: 空白区切りトークンのうち、次のいずれかに**完全一致**するトークンだけをフラグとして識別する（トークン境界 ＝ 前後が空白または文字列端。より大きなトークンの部分文字列や、地の文にフラグ名を含む言及は対象外）:

  | フラグ | 別名 | 意味 |
  |---|---|---|
  | `--claude-review-loop` | `-cldrl` | Claude 標準レビューループ |
  | `--claude-adv-review-loop` | `-cldarl` | Claude 敵対的レビューループ |
  | `--codex-review-loop` | `-cdxrl` | Codex 標準レビューループ |
  | `--codex-advs-review-loop` | `-cdxarl` | Codex 敵対的レビューループ |

  - 検出したフラグは `{レビューループ指定}` として保持し、Phase 3c のコマンド 2 へ**そのまま（verbatim）転送**する。複数指定時の優先順位・セキュリティ影響による自動昇格などの解決は **`smart-issue-resolve` 側の責務**であり、本スキルでは複製しない
  - フラグ名は `smart-issue-resolve` の `argument-hint` を正本として参照する（本スキルで独自にフラグを固定増設しない）
- **やりたいことの説明**: フラグと識別したトークンを除いた残りのテキストを `{やりたいこと}` とする。空なら Phase 1-2 の AskUserQuestion で聞き出す
- 単独トークンのフラグ名が説明の一部として言及されているだけと疑われる場合（例: `smart-issue-resolve の --claude-review-loop の挙動を直したい`）は、**そのトークンをフラグ扱いせず `{やりたいこと}` に残し**（説明シードを欠損させない）、レビューモードも勝手に固定せず、Phase 3b の確定時にユーザーへ意図を 1 度確認する

## ツール選択

要件明確化・承認は AskUserQuestion、spec ファイル操作は Read / Write / Bash を使う。`software-architect` の起動は Skill ツール（Phase 3a）。GitHub API 操作（Phase 2 以降）は GitHub MCP ツール（`issue_write` / `search_issues` / `add_issue_comment` / `get_me` 等）を使い、`gh` CLI との混在を避ける（読み取り系の `gh` 代替は許容）。

## Phase 1（本体）: 要件明確化 → spec 承認

Phase 1 が本スキルの本体である。ここで固めた spec が Phase 2 で Issue 本文（以降の全スキルにとっての永続正本）になるため、曖昧さを残したまま先へ進めない。

### 1-1. 作業ディレクトリの作成

`mktemp -d "${TMPDIR:-/tmp}/sstp-<スラグ>.XXXXXX"` で `{作業Dir}` を作成する（`<スラグ>` は `{やりたいこと}` から作る短い英字スラグ。OS の一時領域で、スキル側に削除手順は持たない）。spec の作業正本は `{作業Dir}/spec.md` のみに置く。**`docs/specs/` へ直接書かない**（working tree を汚すと下流 `smart-issue-resolve` の未コミット変更検出と衝突するため）。

### 1-2. 要件明確化（AskUserQuestion）

`{やりたいこと}` を起点に、AskUserQuestion で「誰の・どんな課題を・何で解決するか」「機能要求」「非機能要求（性能・セキュリティ・保守性）」「制約・スコープ外」「受け入れ基準（検証可能な合否条件）」を掘り下げる。回数上限は設けない（解像度が上がるまで続ける）。`{やりたいこと}` が空なら最初の質問で対象そのものを聞き出す。

- 曖昧さ・複数解釈がある箇所は黙って 1 つに決めず、選択肢として提示して確認する
- ユーザーが確定した事項はその都度 `{作業Dir}/spec.md` に反映する（会話はワーキングメモリ、spec.md が正本）

### 1-3. spec 化

[assets/spec-template.md](assets/spec-template.md) を土台に `{作業Dir}/spec.md` を作成・更新する。見出しセット（概要 / 用語 / 機能要求 / 非機能要求 / 制約 / 受け入れ基準）に沿い、**自己完結した文書**として書く（会話コンテキストを前提にしない ＝ この全文が Issue 本文になる）。該当内容が無い章は見出しごと省略してよいが、順序は入れ替えない。

### 1-4. spec 承認ゲート（唯一のブロッキング承認）

`{作業Dir}/spec.md` の**全文**をユーザーに提示し、AskUserQuestion で次を確認する:

- **承認** → `TZ=Asia/Tokyo date '+%Y-%m-%d'` を実行して日付を得て、`spec.md` 末尾に `## Phase 1 確定（<日付> JST）` セクションを追記する（**物理ゲートの印**。確定した spec の要約・想定スラグを 1〜2 行添える）。その後「物理ゲート」に従って Phase 2 へ進む
- **修正** → 指示を反映して 1-3 に戻り、再度全文提示する
- **中止** → ここで終了する（Issue 起票以降を一切行わない。`{作業Dir}` は OS の一時領域に残して構わない）

## 物理ゲート（Phase 1 → 2）

**`{作業Dir}/spec.md` に `## Phase 1 確定` セクションが存在しない状態で [references/pipeline.md](references/pipeline.md) を Read しない。** 存在を確認してから pipeline.md を読み、Phase 2 以降を実施する（`business-ideation` のフェーズ境界ゲートと同型）。承認前に後続フェーズの詳細手順を先読みしないことで、承認ゲートを物理的に機能させる。

## 承認ゲートの位置づけ

conductor が追加で設けるブロッキング承認は **spec 承認（1-4）のみ**。連鎖先スキル自身の対話（`software-architect` の明確化質問、`smart-issue-plan` / `smart-issue-resolve` 自身の確認）は通常どおり発生するが、それらは conductor が課す追加のブロッキング承認ではない（各スキルの通常挙動）。

## 注意事項

- フェーズロジックを複製しない（進行・受け渡し・ゲートのみ持ち込む）。レビュー観点・優先順位解決・実装フローなどは連鎖先スキルの責務
- spec は `{作業Dir}` の一時領域のみに置く（決定的パスや `docs/specs/` への直接書き込みをしない）。Phase 2 以降の正本は Issue 本文
- レビューループ「なし」を選んだ場合でも、conductor が git 直接操作（コミット・push・PR）を代行しない（連鎖先スキルの安全設計を上書きしない）
- スキル手順に `rm -f` 等の破壊的コマンドを含めない（一時ファイルは OS の一時領域に任せる）
