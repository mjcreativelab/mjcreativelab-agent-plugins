---
name: auto-release
description: リポジトリの repo-level バージョン（v<X.Y.Z> タグ）を自動判定して発行し、GitHub Release を作成する。ユーザーが「リリースして」「バージョン上げて」「タグ切って」「/auto-release」と言ったら起動する。
metadata:
  internal: true
---

# Auto Release

`npx skills` 配布のために repo-level の `v<X.Y.Z>` タグを発行する。配布 skill 本体は
`skills/<skill>/` が正本で、配布は `npx skills`（git tree-SHA ベース）。本 skill 自身は
`internal/` 配下の内部 skill（配布対象外）。
利用者は `npx skills add '<repo>#v<X.Y.Z>' ...` でバージョンを pin できる（`#` が ref。`@` は skill フィルタ）。

> Claude marketplace（`.claude-plugin/marketplace.json` / per-package `plugin.json` /
> per-package タグ `<package>@<semver>`）は v2.0.0 で撤去済み。本スキルは repo-level タグ専用。

## オプション

`-p <プロンプト>`: バージョン番号の指定や挙動の上書き（例: `-p v2.1.0 にして` / `-p major で`）。

## バージョン体系

- **形式**: repo-level SemVer タグ `v<X.Y.Z>`（例: `v1.0.0`, `v2.0.0`）
- **格納先**: git タグのみ（バージョンファイル・plugin.json は持たない）
- **判定基準**: 前回 `v*` タグから HEAD までの **`skills/` 配下**の差分（配布対象 skill の変化）

### バンプルール

前回タグからの差分を分析し、最も大きいバンプを適用する。

| 変更内容 | バンプ | 例 |
|----------|--------|-----|
| 配布 skill の削除・リネーム・互換性破壊（`skills/` 差分に現れる） | **メジャー** | 1.2.0 → 2.0.0 |
| 配布 skill の新規追加（`skills/` 下に新ディレクトリ） | **マイナー** | 1.0.0 → 1.1.0 |
| 既存 skill の修正・改善（上記以外） | **パッチ** | 1.0.0 → 1.0.1 |

- 内部 skill（`metadata.internal: true`。例: 本 `auto-release`）の変更は配布物に影響しないためバンプ対象外。
- ドキュメントのみ（README / CLAUDE.md / docs）の変更も配布 skill 不変ならバンプ不要（必要なら `-p` で明示）。
- リポジトリ構造・配布経路の**一度きりの破壊的変更**（例: v2.0.0 の marketplace 撤去）は `skills/` 差分に現れないため自動判定の対象外。`-p` で明示的に major を指定してリリースする。

## ツール選択

GitHub Release 作成は `gh release create`。git 操作は Bash。

## 手順

### 0. 事前チェック

- **main 上で実行する**（リリースは main の HEAD をタグ付けするため、対象変更は merge 済みであること）。作業ブランチにいる場合はユーザーに確認し、main へ切替・pull する。

```bash
git rev-parse --abbrev-ref HEAD
git fetch origin main
git checkout main && git pull --ff-only origin main
```

### 1. 前回バージョンの特定

```bash
git tag --list 'v*' --sort=-v:refname | head -1
```

- タグあり → そのバージョンを前回値
- タグ無し（初回）→ ユーザーにバージョンを確認（`-p` 指定があればそれに従う）

### 2. 差分分析とバンプ判定

**前回タグがある場合のみ**差分分析する（初回リリース＝前回タグ無しは本手順をスキップし、手順 3 でユーザー指定のバージョンをそのまま使う）:

```bash
git diff --name-status <v-prev>..HEAD -- skills/
```

skill ディレクトリ単位で追加（`A`）/ 削除（`D`）/ リネーム（`R`）/ 修正（`M`）を集計し、「バンプルール」で判定する。差分が無ければ「リリース不要」と報告して終了（`-p` で強制指定があれば従う）。

**内部 skill の除外**: 削除（`D`）・リネーム（`R`）と判定したエントリは、旧リビジョン側の frontmatter を確認し（`git show <v-prev>:<旧パス> | head -8`）、`metadata.internal: true` の skill はバンプ判定から除外する（例: 内部 skill の `internal/` への移設は `D skills/...` に見えるが major 対象ではない）。

### 3. ユーザー確認

新バージョンと変更内容の要約を提示し、承認を得る:

```
前回: v1.1.0 → 次版: v1.2.0 (新 skill 追加 → マイナー)
配布 skill 差分:
  A skills/<new-skill>/SKILL.md
  M skills/smart-commit/SKILL.md
```

ユーザーが別バージョンを指定した場合（破壊的変更で major にするなど）はそれに従う。

### 4. タグ発行

main の HEAD に注釈付きタグを作成・push する:

```bash
git tag -a v<X.Y.Z> -m "v<X.Y.Z>: <変更要約>"
git push origin v<X.Y.Z>
```

`--no-verify` は使わない。force push はしない（タグは新規発行のみ）。

### 5. GitHub Release 作成

```bash
gh release create v<X.Y.Z> --title "v<X.Y.Z>" --notes "<差分要約・移行注記>"
```

リリースノートに配布 skill の差分要約を載せる。破壊的変更がある場合は移行手順を明記する。

### 6. 結果報告

```
リリース完了:
  バージョン: v<old> → v<X.Y.Z>
  タグ: v<X.Y.Z>
  Release: <release-url>
  pin 例: npx skills add 'mjcreativelab/mjcreativelab-agent-plugins#v<X.Y.Z>' --skill <name> -g
```

## 注意事項

- main への直接コミットはしない。本スキルはタグ発行のみで、ソース変更は事前に PR 経由で merge 済みであること
- `--no-verify` / force push は使わない
- 旧 per-package タグ（`<package>@<semver>`）・旧 codex タグ（`mjcreativelab-claude-plugins@1.0.0`）は不変で残る。repo-level タグ `v*` とは別軸（履歴）
- CHANGELOG を運用する場合は GitHub Release のノートを一次情報とする
