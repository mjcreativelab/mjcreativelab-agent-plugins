# skills-sources

claude package と codex plugin で配布する skill 一式の **正本**を置くディレクトリ。

## 階層

```
skills-sources/
└── <package-name>/
    └── <skill-name>/
        ├── SKILL.md       # 必須
        ├── README.md      # 任意
        ├── assets/        # 任意（テンプレート、シェルスクリプト等）
        └── references/    # 任意（対応表、ルール表等の読み取り専用情報）
```

ディレクトリ階層 `<package-name>/<skill-name>/` が claude package 所属を表現する。

## 配布先（同期によって生成される）

`/skill-sync`（または `python3 tools/sync_skill_sources.py`）で以下にミラーされる:

| 配布先 | パス | レイアウト |
|---|---|---|
| claude package | `packages/<package>/skills/<skill>/` | package 階層を保持 |
| codex plugin | `.codex-plugin/skills/<skill>/` | package を平坦化 |

両配布先は skills-sources の **完全ミラー**（orphan 削除あり）。配布先の中身を直接編集しても次回 sync で上書き・削除される。

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
```
