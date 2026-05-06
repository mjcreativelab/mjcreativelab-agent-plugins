---
name: skill-sync
description: skill-sources の skill ディレクトリを claude/codex の配布先に target 別 render する。/skill-sync で全スキル同期、/skill-sync <skill-name> で個別同期、/skill-sync --check で差分確認。
disable-model-invocation: true
argument-hint: "[skill-name|--check]"
---

# skill-sync

`skill-sources/<package>/<skill>/` 配下の skill 一式を正本として、配布先に target 別 render する。

| 配布先 | パス | レイアウト |
|---|---|---|
| claude package | `packages/<package>/skills/<skill>/` | package 階層を保持 |
| codex plugin | `skills/<skill>/`（ルート直下、`.codex-plugin/plugin.json` の `"skills": "./skills/"` 参照先） | package を平坦化 |

`.codex-plugin/` ディレクトリは plugin metadata（`plugin.json`）専用で、skill 本体はリポジトリルートの `skills/` に配置する。

render 結果に無いファイルは target から削除される（orphan 削除）。共通ファイルを基準にしつつ、`codex/` または `claude/` 配下の override を target root に重ねられる。

ディレクトリ階層が package 所属を表現するため、新規 package・新規 skill を追加してもスクリプトの編集は不要。codex 側はフラットに配置されるため、**skill 名はリポジトリ全体で一意**である必要がある（重複時はエラーで停止）。

## source 構造

```
skill-sources/<package>/<skill>/
  SKILL.md
  README.md
  assets/
  references/
  codex/          # 任意: codex 専用 override
  claude/         # 任意: claude 専用 override
  skill-sync.yaml # 任意: target ごとの設定
```

override は target root に重ねる。例: `codex/SKILL.md` は `skills/<skill>/SKILL.md` として出力される。

Codex 向け `SKILL.md` は frontmatter を Codex validator 向けに正規化する:

- 残す key: `name`, `description`, `license`, `metadata`
- 削る key: `argument-hint`, `disable-model-invocation`, `model`, `allowed-tools` など
- `README.md` はデフォルトで Codex に出さない

## 引数の解析

| `$ARGUMENTS` | 動作 |
|---|---|
| 空 | 全スキルをミラー |
| `<skill-name>` | 指定スキルのみミラー |
| `--check` | 差分確認のみ（書き込み・削除なし） |
| `--target claude` | claude target のみ同期/確認 |
| `--target codex` | codex target のみ同期/確認 |

## 実行

```bash
python3 tools/sync_skill_sources.py $ARGUMENTS
```

通常モードの出力:

| ラベル | 意味 |
|---|---|
| `OK` | 同期済み（変更なし） |
| `COPIED` | render 結果を target へコピー/書き込み（新規・更新） |
| `REMOVED` | target にあって render 結果に無い orphan を削除 |
| `DISABLED` | `skill-sync.yaml` で target が無効化されている |

`--check` モードでは書き込みを行わず、`OUTDATED` / `ORPHAN` で差分のみ報告し、差分があれば exit code 1 で終了する。

Codex target の生成後は、必要に応じて frontmatter 検証を実行する:

```bash
python3 tools/validate_codex_skills.py
```

## 運用フロー

```
skill-sources/<package>/<skill>/ 配下を編集
  → /skill-sync --check   ← 差分確認
  → /skill-sync           ← claude/codex 両方へミラー
  → git commit & push
```

## 重要な前提

- **正本は `skill-sources/`**。`packages/<pkg>/skills/<skill>/` と `skills/<skill>/`（ルート直下） の中身は generated。直接編集しても次回 sync で上書き・削除される
- skill 単位で render 同期するため、render 結果に無いファイルは target から削除される
- Claude 専用 skill は `skill-sync.yaml` で `targets.codex.enabled: false` にする
- Codex 専用の手順・ツール名が必要な場合は `codex/SKILL.md` を作る

## 対応スキル一覧

`skill-sources/<package>/<skill>/SKILL.md` を走査して自動検出する。スクリプトの編集は不要。

### 既存 package に新規スキル追加

1. `skill-sources/<package>/<new-skill>/SKILL.md` を作成
2. 必要なら `skill-sources/<package>/<new-skill>/assets/` `references/` `README.md` も配置
3. Codex にそのまま出せない場合は `codex/SKILL.md` または `skill-sync.yaml` を追加
4. `/skill-sync` を実行 → `packages/<package>/skills/<new-skill>/` と `skills/<new-skill>/` の両方が自動作成される

### 新規 package + 新規スキル追加

1. `skill-sources/<new-package>/<new-skill>/` 配下に skill 一式を作成
2. `packages/<new-package>/.claude-plugin/plugin.json` を作成（version・name 等を記述）
3. `.claude-plugin/marketplace.json` の `plugins` 配列にエントリを追加
4. `/skill-sync` を実行 → claude / codex の配布先が自動作成される
