# Agent Skills Monorepo

Claude Code / Codex / Cursor / Gemini など各種エージェント用のスキル集（skills, hooks, rules）の開発リポジトリ。`skills/<skill>/` を直接正本とし、[vercel-labs/skills](https://github.com/vercel-labs/skills) の **`npx skills`** で配布する（クロスツール単一経路。render 工程・中間正本・plugin マニフェストは持たない）。

> **v2.0.0 で配布を `npx skills` に一本化**。旧 Claude Code marketplace（`.claude-plugin/`）と旧 Codex 単一プラグイン配布は撤去済み。

## 標準ワークフロー

1. `skills/<skill>/` を直接編集（SKILL.md / assets / references）
2. `npx skills add ./ --list` で検出を確認（必要に応じてローカル install で動作確認）
3. PR 経由で main にマージ（`/smart-commit main にコミット` で直接コミット可）
4. `/auto-release` で repo-level `v<X.Y.Z>` タグを発行（GitHub Release 作成）

## Git / GitHub 運用

### ブランチ運用

- **main への直接コミットは禁止** — 必ず feature branch を作成し、PR 経由でマージする
- **すべての変更は PR を作成する** — レビューなしで main に直接 push しない
- Commit messages: 日本語 OK、conventional commits を推奨

**特例**: `/smart-pr` や `/smart-commit` に `main にコミット` という引数が渡された場合は、main に直接コミット・push してよい。

### ブランチ命名規則

フォーマット: `{type}/issue-{番号}-{簡潔な説明}`

| prefix      | 用途                             |
| ----------- | -------------------------------- |
| `feature/`  | 新機能・機能追加                 |
| `fix/`      | バグ修正                         |
| `refactor/` | リファクタリング（機能変更なし） |
| `docs/`     | ドキュメントのみの変更           |
| `chore/`    | ビルド・CI・依存関係など雑務     |
| `test/`     | テストの追加・修正               |

ルール:
- **kebab-case**（小文字 + ハイフン区切り）を使う
- Issue に紐づく作業は必ず `issue-{番号}` を含める
- 説明部分は **英語・3〜5 語** 程度に収める
- マイルストーン分割がある場合は末尾に `-m{番号}` を付ける
- Issue に紐づかない繰り返し作業（chore/docs/refactor 等）は、末尾にタイムスタンプ `-YYYYMMDD` を付けて一意にする（例: `docs/update-readme-20260326`）

### PR / Issue 作成ルール

- PR・Issue 作成時は作成者を自動アサインする（GitHub MCP の `get_me` または `gh api user` で取得した GitHub ユーザー名を使用）
- Issue 作成時は内容に適した既存ラベルを付与する
- **Issue 作成は GitHub MCP ツール (`issue_write`) を使用する**（ラベル付与・アサインも同ツールで行う）
- コミット・PR に closing keyword は使わない（Issue はマージ後に手動クローズする）。実装済みでも Issue が open のまま残ることがあるため、Issue 着手前にマージ済み PR がその番号を参照していないか確認し、解決済みなら検証コメントを添えてクローズする（例: #69 / #72 は PR #73 で実装済みのまま open だった）

> 上記規則は `smart-commit` / `smart-issue-plan` / `smart-issue-resolve` / `smart-pr` の各 SKILL.md にも内蔵されている（`npx skills` 経由でインストールされた利用者がプロジェクト外ファイルを参照できないため）。本リポジトリで作業する際は CLAUDE.md（本セクション）が一次情報源。

## 記述ルール

- ファイルパスにユーザー名を含めない。ホームディレクトリは `/Users/<name>/` ではなく `~/` で表記する（SKILL.md・コメント・ドキュメント・コミットメッセージ・PR 本文のいずれも同様）
- 実装ノートは `docs/implementation-notes/YYYY-MM-DD-<タスクスラグ>.md` に作成し、変更と同じ PR でコミットする。ルート直下に `implementation-notes.md` を残さない（誤コミット防止のため .gitignore で除外済み）

## よく使うコマンド

```bash
# 個人設定（gitignore 対象）: .claude/settings.local.json にパーミッション allowlist など個人環境の設定を記述

# npx skills が検出する skill 一覧（配布の確認）
npx skills add ./ --list

# ローカル install で動作確認（任意のディレクトリで）
npx skills add ./ --skill <skill-name>

# assets/ 内のシェルスクリプト構文チェック
bash -n skills/<skill-name>/assets/<name>.sh

# SKILL.md frontmatter 確認
head -5 skills/<skill-name>/SKILL.md

# リリース（repo-level v<X.Y.Z> タグの発行 + GitHub Release）
/auto-release

# git pull が "unable to update local ref" で失敗した場合の復旧（マージ直後に発生することがある）
# 注意: reset --hard は未コミット変更を破棄する。実行前に git status --short で clean を確認すること
git update-ref refs/remotes/origin/main <merge-sha> && git reset --hard <merge-sha>

# Workflow 雛形（references/agent-orchestration.md の js ブロック）の構文チェック
# 正規表現・グロブ文字を含むため zsh 直打ちせず bash スクリプトファイル（または bash /dev/stdin）経由で実行する
CHECKDIR=$(mktemp -d) && awk -v dir="$CHECKDIR" '/^```js$/{f=1; n++; next} /^```$/{f=0} f{print > (dir "/block-" n ".js")}' skills/<skill>/references/agent-orchestration.md && for b in "$CHECKDIR"/block-*.js; do { echo 'void (async () => {'; sed 's/^export const meta/const meta/' "$b"; echo '})'; } > "$b.wrapped.js"; mise exec node -- node --check "$b.wrapped.js" && echo "OK: $(basename "$b")"; done
```

## リポジトリ構造

```
skills/                          # 配布 skill の正本（直接編集・npx 標準探索場所）
  # Git ワークフロー系
  smart-commit/                  # 差分を作業単位で分割コミット
  smart-pr/                      # PR 作成・更新の自動化
  smart-git-sync/                # ブランチ同期・整理
  smart-issue-resolve/           # Issue からブランチ作成〜実装（役割別エージェントのオーケストレーション + レビューループ）
  smart-issue-plan/              # Issue の実装計画を作成・更新
  smart-review/                  # ローカル変更のセルフレビュー
  smart-review-apply/            # レビューフィードバックの適用
  # スキル品質改善・環境構成レビュー
  skill-improver/                # skill-creator 連携 + コンテキスト管理・静的チェック
  empirical-prompt-tuning/       # 新規 subagent 実行でプロンプト・skill を反復チューニング
  claude-code-update-review/     # Claude Code バージョンアップ後の構成レビュー
  # コード開発ライフサイクル支援
  software-architect/            # 要件・スペックから「あるべき設計」を言語化
  code-reviewer/                 # 仕様整合・設計適合・可読性の観点でレビュー
  code-reviewer-adversarial/     # Breaker (Claude) × Judge (Codex) の敵対的レビュー
  security-auditor/              # STRIDE・認可・データフロー等の設計セキュリティ監査
  branch-visualize/              # ブランチ差分の構成図可視化（Mermaid / D2 / HTML 自動選定）
  # 事業企画
  business-ideation/             # ビジネス・サービス案の発散→深掘り→評価（汎用・notes 正本方式）
  # デザイン
  game-ui-design/                # ゲーム UI（HUD / メニュー / コントローラーナビ等）の設計観点
  # システムメンテナンス
  disk-space-cleanup/            # ディスク空き容量の確保（開発系キャッシュのスキャン→確認→削除）
  # エージェント記憶管理
  memory-dream/                  # 記憶階層の consolidation（重複・矛盾・陳腐化の除去。Dreams の手動再現）
internal/                        # 内部 skill（npx 標準探索ルート外・配布対象外）
  auto-release/                  # repo-level タグ発行・GitHub Release（リポジトリ自身のリリース用）
  global-config-pull/            # ~/.claude/ → dotfiles/claude/ へ取り込む
  global-config-push/            # dotfiles/claude/ → ~/.claude/ へ反映する
dotfiles/                        # ホストマシンのグローバル設定（個人管理用・配布対象外）
  claude/
    CLAUDE.md                    # グローバル Claude Code 指示ファイル
    settings.json                # グローバル設定（hooks・permissions・statusLine・plugins 等）
    statusline-command.sh        # ステータスライン表示スクリプト
    rules/                       # CLAUDE.md から条件読み込みされる外部参照ルール（ふるまい・開発判断ガイドライン）
docs/                            # 設計・移行ドキュメント（migration-npx-skills.md、empirical-tuning/、implementation-notes/〔実装ノートのアーカイブ〕等）
```

`skills/<skill>/` が配布 skill の唯一の正本（直接編集）。skill 名はリポジトリ全体で一意。スキルの説明・使用例・前提条件は各 `skills/<skill>/README.md` に書く（npx install でスキルと一緒に配布される）。旧 `packages/`（グループ README）は per-skill README と重複・陳腐化したため v2.0.2 で解体済み。

### 配布の仕組み（単一正本・npx skills）

`skills/<skill>/` が skill の唯一の正本（generated な中間物・render 工程は無い）。配布は `npx skills`（[vercel-labs/skills](https://github.com/vercel-labs/skills)・git tree-SHA ベース）:

- `npx skills add 'mjcreativelab/mjcreativelab-agent-prompts#v<X.Y.Z>' --skill <name> -g` で各エージェントへ install。skill は `.agents/skills/<skill>/` に配置され Claude Code / Codex / Cursor / Gemini CLI / GitHub Copilot 等へ展開される。
- frontmatter は逐語コピーされる（`allowed-tools` 等は標準仕様、`argument-hint` / `disable-model-invocation` は Claude 拡張で他エージェントは無視）。

注意点:

- 内部 skill（リポジトリ自身の運用用。例: `auto-release`）は **`internal/<skill>/` に置く**（npx の標準探索ルート外のため、リモート探索にも `--skill '*'` にも含まれない）。保険として frontmatter に `metadata.internal: true` も付ける（標準ルートに置かれても `--list` から隠れる）。
  - **`skills/` や `.claude/skills/` には置かない**: どちらも npx リモート探索の優先ルートで、internal flag があっても `--skill '*'` で install されてしまう（v2.0.1 では `skills/` に置いていた）。
  - ローカルでこのリポジトリ自身に internal skill（`/auto-release`・`/global-config-pull`・`/global-config-push`）を使う場合は `npx skills add ./internal/<skill> --skill <skill> -g` で global install して呼ぶ（skill 改修時は同コマンドで再 add）。`internal/` は探索ルート外のため、リポジトリに置くだけではスラッシュコマンドとして認識されない。
- 配布先に symlink を作らない。skill 内のサポートファイル参照は `${CLAUDE_SKILL_DIR}` ではなく SKILL.md からの相対パスを基本にすると各エージェントで解決しやすい。
- npx のデフォルト探索は浅い（全階層走査は `--full-depth`）。
- **`@` は ref ではなく skill フィルタ**: `owner/repo@X` の `@X` は `--skill X` 相当（CLI v1.5.9 の source-parser で確認）。バージョン pin は fragment 構文 **`owner/repo#v<X.Y.Z>`**（zsh ではソース全体を引用符で囲む。`#ref@skill` の複合も可）。`#ref` は探索・install に効き、lock（skills-lock.json）に `ref` が記録され `npx skills update` も pin に従う。ただし blob fast path（skills.sh download API）が ref を渡さない既知問題があり（[vercel-labs/skills#1123](https://github.com/vercel-labs/skills/pull/1123) で修正中）、ref の中身の権威確認は `git ls-tree -r origin/<ref> --name-only` で行う。
- 新規 skill 追加時に同期スクリプト・マニフェストは不要（`skills/<skill>/` を直接追加するだけ）。

### タグ運用

- **repo-level `v<X.Y.Z>`**（SemVer）: `npx skills` の pin 用（例: `npx skills add '<repo>#v2.0.2' ...`。`@` ではなく `#`）。`/auto-release` が `skills/` 差分で判定・発行する。バージョンは git タグのみ（バージョンファイル・plugin.json なし）。
- 旧タグ（per-package `<package>@<semver>`・旧 codex `mjcreativelab-claude-plugins@1.0.0`）は不変で残る（履歴）。これらは廃止済みの旧配布経路のもの。

## スキルファイル形式

### ディレクトリ構造

skill は `<name>/SKILL.md` のディレクトリ構造が必須（フラットファイル配置では認識されない）。

```
<skill-name>/
├── SKILL.md          # メイン指示（必須・500行以下推奨）
├── assets/           # テンプレート・スクリプト（出力物の雛形、実行スクリプト）
└── references/       # 参照表・定義（対応表、ルール表など読み取り専用の情報）
```

SKILL.md からサポートファイルを参照して、必要な時だけ読み込むようにする:

```markdown
GitMoji と type の対応: [references/gitmoji-types.md](references/gitmoji-types.md)
```

> user-invocable な機能も `commands/` ではなく `skills/` に統一する（`disable-model-invocation: true` を付けた Skill として追加する）。frontmatter・引数パース・コンテキスト管理の規約を揃えるため。

### frontmatter

```yaml
---
name: my-skill                    # kebab-case、ディレクトリ名と一致させる（Agent Skills 標準）
description: スキルの説明           # 必須。自動読み込み判断・トリガー語に使用
argument-hint: "[issue-number]"    # オートコンプリートに表示するヒント（Claude 拡張）
disable-model-invocation: true     # true → ユーザーの /name でのみ起動（副作用のあるスキル向け・Claude 拡張）
allowed-tools: Read, Grep, Glob    # スキル実行中に許可なしで使えるツール（標準フィールド）
metadata:                          # 任意の拡張枠（標準フィールド）。例: internal: true で npx --list から隠す
  internal: true
---
```

`name` + `description` は必ず記載する（Agent Skills 標準の必須項目）。他はスキルの性質に応じて使用。`argument-hint` / `disable-model-invocation` は Claude 拡張で他エージェントは無視する。

### 文字列置換

SKILL.md 内で使用できる変数:

| 変数 | 用途 |
|------|------|
| `$ARGUMENTS` | スキル呼び出し時の引数全体 |
| `$ARGUMENTS[N]` / `$N` | N番目の引数（0始まり） |
| `${CLAUDE_SKILL_DIR}` | SKILL.md のあるディレクトリのパス（Claude Code 固有） |
| `${CLAUDE_SESSION_ID}` | セッションID |

`${CLAUDE_SKILL_DIR}` は Claude Code 固有で他エージェントでは解決されない。クロスツール配布する skill では SKILL.md からの相対パスを基本にする:

```bash
bash assets/git-sync.sh
```

### 動的コンテキスト注入

`` !`command` `` 構文でスキル読み込み前にシェルコマンドを実行し、結果を埋め込める:

```yaml
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`
```

### クロスツール配布時の frontmatter / token 互換性

`npx skills` は frontmatter を逐語コピーする（正規化しない）。Agent Skills 標準仕様
（<https://agentskills.io/specification>）に沿うため、`name` / `description` は必須、
`allowed-tools` / `license` / `metadata` は標準フィールド。`argument-hint` /
`disable-model-invocation` は Claude 拡張で、他エージェントは**無視**する（reject しない）。

本文中の以下は Claude 固有で、他エージェントでは解決されない（graceful degradation 前提で書く）:

- tools: `AskUserQuestion`, `WebSearch`, `WebFetch`, `Skill`, `Agent`, `Task`
- 変数: `${CLAUDE_SKILL_DIR}`（他エージェントでは未解決。SKILL.md からの相対パスを基本にする）
- skill 参照: `codex:rescue` や `mcp__plugin_github_github__*`（エージェントごとに discovery 機構が異なる）

クロスツールで確実に動かしたい skill は、これらに依存しない表現を選ぶ。Claude 専用前提の
skill（例: `code-reviewer-adversarial` の Codex 連携）は、その旨を description に明記する。

## スキル改修時の注意

- SKILL.md は **500行以下**に保つ。大きなコンテンツは `assets/` または `references/` に切り出す
- GitHub API 操作は MCP ツールに統一する（`gh` CLI との混在を避ける）
- `SKILL.md` と同 skill の `README.md` を同時に更新すること。外部スクリプトがある場合はそれも更新
- スキルの動作が CLAUDE.md の Git/GitHub 運用規則と関連する場合、CLAUDE.md と整合性を保って更新すること（Git 規約はプラグイン外参照不可のため各 SKILL.md にも内蔵されている）
- シェルスクリプト改修後は `bash -n` で構文チェックすること
- SKILL.md にインラインで埋め込むシェルスクリプトに正規表現パターン（`^[[:space:]]` 等）が含まれる場合、zsh がグロブ展開してエラーになる。`bash /dev/stdin` または一時ファイル経由で実行する旨を明記すること
- 複数フェーズのスキルでは「後半を省略すると危険」ではなく「前半が本体」と記述する。escape hatch（スキップ条件）は最小限にし、フェーズ境界にゲート（前提確認）を設ける
- 他スキルに依存するスキルのテスト・レビュー時も、依存先を実際に Skill ツールで呼び出す。SKILL.md を Read して手動で手順を適用する方法では依存スキルの実行が省略され、正しい検証にならない
- 後続フェーズの手順が SKILL.md 内に見えていると、テキストのゲート指示だけではスキップを防げない。後続フェーズの詳細手順は `references/` に切り出し、前フェーズの出力ファイル存在チェックを物理ゲートにする
- スキルの手順に `rm -f` 等の破壊的コマンドを含めない。一時ファイルは OS の一時領域に任せること
- `-p` 等のオプション引数を持つスキルには「引数の解析」セクションを設ける（smart-commit の形式を参照）。同一グループ内で引数パースの書き方を統一すること
- スキル改修時は frontmatter を確認する: 副作用のあるスキルに `disable-model-invocation: true` があるか、`allowed-tools` が設定されているか、`description` に類似スキルとの差別化文言があるか
- **レビュープロンプトの二重化と同期（マスター）**: 敵対レビューの Breaker / Judge プロンプト（攻撃観点・4 分類裁定基準）と標準レビュー観点の骨格は、スキル間ファイル参照不可・Skill 合成不可の制約から意図的に複数スキルへ二重化している。次のいずれかを変更したら対応箇所をすべて同期すること（可読性を観点に含めるか等、各スキルの identity として意図的に異なる部分は除く）:
  - `smart-issue-resolve/references/agent-orchestration.md` — 雛形 B（`sir-claude-review-set`）の reviewerPrompt / breakerPrompt / judgePrompt、雛形 C（`sir-codex-breaker`）の Breaker
  - `smart-issue-plan/references/agent-orchestration.md` — `sip-plan-review-set`（計画テキスト用に適応した変種）
  - `code-reviewer/references/agent-orchestration.md` — `--isolated` の単発隔離レビュー（`cr-isolated-review`）
  - `code-reviewer-adversarial/references/agent-orchestration.md` — `--claude-judge` の Breaker×Judge（`cra-claude-judge`）
  各 SKILL.md にも同期ノートを内蔵している（本項がマスター）。
- Workflow ツールで雛形を起動・検証する際、`args` が JSON 文字列で届く環境がある（`typeof args === 'string'`。プローブで実測）。全雛形（resolve 雛形 A〜E・`sip-plan-review-set`・`cr-isolated-review`・`cra-claude-judge`）は meta 直後に正規化シム `args = typeof args === 'string' ? JSON.parse(args) : (args || {})` を内蔵済みのため、起動時に手動でシムを挿入する必要はない（文字列・オブジェクトどちらで届いても本文のトップレベル `args.` 参照が機能する）。「`args` は JSON 値として渡す（文字列化した JSON を渡さない）」契約は維持する

## 新規スキル追加手順

1. `skills/<skill-name>/` ディレクトリを作成
2. `SKILL.md` を作成（frontmatter: `name`〔ディレクトリ名と一致〕 + `description`）
3. `skills/<skill-name>/README.md` を作成（スキルの説明・使用例・前提条件。npx install で配布される）
4. この `CLAUDE.md` のリポジトリ構造セクションとルート `README.md` のスキル一覧表にスキルを追記
5. `npx skills add ./ --list` で検出されることを確認
6. リリースは `/auto-release`（新 skill 追加 → マイナーバンプ）

## 変更履歴（パッケージ名・配布経路）

Git タグは変更不可 — 旧タグは旧名のまま残る。グループ（パッケージ）概念は v2.0.2 で解体済み（下記「配布経路の変更履歴」参照）。

### パッケージ名変更履歴

- `mjc-git-workflow` → `mjc-git-workflow-tools`（旧タグ: `mjc-git-workflow@1.1.4` まで）
- `mjc-claude-skill-tool` → `mjc-claude-improver-tools`（旧タグ: `mjc-claude-skill-tool@1.2.1` まで）
- `mjcreativelab-claude-plugins` → `mjcreativelab-agent-plugins`（リポジトリ名・旧 marketplace 名・旧 codex plugin 名を一括リネーム。旧 codex タグ: `mjcreativelab-claude-plugins@1.0.0` まで）
- `mjcreativelab-agent-plugins` → `mjcreativelab-agent-prompts`（リポジトリ名変更。npx 参照パスを更新）

### 配布経路の変更履歴

- ~v1.x: Claude Code marketplace（per-package `.claude-plugin/plugin.json` + `<package>@<semver>` タグ）+ 旧 Codex 単一プラグイン配布（ルート `skills/` + `.codex-plugin/`）。
- v2.0.0〜: `npx skills` 一本化（repo-level `v<X.Y.Z>` タグ）。marketplace・per-package plugin.json・per-package タグ運用は撤去。
- v2.0.2〜: `packages/`（グループ README）を解体。スキル説明は per-skill `skills/<skill>/README.md` に一本化、チューニング記録は `docs/empirical-tuning/` へ移設。内部 skill `auto-release` は `skills/` から `internal/` へ移設（リモート探索・`--skill '*'` からの除外）。
