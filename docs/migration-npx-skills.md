# Migration Plan: `npx skills add` への一本化

本リポジトリの skill 配布経路を、Claude Code marketplace と Codex marketplace の 2 系統から、vercel-labs/skills の `npx skills add` 1 系統に集約するための移行計画。

- 対象: `packages/` 配下の全 skill + 今後追加される skill
- 期間想定: フェーズ 1〜4 を 2〜3 リリースサイクル
- 上位ゴール: 1 つの install コマンドで Claude Code / Codex / Cursor / Gemini CLI を横断的にサポートする

## 実装メモ（2026-06-02 更新・原計画からの変更）

Phase 0 検証（`docs/specs/npx-skills-compatibility-report.md`）の結果を受け、原計画から以下を変更して着手済み:

- **主チャネル = `npx skills`** に決定（marketplace は当面維持し Phase 3-4 で sunset）。
- **正本 = `packages/<plugin>/skills/` を直接編集**（= b1）。原計画 §1.3 / §3.1 は `skill-sources/` を
  維持する想定だったが、単一 target では `skill-sources/` → `packages/` が無変換の冗長コピーになるため、
  **`skill-sources/` / `/skill-sync` / `tools/sync_skill_sources.py` / `tools/validate_codex_skills.py` を全廃**した。
- **正規化版 root `skills/` と root `.codex-plugin/` を削除**（旧 Codex 単一プラグイン配布を撤去）。`npx skills` は
  `packages/<plugin>/skills/`（フル frontmatter）を一意に解決する（探索衝突を解消済み）。
- 正本配置は当面 `packages/` のまま（`.agents/skills/` への集約は将来検討）。
- `auto-release` は claude package 単一バージョニングへ簡素化済み。
- 以下の Phase 記述のうち「`skill-sources/` 維持」「`packages/<plugin>/skills/` 削除」を前提とする箇所は
  本メモが優先する（Phase 2 の sync 単一化は「skill-sources 全廃」で代替済み）。
- **タグ運用を確定**: repo-level `v<X.Y.Z>`（npx pin 用・初回 `v1.0.0`）+ per-package `<package>@<semver>`
  （Claude marketplace 用）の併用。`v2.0.0` は marketplace 撤去（Phase 4）に予約。
- **内部 skill の扱い**: `auto-release` に `metadata.internal: true` を付与（`npx skills ... --list` の表示から隠す）。
  ただし**このバージョンの npx は `--skill '*'` から internal を除外しない**ため、wildcard install には含まれる。
  クリーンな配布は `--skill <name>` の名前指定で行う（要追跡: npx 側の wildcard 除外手段 / auto-release の配置）。
- **Phase 3-4 をクリーンカットで実施（2026-06-02）**: sunset 期間を置かず、Claude marketplace を即撤去。
  `.claude-plugin/marketplace.json` と per-package `.claude-plugin/plugin.json` を削除、`/auto-release` を
  repo-level `v<X.Y.Z>` タグ運用へ全面改修、README/CLAUDE.md から marketplace 記述を除去、`v2.0.0` を発行。
  以降の配布は `npx skills` のみ。
- **v2.0.1: skill を `skills/<skill>/`（トップレベル）へ移設**: v2.0.0 後に判明した問題への修正。`npx skills` の
  **リモート clone 時のデフォルト探索は浅い（2 階層）**ため、`packages/<group>/skills/<skill>/`（4 階層）は
  `--full-depth` 無しでは発見されず（clean probe で default=1 / `--full-depth`=16 を確認）。marketplace.json が
  暗黙の探索ポインタを兼ねていたため撤去で露呈した。配布 skill を npx 標準の浅い `skills/<skill>/` へ移設し、
  `packages/<group>/` は README（グループ説明）のみに。`/auto-release` のバンプ判定基準も `skills/` 差分へ更新。
  ~~**注意（要クリーン環境検証）**: 内部 skill `auto-release`（`.claude/skills/`）が `skills/` 探索を妨げないかは、
  本セッションの npx clone キャッシュ汚染により未検証。別マシン/CI 等の clean 環境で `@v2.0.1 --list` が
  全 skill を返すことを確認すること。~~ → **検証済み・解消（2026-06-02）**: `'#v2.0.1' --list` が
  15 配布 skill を返すことを確認（次項参照。`@v2.0.1` という当時の検証コマンド自体が誤構文だった）。
- **`@<ref>` 問題の真因判明（2026-06-02・CLI v1.5.9 ソース照合 + 実証）**: `owner/repo@X` の `@X` は
  **ref ではなく skill フィルタ**（`--skill X` 相当）。本メモおよび README の `@v<X.Y.Z>` pin 例は version pin
  として機能していなかった（探索は常に default branch）。「キャッシュ汚染」「CLI バージョンの揺れ」という
  当時の推定は誤り。正しい ref pin は fragment 構文 **`owner/repo#v<X.Y.Z>`**（`#ref@skill` 複合可）。
  `'#v2.0.1' --list` が 15 skill を返すこと、probe ブランチで `#ref` install が ref の中身を届けることを実証済み。
  既知の上流問題: blob fast path（skills.sh download API）は ref を渡さない
  （[vercel-labs/skills#1123](https://github.com/vercel-labs/skills/pull/1123) で修正中）。詳細は Issue #47 のコメント参照。

> ⚠️ **以降（§1〜§9）は実装前の当初ドラフト（2026-05 時点・履歴）**。`skill-sources/` / `/skill-sync` /
> `tools/sync_skill_sources.py` / ルート `skills/` / `packages/*/skills/` 削除 などに言及する箇所は、
> 上記「実装メモ」と実際の実装（PR #46）で**撤去済みの旧構造**を指す。現行の正は「実装メモ」。
> 未着手で有効なのは Phase 3-4（marketplace の deprecate → 撤去）と Phase 1 残り（タグ運用・ラベル）のみ。

## 1. 背景と目的

### 1.1 現状（As-Is）

3 つの distribution path が並走している:

| 経路 | エントリポイント | 配置先 | frontmatter |
|------|------|------|------|
| Claude Code marketplace | `.claude-plugin/marketplace.json` + `packages/<plugin>/.claude-plugin/plugin.json` | `packages/<plugin>/skills/<skill>/` | フル仕様 |
| Codex marketplace | `.codex-plugin/plugin.json` | `skills/<skill>/`（ルート直下、平坦） | 正規化済み（`argument-hint` / `allowed-tools` / `disable-model-invocation` / `model` を除去） |
| ローカル試用 | `claude --plugin-dir ./packages/<plugin>` | 同上 | フル仕様 |

正本は `skill-sources/<package>/<skill>/`。`tools/sync_skill_sources.py`（`/skill-sync`）が上記 2 target に render する。

### 1.2 課題

- 同じ skill を 2 経路に同期する負荷と、frontmatter 差異の維持コスト
- 利用者から見て「どの install 方法が正解か」が分かりにくい
- 新規エージェント（Cursor / Gemini CLI 等）に都度 distribution path を増やすコスト
- per-plugin 単位のバージョニング（`mjc-git-workflow-tools@1.1.6` 形式）が npx skills の repo-level 取得モデルと噛み合わない

### 1.3 目的

- 配布経路を `npx skills add mjcreativelab/mjcreativelab-agent-plugins` 1 つに集約
- frontmatter は Claude フル仕様で統一（`argument-hint` / `allowed-tools` / `disable-model-invocation` を保持）
- skill 著者のフロー（`skill-sources/` を編集 → `/skill-sync`）は変更しない

## 2. 技術調査サマリ

`npx skills`（[vercel-labs/skills](https://github.com/vercel-labs/skills)）の挙動を確認した結果:

- **Source 指定**: `owner/repo` ショートハンド / 完全 URL / repo 内の skill パス / ローカルパス
- **探索場所**: repo ルート, `skills/`, `skills/.curated/`, `skills/.experimental/`, `skills/.system/`, `.claude/skills/`, `.agents/skills/` 等。標準場所で見つからない場合のみ再帰探索が走る
- **必須 frontmatter**: `name`（kebab-case）, `description`
- **コマンド**: `npx skills add <source> [--skill <name>...] [--skill '*'] [--list] [-g] [-a <agent>]`
- **インストール先**: project は `./.claude/skills/`, global は `~/.claude/skills/`。`-a <agent>` で agent 別パスに切替

→ 現状の root `skills/`（10 skill、Codex 正規化済み）は **そのままでも `npx skills` の標準探索対象**。配置は変えずに、frontmatter を Claude フル仕様に戻すだけで Claude / Codex 両対応の単一 distribution になる前提で計画する。

> **解決済み（2026-06-02 調査）**: Codex は Claude フル仕様 frontmatter を許容する。根拠 2 点:
> 1. **Agent Skills 標準仕様**（<https://agentskills.io/specification>）が `allowed-tools` を正式な
>    optional フィールドとして定義し、`metadata` を任意拡張枠とする。必須は `name` / `description` のみ。
>    本文（Markdown body）は「no format restrictions」。
> 2. **実証**: `st-tech/new-product-claude-cookbook`（同一著者の本番リポジトリ）が `allowed-tools` を
>    含む共有 SKILL.md を `.codex-plugin` + `.agents/plugins/marketplace.json` 経由で Codex 配布できている。
>
> `argument-hint` / `disable-model-invocation` は標準外だが Codex は **無視**する（reject ではない）。
> よって Phase 0 の frontmatter 厳格度検証は不要。残る Phase 0 タスクは「`npx skills` の探索/install 挙動」と
> 「tool token（`AskUserQuestion` / `${CLAUDE_SKILL_DIR}` 等）の graceful degradation」の確認に絞れる。

## 3. 目標状態（To-Be）

### 3.1 リポジトリレイアウト

```
.
├── skill-sources/                # 正本（変更なし）
│   └── <package>/<skill>/
├── skills/                       # render 先（npx skills 探索対象）
│   └── <skill>/SKILL.md          # Claude フル仕様 frontmatter
├── tools/
│   └── sync_skill_sources.py     # 単一 target に簡素化
├── README.md                     # 新 install 手順
└── CLAUDE.md                     # marketplace 記述を削除
```

削除されるもの:

- `.claude-plugin/marketplace.json`
- `.codex-plugin/plugin.json`（plus `.codex-plugin/` ディレクトリ）
- `packages/<plugin>/.claude-plugin/plugin.json`
- `packages/<plugin>/skills/` 配下（render 出力）
- `packages/<plugin>/README.md` の install セクション（package 単位のインストールは廃止のため）
- 場合により `packages/` ディレクトリ全体（README 集約後）

### 3.2 ユーザー向けインストール手順（最終形）

> 推奨は **グローバル install + tag pin**。プロジェクト install は `npx skills update` で更新できないため、用途を限る。

```bash
# 利用可能な skill 一覧
npx skills add mjcreativelab/mjcreativelab-agent-plugins --list

# ★推奨: グローバルに tag 固定でインストール（更新は `npx skills update` で完結）
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.0.0 --skill smart-commit -g
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.0.0 --skill '*' -g

# プロジェクト install（更新時は再 add が必要）
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.0.0 --skill smart-commit

# Codex / Cursor / Gemini 向け
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.0.0 --skill smart-commit -a codex -g

# 更新確認 / 取り込み（global のみ）
npx skills check
npx skills update            # 全 skill を最新タグへ
npx skills update smart-commit

# プロジェクト install の更新は再 add（lockfile に乗らないため）
npx skills add mjcreativelab/mjcreativelab-agent-plugins@v2.1.0 --skill '*'
```

### 3.3 バージョニングとアップデート方式

#### バージョニング

- 現状: per-plugin タグ（例: `mjc-git-workflow-tools@1.1.6`）
- 移行後: repo 単位の SemVer タグ（例: `v2.0.0`）
- `npx skills` は **GitHub tree SHA ベース**で更新を検出するため、SemVer は厳密には不要。ただし `@tag` 指定で pin できるため、利用者の supply-chain 安全性のためにリリースタグを継続発行する
- CHANGELOG で package 別に変更点を分類する

#### アップデート方式

marketplace の `/plugin update` とは挙動が異なるため、利用者向けの運用設計が必要。

| 観点 | 旧（marketplace） | 新（npx skills） |
|---|---|---|
| 更新単位 | プラグイン単位 | skill 単位 |
| バージョン基準 | `plugin.json` の SemVer | GitHub tree SHA（skill フォルダの hash） |
| Lockfile | なし（marketplace 側で管理） | `~/.agents/.skill-lock.json`（global のみ記録） |
| グローバル install の更新 | `/plugin update` | `npx skills update [name]` / `npx skills check` |
| プロジェクト install の更新 | `/plugin update` | **非対応**（`npx skills update` は silent skip） |
| pin | バージョン文字列 | `@<tag>` / `@<sha>` |

**重要な制約**: [vercel-labs/skills#337](https://github.com/vercel-labs/skills/issues/337) の通り、プロジェクトスコープ（`.claude/skills/` 配置）の skill は lockfile に記録されないため、`npx skills update` から **silent skip される**。回避策は `npx skills add` の再実行のみ。

#### 推奨運用（README に明記する内容）

1. **常用 skill はグローバル install を推奨**: `npx skills add mjcreativelab/mjcreativelab-agent-plugins@<tag> --skill <name> -g`
   - 更新は `npx skills update` で完結
   - 複数プロジェクトで使い回せる
2. **プロジェクト固有 skill のみプロジェクト install**: `npx skills add ... --skill <name>`（`-g` なし）
   - 更新は `npx skills add ... --skill '*'` の再実行で取り込む
   - README に「更新したい場合は再 add」と明示
3. **バージョン pin の推奨**: README 例示は `@<最新リリースタグ>` を含める形にし、HEAD 追従ではなく明示的アップデートを促す
4. **更新確認コマンド**: `npx skills check` でドリフト検出を案内（global のみ動作）

## 4. フェーズ計画

### Phase 0 — 事前検証（短縮版・0.5〜1 日）

frontmatter 厳格度は調査で解決済み（§2 の「解決済み」note 参照）。検証ゴールを
「`npx skills add` の探索/install 挙動」と「tool token の graceful degradation」に絞る。

| タスク | 検証コマンド | 期待結果 |
|------|------|------|
| 全 skill 列挙 | `npx skills add ./ --list` | 全 skill が表示される（探索場所が現レイアウトを拾うか確認） |
| Local install（Claude） | `npx skills add ./ --skill smart-commit` | `.claude/skills/smart-commit/SKILL.md` が配置される |
| Claude Code 認識 | `/smart-commit` をプロンプト入力 | 起動する |
| Codex install | `npx skills add ./ --skill smart-commit -a codex` | エラーなく配置される |
| Codex 認識 | Codex CLI から smart-commit を呼ぶ | 起動する（frontmatter 由来エラーは出ない想定。出れば記録） |
| Tool token 検証 | `AskUserQuestion` / `WebSearch` / `Skill` / `Agent` / `${CLAUDE_SKILL_DIR}` を含む skill を Codex で実行 | graceful degradation を確認（現状すでに Codex へ素通しのため退行なしのはず） |

成果物:

- `docs/specs/npx-skills-compatibility-report.md`（テスト結果）
- tool token の graceful degradation 結果一覧

判断ゲート: 万一 Codex で fatal error が出る場合のみ、Phase 2 で `skill-sync.yaml` の
per-target frontmatter override を残すパスに切り替える（frontmatter 起因は想定低）。

### Phase 1 — `npx skills` を並走経路として追加（1 リリース）

既存経路を残したまま、新経路を整備する。

1. **README 更新**
   - `README.md` の「インストール」セクションを 3 段構成に: 推奨（npx skills）/ 既存（marketplace）/ ローカル試用
   - npx skills セクションは「グローバル install + `@<tag>` pin」を一次案内にし、`npx skills update` / `npx skills check` の使い方を含める
   - プロジェクト install は二次案内とし、「更新は再 add」と明示する
   - `packages/<plugin>/README.md` にも個別の `npx skills add ... --skill <name>` 例を追記
2. **タグ運用の準備**
   - 次回リリースから `vX.Y.Z` 形式の repo-level タグを追加（per-plugin タグは継続）
   - `.claude/skills/auto-release/SKILL.md` に並走モードを追記
3. **Issue/PR ラベル**
   - `migration:npx-skills` ラベルを作成し、関連 PR を可視化

### Phase 2 — sync スクリプトを単一 target に簡素化（1 リリース）

`tools/sync_skill_sources.py` を修正:

| 変更点 | 詳細 |
|------|------|
| Target 数 | 2 → 1（`skills/` のみ） |
| Frontmatter 正規化 | `sanitize_codex_frontmatter()` を削除（または `targets.codex.strict_frontmatter: true` を opt-in に） |
| Render 先 | `packages/<plugin>/skills/<skill>/` への render を停止 |
| 平坦化検証 | skill 名のグローバル一意性チェックは維持 |
| Codex 互換性ガード | Phase 0 結果に応じ、必要最小限の token 除去を skill-sync.yaml の per-skill override で実装 |

スクリプト修正後:

```bash
# 旧 packages/<plugin>/skills/ を削除
git rm -r packages/*/skills/

# 新 sync で skills/ を再生成
python3 tools/sync_skill_sources.py

# 期待 diff: frontmatter に argument-hint / allowed-tools / disable-model-invocation が復活
```

CLAUDE.md 更新:

- 「Codex は以下の token を解釈できない」セクションを Phase 0 結果に基づき書き換える
- `tools/sync_skill_sources.py` の説明を新仕様に更新

### Phase 3 — 旧経路の deprecate（1 リリース）

1. `.claude-plugin/marketplace.json` の `description` に DEPRECATED 表記を追記
2. `packages/<plugin>/README.md` の冒頭に「このパッケージは npx skills 経由に統合中。next major で削除予定」の通知を追加
3. `.codex-plugin/plugin.json` の `description` に同様の表記
4. GitHub Issue で sunset を告知（migration 手順へリンク）
5. Sunset 期間を最低 1 リリースサイクル確保

### Phase 4 — 旧インフラを削除（major bump）

`v2.0.0` リリースで以下を削除:

```bash
git rm .claude-plugin/marketplace.json
git rm -r .codex-plugin/
git rm -r packages/*/.claude-plugin/
# packages/<plugin>/README.md は概要・スキル一覧として残すか統合判断
# 場合により packages/ ディレクトリ自体を撤去し README.md 集約
```

加えて:

- `CLAUDE.md` から marketplace / `.codex-plugin/` に関する記述を全削除
- `tools/sync_skill_sources.py` のコメントから旧構造への言及を削除
- `auto-release` skill を unified versioning 専用に書き換え

### Phase 5 — 後始末

- `docs/migration-npx-skills.md`（本ドキュメント）の Status を `Completed` に更新
- 過去の per-plugin tag は git tag として残す（不変）が、リリースノートで最終バージョンを明示
- 新規プラグイン追加手順（CLAUDE.md）を npx skills 前提に簡素化

## 5. 影響を受けるファイル一覧

| ファイル | 操作 | フェーズ |
|---|---|---|
| `README.md` | 編集（install 手順） | 1, 4 |
| `CLAUDE.md` | 編集（marketplace 記述削除） | 2, 4 |
| `tools/sync_skill_sources.py` | 編集（単一 target 化） | 2 |
| `packages/<plugin>/README.md` | 編集 → 削除 or 集約 | 1, 3, 4 |
| `packages/<plugin>/skills/` | 削除 | 2 |
| `packages/<plugin>/.claude-plugin/plugin.json` | 削除 | 4 |
| `.claude-plugin/marketplace.json` | 削除 | 4 |
| `.codex-plugin/plugin.json` | 削除 | 4 |
| `.claude/skills/auto-release/SKILL.md` | 編集（unified versioning） | 1, 4 |
| `.claude/skills/skill-sync/SKILL.md` | 編集（target 数の説明） | 2 |
| `docs/specs/npx-skills-compatibility-report.md` | 新規 | 0 |

## 6. リスクと緩和策

| リスク | 影響 | 緩和策 |
|---|---|---|
| Codex CLI が `argument-hint` 等を reject する | Codex ユーザーが skill を起動できない | **低リスク（解決済み・§2 note）**: Agent Skills 標準が `allowed-tools` を正式定義、cookbook が full frontmatter を本番 Codex 配布済み。`argument-hint` 等は Codex が無視。万一に備え `skill-sync.yaml` の per-target override は残せる |
| 既存 marketplace ユーザーが突然動かなくなる | ユーザー断絶 | Phase 1〜3 で並走 + 明示的告知。最低 1 リリースサイクルの sunset 期間 |
| Tool token（`AskUserQuestion` / `WebSearch` / `Skill` / `Agent` / `Task`）が Codex で動かない | 一部 skill が機能不全 | CLAUDE.md の「Codex 配布時の禁止 token」記述を維持し、対象 skill には `codex/SKILL.md` override で代替表現を用意 |
| `${CLAUDE_SKILL_DIR}` が Codex で解釈されない | スクリプト参照失敗 | 同上。`codex/SKILL.md` override で相対パスに置換 |
| per-plugin の semantic versioning 履歴が途切れる | リリースノート分断 | CHANGELOG で旧タグ → 新タグの対応表を提示 |
| Skill 名衝突（npx skills の flat 配置） | install 失敗 | `discover_skills()` の一意性検証で既に防止済み |
| `npx skills` の仕様変更（破壊的変更） | 移行先が安定しない | バージョン pin（`npx skills@<version>`）を README で例示。Phase 0 時点の vercel-labs/skills バージョンを記録 |
| README から marketplace 経路を削除した直後、検索流入のユーザーが迷う | DX 低下 | Phase 4 の README に「旧 marketplace は v1.x まで利用可能。`vX.Y.Z` 以降は npx skills 経由」と注記 |
| **プロジェクト install の skill が `npx skills update` で更新されない**（[#337](https://github.com/vercel-labs/skills/issues/337)） | 更新漏れ・ドリフト | README で「常用 skill は `-g`（global）install を推奨」を一次案内。プロジェクト install には「更新は `npx skills add ... --skill '*'` を再実行」を明記。`npx skills check` で global 側のドリフトを定期確認するワンライナーも例示 |
| Tree SHA ベースの更新検出のため、SemVer 感が薄い | リリースノートを追えない | repo-level タグを継続発行し、`@<tag>` での pin を README 例示で標準にする。CHANGELOG を `vX.Y.Z` 単位で維持 |
| HEAD 追従 install による supply-chain リスク | 意図しない変更の流入 | README の install 例を `@<tag>` 付き形式に統一。タグなし install は「お試し」用途と明記 |

## 7. ロールバック方針

- フェーズ 1〜3: 旧経路は無傷で動作するため、コード変更を revert すれば即座にロールバック可能
- フェーズ 2 後: `tools/sync_skill_sources.py` を旧版に戻し、`/skill-sync` を再実行すれば `packages/<plugin>/skills/` が再生成される
- フェーズ 4 後: git 履歴から `.claude-plugin/` / `.codex-plugin/` / `packages/` を復元可能。タグからの cherry-pick で再構築

## 8. 検証チェックリスト（フェーズ完了判定用）

### Phase 0
- [ ] `npx skills add ./ --list` で 14 skill が表示される
- [ ] Claude Code から各 skill が起動する
- [ ] Codex CLI から各 skill が起動する（or 動作不能 skill が明示されている）
- [ ] 互換性レポートが `docs/specs/` に保存されている

### Phase 1
- [ ] README に新 install 手順が記載されている
- [ ] 既存の marketplace 経路もまだ動作する
- [ ] `vX.Y.Z` 形式の repo-level タグが少なくとも 1 つ存在する

### Phase 2
- [ ] `skills/<skill>/SKILL.md` に Claude フル仕様 frontmatter が反映されている
- [ ] `packages/<plugin>/skills/` 配下がリポジトリから消えている
- [ ] `tools/sync_skill_sources.py` の単体テスト / smoke run が通る

### Phase 3
- [ ] README / `marketplace.json` / `.codex-plugin/plugin.json` に DEPRECATED 通知がある
- [ ] Sunset 告知 issue が open されている

### Phase 4
- [ ] `.claude-plugin/` / `.codex-plugin/` / `packages/<plugin>/.claude-plugin/` が削除されている
- [ ] CLAUDE.md から marketplace 関連の記述が削除されている
- [ ] `v2.0.0` タグが切られている

## 9. オープン課題

- [x] **`npx skills` の skill 取得対象 ref と update 挙動**: `@<tag>` / `@<sha>` で pin 可能。lockfile は `~/.agents/.skill-lock.json` で global のみ記録。プロジェクトスコープは update 非対応（[#337](https://github.com/vercel-labs/skills/issues/337) 追跡中）。本計画は global install + tag pin を推奨運用とする
- [x] **Codex CLI 2026 版の frontmatter 厳格度**: 解決済み（2026-06-02 調査・§2 note）。Agent Skills
  標準が `allowed-tools` を正式フィールド化、cookbook が full frontmatter を本番 Codex 配布済み。
  `argument-hint` / `disable-model-invocation` は Codex が無視（reject ではない）
- [ ] **`auto-release` の再設計**: per-plugin → unified に移行する際の CHANGELOG 自動生成方法。tag は `vX.Y.Z` を継続発行する（tree SHA だけでは利用者が pin できないため）
- [ ] **packages/ ディレクトリの去就**: 完全撤去 vs README 集約場所として維持
- [ ] **vercel-labs/skills#337 の解決状況の追跡**: project-scope update が実装されたら推奨運用を再評価する

## 10. ステータス

| フェーズ | ステータス | 完了日 |
|---|---|---|
| Phase 0 | Done（互換性レポート済み） | 2026-06-02 |
| Phase 1 | In progress（README に npx 手順追記済み。タグ運用・ラベルは未） | - |
| Phase 2 | Superseded（skill-sources 全廃・packages 直接正本化で代替） | 2026-06-02 |
| Phase 3-4 | Done（クリーンカットで marketplace 撤去・auto-release 改修・v2.0.0） | 2026-06-02 |
| Phase 5 | Not started（後始末: 旧タグのリリースノート整理等） | - |

---

## 参考リンク

- [vercel-labs/skills](https://github.com/vercel-labs/skills) — `npx skills` CLI 本体
- [skills - npm](https://www.npmjs.com/package/skills) — npm パッケージ
- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [skills.sh](https://skills.sh) — skill 検索プラットフォーム
