# memory-dream

git 管理された記憶階層（MEMORY.md・notes・projects 等）を再編し、重複・矛盾・陳腐化を除去する consolidation スキル。Anthropic Managed Agents の **Dreams**（Claude Code の Auto Dream / `/dream`）を、これらが使えない環境（手動・git ベースの記憶階層）で再現する。

## 使い方

```
/memory-dream
/memory-dream --codex-review-loop
/memory-dream --claude-review-loop   # または -cldrl（Codex 不要）
```

副作用（記憶ファイルの書き換え・commit）があるため `disable-model-invocation: true` を設定している。Claude Code ではユーザーの `/memory-dream` でのみ起動する（他エージェントはこのフラグを無視するため、「記憶を整理して」「dream して」でも起動しうる）。

記憶階層のルートは Phase 0 が自動特定するため、記憶ディレクトリへ移動する必要はない。整理したい記憶を持つ環境（Claude Code なら対象プロジェクト）の中であれば、どのディレクトリから実行してもよい。ただし対象記憶は実行する環境に紐づく（Claude Code は記憶がプロジェクト単位のため、別プロジェクトで実行するとそのプロジェクトの記憶が対象になる）。

## オプション

| オプション | 説明 |
|---|---|
| `--codex-review-loop`（`-cdxrl`） | ユーザーレビュー依頼の前に、dream の全差分を Codex（`codex:rescue`）による独立レビューループにかける（Claude Code + Codex プラグイン環境前提）。収束・打ち切りとなってもユーザーの採用前レビューは省略しない |
| `--claude-review-loop`（`-cldrl`） | 同上のレビューループを、コンテキスト隔離した Sonnet（effort max）レビュワーエージェントで実施する（Codex 不要・Claude Code の Workflow ツール前提）。レビュー観点は codex 系と同一。別系統モデルの独立性はないため、Codex が使える環境では `-cdxrl` を推奨 |

> 両方指定した場合は codex 系を優先する（別系統モデルの独立性がより高い）。

## 動作内容

1. **Phase 0（ゲート）**: 記憶階層のルートを特定し、git working tree が clean であること・更新禁止レイヤを確認。確認結果を一時ファイル（inventory）に書き出してから先へ進む。特定できなければユーザーに確認して停止
2. **Mine（採掘）**: 直近セッションの transcript や作業内容から、繰り返しの指摘・確定方針・新事実を抽出
3. **Consolidate（統合）**: 既存記憶へマージ。相対日付 → 絶対日付（基準日は git 履歴で特定）、矛盾は最新値で解決、消滅した参照は参照先リポジトリで現存確認のうえ除去
4. **Dedup & Resolve（重複排除・矛盾解消）**: 階層をまたぐ重複を下位レイヤ側から除去。真の矛盾はユーザー確認
5. **Prune & Index（剪定・索引化）**: 索引を lean 化（目安 200 行未満）、notes 一覧を再生成・同期
6. 論理単位ごとに commit し、チェックリストで自己検証。`--codex-review-loop` / `--claude-review-loop` 指定時はレビューループ（採用 0 件まで、3 ラウンドごとに継続確認）を実施
7. ユーザーの採用前レビューへ（push は明示指示まで保留）

## 前提条件（依存する機能）

- **git** — 記憶階層のバージョン管理が前提。相対日付・矛盾の新旧判定（`git log -p` / `git blame`）、論理単位ごとの commit 分離に必須
- **ファイル編集ツール（Edit / Write）** — 記憶ファイルの書き換えに必須
- **AskUserQuestion** — 真の矛盾・レビューループ継続のユーザー確認に使用（Claude Code 拡張。他エージェントではテキスト確認にフォールバック）
- **セッション transcript へのアクセス** — Phase 1（Mine）の材料（任意。参照できない場合は現在の会話と既存記憶のみで実施）
- **Codex プラグイン（`codex:rescue` スキル）** — `--codex-review-loop` 使用時のみ必須（Claude Code + Codex CLI 設定済み環境前提）。利用不能時は「Codex レビュー未実施」と明示してユーザーレビューのみに切り替える（Claude がレビューを代行せず、claude 系へも勝手に切り替えない）
- **Workflow ツール** — `--claude-review-loop` 使用時のみ必須（Claude Code 固有。利用できない環境では「Claude レビュー未実施」と明示してユーザーレビューのみに degrade する）
- 環境の常時ロード指示（AGENTS.md / CLAUDE.md / MEMORY.md 等）が記憶階層の場所と各レイヤの役割を定義していること（特定できない場合はユーザーに確認して停止する）

## 安全性

- **入力非破壊**: 変更は論理単位ごとの commit に分離し、revert 可能な状態を保つ。push はユーザーの明示指示まで保留
- 更新禁止レイヤ（Phase 0 で列挙したもの。例: AGENTS.md）は変更せず、commit 前に `git diff --name-only` で機械的に確認する。設計文書（構成例の `specs/` 等）も原則触らない
- consolidation の出力には hallucination が混入しうる前提で、採用前のユーザーレビューをフローに組み込んでいる（`--codex-review-loop` / `--claude-review-loop` はその前段の独立レビュー）

## 関連スキル

- `codex:rescue` — `--codex-review-loop` のレビュアーとして呼び出される Codex 連携スキル（`--claude-review-loop` は Workflow ツールで隔離 Sonnet レビュワーを起動するため Codex 不要）
- `/code-reviewer-adversarial` — コード変更向けの敵対的レビュー（memory-dream のレビューループは記憶差分向けの標準レビュー）
