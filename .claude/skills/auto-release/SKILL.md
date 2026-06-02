---
name: auto-release
description: パッケージのバージョン更新・タグ付け・リリース PR の作成・マージを一括で行う。ユーザーが「リリースして」「バージョン上げて」「/auto-release」と言ったら起動する。
metadata:
  internal: true
---

# Auto Release

パッケージ（claude package）のバージョンを自動判定して更新し、タグ付け・PR 作成・squash merge までを一括で行う。

## オプション

`-p <プロンプト>`: バージョン番号の指定やリリース対象の絞り込みなど追加指示。

例: `-p 1.2.0 にして` / `-p mjc-git-workflow-tools だけ`

## バージョン体系

リリース対象は `packages/<plugin>/` の **claude package** 単位。`packages/<plugin>/skills/`
が skill の正本であり、Claude marketplace と npx skills の双方がここを参照する
（render 工程・codex 専用配布物は持たない）。

- **タグ形式**: `<package-name>@<semver>`（例: `mjc-git-workflow-tools@1.1.0`）
- **バージョン格納先**: `packages/<plugin>/.claude-plugin/plugin.json` の `version`
- **判定基準**: 前回タグからの `packages/<plugin>/` 配下の差分

### バージョンバンプルール

前回タグからの差分を分析し、以下のルールで自動判定する。複数の変更種別が混在する場合は、最も大きいバンプを適用する。

| 変更内容 | バンプ | 例 |
|----------|--------|-----|
| `packages/` に新しいパッケージディレクトリが追加された | **メジャー** | 1.0.0 → 2.0.0 |
| 既存パッケージに新しいスキルが追加された（`skills/` 下に新ディレクトリ） | **マイナー** | 1.0.0 → 1.1.0 |
| 既存コードの修正・改善（上記以外） | **パッチ** | 1.0.0 → 1.0.1 |

## ツール選択

GitHub API 操作には **GitHub MCP ツール**を優先。git 操作は Bash。

## 事前準備: ツール一括取得

手順で使用する MCP ツールを **1回の ToolSearch で一括取得** する:

```
ToolSearch: select:AskUserQuestion,mcp__plugin_github_github__create_pull_request,mcp__plugin_github_github__issue_write,mcp__plugin_github_github__merge_pull_request
```

これにより ToolSearch のラウンドトリップを最小化する。

## 手順

### 0. 事前整合性チェック（marketplace.json）

`packages/` 配下のディレクトリと `.claude-plugin/marketplace.json` の `plugins[].name` を突き合わせ、未登録パッケージがないか確認する。

```bash
ls -d packages/*/ | xargs -n1 basename
```

未登録パッケージの扱いはリリース対象との関係で分岐する:

| 状況 | 対応 |
|---|---|
| 全パッケージが登録済み | そのまま手順 1 へ進む |
| 未登録パッケージを **今回リリースする** | 同期は不要。リリース PR（手順 6）で `marketplace.json` 追記を同梱する |
| 未登録パッケージを **今回リリースしない** | 先に **marketplace 同期 PR** を作成・マージしてから手順 1 へ進む |

未登録パッケージが見つかった場合は、`.claude-plugin/plugin.json` が存在することを事前確認する。存在しなければリリース対象として未準備のため、ユーザーに通知して中断する。

#### 同期 PR の手順（リリース対象外の未登録パッケージがある場合のみ）

このフェーズは main/master ブランチから開始する。作業ブランチにいる場合はユーザーに状況確認してから進める。

```bash
git checkout main && git pull origin main
git checkout -b chore/sync-marketplace-$(date +%Y%m%d)
```

ブランチ名は CLAUDE.md のルール (`chore/<説明>-YYYYMMDD`) に従う。`.claude-plugin/marketplace.json` の `plugins` 配列に未登録パッケージのエントリを追加する（`name` + `source` のみ）:

```json
{ "name": "<package-name>", "source": "./packages/<package-name>" }
```

コミットメッセージ:

```
📦 chore: add <package-names> to marketplace
```

`create_pull_request` で PR 作成 → `issue_write` でアサイン → `merge_pull_request`（squash）でマージ。マージ後は main を pull し、リモートブランチを削除してから手順 1 に進む:

```bash
git checkout main && git pull origin main
git push origin --delete chore/sync-marketplace-<date>
```

### 1. 対象パッケージの特定

`packages/` 配下の各プラグインの `.claude-plugin/plugin.json` を読み取り、登録されているパッケージ一覧を取得する。

- パッケージが1つだけ → そのパッケージを対象とする
- 複数パッケージがある → ユーザーに対象を確認する（`-p` で指定があればそれに従う）

新規追加パッケージ（手順 0 で marketplace に追加したもの）が含まれる場合、初回リリースとなるため手順 2 でユーザーにバージョン指定を促す。

### 2. 前回バージョンの特定

対象 claude package の既存タグを検索する:

```bash
git tag --list '<package-name>@*' --sort=-v:refname | head -1
```

- **タグが存在する** → そのバージョンを前回バージョンとして使用
- **タグが存在しない（初回リリース）** → ユーザーにバージョンを手動指定してもらう（`-p` で指定があればそれに従う）

### 3. 差分分析とバージョン判定

前回タグから HEAD までの `packages/<package-name>/` 配下の差分を分析する:

```bash
git diff --name-only <package-name>@<version>..HEAD -- packages/<package-name>/
```

「バージョンバンプルール」に照らして判定し、ユーザーに提示する:

```
対象: mjc-git-workflow-tools
現在: 1.0.0 → 次版: 1.1.0 (新スキル追加 → マイナー)
```

初回リリースの場合は差分分析をスキップし、ユーザー指定のバージョンをそのまま使う。

### 4. ユーザー確認

バージョンと変更内容の要約を提示し、承認を得る。ユーザーが別のバージョンを指定した場合はそれに従う。

### 5. リリースブランチの作成

現在のブランチが main/master の場合のみリリースブランチを作成する:

```
release/<package-name>-v<version>
```

例: `release/mjc-git-workflow-tools-v1.1.0`

既に作業ブランチにいる場合は、そのブランチ上で作業を続ける。

### 6. plugin.json の更新

対象 claude package の `packages/<package-name>/.claude-plugin/plugin.json` の `version` を新バージョンに更新する。

**初回リリースで `marketplace.json` 未登録の場合**: 同じコミットで `.claude-plugin/marketplace.json` の `plugins` 配列にもエントリを追加する（`{ "name": "<package-name>", "source": "./packages/<package-name>" }`）。

### 7. コミット

変更をコミットする:

```
🔖 release(<package-name>): v<version>
```

`Co-Authored-By` トレーラーは付けない。`--no-verify` は使わない。

### 8. プッシュ

ブランチをリモートにプッシュする:

```bash
git push -u origin <branch>
```

### 9. PR 作成

GitHub MCP ツール (`create_pull_request`) で PR を作成する。

**タイトル**: `release(<package-name>): v<version>`

**本文**: [assets/release-pr-template.md](assets/release-pr-template.md) を使用。

PR 作成後、`issue_write` でアサインとラベル（`release` があれば付与）を設定する（GitHub API では PR も Issue 番号で操作可能）。

### 10. squash merge

PR の CI チェックが通っていることを確認してから `merge_pull_request`（merge_method: `squash`）で squash merge する。

CI チェックが設定されていない場合はそのままマージする。マージ後、`git push origin --delete <branch>` でリモートブランチを削除する。

### 11. タグ付け

squash merge 後、main 上の新しいコミットにタグを付ける:

```bash
git checkout main
git pull origin main
git tag <package-name>@<version>
git push origin <package-name>@<version>
```

### 12. 結果報告

以下を表示して完了:

```
リリース完了:
  パッケージ: <package-name>
  バージョン: <old-version> → <version>
  タグ: <package-name>@<version>
  PR: <pr-url>
```

## 注意事項

- main への直接コミットはしない（必ず PR 経由）
- `--no-verify` は使わない
- force push はしない（タグは squash merge 後に main 上で作成するため不要）
- リリース PR では `plugin.json` 以外のファイルは変更しない（ソースコードの変更は事前にコミット済みであること）。ただし**初回リリースに限り**、`marketplace.json` への登録追記を同梱可
- 今回リリース対象外の未登録パッケージがある場合は、先に marketplace 同期 PR を分離してマージする
