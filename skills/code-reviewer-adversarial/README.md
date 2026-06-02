# code-reviewer-adversarial

**Breaker**（Claude Opus 4.7）× **Judge**（Codex gpt-5.4、`codex:rescue` 経由）の二者構造で、反例生成とテスト実行により「本当の欠陥」のみを抽出する敵対的コードレビュー。重要変更・最終ゲート・見逃したくない場面に使う。対象が PR なら確認ゲート経由で PR Review として投稿する。

## どんなケースで使うか

- **認証 / 認可 / 決済 / データスキーマ（マイグレーション）/ 外部 API** を含む重要変更の最終ゲート
- 通常レビューで見逃したくない **セキュリティ / 性能 / 仕様未充足** のリスクを炙り出したい
- 別系統モデル（Claude × Codex）のクロスチェックで **共犯化を避けた独立裁定** を得たい

使わない場面:

- 通常のレビュー・コミット前セルフレビュー → `/code-reviewer`
- 可読性・命名レベルの指摘 → `/code-reviewer`
- 設計レベルの検討 → `/software-architect`

## 二者構造の狙い

| 役割 | 担当 | 評価関数 |
| --- | --- | --- |
| **Breaker** | Claude Opus 4.7 | コードを **壊す**。反例・攻撃シナリオ・不変条件違反を生成し、可能な限り failing テストとして実行する |
| **Judge** | Codex gpt-5.4（`codex:rescue` 経由） | Breaker の指摘を「真の欠陥 / 仕様未定 / 低優先度 / ノイズ」に分類し、修正コストと見合うかを裁定する |

評価関数を意図的にずらすことで、**本当の欠陥を見逃さない** × **false positive を抑える** の両立を狙う。Breaker は指摘件数で評価されず、反例テストで `fail` させられたものだけが採用される。Judge は Claude と別系統モデルで裁定するため共犯化を避けられる。

## 使い方

```
/code-reviewer-adversarial [<PR番号|branch|ref..ref|path>] [--test <cmd>] [-p <重点観点>]
```

### 例

```
/code-reviewer-adversarial                                   # 現在の未コミット変更 + 現在ブランチ vs main
/code-reviewer-adversarial 42                                # PR #42
/code-reviewer-adversarial main..HEAD                        # 現在ブランチの全コミット
/code-reviewer-adversarial packages/mjc-git-workflow-tools/ -p N+1
/code-reviewer-adversarial --test "pnpm test" feature/add-foo
```

## オプション

| オプション        | 説明                                                       |
| ----------------- | ---------------------------------------------------------- |
| `--test <cmd>`    | 反例テスト実行に使うコマンド（自動検出より優先）           |
| `-p <プロンプト>` | Breaker persona に追加注入する重点観点（例: `N+1`、`TOCTOU`）|

## フェーズ構成

### Phase 0 — 前提把握

- 引数解析 / 変更範囲取得 / 書き出しモード判定 / 仕様・設計の確認 / テストランナー確定
- テストコマンドが確定できない場合は **テスト記述のみモード**（反例を書くが実行はしない）にフォールバック
- 確定値を 1 ブロックで表示してゲートにする

### Phase 1 — Breaker

3 persona で反例を順に列挙する:

1. **Security** — 認可逸脱・インジェクション・秘密情報漏洩・TOCTOU・Confused Deputy
2. **Performance** — N+1・境界外入力・競合・メモリリーク・タイムアウト・移行性能
3. **Specification** — 仕様未充足・契約違反・後方互換性破壊・移行失敗

各指摘は failing テストで検証し、`pass` したものは破棄（自己ノイズフィルタ）。全 persona の指摘をそのまま並べた報告書を作り、重複統合・ノイズ除外は Judge に委ねる（共犯化回避）。

### Phase 2 — Judge

`codex:rescue` で Codex を呼び出し、Breaker 報告書を 4 カテゴリに裁定する:

| カテゴリ   | 意味                                                         | 最終出力への扱い                   |
| ---------- | ------------------------------------------------------------ | ---------------------------------- |
| 真の欠陥   | 仕様違反 / セキュリティリスク / 性能問題として妥当で修正価値あり | 含める                             |
| 仕様未定   | 仕様が曖昧で、Breaker が勝手な前提を置いている               | 「仕様確認が必要」として分離       |
| 低優先度   | 妥当だが重大度が低く、修正コストに見合わない                  | サマリに件数のみ                   |
| ノイズ     | 反証不能・誤解・的外れ                                         | 除外（件数のみ報告）               |

**Judge 呼び出し不能時**（`codex:rescue` 未設定等）は Phase 2 で停止し、Phase 3 を出力しない。Claude 側で Judge 裁定を模擬・代行してはならない（別系統モデルによる独立裁定が本スキルの核のため）。

### Phase 3 — 最終出力

サマリ / 🚫 真の欠陥 / ❓ 仕様未定 / 📉 低優先度 / 🔇 ノイズ / 💡 修正推奨の順序、の構造で出力する。各「真の欠陥」は **指摘内容 / 再現条件 / 最小反例 / 影響範囲 / 重大度 / 修正案 / 確信度** の 7 フィールド固定スキーマで表示する。

### Phase 4 — PR 投稿ゲート

書き出しモードが有効なら `AskUserQuestion` を経て PR Review として投稿する（Judge 呼び出し不能で Phase 3 を出さなかった場合は到達しない）。

- 投稿ツール: `mcp__plugin_github_github__pull_request_review_write`（`event: "COMMENT"`）
- 識別マーカー `<!-- claude-code-review:code-reviewer-adversarial -->` を先頭に付与
- approve / request_changes は人間レビュアーに残す

## 前提条件

- `codex:rescue` スキルが呼び出し可能な環境（Codex CLI 設定済み）
- `--test` 指定 or 自動検出可能なテストランナー（なければ「テスト記述のみモード」にフォールバック）
- PR 投稿を使う場合は GitHub MCP の接続と書き込み権限

## 関連スキル

- `/code-reviewer` — 通常のコードレビュー（仕様整合・設計適合・可読性）
- `/software-architect` — 実装前の設計
- `/security-auditor` — 設計レベルのセキュリティ監査
- `codex:rescue` — Judge として呼び出される Codex 連携スキル

## 元になったスキル

特定のスキルをベースにしたものではなく、本リポジトリ独自の設計。次の設計思想を組み合わせている:

- **敵対的レビュー / レッドチーミング** — Breaker が「壊す」側として攻撃シナリオ・反例を生成する
- **Builder vs Breaker** の分離 — 読むレビューではなく、反例で破壊可能性を検証するレビュー
- **別系統モデルによる独立裁定** — Claude と Codex の評価関数をずらして共犯化を避ける（`CLAUDE.md` の「AI Agent Role Assignment」で定義しているクロスチェック運用を具体化）
- **failing テストによる自己ノイズフィルタ** — 反例を実行して `pass` したものは自動で破棄する

## 使い分け

- 通常レビュー・コミット前セルフレビュー → `/code-reviewer`
- 重要変更（認証 / 認可 / 決済 / スキーマ / 外部 API）・最終ゲート・高コスト領域 → `/code-reviewer-adversarial`

通常フローの「最終ステップで Codex レビュー」は、本スキルを使う場合 Judge 呼び出しが相当する。別途追加の Codex レビューは不要。

## 推奨: 新規セッションで実行する

このスキルは **作業セッションとは別の新規セッションで実行する** ことを推奨する。

- Breaker が反例テストを生成・実行し、Judge へ diff と報告書を渡すため、クリーンなコンテキストで開始する方が安定する
- **重要変更の PR を出す直前、新規セッションで `/code-reviewer-adversarial <PR番号>` を実行するのがベスト**
