# skills-sources

claude package と codex plugin で配布する skill 一式の **正本**を置くディレクトリ。
配布先へは単純コピーではなく、target ごとの render で書き出す。

## 階層

```
skills-sources/
└── <package-name>/
    └── <skill-name>/
        ├── SKILL.md       # 必須
        ├── README.md      # 任意
        ├── assets/        # 任意（テンプレート、シェルスクリプト等）
        ├── references/    # 任意（対応表、ルール表等の読み取り専用情報）
        ├── codex/         # 任意（codex 専用 override）
        ├── claude/        # 任意（claude 専用 override）
        └── skill-sync.yaml # 任意（target ごとの有効/無効・除外設定）
```

ディレクトリ階層 `<package-name>/<skill-name>/` が claude package 所属を表現する。

## 配布先（同期によって生成される）

`/skill-sync`（または `python3 tools/sync_skill_sources.py`）で以下に render される:

| 配布先 | パス | レイアウト |
|---|---|---|
| claude package | `packages/<package>/skills/<skill>/` | package 階層を保持 |
| codex plugin | `skills/<skill>/`（ルート直下） | package を平坦化 |

配布先は generated。配布先の中身を直接編集しても次回 sync で上書き・削除される。

## render ルール

- 共通ファイル（`SKILL.md` / `assets/` / `references/` 等）を各 target へ出力する
- `codex/` または `claude/` 配下に同名ファイルがあれば、target 側では root に重ねる
  - 例: `codex/SKILL.md` → `skills/<skill>/SKILL.md`
  - 例: `codex/references/foo.md` → `skills/<skill>/references/foo.md`
- `codex/` / `claude/` / `skill-sync.yaml` / `skill-sync.json` は配布先に出さない
- Codex 向け `SKILL.md` は frontmatter を Codex validator 向けに正規化する
  - 残す key: `name`, `description`, `license`, `metadata`
  - 削る key: `argument-hint`, `disable-model-invocation`, `model`, `allowed-tools` など
- Codex 向けは `README.md` をデフォルトで出さない。必要な場合は `include_readme: true` を指定する
- render 結果に存在しないファイルは配布先から削除する（orphan 削除あり）

## skill-sync.yaml

target ごとの差分は `skill-sync.yaml` に書く。外部 YAML ライブラリを使わないため、以下の subset のみ使用する。

```yaml
targets:
  claude:
    enabled: true
  codex:
    enabled: true
    include_readme: false
    exclude:
      - references/claude-only.md
```

| key | 説明 |
|---|---|
| `enabled` | `false` にすると、その target の配布先を空にする（既存 generated ファイルは削除対象） |
| `include_readme` | Codex target で `README.md` も出す場合に `true` |
| `exclude` | target に出さないファイル/ディレクトリのリスト |

## 制約

- **skill 名はリポジトリ全体で一意**である必要がある（codex 側がフラット配置のため）
- 配布先に symlink を作成しない（実体コピーのみ）
- `.claude/skills/`（プロジェクトローカルスキル）はこの同期処理の対象外

## コマンド

```bash
# 全スキル同期
python3 tools/sync_skill_sources.py

# 個別同期
python3 tools/sync_skill_sources.py smart-commit

# 差分確認のみ（exit 1 = 差分あり）
python3 tools/sync_skill_sources.py --check

# codex 側だけ差分確認
python3 tools/sync_skill_sources.py --check --target codex

# codex skill の frontmatter 検証
python3 tools/validate_codex_skills.py
```
