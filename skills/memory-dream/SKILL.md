---
name: memory-dream
description: >
  エージェントの記憶階層（MEMORY.md・notes・projects 等）を再編し、重複・矛盾・陳腐化を除去する
  consolidation（Anthropic Dreams の手動・git ベース再現）。
  大規模リファクタ直後や 20〜30 セッション蓄積で記憶がノイズ化したとき、
  「記憶を整理して」「dream して」「/memory-dream」で起動。
  --codex-review-loop（-cdxrl）を付けると採用前に Codex レビューループを実施する
  （Claude Code + Codex プラグイン環境前提）。
argument-hint: "[--codex-review-loop|-cdxrl]"
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep, Edit, Write, AskUserQuestion
---

# memory dream（記憶の整理 / consolidation）

git 管理された記憶階層を定期的に再編し、重複・矛盾・陳腐化を除去する作業の手順書。Anthropic Managed Agents の **Dreams**（Claude Code では Auto Dream / `/dream`）を、これらが使えない環境（手動・git ベースの記憶階層）で再現する。

## 引数の解析

`$ARGUMENTS` を解析する:

- `--codex-review-loop` または `-cdxrl` → `{レビューモード}` を `standard` にする
- 指定がない場合 → `{レビューモード}` は `off`

例: `/memory-dream --codex-review-loop` → レビューモード: standard

## これは何か / なぜ必要か

エージェントはセッションごとに記憶へ追記する。追記は局所的・増分的なので、20〜30 セッションを超えると memory store に**重複・矛盾・陳腐化エントリ**が溜まり、ノートが「思い出す助け」から「混乱させるノイズ」へ転落する（相対日付の意味喪失、削除済みファイルを指す古い手順など）。

Dreams は人間の REM 睡眠による記憶定着のメタファ。過去セッションと既存 store を読み、**重複をマージ・古い/矛盾する値を最新で置換・繰り返しパターンを簡潔な知見として抽出**した新しい store を生成する。本家 API では入力 store を決して書き換えず、出力は別 store としてレビューしてから採用する（opt-in）。

## 原則

1. **入力非破壊**: 変更は論理単位ごとの commit に分離し、revert 可能な状態を保つ。push はユーザーの明示指示まで保留する
2. **採用前レビュー必須**: consolidation の出力には hallucination が混入しうる。commit をユーザーがレビューしてから採用する（`{レビューモード}` が `standard` の場合は、その前段に Codex レビューループを挟む）
3. **記憶の再編であって fine-tune ではない**: 変わるのは外部記憶のみ。モデルは変わらない

## Phase 0: 対象階層の確認（ゲート）

以降のフェーズに進む前に、次をすべて満たすこと。

1. **記憶階層のルートを特定する**。環境の常時ロード指示（AGENTS.md / CLAUDE.md / MEMORY.md 等）が記憶階層とその場所を定義していれば、それに従う。特定できない場合は**ユーザーに確認して止まる**（推測で進めない）
2. ルートが **git 管理下**であり、`git status --short` が clean であることを確認する。未コミット変更が残っている場合はユーザーに扱いを確認する
3. **レイヤ一覧と各レイヤの役割**（ロード順・更新可否）を列挙し、`更新禁止` のレイヤを対象外として明示する
4. 確認結果（記憶階層ルートの絶対パス・開始時 HEAD の commit hash・レイヤ表と対象/対象外）を `${TMPDIR:-/tmp}/memory-dream-inventory.md` に書き出す。**このファイルが無い状態で Phase 1 以降へ進まない**（物理ゲート）

構成例（agents-share 環境。上 5 行は毎セッション自動ロードされる順、末尾 2 行は on-demand・参照時のみ）:

| レイヤ | 役割 | dream での扱い |
|---|---|---|
| `AGENTS.md` | 世界のルール（最上位） | **更新禁止**。対象外、ただしルールの定義元として参照する |
| `MEMORY.md` | チーム共通知識 | 対象 |
| `auto-memory/MEMORY.md`（索引）+ `auto-memory/*.md` | 索引 + 関連時に想起される個別記憶 | 対象（索引は 1 ファイル 1 行のフック） |
| session-start で読む notes（例: `notes/ghq.md`, `notes/specs.md`） | 起動時ロードのメモ | 対象 |
| `projects/<project>.md` | プロジェクト固有 | 対象 |
| `notes/*.md`（on-demand） | 随時参照のメモ | 対象 |
| `specs/` | 設計文書（プロジェクト固有） | 原則触らない（ルール重複の対象外） |

## 4 フェーズ手順

### Phase 1: Mine（採掘）

前提: `${TMPDIR:-/tmp}/memory-dream-inventory.md` が存在すること（無ければ Phase 0 へ戻る）。

直近セッションの transcript や作業内容から、繰り返し出た指摘・確定した方針・新事実を抽出する。

- transcript の場所は環境による（例: Claude Code は `~/.claude/projects/<project>/`、Codex は `~/.codex/sessions/`）。参照できない場合は、現在の会話と既存記憶の内部矛盾だけを材料にする
- 一回限りのデバッグメモは拾わない

### Phase 2: Consolidate（統合）

抽出物を既存記憶へマージする。

- 相対日付（「昨日」等）は**絶対日付に変換**する。基準日（そのメモが書かれた日）は `git log -p -- <file>` や `git blame` で当該行が追記された commit 日時から特定する。特定できない場合は変換せず、真の矛盾と同様にユーザー確認（Phase 3）へ回す
- 矛盾は最新の値で解決し、古い記述を置換する。新旧は git 履歴（当該行の追記日時）で判定する
- 存在しないファイル・関数・フラグを指す記述は、**参照先がどのリポジトリ・パスを指すかを特定してから**現存確認し、更新するか除去する。参照先にアクセスできない・特定できない場合は除去せず、そのまま残すかユーザーに確認する

### Phase 3: Dedup & Resolve（重複排除・矛盾解消）

階層をまたいだ重複を除去する。

- **最重要原則: 上位レイヤが定めるルールを下位で再掲しない。** 下位は重複を黙って消し、そのレイヤ固有の知見だけ残す（残し方は後述「成果ファイルの書き方」に従う）
- どちらが正か判断できない真の矛盾はユーザーへ確認する（Claude Code では `AskUserQuestion`、他エージェントではテキストで確認する）

### Phase 4: Prune & Index（剪定・索引化）

- 索引（`MEMORY.md` 系。存在するもののみ）は lean に保つ（目安 200 行未満）
- 冗長な節・完了済みで価値のない記述を削除する。削除で内容がすべて失われたファイル（完了済みプロジェクトのメモ等）はファイルごと削除してよい（commit で revert 可能）。削除したら索引・notes 一覧からも除去する
- `notes/` ディレクトリがある環境では、`MEMORY.md` の「notes 一覧」セクションを毎回再生成して同期する（差分がなければ no-op。セクションが無ければ新設する）。notes は階層化され on-demand では発見されにくいため、常時ロードされる `MEMORY.md` に全パスを置く:

  ```bash
  # 記憶階層ルートで実行し、出力で「notes 一覧」セクション内のコードブロックを置換する
  find notes -type f -name '*.md' | sort
  ```

論理単位の編集が完了するたびに commit する（複数フェーズが同一ファイルを触るため、フェーズごとに commit を挟むとよい）。全フェーズ完了後、チェックリストで自己検証し、`{レビューモード}` が `standard` なら「Codex レビューループ」を実施してから、ユーザーへレビューを依頼する（push はしない）。

## 重複排除の判定ルール

- 重複は常に「下位 → 上位」方向で発生する。**修正は下位レイヤ側**で行い、最上位レイヤ（AGENTS.md 等・自己整合）は触らない
- 各情報の定義箇所を一つに保つ。上位が定めるルールは下位から単に消す。必要なら手順の所在だけを 1 句で指す（例: 「PR 本文は `notes/playbook/github-pr.md` に従う」）
- ディレクトリ構造・コミット運用・記憶貢献ルールなどの「世界のルール」は最上位レイヤが定める。notes / projects には固有情報のみ書く

## 成果ファイルの書き方（重要）

判断のメタと経緯はこの playbook 側に置き、**成果ファイル（MEMORY.md / projects / notes）には書かない**。成果ファイルから除くもの:

- **重複回避の注記**（「これは X が定める、ここでは重複させない／再掲しない」等のメタ説明）。重複は黙って消すだけでよい
- **経緯・履歴**（**Why:** 行、失敗談、「繰り返し外している」「同じ指摘を N 回受けた」、学習日・セッション ID など）

残すのは、現行で正しい知見・ルール・再現手順だけ。理由が行動を変える技術的因果（「A だと B が壊れるので C する」）は知見の一部として残してよいが、誰がいつ何を指摘したかは残さない。

> 例外: 環境の常時ロード指示が成果ファイルの書式を明示的に定めている場合（例: feedback メモに **Why:** を必須とする運用）は、そちらを優先する。

## チェックリスト

ユーザーへレビューを依頼する前（`{レビューモード}` が `standard` の場合は Codex レビューループの前）に全項目を確認する:

- [ ] 相対日付をすべて絶対日付へ変換した（基準日は git 履歴で特定。特定できないものは変換せずユーザー確認へ回した）
- [ ] 上位が定めるルールを下位から削った（重複回避の注記自体も残していない）
- [ ] 成果ファイルから経緯・履歴（Why / 失敗談 / 再発回数 / 学習日 / セッション ID）を除いた
- [ ] 矛盾を最新値で解決した（曖昧なものはユーザー確認済み）
- [ ] 存在しないファイル・シンボルへの参照を、参照先リポジトリで現存確認のうえ更新 or 除去した（確認できないものは残した）
- [ ] 索引（`MEMORY.md` 系。存在するもののみ）が lean（目安 200 行未満）
- [ ] `notes/` がある環境では「notes 一覧」を再生成・同期した
- [ ] `git diff --name-only <開始時 HEAD>..HEAD` の出力に更新禁止レイヤ（inventory で列挙したもの）が含まれないことを確認した
- [ ] 変更を論理単位ごとに commit した（push はしていない）
- [ ] ユーザーレビューを経てから採用する（dream 出力は hallucination 混入の懸念があるため鵜呑みにしない）

## Codex レビューループ（--codex-review-loop）

`{レビューモード}` が `standard` の場合、チェックリストの自己検証後・ユーザーへのレビュー依頼前に実施する。別系統モデル（Codex）による独立レビューが目的のため、**Claude 自身が Codex のレビューを模擬・代行してはならない**。返ってきた指摘の採用 / 不採用（過剰対応かどうか）の判定は、レビュイーである Claude が行う。

1. **レビュー取得** — [assets/codex-review-prompt.md](assets/codex-review-prompt.md) のテンプレートを埋め、Skill ツールで `codex:rescue` を呼び出す。Codex が dream の全差分（`git diff <開始時 HEAD>..HEAD`）を記憶階層の git 履歴と照合してレビューする
2. **妥当性判定** — 指摘を 1 件ずつ「採用 / 不採用」に分類する。不採用（妥当性がない・過剰対応・スコープ外）の理由は 1 行で記録する
3. **修正** — 採用指摘を反映し、修正 commit を積む（既存 commit は書き換えない）
4. **収束判定** — 採用が 0 件ならループ終了（収束）。1 件以上なら手順 5（上限チェック）へ進む（**必ず上限チェックを経由する**。直接手順 1 へ戻らない）
5. **上限チェック** — ラウンド数が 3 の倍数（3, 6, …）に達したら、残指摘の要約を提示して AskUserQuestion で「続行 / 打ち切り / 中止」を確認する。達していなければラウンドを +1 して手順 1 へ戻る

ループが収束・打ち切りとなっても、**ユーザーの採用前レビュー（原則 2）は省略しない**。レビュー依頼時にラウンド数・採用/不採用件数の要約を添える。

### フォールバック（codex:rescue 利用不能時）

以下のいずれかに該当する場合に実施する:

- **呼び出し不能** — Codex プラグイン未導入・Codex CLI 未設定・他エージェント環境などで `codex:rescue` が呼び出せない
- **復旧不能なハング** — レビューが返らず（silent death）、[assets/codex-review-prompt.md](assets/codex-review-prompt.md) の「運用ノート」に従った復旧（cancel → `--resume` 再投入）を 2 回試みても完了しない（ハング時は即フォールバックせず、必ず先に復旧を試みる）

該当した場合:

- Claude 自身でレビューを代行しない
- 「Codex レビュー未実施」とユーザーに明示し、通常どおりユーザーの採用前レビューへ進む

## いつ実施するか

- **大規模リファクタ直後**（リネーム多数・フレームワーク移行・API 構造変更）— 古いエントリが混乱を増やすため最優先
- **セッション数の蓄積時** — 本家デフォルトの目安は 24h かつ 5 セッション以上、実務的には 20〜30 セッションでノイズ化する
- **ユーザーが「記憶を整理して」「dream して」と指示したとき**

## 参考

- [Dreams — Claude Platform Docs](https://platform.claude.com/docs/en/managed-agents/dreams)（公式。`managed-agents-2026-04-01` + `dreaming-2026-04-21` beta header、最大 100 セッション）
- [What Is Claude Dreaming? (MindStudio)](https://www.mindstudio.ai/blog/what-is-claude-dreaming-anthropic-agent-memory)
- [Claude Code Dreams: Auto Dream guide (Supalaunch)](https://supalaunch.com/blog/claude-code-dreams-auto-dream-memory-consolidation-guide)
- [Auto-dream mechanics (claudefa.st)](https://claudefa.st/blog/guide/mechanics/auto-dream)
- [grandamenium/dream-skill](https://github.com/grandamenium/dream-skill)（4 フェーズ consolidation の OSS 再現）
