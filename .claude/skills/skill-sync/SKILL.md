---
name: skill-sync
description: skills-sources の skill ディレクトリを claude/codex の配布先にミラーする。/skill-sync で全スキル同期、/skill-sync <skill-name> で個別同期、/skill-sync --check で差分確認。
disable-model-invocation: true
argument-hint: "[skill-name|--check]"
---

# skill-sync

`skills-sources/<package>/<skill>/` 配下の **skill ディレクトリ全体**（SKILL.md / assets/ / references/ / README.md など）を正本として、配布先にミラーする。

| 配布先 | パス | レイアウト |
|---|---|---|
| claude package | `packages/<package>/skills/<skill>/` | package 階層を保持 |
| codex plugin | `skills/<skill>/`（ルート直下、`.codex-plugin/plugin.json` の `"skills": "./skills/"` 参照先） | package を平坦化 |

`.codex-plugin/` ディレクトリは plugin metadata（`plugin.json`）専用で、skill 本体はリポジトリルートの `skills/` に配置する。

ミラーは**完全同期**で、source に無いファイルは target から削除される（orphan 削除）。これにより `${CLAUDE_SKILL_DIR}/assets/...` など skill 内の相対参照が両配布先で同じ構造で解決される。

ディレクトリ階層が package 所属を表現するため、新規 package・新規 skill を追加してもスクリプトの編集は不要。codex 側はフラットに配置されるため、**skill 名はリポジトリ全体で一意**である必要がある（重複時はエラーで停止）。

## 引数の解析

| `$ARGUMENTS` | 動作 |
|---|---|
| 空 | 全スキルをミラー |
| `<skill-name>` | 指定スキルのみミラー |
| `--check` | 差分確認のみ（書き込み・削除なし） |

## 実行

```bash
python3 tools/sync_skill_sources.py $ARGUMENTS
```

通常モードの出力:

| ラベル | 意味 |
|---|---|
| `OK` | 同期済み（変更なし） |
| `COPIED` | source から target へコピー（新規・更新） |
| `REMOVED` | target にあって source に無い orphan を削除 |

`--check` モードでは書き込みを行わず、`OUTDATED` / `ORPHAN` で差分のみ報告し、差分があれば exit code 1 で終了する。

## 運用フロー

```
skills-sources/<package>/<skill>/ 配下を編集
  → /skill-sync --check   ← 差分確認
  → /skill-sync           ← claude/codex 両方へミラー
  → git commit & push
```

## 重要な前提

- **正本は `skills-sources/`**。`packages/<pkg>/skills/<skill>/` と `skills/<skill>/`（ルート直下） の中身は generated。直接編集しても次回 sync で上書き・削除される
- skill 単位で完全同期するため、source に無いファイルは target から削除される

## 対応スキル一覧

`skills-sources/<package>/<skill>/SKILL.md` を走査して自動検出する。スクリプトの編集は不要。

### 既存 package に新規スキル追加

1. `skills-sources/<package>/<new-skill>/SKILL.md` を作成
2. 必要なら `skills-sources/<package>/<new-skill>/assets/` `references/` `README.md` も配置
3. `/skill-sync` を実行 → `packages/<package>/skills/<new-skill>/` と `skills/<new-skill>/` の両方が自動作成される

### 新規 package + 新規スキル追加

1. `skills-sources/<new-package>/<new-skill>/` 配下に skill 一式を作成
2. `packages/<new-package>/.claude-plugin/plugin.json` を作成（version・name 等を記述）
3. `.claude-plugin/marketplace.json` の `plugins` 配列にエントリを追加
4. `/skill-sync` を実行 → claude / codex の配布先が自動作成される
