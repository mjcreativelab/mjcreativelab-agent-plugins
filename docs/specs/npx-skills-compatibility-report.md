# npx skills 互換性検証レポート（Phase 0）

- 日付: 2026-06-02
- 対象: `npx skills`（[vercel-labs/skills](https://github.com/vercel-labs/skills)）での本リポジトリ skill の探索・install 挙動
- 環境: node v24.13.0 / npx 11.6.2（mise シム経由）。実行時に `claude-code` agent を自動判定（非対話 install）

## 実施テストと結果

### Test 1: 探索（`npx skills add ./ --list`）
- **17 skill を検出**（`packages/<plugin>/skills/` の 15 + `.claude/skills/` の auto-release・skill-sync 2）。同名は dedup。
- `allowed-tools` / `argument-hint` / `disable-model-invocation` を含む skill も**エラーなく**列挙。
- → npx の探索は `packages/` のネストも `.claude/skills/` も拾う**貪欲**な挙動。

### Test 2: install（リポジトリ全体をソース指定）
- `npx skills add <repo> --skill smart-commit` → **`./.agents/skills/smart-commit/`** に配置。
  - 表示: `universal: Codex, Cursor, Gemini CLI, GitHub Copilot, Amp +9 more`（**14 エージェント対応**）。
- だが install された frontmatter は `name`+`description` のみに**削られていた**。
  - 原因 = npx が**正規化済みの root `skills/`（codex render）を優先選択**したため（npx が削ったのではない。Test 3 で確定）。

### Test 3: install（フル仕様のみのソース `packages/mjc-git-workflow-tools` を指定）
- 同じ `.agents/skills/smart-commit/` に配置。
- frontmatter は `argument-hint` / `disable-model-invocation` / `allowed-tools` **すべて逐語保持**。
- プロジェクトに `skills-lock.json` が生成された（移行計画執筆時の想定 `~/.agents/.skill-lock.json`（global のみ）から進化している可能性 → project-scope update を再確認要）。

## 結論

1. ✅ **npx skills はフル Claude frontmatter を逐語保持**（正規化しない）。§2「解決済み」note を実機で裏付け。
2. ✅ **universal install 先 = `.agents/skills/`**（APM・cookbook と同一規約）。14 エージェント（Amp 含む）対応。
3. ⚠️ **同名 skill が複数箇所に存在すると探索優先順位が曖昧**（root `skills/` 正規化版 vs `packages/` フル版）。
   → **単一の正本に集約必須**。推奨: 正本を `.agents/skills/<skill>/`（フル frontmatter）に一本化し、codex 正規化版 root `skills/` は撤去。
4. ⚠️ 内部用 meta-skill（auto-release。skill-sync は本移行で削除予定）が `.claude/skills/` から探索される。
   → `--skill '*'` で過剰提示の懸念。内部 skill は `.claude/skills/` に留め、配布は named install かキュレーション dir（`skills/.curated/` 等）で制御。
5. ℹ️ frontmatter 厳格度・token reject の問題は**発生せず**（§2 の結論と整合）。

## 残タスク（実機ランタイム・要ユーザー操作）
- install 済み skill を **Claude Code** で起動 → 認識・動作確認。
- 同 skill を **Codex** で起動 → 認識・動作確認、tool token（`AskUserQuestion` / `${CLAUDE_SKILL_DIR}` 等）の graceful degradation 記録。
- `skills-lock.json`（project）での `npx skills update` 挙動を確認（[#337](https://github.com/vercel-labs/skills/issues/337) が解消済みか）。

## 計画への反映提案
- 移行計画 §3.1 の正本配置を root `skills/` → **`.agents/skills/`** に変更（universal install 先・APM/cookbook と整合）。
- Phase 2 の「単一 target 化」は本検証で必要性が裏付けられた（複数コピーの優先順位曖昧を解消するため）。
