# エージェントオーケストレーション（--isolated 単発レビュー Workflow スクリプト雛形）

code-reviewer の `--isolated` モードで起動する、コンテキスト隔離した単発レビューエージェントの Workflow スクリプト雛形。SKILL.md「エージェント隔離モード（--isolated）」から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md を参照）。

## 前提とゲート

- スクリプトはこの雛形を**そのまま** `script`（または本ファイルから抽出した `scriptPath`）に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない）。ただし呼び出し経路によっては文字列（`typeof args === 'string'`）で着弾する環境があるため、雛形は meta 直後に正規化シム（`args = typeof args === 'string' ? JSON.parse(args) : (args || {})`）を持つ。文字列・オブジェクトどちらで届いても本文のトップレベル `args.` 参照が機能する
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- **進捗の可視化**: IDE 拡張では `/workflows` の進捗表示が使えないため、`log()` で開始日時・完了を可視化する。開始日時はオーケストレーターが起動直前に `TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'` を実測して `args.startedAt` で渡し（省略可・ログ表示専用で `agent()` プロンプトへは埋め込まない — resume のキャッシュ一致を保つ）、`agent()` はプロンプト末尾の指示（`TAIL_NOTE`）で同フォーマットの時刻を実行して構造化出力の `nowJst`（`NOW_JST_FIELD`）として返す。スクリプトは `agent()` 呼び出し直後にその値で `log(`[YYYY-MM-DD hh:mm:ss JST] ...`)` する（スクリプト自身は時刻を生成できないため、必ずエージェントの返り値から取得する）
- **プロンプトは英語・出力は日本語**: `agent()` に渡すプロンプト本文・スキーマ `description` は英語で記述する（指示追従の精度向上）。ユーザーが読む内容 — レビュー結果（5 区分 markdown）・`log()` 文字列・`meta` — は日本語のまま（`TAIL_NOTE` が日本語出力を指示する）
- レビュー結果の出力（チャット表示）と PR 投稿ゲートはオーケストレーター（メインセッション）が担う。エージェントはレビュー結果（5 区分 markdown）を返すだけで、投稿・コミットはしない

## 雛形: 単発隔離レビュー（cr-isolated-review）

`args`: `{ target, diffBase, focus, startedAt }`
（`target`: レビュー対象の識別子〔PR 番号 / ブランチ名 / `ref..ref` / パス / "未コミット変更"〕。`diffBase`: diff の取り方の説明〔例: 「`git diff main...HEAD` + 未コミット変更」「`git diff <ref>..<ref>`」「PR #N の diff を GitHub MCP で取得」「指定パス配下のみ」〕。`focus`: 追加の重点観点。無ければ空文字。`startedAt`: 起動直前に実測した開始日時〔開始ログ表示専用・省略可〕）

```js
export const meta = {
  name: 'cr-isolated-review',
  description: 'code-reviewer --isolated の単発隔離レビュー（Opus / effort max）',
  phases: [{ title: 'Review', detail: 'コンテキスト隔離した単発レビュー' }],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const NOW_JST_FIELD = { type: 'string', description: "Completion time in JST: the verbatim output of `TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'`" }
const TAIL_NOTE = "Output language: write all output content (the review markdown and structured output fields) in Japanese; keep code identifiers, file paths, and commands as-is. Finally, run `TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'` and put its verbatim output into nowJst."
const ts = (t) => (t ? `[${t} JST] ` : '')

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['review', 'nowJst'],
  properties: {
    review: { type: 'string', description: 'The 5-section markdown (including the Codex cross-check section when applicable)' },
    nowJst: NOW_JST_FIELD,
  },
}

log(`${ts(args.startedAt)}隔離レビュー開始（対象: ${args.target}）`)

const result = await agent(`You are a reviewer of implemented code. From an independent position without the conversational / implementation context, review the change to ensure spec conformance, design fit, and readability.
## Review target
- Target: ${args.target}
- Diff acquisition: ${args.diffBase}
  Identify the changed files and lines yourself accordingly (for a PR target, fetch the diff via GitHub MCP tools such as pull_request_read; if large, keep only the diff text and the changed-file list). If related requirement docs, ADRs, or Issues exist, consult them and check the change against the spec.
${args.focus ? `- Focus aspects: ${args.focus}\n` : ''}## Aspects (check all 6)
- 仕様整合: agreement with requirements and design documents
- 設計適合: consistency with the existing architecture and conventions
- 可読性: naming, structure, comments (final spec only; history comments are not acceptable)
- テスト: coverage adequacy and boundary-condition handling
- オーバーエンジニアリング: excessive abstraction, unused extensibility
- 横断影響: missed impact on skills, configs, and other domains (grep recommended: related tests, docs, CI configs, similar patterns elsewhere)
## Output format (5 sections; sections with no findings must still appear, marked なし)
### 🚫 ブロッカー
(problems that block merging)
### ⚠️ 推奨
(should be fixed, but merging is possible)
### 💬 nit
(matter of taste; can be addressed next time)
### ✅ Good
(good implementations and decisions)
### 🔄 横断影響
(results of the cross-cutting impact check on skills, configs, and related domains)
Writing rules: each finding is a 3-part set — what / why / how to fix (✅ Good may be 2 parts: what / why). Keep code samples to fragments of ~3 lines (no full functions or finished code). Verify dubious findings yourself before reporting them.
If the change touches authentication / authorization, payment / billing, data schemas, or external API / dependency contracts, append the section 「### Codex クロスチェック推奨」 (理由: the matching category) right after the 5 sections.
## Constraints
- Do not modify code or files (review only). Do not commit or push. Do not post to the PR (the caller does that).
Final output: put the 5-section markdown (including the Codex cross-check section when applicable) verbatim into review. ${TAIL_NOTE}`,
  { label: 'reviewer:isolated', phase: 'Review', model: 'opus', effort: 'max', schema: REVIEW_SCHEMA })
if (result === null) return { review: null }
log(`[${result.nowJst} JST] レビュー完了`)

return { review: result.review }
```

返却の `review`（5 区分 markdown）をオーケストレーターがチャットに表示し、書き出しモードが有効なら SKILL.md「PR 書き出しモード」のテンプレートに埋めて確認ゲート経由で投稿する。`agent()` が `null` を返した（ユーザーのスキップ / 終端エラー）場合は、1 回だけ `resumeFromRunId` で再開を試み、それでも失敗ならメインセッションでの通常レビュー（SKILL.md 手順 4）に degrade する。

## 同期ノート

本雛形のレビュー観点は SKILL.md「観点」節（6 観点）と一致させる。敵対レビューの Breaker / Judge プロンプトや smart-issue-resolve 雛形 B の reviewerPrompt との共有関係は CLAUDE.md「スキル改修時の注意」を参照する。プロンプトは英語・出力（5 区分 markdown・`log()`）は日本語という言語規約（Issue #122）も同期対象 4 スキルで共通。
