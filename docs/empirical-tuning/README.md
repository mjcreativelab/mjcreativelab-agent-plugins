# Empirical Prompt Tuning 設計書 — mjc-git-workflow

`mjc-claude-skill-tool:empirical-prompt-tuning` を使って `mjc-git-workflow` 配下 7 skills をチューニングするための設計書。

1 skill 1 セッションを推奨する（subagent dispatch が multi 発生する前提）。

## ファイル構成

| 設計書 | 対象 skill | 推奨実行順 |
|---|---|---|
| [smart-commit.md](./smart-commit.md) | smart-commit | 1 |
| [smart-pr.md](./smart-pr.md) | smart-pr | 2 |
| [smart-review.md](./smart-review.md) | smart-review | 3 |
| [smart-review-apply.md](./smart-review-apply.md) | smart-review-apply | 4 |
| [smart-issue-plan.md](./smart-issue-plan.md) | smart-issue-plan | 5 |
| [smart-issue-resolve.md](./smart-issue-resolve.md) | smart-issue-resolve | 6 |
| [smart-git-sync.md](./smart-git-sync.md) | smart-git-sync | 7 |

## 使い方

1. 新しい Claude Code セッションを起動
2. 当該設計書をコンテキストとして読ませる（例: `@docs/empirical-tuning/smart-commit.md を参照しつつ empirical-prompt-tuning を実施して`）
3. `/empirical-prompt-tuning` を呼ぶ
4. skill が設計書のシナリオ・要件チェックリストを使って subagent dispatch を開始

## iter 0 状態

全 7 skills の description/body 整合チェックは本設計書作成時に完了済み:

- `smart-commit` — description にブランチ切替の副作用を追記済み
- `smart-pr` — description に merge の副作用を追記済み
- `smart-review` — `disable-model-invocation: true` と `Write` を追加済み
- `smart-review-apply` — `allowed-tools` を追加済み
- 残り 3 skills は整合済み

つまり各設計書では **iter 1（baseline）から開始する**。iter 0 はスキップしてよい。

## 前提の共通事項

### 評価軸（全 skill 共通）

詳細は `mjc-claude-skill-tool:empirical-prompt-tuning` の SKILL.md を参照。本設計書では各 skill の要件チェックリストのみ定義する。

- 成功/失敗: `[critical]` 項目が全て ○ のときのみ成功
- 精度: ○=1.0、部分的=0.5、×=0 で加重平均
- steps / duration: Task tool usage メタから抽出
- retries: subagent 自己申告

### subagent 起動プロンプト テンプレート

```
あなたは <skill 名> を白紙で読む実行者です。

## 対象プロンプト
Read: skills/<skill>/SKILL.md

## シナリオ
<シナリオ本文>

## 要件チェックリスト
1. [critical] <項目>
2. ...

## タスク
1. 対象 SKILL.md に従ってシナリオを実行し、成果物を生成する。
   （副作用のある操作は dry-run で表現してよい。実際に git commit / push / PR 作成などは行わず、
    「この時点でこのコマンドを実行する」「この内容で `create_pull_request` を呼ぶ」と明記する。
    ただし、ユーザー承認を取るフローの有無は dry-run でも判定対象。）
2. レポート構造に従って返答する。

## レポート構造
- 成果物: <生成物 / 実行予定コマンドサマリ>
- 要件達成: 各項目について ○ / × / 部分的（理由付き）
- 不明瞭点: 対象 SKILL.md で詰まった箇所・解釈に迷った文言（箇条書き）
- 裁量補完: 指示で決まっておらず自分の判断で埋めた箇所（箇条書き）
- 再試行: 同じ判断をやり直した回数と理由
```

### 収束判定

- 連続 2 iter で次を全て満たすまで回す:
  - 新規不明瞭点: 0 件
  - 精度: 前回比 +3pt 以下
  - steps: 前回比 ±10% 以内
  - duration: 前回比 ±15% 以内
- iter 5 でも未収束なら打ち切る（設計方針を疑う）
- 収束時に hold-out シナリオ 1 本で過適合チェック

### dry-run ポリシー

すべての評価は **副作用を起こさない** ことが必須。subagent には次を徹底させる:

- `git commit` / `git push` / `git checkout` の書き込み系は実行しない。代わりに「この時点でこのコマンドを実行」と明記
- GitHub MCP の `create_pull_request` / `issue_write` / `add_issue_comment` 等の書き込み系は呼ばない。payload をレポートに出力
- 読み取り系（`issue_read`, `list_pull_requests`, `git diff`, `git log` 等）は実行してよい
- 要件チェックリスト項目は dry-run の出力内容から判定する
