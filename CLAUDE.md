# Claude Plugins Monorepo

Claude Code 用プラグイン（skills, hooks, rules）の開発リポジトリ。

## 標準ワークフロー

1. `skills-sources/<package>/<skill>/` を編集（必要なら `codex/` override や `skill-sync.yaml` を追加）
2. `/skill-sync --check` で差分確認 → `/skill-sync` で claude(`packages/`) と codex(`skills/`) に render
3. PR 経由で main にマージ（`/smart-commit main にコミット` で直接コミット可）
4. `/auto-release` でバージョンバンプ・タグ付け・リリース PR を一括作成

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

> 上記規則は `smart-commit` / `smart-issue-plan` / `smart-issue-resolve` / `smart-pr` の各 SKILL.md にも内蔵されている（マーケットプレイス経由でインストールされた利用者がプロジェクト外ファイルを参照できないため）。本リポジトリで作業する際は CLAUDE.md（本セクション）が一次情報源。

## よく使うコマンド

```bash
# 個人設定（gitignore 対象）: .claude/settings.local.json にパーミッション allowlist など個人環境の設定を記述

# ローカルでプラグインをテスト
claude --plugin-dir ./packages/<plugin>

# セッション中にプラグインの変更を反映
/reload-plugins

# マーケットプレイスの検証
claude plugin validate .

# assets/ 内のシェルスクリプト構文チェック
bash -n packages/<plugin>/skills/<skill-name>/assets/<name>.sh

# SKILL.md frontmatter 確認
head -5 packages/<plugin>/skills/<skill-name>/SKILL.md


# skills-sources/ を claude(packages/) と codex(ルート skills/) 両方に render
/skill-sync

# 特定スキルのみコピー
/skill-sync <skill-name>

# 差分確認のみ（コピーしない）
/skill-sync --check

# codex 側だけ差分確認（claude も同様に --target claude）
python3 tools/sync_skill_sources.py --check --target codex

# codex SKILL.md の frontmatter 検証
python3 tools/validate_codex_skills.py

# リリース（plugin.json のバージョンバンプ + タグ + リリース PR）
/auto-release
```

## リポジトリ構造

```
.claude-plugin/
  marketplace.json               # マーケットプレイスカタログ（プラグイン一覧）
.codex-plugin/
  plugin.json                    # codex プラグインマニフェスト
skills/                          # codex 用 skill 配置先（generated、編集禁止）
skills-sources/                  # claude/codex 両配布先の正本（編集はここ）
  <package-name>/<skill-name>/   # SKILL.md + assets/ + references/ + README.md + target override
packages/
  mjc-git-workflow-tools/        # Git ワークフロー系プラグイン
    .claude-plugin/
      plugin.json                # プラグインマニフェスト（name, version 等）
    skills/
      smart-commit/              # 差分を作業単位で分割コミット
      smart-pr/                  # PR 作成・更新の自動化
      smart-git-sync/            # ブランチ同期・整理
      smart-issue-resolve/       # Issue からブランチ作成〜実装
      smart-issue-plan/          # Issue の実装計画を作成・更新
      smart-review/              # ローカル変更のセルフレビュー
      smart-review-apply/        # レビューフィードバックの適用
    README.md
  mjc-claude-improver-tools/       # スキル品質改善・環境構成レビューツール
    .claude-plugin/
      plugin.json
    skills/
      skill-improver/              # skill-creator 連携 + コンテキスト管理・静的チェック
      empirical-prompt-tuning/     # 新規 subagent 実行でプロンプト・skill を反復チューニング
      claude-code-update-review/   # Claude Code バージョンアップ後の構成レビュー
    README.md
  mjc-code-develop-tools/          # コード開発ライフサイクル支援（設計/レビュー/セキュリティ監査）
    .claude-plugin/
      plugin.json
    skills/
      software-architect/          # 要件・スペックから「あるべき設計」を言語化
      code-reviewer/               # 仕様整合・設計適合・可読性の観点でレビュー
      code-reviewer-adversarial/   # Breaker (Claude) × Judge (Codex) の敵対的レビュー
      security-auditor/            # STRIDE・認可・データフロー等の設計セキュリティ監査
    README.md
.claude/
  skills/
    auto-release/                # バージョン更新・タグ付け・リリース（プロジェクトローカル）
    skill-sync/                  # skills-sources/ → 配布先 render（プロジェクトローカル）
tools/
  sync_skill_sources.py          # skills-sources/ から packages/ と skills/ へ render
  validate_codex_skills.py       # codex SKILL.md frontmatter の検証
```

codex 配布の特殊な点: `.codex-plugin/` は plugin.json 専用、skill 本体はルート `skills/` に配置（`plugin.json` の `"skills": "./skills/"` 参照先）。


### skills-sources/（スキル共通本体）

claude package と codex plugin で配布する skill 一式（`SKILL.md` + `assets/` + `references/` + 任意の `README.md` + target override）の正本を置く。配置は `skills-sources/<package-name>/<skill-name>/`（ディレクトリ階層が claude package 所属を表現する）。

`tools/sync_skill_sources.py`（`/skill-sync`）で以下に target 別 render（orphan 削除あり）する:

- claude: `packages/<package>/skills/<skill>/`（package 階層を保持）
- codex: `skills/<skill>/`（リポジトリルート直下に平坦化。`.codex-plugin/plugin.json` の `"skills": "./skills/"` が指す先）

> **注意**: `.codex-plugin/` ディレクトリは plugin metadata（`plugin.json`）専用。skill 本体はルートの `skills/` に配置する。`.codex-plugin/skills/` には何も置かない。

配布先の中身は generated。直接編集しても次回 sync で上書き・削除される。配布先に symlink を作成しない。`.claude/skills/`（プロジェクトローカルスキル）はこの同期処理の対象外。

target 差分の扱い:

- `codex/` または `claude/` 配下のファイルは target root に重ねる（例: `codex/SKILL.md` → `skills/<skill>/SKILL.md`）
- `skill-sync.yaml` / `skill-sync.json` で target ごとの `enabled` / `exclude` / `include_readme` を指定できる
- Codex 向け `SKILL.md` は frontmatter を Codex validator 向けに正規化する（`argument-hint` / `disable-model-invocation` / `model` / `allowed-tools` 等は出力しない）
- Codex 向けは `README.md` をデフォルトで出力しない。必要な場合のみ `include_readme: true` を指定する
- Claude 専用 skill は `skill-sync.yaml` で `targets.codex.enabled: false` にする
- リリース時のバンプ判定は rendered 出力（`packages/` / `skills/`）の diff で行う。`skills-sources/` の diff は判定基準にしない（skill-sync.yaml 変更や override 影響を取りこぼすため）

新規 skill・新規 package 追加時もスクリプト編集は不要（自動検出される）。codex 側はフラット配置のため **skill 名はリポジトリ全体で一意**である必要がある。

## プラグイン構造

### マニフェスト

各プラグインは `.claude-plugin/plugin.json` が必須。**`plugin.json` のみ** `.claude-plugin/` 内に配置。他のディレクトリ（`skills/`, `hooks/` 等）はプラグインルートに置く。

```json
{
  "name": "my-plugin",
  "description": "プラグインの説明",
  "version": "1.0.0",
  "author": { "name": "author-name" }
}
```

`version` と個別プラグインの `description` は `plugin.json` で管理する（`marketplace.json` との重複を避けるため、`marketplace.json` のプラグインエントリには `name` + `source` のみ記載する）。

### プラグインのディレクトリ構成

```
<plugin-name>/
  .claude-plugin/
    plugin.json    # マニフェスト（必須）
  skills/          # スキル定義（SKILL.md）
  agents/          # カスタムエージェント定義
  hooks/           # hooks.json でイベントハンドラー
  commands/        # Markdown ベースのコマンド
  .mcp.json        # MCP サーバー設定
  .lsp.json        # LSP サーバー設定
  settings.json    # プラグイン有効時のデフォルト設定
  README.md
```

必要なサブディレクトリだけ配置する。

本 monorepo では user-invocable な機能も `commands/` ではなく `skills/` に統一する（`disable-model-invocation: true` を付けた Skill として追加する）。frontmatter・引数パース・コンテキスト管理の規約を揃えるため。

### マーケットプレイスカタログ

`.claude-plugin/marketplace.json` はプラグインの一覧と取得元を定義する。各プラグインエントリには `name` + `source` が最低限必要。

```json
{
  "name": "marketplace-name",
  "description": "マーケットプレイスの説明",
  "owner": { "name": "owner-name" },
  "plugins": [
    { "name": "plugin-name", "source": "./packages/plugin-name" }
  ]
}
```

### 配布・インストール

```bash
# marketplace として登録
/plugin marketplace add mjcreativelab/mjcreativelab-agent-plugins

# プラグインをインストール
/plugin install <plugin-name>@mjcreativelab-agent-plugins
```

### キャッシュの注意

プラグインはインストール時にキャッシュディレクトリにコピーされる。プラグインディレクトリ外のファイル（`../shared-utils` 等）はコピーされないため参照不可。ファイル共有が必要な場合はシンボリックリンクを使用する。

hooks や MCP 設定でプラグイン内のファイルを参照するには `${CLAUDE_PLUGIN_ROOT}` を使用する（スキル内の `${CLAUDE_SKILL_DIR}` とは別物）。

## スキルファイル形式

### ディレクトリ構造

プロジェクトローカルスキル（`.claude/skills/`）もプラグインスキルも `<name>/SKILL.md` のディレクトリ構造が必須（フラットファイル配置では認識されない）。

```
<skill-name>/
├── SKILL.md          # メイン指示（必須・500行以下推奨）
├── assets/           # テンプレート・スクリプト（出力物の雛形、実行スクリプト）
└── references/       # 参照表・定義（対応表、ルール表など読み取り専用の情報）
```

SKILL.md からサポートファイルを参照して、Claude が必要な時だけ読み込むようにする:

```markdown
GitMoji と type の対応: [references/gitmoji-types.md](references/gitmoji-types.md)
```

### frontmatter

```yaml
---
name: my-skill                    # kebab-case、省略時はディレクトリ名
description: スキルの説明           # 推奨。Claude が自動読み込みの判断に使用
argument-hint: "[issue-number]"    # オートコンプリートに表示するヒント
disable-model-invocation: true     # true → ユーザーの /name でのみ起動（副作用のあるスキル向け）
user-invocable: false              # false → / メニュー非表示（バックグラウンド知識向け）
allowed-tools: Read, Grep, Glob    # スキル実行中に許可なしで使えるツール
context: fork                      # fork → サブエージェントで実行（メイン会話と分離）
agent: Explore                     # context: fork 時のサブエージェントタイプ
---
```

`name` + `description` は必ず記載する。他はスキルの性質に応じて使用。

> `context`, `agent`, `user-invocable` は Claude Code プラットフォームの機能。本リポジトリでは未使用だがリファレンスとして記載。

### 文字列置換

SKILL.md 内で使用できる変数:

| 変数 | 用途 |
|------|------|
| `$ARGUMENTS` | スキル呼び出し時の引数全体 |
| `$ARGUMENTS[N]` / `$N` | N番目の引数（0始まり） |
| `${CLAUDE_SKILL_DIR}` | SKILL.md のあるディレクトリのパス |
| `${CLAUDE_SESSION_ID}` | セッションID |

`${CLAUDE_SKILL_DIR}` を使えば、インストール先パスに依存せずスキル内のファイルを参照できる:

```bash
bash ${CLAUDE_SKILL_DIR}/assets/git-sync.sh
```

### 動的コンテキスト注入

`` !`command` `` 構文でスキル読み込み前にシェルコマンドを実行し、結果を埋め込める:

```yaml
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`
```

### Codex 配布時の禁止 token

Codex は以下の token を解釈できない。skills-sources の SKILL.md 本文にこれらが必要な場合、`codex/SKILL.md` override で代替表現を書くか、`skill-sync.yaml` で `targets.codex.enabled: false` にする:

- tools: `AskUserQuestion`, `WebSearch`, `WebFetch`, `Skill`, `Agent`, `Task`
- 変数: `${CLAUDE_SKILL_DIR}`（Codex では SKILL.md からの相対パスで解決）
- skill 参照: `codex:rescue` や `mcp__plugin_github_github__*`（Codex は別の plugin discovery 機構を使う）

## スキル改修時の注意

- SKILL.md は **500行以下**に保つ。大きなコンテンツは `assets/` または `references/` に切り出す
- GitHub API 操作は MCP ツールに統一する（`gh` CLI との混在を避ける）
- `SKILL.md` + `README.md` を同時に更新すること。外部スクリプトがある場合はそれも更新
- スキルの動作が CLAUDE.md の Git/GitHub 運用規則と関連する場合、CLAUDE.md と整合性を保って更新すること（Git 規約はプラグイン外参照不可のため各 SKILL.md にも内蔵されている）
- シェルスクリプト改修後は `bash -n` で構文チェックすること
- SKILL.md にインラインで埋め込むシェルスクリプトに正規表現パターン（`^[[:space:]]` 等）が含まれる場合、zsh がグロブ展開してエラーになる。`bash /dev/stdin` または一時ファイル経由で実行する旨を明記すること
- 複数フェーズのスキルでは「後半を省略すると危険」ではなく「前半が本体」と記述する。escape hatch（スキップ条件）は最小限にし、フェーズ境界にゲート（前提確認）を設ける
- 他スキルに依存するスキルのテスト・レビュー時も、依存先を実際に Skill ツールで呼び出す。SKILL.md を Read して手動で手順を適用する方法では依存スキルの実行が省略され、正しい検証にならない
- 後続フェーズの手順が SKILL.md 内に見えていると、テキストのゲート指示だけではスキップを防げない。後続フェーズの詳細手順は `references/` に切り出し、前フェーズの出力ファイル存在チェックを物理ゲートにする
- スキルの手順に `rm -f` 等の破壊的コマンドを含めない。一時ファイルは OS の一時領域に任せること
- `-p` 等のオプション引数を持つスキルには「引数の解析」セクションを設ける（smart-commit の形式を参照）。同一プラグイン内で引数パースの書き方を統一すること
- スキル改修時は frontmatter を確認する: 副作用のあるスキルに `disable-model-invocation: true` があるか、`allowed-tools` が設定されているか、`description` に類似スキルとの差別化文言があるか

## 新規スキル追加手順

1. `packages/<plugin>/skills/<skill-name>/` ディレクトリを作成
2. `SKILL.md` を作成（frontmatter: `name` + `description`）
3. `packages/<plugin>/README.md` にスキルの説明・使用例を追加
4. この `CLAUDE.md` のリポジトリ構造セクションにスキルを追記

## 新規プラグイン追加手順

1. `packages/<plugin-name>/` ディレクトリを作成
2. `packages/<plugin-name>/.claude-plugin/plugin.json` を作成
3. `packages/<plugin-name>/skills/` 等にコンポーネントを配置
4. `.claude-plugin/marketplace.json` の `plugins` 配列にエントリを追加
5. `claude --plugin-dir ./packages/<plugin-name>` でローカルテスト
6. この `CLAUDE.md` のリポジトリ構造セクションにプラグインを追記

## パッケージリネーム時の注意

リネーム対象: ディレクトリ（`git mv`）、`plugin.json` の `name`、`marketplace.json`、`CLAUDE.md`、各 `README.md`、SKILL.md 内の参照、`settings.local.json` のパス

Git タグは変更不可 — 旧タグは旧名のまま残る。新リリース以降のタグが新名になる。

初回リリースタグ: コードが既に main にマージ済みでタグがない場合、リリースブランチ不要。マージコミットに直接タグ付けする。

### パッケージ名変更履歴

- `mjc-git-workflow` → `mjc-git-workflow-tools`（旧タグ: `mjc-git-workflow@1.1.4` まで）
- `mjc-claude-skill-tool` → `mjc-claude-improver-tools`（旧タグ: `mjc-claude-skill-tool@1.2.1` まで）
- `mjcreativelab-claude-plugins` → `mjcreativelab-agent-plugins`（リポジトリ名・marketplace 名・codex plugin 名を一括リネーム。旧 codex タグ: `mjcreativelab-claude-plugins@1.0.0` まで）
