# エージェントオーケストレーション（--isolated 単発レビュー Workflow スクリプト雛形）

code-reviewer の `--isolated` モードで起動する、コンテキスト隔離した単発レビューエージェントの Workflow スクリプト雛形。SKILL.md「エージェント隔離モード（--isolated）」から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md を参照）。

## 前提とゲート

- スクリプトはこの雛形を**そのまま** `script`（または本ファイルから抽出した `scriptPath`）に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない）。ただし呼び出し経路によっては文字列（`typeof args === 'string'`）で着弾する環境があるため、雛形は meta 直後に正規化シム（`args = typeof args === 'string' ? JSON.parse(args) : (args || {})`）を持つ。文字列・オブジェクトどちらで届いても本文のトップレベル `args.` 参照が機能する
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- **進捗の可視化**: IDE 拡張では `/workflows` の進捗表示が使えないため、`agent()` はプロンプト末尾の指示（`TIME_NOTE`）で `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を構造化出力の `nowJst`（`NOW_JST_FIELD`）として返す。スクリプト側は `agent()` 呼び出し直後にその値で `log(`[HH:MM JST] ...`)` する（スクリプト自身は時刻を生成できないため、必ずエージェントの返り値から取得する）
- レビュー結果の出力（チャット表示）と PR 投稿ゲートはオーケストレーター（メインセッション）が担う。エージェントはレビュー結果（5 区分 markdown）を返すだけで、投稿・コミットはしない

## 雛形: 単発隔離レビュー（cr-isolated-review）

`args`: `{ target, diffBase, focus }`
（`target`: レビュー対象の識別子〔PR 番号 / ブランチ名 / `ref..ref` / パス / "未コミット変更"〕。`diffBase`: diff の取り方の説明〔例: 「`git diff main...HEAD` + 未コミット変更」「`git diff <ref>..<ref>`」「PR #N の diff を GitHub MCP で取得」「指定パス配下のみ」〕。`focus`: 追加の重点観点。無ければ空文字）

```js
export const meta = {
  name: 'cr-isolated-review',
  description: 'code-reviewer --isolated の単発隔離レビュー（Sonnet / effort max）',
  phases: [{ title: 'Review', detail: 'コンテキスト隔離した単発レビュー' }],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['review', 'nowJst'],
  properties: {
    review: { type: 'string', description: '5 区分markdown（該当すれば Codex クロスチェック推奨節を含む）' },
    nowJst: NOW_JST_FIELD,
  },
}

const result = await agent(`あなたは実装コードのレビュワーである。会話・実装の文脈を持たない独立の立場から、仕様整合・設計適合・可読性を担保するレビューを行う。
## レビュー対象
- 対象: ${args.target}
- diff の取得: ${args.diffBase}
  上記に従って変更されたファイルと行を自分で特定する（PR 対象なら GitHub MCP の pull_request_read 等で diff を取得。大きい場合は diff テキストと変更ファイルリストのみ保持する）。関連する要件ドキュメント・ADR・Issue があれば参照して仕様と照合する。
${args.focus ? `- 重点観点: ${args.focus}\n` : ''}## 観点（6 観点で確認する）
- 仕様整合: 要件・設計ドキュメントとの一致
- 設計適合: 既存アーキテクチャ・コンベンションとの整合
- 可読性: 命名・構造・コメント（最終仕様のみ。履歴コメントは NG）
- テスト: カバレッジの妥当性・境界条件の扱い
- オーバーエンジニアリング: 過剰な抽象化・未使用の拡張性
- 横断影響: skills・設定・他ドメインへの影響漏れ（関連テスト・ドキュメント・CI 設定・類似パターンの他箇所を grep 推奨）
## 出力フォーマット（5 区分。該当が無い区分も「なし」と明記する）
### 🚫 ブロッカー
（マージ不可の問題）
### ⚠️ 推奨
（改善すべきだがマージは可能）
### 💬 nit
（好みの範囲・次回対応可）
### ✅ Good
（良い実装・判断）
### 🔄 横断影響
（skills・設定・関連ドメインへの影響漏れ検出結果）
記述ルール: 各指摘は「何が・なぜ・どう直す」の 3 点セット（✅ Good は「何が・なぜ」の 2 要素で可）。サンプルは 3 行程度までの断片に留める（関数全体や完成形コードを書かない）。妥当性が疑わしい指摘は自ら検証してから出す。
認証・認可 / 決済・課金 / データスキーマ / 外部 API・依存契約のいずれかに該当する変更が含まれる場合は、5 区分の直後に「### Codex クロスチェック推奨」節（理由: 該当カテゴリ）を追加する。
## 制約
- コード・ファイルを変更しない（レビューのみ）。コミット・push はしない。PR への投稿もしない（呼び出し元が行う）
最終出力: review に上記 5 区分（該当すれば Codex クロスチェック推奨節を含む）の markdown をそのまま入れる。${TIME_NOTE}`,
  { label: 'reviewer:isolated', phase: 'Review', model: 'sonnet', effort: 'max', schema: REVIEW_SCHEMA })
if (result === null) return { review: null }
log(`[${result.nowJst} JST] レビュー完了`)

return { review: result.review }
```

返却の `review`（5 区分 markdown）をオーケストレーターがチャットに表示し、書き出しモードが有効なら SKILL.md「PR 書き出しモード」のテンプレートに埋めて確認ゲート経由で投稿する。`agent()` が `null` を返した（ユーザーのスキップ / 終端エラー）場合は、1 回だけ `resumeFromRunId` で再開を試み、それでも失敗ならメインセッションでの通常レビュー（SKILL.md 手順 4）に degrade する。

## 同期ノート

本雛形のレビュー観点は SKILL.md「観点」節（6 観点）と一致させる。敵対レビューの Breaker / Judge プロンプトや smart-issue-resolve 雛形 B の reviewerPrompt との共有関係は CLAUDE.md「スキル改修時の注意」を参照する。
