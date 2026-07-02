# memory-dream

git 管理された記憶階層（MEMORY.md・notes・projects 等）を再編し、重複・矛盾・陳腐化を除去する consolidation スキル。Anthropic Managed Agents の **Dreams**（Claude Code の Auto Dream / `/dream`）を、これらが使えない環境（手動・git ベースの記憶階層）で再現する。

## 使い方

```
/memory-dream
```

副作用（記憶ファイルの書き換え・commit）があるため `disable-model-invocation: true` を設定している。Claude Code ではユーザーの `/memory-dream` でのみ起動する（他エージェントはこのフラグを無視するため、「記憶を整理して」「dream して」でも起動しうる）。

## 動作内容

1. **Phase 0（ゲート）**: 記憶階層のルートを特定し、git working tree が clean であること・更新禁止レイヤを確認。確認結果を一時ファイル（inventory）に書き出してから先へ進む。特定できなければユーザーに確認して停止
2. **Mine（採掘）**: 直近セッションの transcript や作業内容から、繰り返しの指摘・確定方針・新事実を抽出
3. **Consolidate（統合）**: 既存記憶へマージ。相対日付 → 絶対日付（基準日は git 履歴で特定）、矛盾は最新値で解決、消滅した参照は参照先リポジトリで現存確認のうえ除去
4. **Dedup & Resolve（重複排除・矛盾解消）**: 階層をまたぐ重複を下位レイヤ側から除去。真の矛盾はユーザー確認
5. **Prune & Index（剪定・索引化）**: 索引を lean 化（目安 200 行未満）、notes 一覧を再生成・同期
6. 論理単位ごとに commit し、チェックリストで自己検証のうえユーザーレビューへ（push は明示指示まで保留）

## 前提条件

- 記憶階層が git リポジトリで管理されていること
- 環境の常時ロード指示（AGENTS.md / CLAUDE.md / MEMORY.md 等）が記憶階層の場所と各レイヤの役割を定義していること（特定できない場合はユーザーに確認して停止する）

## 安全性

- **入力非破壊**: 変更は論理単位ごとの commit に分離し、revert 可能な状態を保つ。push はユーザーの明示指示まで保留
- 更新禁止レイヤ（Phase 0 で列挙したもの。例: AGENTS.md）は変更せず、commit 前に `git diff --name-only` で機械的に確認する。設計文書（構成例の `specs/` 等）も原則触らない
- consolidation の出力には hallucination が混入しうる前提で、採用前のユーザーレビューをフローに組み込んでいる
