# エージェントオーケストレーション（claude-judge モード Workflow スクリプト雛形）

code-reviewer-adversarial の `--claude-judge` モード（および Codex 不在時の自動フォールバック）で起動する、**独立 Opus Breaker × 独立 Opus Judge（バッチ並列 + 見落とし探索分離）の単発敵対レビュー**の Workflow スクリプト雛形。SKILL.md「claude-judge モード」から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md「Judge 利用不能時のフォールバック」を参照）。

> 本雛形の Breaker / Judge プロンプトは smart-issue-resolve `references/agent-orchestration.md` の雛形 B（`sir-claude-review-set`）の `breakerPrompt` / `judgeBatchPrompt` からの移植である（単発用に、ループ制御〔ラウンド・経緯〕と context.md 依存を除き、レビュー対象を `args` の diff 基準に読み替えた）。Judge は ≤4 件/バッチのフラット `parallel` 裁定（`effort: 'high'`）と、Breaker 見落としの独立探索を担う miss-finder（`effort: 'max'`・diff スコープ）に分離している（バッチ分割・miss-finder 分離は Issue #107、Breaker/Judge の opus 化は Issue #111。Judge バッチの effort は #111 で max 化 → ≤4 件/バッチの有界作業量に max は過剰として Issue #113 で high へ戻した）。攻撃観点・4 分類裁定基準を変更するときは CLAUDE.md「スキル改修時の注意」の同期対象と揃える。

## 前提とゲート

- スクリプトはこの雛形を**そのまま** `script`（または本ファイルから抽出した `scriptPath`）に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない）。ただし呼び出し経路によっては文字列（`typeof args === 'string'`）で着弾する環境があるため、雛形は meta 直後に正規化シム（`args = typeof args === 'string' ? JSON.parse(args) : (args || {})`）を持つ。文字列・オブジェクトどちらで届いても本文のトップレベル `args.` 参照が機能する
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- **進捗の可視化**: IDE 拡張では `/workflows` の進捗表示が使えないため、`log()` で開始日時・進捗・裁定結果を可視化する。開始日時はオーケストレーターが起動直前に `TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'` を実測して `args.startedAt` で渡し（省略可・ログ表示専用で `agent()` プロンプトへは埋め込まない — resume のキャッシュ一致を保つ）、各 `agent()` はプロンプト末尾の指示（`TAIL_NOTE`）で同フォーマットの時刻を実行して構造化出力の `nowJst`（`NOW_JST_FIELD`）として返す。スクリプトは完了ログに使うほか、直近値を `lastJst` に保持して Judge 起動などの開始ログに使う（`parallel()` バッチは各結果の `nowJst` の最大値を完了時刻とする）。裁定完了時には真の欠陥 / 仕様未定 / 除外の内訳と各指摘のタイトルを `log()` で出力する（件数上限つき）
- **プロンプトは英語・出力は日本語**: `agent()` に渡すプロンプト本文・スキーマ `description` は英語で記述する（指示追従の精度向上）。ユーザーが読む内容 — 構造化出力の中身（反例・指摘のタイトル / detail 等）・`log()` 文字列・`meta`・カテゴリ enum 値（`真の欠陥` / `仕様未定` / `低優先度` / `ノイズ`）— は日本語のまま（`TAIL_NOTE` が日本語出力を指示する）
- Phase 3（最終出力）・Phase 4（PR 投稿ゲート）はオーケストレーター（メインセッション）が担う。エージェントは裁定結果を返すだけで、投稿・コミットはしない
- **単発**（ループ・収束判定・上限チェックは持たない）

## 雛形: claude-judge 単発敵対レビュー（cra-claude-judge）

`args`: `{ target, diffBase, testCmd, focus, startedAt }`
（`target`: レビュー対象の識別子〔PR 番号 / ブランチ名 / `ref..ref` / パス / "未コミット変更"〕。`diffBase`: diff の取り方の説明。`testCmd`: 反例テスト実行コマンド。空文字なら「記述のみモード」〔反例テストは書くが実行しない〕。`focus`: 追加の重点観点〔Breaker に注入〕。無ければ空文字。`startedAt`: 起動直前に実測した開始日時〔開始ログ表示専用・省略可〕）

```js
export const meta = {
  name: 'cra-claude-judge',
  description: 'code-reviewer-adversarial claude-judge モード（独立 Opus Breaker × 独立 Opus Judge・単発）',
  phases: [
    { title: 'Break', detail: '独立 Opus Breaker による反例・攻撃シナリオ生成' },
    { title: 'Judge', detail: 'Judge バッチ並列裁定（≤4 件/バッチ・max）∥ miss-finder（Breaker 見落としの独立探索・max）' },
  ],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const NOW_JST_FIELD = { type: 'string', description: "Completion time in JST: the verbatim output of `TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'`" }
const TAIL_NOTE = "Output language: write all output content (structured output fields and any files you write) in Japanese; keep code identifiers, file paths, and commands as-is. Finally, run `TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'` and put its verbatim output into nowJst."
const ts = (t) => (t ? `[${t} JST] ` : '')
let lastJst = args.startedAt || ''

const target = `Review target: ${args.target}. Diff acquisition: ${args.diffBase} (identify the changed files, lines, and hunks yourself accordingly; for a PR target, fetch the diff via GitHub MCP; if large, keep only the diff text and the changed-file list).`
const testNote = args.testCmd
  ? `Run probe tests with ${args.testCmd} to verify them.`
  : `The test runner is undetermined, so this is describe-only mode: write probe tests but do not run them (mark unrun hypotheses verified: UNVERIFIED).`

const BREAK_SCHEMA = {
  type: 'object',
  required: ['counterexamples', 'nowJst'],
  properties: {
    counterexamples: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'scenario', 'verified'],
        properties: {
          title: { type: 'string' },
          scenario: { type: 'string', description: 'The counterexample, attack scenario, or invariant violation' },
          verified: { type: 'string', enum: ['fail', 'UNVERIFIED'], description: 'fail = verified by a probe test / UNVERIFIED = hypothesis that could not be verified by execution' },
          evidence: { type: 'string', description: 'File path, line, test execution results, etc.' },
        },
      },
    },
    nowJst: NOW_JST_FIELD,
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['items', 'nowJst'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'category', 'basis', 'detail'],
        properties: {
          title: { type: 'string' },
          category: { type: 'string', enum: ['真の欠陥', '仕様未定'] },
          severity: { type: 'string', enum: ['High', 'Medium', 'Low'] },
          basis: { type: 'string', description: 'Primary evidence such as file path and line numbers' },
          detail: { type: 'string' },
          fix: { type: 'string', description: 'A concrete mitigation (attach to 真の欠陥 findings)' },
        },
      },
    },
    dismissed: {
      type: 'array',
      items: { type: 'object', required: ['title', 'category'], properties: { title: { type: 'string' }, category: { type: 'string', enum: ['低優先度', 'ノイズ'] } } },
      description: 'Not adopted (keep only count and title for auditability)',
    },
    nowJst: NOW_JST_FIELD,
  },
}

log(`${ts(lastJst)}claude-judge 敵対レビュー開始（対象: ${args.target}）`)

const breaker = await agent(`You are a Breaker. Do not merely read the implemented code — break it. Enumerate counterexamples, attack scenarios, and invariant violations. Stay independent, without the conversational / implementation context, and default to skepticism: treat implementations that only hold on the happy path as real weaknesses, and grant no credit to good intentions, partial fixes, or promises of follow-up work.
## Input
1. ${target}
2. If related requirements, specs, or design intent exist, check them via Issues / ADRs / documents.
${args.focus ? `\n## Focus aspects (attack these with priority)\n${args.focus}\n` : ''}## Attack aspects (cover all)
- Security: authorization bypass, injection, secret leakage, TOCTOU, PII exposure, confused deputy
- Spec: unmet acceptance criteria, contract violations (inputs / outputs, pre / postconditions), backward-compatibility breakage, version skew / schema drift
- Regression: breaking existing behavior or callers
- Operations, maintainability, availability: missing observability, fragile deploy / rollback, excessive coupling, missing timeouts / retries, behavior on failure or dependency degradation, resource exhaustion, single points of failure
- Data integrity & performance: transaction boundaries, atomicity, idempotency (double execution), broken concurrent updates, partial failure, reentrancy, irreversible state changes, N+1 or excessive I/O, computational complexity
- Architecture: layer-responsibility violations, boundary intrusion, unverified execution paths
## Probe tests
- Where possible, write each hypothesis as a minimal failing test. The test filename must contain .breaker-probe. (e.g. foo.breaker-probe.test.ts). ${testNote}
- Discard hypotheses whose test passes, and delete those probe tests yourself before finishing. Report hypotheses whose test fails as verified counterexamples (verified: fail) and leave the test in the tree.
- Mark hypotheses that cannot be verified by execution as verified: UNVERIFIED.
## Constraints
- No code changes other than probe tests. Do not commit or push.
- Do not report "good code" or readability findings (out of scope for this skill).
- Mark unfalsifiable findings verified: UNVERIFIED and treat their confidence as low, expecting the Judge to cut them as noise.
Final output: put the counterexample list into counterexamples (no dedup or categorization — that is the Judge's role). ${TAIL_NOTE}`,
  { label: 'breaker', phase: 'Break', model: 'opus', effort: 'max', schema: BREAK_SCHEMA })
if (breaker === null) return { status: 'agent-failed', at: 'breaker' }
lastJst = breaker.nowJst || lastJst
log(`[${breaker.nowJst} JST] breaker 完了（反例${breaker.counterexamples.length}件）`)
for (const c of breaker.counterexamples.slice(0, 10)) log(`- [${c.verified}] ${c.title}`)
if (breaker.counterexamples.length > 10) log(`- …他${breaker.counterexamples.length - 10}件`)

// Judge をバッチ並列化（≤4 件/バッチ・effort high・evidence 限定照合・見落とし探索なし）し、Breaker 見落としの独立探索（miss-finder・effort max・diff スコープ・同じ 4 分類で自己分類）を並列の独立エージェントへ分離する。両者をフラット parallel の異種 thunk 群として同時起動する（#88 の no-throw parallel 契約に依存し try/catch で囲まない）
const judgeBatchPrompt = (batch, batchNum, batchTotal) => `You are the Judge (adjudicator). Another agent (the Breaker) generated counterexamples / attack scenarios; adjudicate them by checking them against the real code in the repository. Do not defer to the Breaker — judge independently. You were involved in neither the implementation nor the counterexample generation. This is batch ${batchNum}/${batchTotal} of the Breaker counterexamples.
## Input
1. ${target}
2. The counterexamples to adjudicate in this batch (handle no others):
${JSON.stringify(batch, null, 2)}
## Adjudication task
Check each counterexample against the real code and classify it into exactly one of these 4 categories (use these exact Japanese values for category):
- 真の欠陥 (true defect): valid as a spec violation, security issue, regression, operations / maintainability / availability problem, data-integrity / performance problem, missing test coverage, or architecture violation — worth fixing.
- 仕様未定 (spec undecided): the spec is ambiguous and the Breaker made an arbitrary assumption (needs spec confirmation).
- 低優先度 (low priority): valid but low severity; not worth the fix cost.
- ノイズ (noise): unfalsifiable, a misunderstanding, or off the mark (excluded).
## Scoped verification (keep moving steadily)
- Adjudicate only the inline batch above. Do not read or handle other batches.
- Limit verification to the files / lines pointed to by each counterexample's evidence. If a counterexample has no evidence, limit verification to the changed range and the places its scenario names. In either case, do not run unrelated wide-area greps or cross-service exploration.
- Keep tool calls progressing steadily within ~3 minutes (do not stall on a single exploration).
- Do not independently hunt for defects the Breaker missed in this batch (a separate agent, the miss-finder, does that — avoid duplication).
## Constraints
- Readability, naming, and style are out of scope.
- Classify as 真の欠陥 only counterexamples that can answer all 4 of: (1) what happens, (2) why that code path is vulnerable, (3) the expected impact, (4) a concrete mitigation. Concerns that cannot answer them go to 低優先度 or ノイズ.
- Prefer a few strong, defensible findings over many weak ones.
- Do not modify code or files (adjudication only). Do not commit.
- Put only 真の欠陥 and 仕様未定 into items (set category, and attach fix to 真の欠陥 findings); leave 低優先度 / ノイズ in dismissed with count and title only.
${TAIL_NOTE}`

const missFinderPrompt = () => `You are the Judge (adjudicator, miss-finding role). Another agent (the Breaker) generated counterexamples, but your role is to independently hunt for defects the Breaker missed. You were involved in neither the implementation nor the counterexample generation.
## Input
1. ${target}
2. The counterexamples the Breaker already raised (reference for avoiding duplication; do not re-adjudicate them):
${JSON.stringify(breaker.counterexamples, null, 2)}
## Task
- Scoped to the change set (diff), independently hunt for defects the Breaker did not raise. Self-classify what you find using the same 4-category criteria as the Breaker counterexamples:
  - 真の欠陥 (true defect): valid as a spec violation, security issue, regression, operations / maintainability / availability problem, data-integrity / performance problem, missing test coverage, or architecture violation — worth fixing.
  - 仕様未定 (spec undecided): the spec is ambiguous and an arbitrary assumption would be required (needs spec confirmation).
  - 低優先度 / ノイズ: anything that does not reach the bar above.
## Scope limits (stall avoidance)
- Limit the exploration to the change set (diff). Do not run unrelated wide-area greps or cross-service exploration.
- Keep tool calls progressing steadily within ~3 minutes (do not stall on a single exploration).
- Do not repeat counterexamples the Breaker already raised (new misses only).
## Constraints
- Readability, naming, and style are out of scope.
- Classify as 真の欠陥 only findings that can answer all 4 of: (1) what happens, (2) why that code path is vulnerable, (3) the expected impact, (4) a concrete mitigation. Concerns that cannot answer them go to 低優先度 or ノイズ.
- Do not modify code or files (adjudication only). Do not commit.
- Put only 真の欠陥 and 仕様未定 into items (set category, and attach fix to 真の欠陥 findings); leave 低優先度 / ノイズ in dismissed with count and title only.
${TAIL_NOTE}`

const scen = breaker.counterexamples || []
const BATCH = 4
const batches = []
for (let b = 0; b < scen.length; b += BATCH) batches.push(scen.slice(b, b + BATCH))
log(`${ts(lastJst)}judge 起動（反例${scen.length}件・${batches.length}バッチ + miss-finder）`)
const thunks = [
  ...batches.map((batch, bi) => () =>
    agent(judgeBatchPrompt(batch, bi + 1, batches.length), { label: `judge:b${bi + 1}`, phase: 'Judge', model: 'opus', effort: 'high', schema: FINDINGS_SCHEMA })),
  () => agent(missFinderPrompt(), { label: 'miss-finder', phase: 'Judge', model: 'opus', effort: 'max', schema: FINDINGS_SCHEMA }),
]
const results = await parallel(thunks)
const judgeResults = results.slice(0, batches.length)
const missResult = results[batches.length]
const okJudge = judgeResults.filter(Boolean)
if (batches.length > 0 && okJudge.length === 0) return { status: 'agent-failed', at: 'judge' }
const judgeDegraded = okJudge.length < batches.length
const missSearchFailed = missResult === null
if (judgeDegraded) log(`judge: ${batches.length - okJudge.length}/${batches.length} バッチ失敗（部分裁定で続行・未裁定の反例あり）`)
if (missSearchFailed) log(`miss-finder 失敗（全反例は裁定済み・独立探索のみ喪失）`)
const times = [...okJudge, missResult].filter(Boolean).map((r) => r.nowJst).filter(Boolean).sort()
if (times.length) { lastJst = times[times.length - 1]; log(`[${lastJst} JST] judge+miss 完了（judge ${okJudge.length}/${batches.length} バッチ・miss-finder ${missResult ? '完了' : '失敗'}）`) }
const items = [...okJudge.flatMap((r) => r.items || []), ...((missResult && missResult.items) || [])]
const dismissed = [...okJudge.flatMap((r) => r.dismissed || []), ...((missResult && missResult.dismissed) || [])]

// 裁定結果の可視化: 内訳と各指摘のタイトルを log で出す（件数上限つき）
const trueDefects = items.filter((it) => it.category === '真の欠陥')
const specItems = items.filter((it) => it.category === '仕様未定')
log(`${ts(lastJst)}裁定結果: 真の欠陥${trueDefects.length}件・仕様未定${specItems.length}件・除外${dismissed.length}件`)
for (const it of items.slice(0, 10)) log(`- [${it.severity || '-'}] ${it.title}${it.category === '仕様未定' ? '〔仕様未定〕' : ''}`)
if (items.length > 10) log(`- …他${items.length - 10}件`)

return { status: 'ok', items, dismissed, counterexamples: breaker.counterexamples, judgeDegraded, missSearchFailed }
```

返却の扱い:

- `status: 'ok'` → オーケストレーターが `items`（真の欠陥 / 仕様未定）と `dismissed`（低優先度 / ノイズの件数）を SKILL.md「Phase 3 — 最終出力」の構造に整形し、Phase 4（PR 投稿ゲート）を通常どおり実施する。Phase 3 サマリの「Judge:」欄は `独立 Opus エージェント（コンテキスト隔離・バッチ並列 + miss-finder）` と記す。出力・投稿の前に `.breaker-probe.` を含む反例テストが変更セットに残っていれば取り除く（単発レビューの使い捨て。回帰テスト化は呼び出し元の判断）
- `judgeDegraded: true` → 一部の Judge バッチが失敗し、その反例（最大 4 件/バッチ）が未裁定のまま結果が返った。未裁定の反例が残る旨を Phase 3 出力に明記し、PR 投稿ゲート前にユーザーへ確認する（硬い recall 欠損）
- `missSearchFailed: true` → miss-finder（Breaker 見落としの独立探索）が失敗した。全反例は裁定済みで独立探索ぶんのみ喪失する（`judgeDegraded` より軽い劣化）。Phase 3 出力に明記する
- `status: 'agent-failed'` → 1 回だけ `resumeFromRunId` で再開を試み、それでも失敗ならメインセッションでの代行はせず、SKILL.md「Judge 利用不能時のフォールバック」の停止ケースに従う（全 Judge バッチ失敗〔`ok.length === 0`〕のみ agent-failed。一部バッチ失敗・miss-finder 失敗は上記フラグで続行する）

## 同期ノート

Breaker / Judge プロンプトの攻撃観点・4 分類裁定基準は smart-issue-resolve 雛形 B（`sir-claude-review-set`）と共通である。変更時は CLAUDE.md「スキル改修時の注意」の同期対象（smart-issue-resolve 雛形 B/C・smart-issue-plan `sip-plan-review-set`・code-reviewer の隔離モード）と揃える。プロンプトは英語・出力（構造化出力の中身・`log()`・カテゴリ enum 値）は日本語という言語規約（Issue #122）も同期対象 4 スキルで共通。標準レビュー（可読性を含む観点）は本スキルの対象外で `/code-reviewer` に委ねる点は codex-judge モードと同じ。

**Judge のバッチ並列化 + miss-finder 分離（cra 固有・Issue #107）**: 単発 Judge を「Judge バッチ（`breaker.counterexamples` を ≤4 件/バッチに分割・フラット `parallel`・`effort: 'high'`・evidence 限定照合・見落とし探索なし）∥ miss-finder（1 体・`effort: 'max'`・diff スコープ・同じ 4 分類で自己分類）」の異種 thunk 群に置換した。裁定基準の**内容**は 4 分類のまま不変なので resolve/plan への内容同期は不要（バッチ分割・miss-finder 分離は cra 側の構造変更）。劣化伝播は `judgeDegraded`（バッチ失敗で未裁定の反例が残る＝硬い recall 欠損）・`missSearchFailed`（見落とし探索のみ喪失＝より軽い劣化）で区別する。`breaker` はレンズ分割しない（resolve/plan とは非対称・Issue #107 の対象表で cra 行は Judge 側のみを指示）。`no-throw parallel` 契約（Issue #88）に依存し `await parallel(...)` を try/catch で囲まない。**Breaker・Judge バッチ・miss-finder の opus 化は Issue #111**（精度優先。miss-finder の effort max は元のまま維持）。**Judge バッチの effort は #111 で high→max 化 → Issue #113 で high へ戻した**（≤4 件/バッチの有界作業量に max は過剰。時間・トークン効率の再バランス）。
