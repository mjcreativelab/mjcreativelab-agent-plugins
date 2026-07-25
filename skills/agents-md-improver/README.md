# agents-md-improver

CLAUDE.md / AGENTS.md / GEMINI.md などエージェント指示ファイル（プロジェクトメモリ）を監査・改善するスキル。リポジトリ内の指示ファイルを走査し、6 基準 100 点満点の品質レポートを提示 → ユーザー承認後に的を絞った更新を適用する。

Anthropic 公式プラグイン [claude-md-management](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-md-management) の `claude-md-improver` skill（Apache-2.0）を、CLAUDE.md 専用からクロスツール（Claude Code / Codex / Cursor / Gemini CLI 等）向けに一般化した移植版。

## 使い方

```
「CLAUDE.md を監査して」
「AGENTS.md が最新か確認して」
「プロジェクトメモリを最適化して」
```

## 動作内容

1. **Discovery**: リポジトリ内の CLAUDE.md / AGENTS.md / GEMINI.md / .claude.local.md を走査。symlink（例: AGENTS.md → CLAUDE.md）は実体と統合して 1 エンティティとして扱う
2. **品質評価**: 6 基準（コマンド・アーキテクチャ・非自明パターン・簡潔さ・鮮度・実行可能性）でスコアリング
3. **品質レポート出力**: 更新前に必ずファイル別の評価・問題点・推奨追記を提示
4. **更新提案**: 的を絞った追記のみを diff 形式で提示（自明な情報・一般論は追加しない）
5. **承認後の適用**: ユーザーが承認した変更のみ Edit で適用

## agents-md-revise との使い分け

| | agents-md-improver | agents-md-revise |
|---|---|---|
| 目的 | 指示ファイルとコードベースの整合維持 | セッションで得た学びの取り込み |
| きっかけ | コードベースの変化・定期メンテナンス | セッション終盤・欠けていたコンテキストの発見 |

## 前提条件

- 対象リポジトリで find / ls が実行できること（symlink 判定に使用）
- 書き込みはユーザー承認後のみ。読み取り専用で監査だけ依頼することも可能
