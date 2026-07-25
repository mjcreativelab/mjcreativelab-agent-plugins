# agents-md-revise

今回のセッションで得た学び（発見したコマンド・パターン・環境の癖・落とし穴）を CLAUDE.md / AGENTS.md / GEMINI.md などのエージェント指示ファイルへ反映するスキル。追記案を diff で提示し、ユーザー承認後にのみ適用する。

Anthropic 公式プラグイン [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) の `/revise-claude-md` command（Apache-2.0）を、クロスツール（Claude Code / Codex / Cursor / Gemini CLI 等）向けに一般化し skill 形式へ変換した移植版。

## 使い方

```
/agents-md-revise
/agents-md-revise テスト実行まわりの学びだけ反映して
```

セッション終盤、「このコンテキストが最初からあれば楽だった」と感じたときに実行する。

## 動作内容

1. セッションを振り返り、将来のセッションに役立つ学びを抽出（コマンド・スタイル・テストアプローチ・環境の癖・落とし穴）
2. リポジトリ内の指示ファイルを特定し、追記の行き先を決定（チーム共有 or 個人ローカル。symlink は実体側へ）
3. 1 概念 1 行の簡潔な追記案を作成（冗長説明・自明情報・一回限りの修正は除外）
4. 変更案を diff 形式で提示
5. ユーザーが承認したファイルのみ編集

## agents-md-improver との使い分け

| | agents-md-revise | agents-md-improver |
|---|---|---|
| 目的 | セッションで得た学びの取り込み | 指示ファイルとコードベースの整合維持 |
| きっかけ | セッション終盤・欠けていたコンテキストの発見 | コードベースの変化・定期メンテナンス |

## 前提条件

- `disable-model-invocation: true`（Claude Code ではユーザーの `/agents-md-revise` でのみ起動。他エージェントはこのフラグを無視するため自動起動しうる — 書き込みは承認ゲートで保護）
