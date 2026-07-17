# 実装ノート: Workflow レビュー雛形への JST 進捗ログ追加

日付: 2026-07-17 (JST)

## 背景・要望

`smart-issue-resolve` / `smart-issue-plan` / `code-reviewer` / `code-reviewer-adversarial` の
Workflow スクリプト雛形は background 実行される。進捗は `/workflows` で確認できるが、IDE 拡張
（VSCode 等）では `/workflows` が使えず、ステップがどこまで進んだか・止まっていないかを確認する
手段がなかった。ユーザー要望: ステップが進行した際に、その時刻（JST hh:mm）付きの進捗メッセージを
出してほしい。

## 仕様に明記されていなかったため自分で判断した事項

- **Workflow スクリプト本体は時刻を生成できない制約への対応**: Workflow ツールは
  `Date.now()` / `Math.random()` / 引数なし `new Date()` をスクリプト内で呼ぶとエラーになる
  （resume の再現性を壊すため）。そのためスクリプト自身は「今の時刻」を取得できない。
  対応として、各 `agent()` にプロンプト末尾で `TZ=Asia/Tokyo date '+%H:%M'` を実行させ、
  結果を構造化出力の共通フィールド `nowJst` として返させ、スクリプト側は `agent()` 呼び出し
  直後にその値で `log(`[HH:MM JST] ...`)` する設計にした（エージェントは実際に Bash を実行する
  ため非決定性の制約を受けない）。
- **粒度・対象範囲**: ユーザーに「全 agent() 呼び出し直後」か「既存 log() 箇所のみ」か等の選択肢を
  提示し、「全 agent() 呼び出し直後」「4 スキル全部」を選択してもらった。これに従い、
  smart-issue-resolve（雛形 A〜E）・smart-issue-plan（sip-plan-review-set）・
  code-reviewer（cr-isolated-review）・code-reviewer-adversarial（cra-claude-judge）の
  すべての `agent()` 呼び出しに `nowJst` を付与した。
  例外: `dev:probe-cleanup`（`.breaker-probe.` ファイルの後始末。低 effort・戻り値を元々
  使用していない軽量ステップ）はログ対象から除外した。情報価値が低く、schema 化のための
  変更コストに見合わないと判断したため。
- **自由記述（schema なし）エージェントの扱い**: 設計役（雛形 A の `architect:design`）・
  セキュリティ監査役（雛形 B/C・plan の `security:audit`）・code-reviewer の単発レビュー
  （`cr-isolated-review`）はもともと schema を使わず自由記述テキストをそのまま返していた。
  `nowJst` を持たせるため、いずれも軽量な schema（`{ summary, nowJst }` または
  `{ review, nowJst }`）に変換した。設計役の戻り値は元々 truthy チェックにしか使われておらず
  実害なし。セキュリティ監査役は戻り値をテンプレート文字列に直接埋め込んでいたため、
  `audit` → `audit.summary` に呼び出し側を追随させた。code-reviewer は戻り値そのものが
  ユーザー表示用の 5 区分 markdown だったため、`return { review: result.review }` の形で
  従来の戻り値契約（`{ review }`。`review` は文字列または agent 失敗時に `null`）を維持した。
- **バッチ並列処理（敵対モード Judge）の時刻集約**: `sir-claude-review-set` /
  `sip-plan-review-set` の Judge は `parallel()` で複数バッチに分割実行されるため、単一の
  完了時刻を持たない。各バッチ結果の `nowJst` のうち最大値（最後に完了したバッチの時刻）を
  ラウンドの Judge 完了時刻としてログに使う設計にした。

## 変更内容

各雛形ファイルに以下を追加（共通パターン。CLAUDE.md「スキル改修時の注意」の同期対象と重なる
4 ファイルすべてに同一パターンで適用済み）:

- `NOW_JST_FIELD`（共通スキーマフィールド定義）/ `TIME_NOTE`（プロンプト末尾に足す指示文）の
  定数をスクリプト冒頭に追加
- 既存の各スキーマ（`FINDINGS_SCHEMA` / `FIX_SCHEMA` / `QA_SCHEMA` / `IMPL_SCHEMA` /
  `BREAK_SCHEMA` 等）に `nowJst`（必須）を追加
- 各エージェントプロンプトの末尾に `${TIME_NOTE}` を追加
- 各 `agent()` 呼び出し直後（null ガードの後）に `log(`[${result.nowJst} JST] <ステップ名> 完了...`)` を追加
- 各ファイルの「前提とゲート」節に、この規約（新しい `agent()` 呼び出しを追加する際も従うこと）を明記

## 検証

`bash -n` 相当として、CLAUDE.md「よく使うコマンド」記載の js ブロック抽出 + `node --check` を
4 ファイルすべてに対して実行し、全ブロックが構文エラー無しであることを確認済み（実行環境:
`mise exec node -- node --check`）。実際に Workflow ツールでこれらの雛形を起動して
ログ出力を目視確認するテストは、この変更セッションでは実施していない（未実施。次回
smart-issue-resolve 等を実際に使う際に確認することを推奨）。

## 補足: 作業ブランチについて

この変更に着手した時点で、作業ツリーは別タスク（Issue #94: edge routing avoidance、
ブランチ `feature/issue-94-edge-routing-avoidance`）向けの未コミット変更
（`skills/structure-visualize/assets/diagram-template.html` 等）と、さらに無関係な
複数の未コミット変更（`CLAUDE.md` / `dotfiles/claude/*` 等、いずれも本セッションでは
一切編集していない）を抱えた状態だった。今回の JST 進捗ログ追加はこれらと独立した変更のため、
コミット・ブランチ運用はユーザーに判断を委ねる。
