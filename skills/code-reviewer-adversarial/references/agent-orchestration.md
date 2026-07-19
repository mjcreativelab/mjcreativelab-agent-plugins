# エージェントオーケストレーション（claude-judge モード Workflow スクリプト雛形）

code-reviewer-adversarial の `--claude-judge` モード（および Codex 不在時の自動フォールバック）で起動する、**独立 Opus Breaker × 独立 Opus Judge（バッチ並列 + 見落とし探索分離）の単発敵対レビュー**の Workflow スクリプト雛形。SKILL.md「claude-judge モード」から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md「Judge 利用不能時のフォールバック」を参照）。

> 本雛形の Breaker / Judge プロンプトは smart-issue-resolve `references/agent-orchestration.md` の雛形 B（`sir-claude-review-set`）の `breakerPrompt` / `judgeBatchPrompt` からの移植である（単発用に、ループ制御〔ラウンド・経緯〕と context.md 依存を除き、レビュー対象を `args` の diff 基準に読み替えた）。Judge は ≤4 件/バッチのフラット `parallel` 裁定（`effort: 'max'`）と、Breaker 見落としの独立探索を担う miss-finder（`effort: 'max'`・diff スコープ）に分離している（バッチ分割・miss-finder 分離は Issue #107、Breaker/Judge の opus 化・Judge バッチの effort max 化は Issue #111）。攻撃観点・4 分類裁定基準を変更するときは CLAUDE.md「スキル改修時の注意」の同期対象と揃える。

## 前提とゲート

- スクリプトはこの雛形を**そのまま** `script`（または本ファイルから抽出した `scriptPath`）に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない）。ただし呼び出し経路によっては文字列（`typeof args === 'string'`）で着弾する環境があるため、雛形は meta 直後に正規化シム（`args = typeof args === 'string' ? JSON.parse(args) : (args || {})`）を持つ。文字列・オブジェクトどちらで届いても本文のトップレベル `args.` 参照が機能する
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- **進捗の可視化**: IDE 拡張では `/workflows` の進捗表示が使えないため、`agent()` はプロンプト末尾の指示（`TIME_NOTE`）で `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を構造化出力の `nowJst`（`NOW_JST_FIELD`）として返す。スクリプト側は `agent()` 呼び出し直後にその値で `log(`[HH:MM JST] ...`)` する（スクリプト自身は時刻を生成できないため、必ずエージェントの返り値から取得する）
- Phase 3（最終出力）・Phase 4（PR 投稿ゲート）はオーケストレーター（メインセッション）が担う。エージェントは裁定結果を返すだけで、投稿・コミットはしない
- **単発**（ループ・収束判定・上限チェックは持たない）

## 雛形: claude-judge 単発敵対レビュー（cra-claude-judge）

`args`: `{ target, diffBase, testCmd, focus }`
（`target`: レビュー対象の識別子〔PR 番号 / ブランチ名 / `ref..ref` / パス / "未コミット変更"〕。`diffBase`: diff の取り方の説明。`testCmd`: 反例テスト実行コマンド。空文字なら「記述のみモード」〔反例テストは書くが実行しない〕。`focus`: 追加の重点観点〔Breaker に注入〕。無ければ空文字）

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

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

const target = `レビュー対象: ${args.target}。diff の取得: ${args.diffBase}（これに従って変更ファイル・行・hunk を自分で特定する。PR 対象なら GitHub MCP で diff を取得。大きい場合は diff テキストと変更ファイルリストのみ保持する）。`
const testNote = args.testCmd
  ? `反例テストは ${args.testCmd} で実行して検証する。`
  : `テストランナー未確定のため「記述のみモード」: 反例テストは書くが実行はしない（未実行の仮説は verified: UNVERIFIED とする）。`

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
          scenario: { type: 'string', description: '反例・攻撃シナリオ・不変条件違反の内容' },
          verified: { type: 'string', enum: ['fail', 'UNVERIFIED'], description: 'fail=反例テストで検証済み / UNVERIFIED=実行で確認できない仮説' },
          evidence: { type: 'string', description: 'ファイルパス・行・テスト実行結果など' },
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
          basis: { type: 'string', description: 'ファイルパス・行番号など一次情報' },
          detail: { type: 'string' },
          fix: { type: 'string', description: 'リスクを下げる具体策（真の欠陥に付ける）' },
        },
      },
    },
    dismissed: {
      type: 'array',
      items: { type: 'object', required: ['title', 'category'], properties: { title: { type: 'string' }, category: { type: 'string', enum: ['低優先度', 'ノイズ'] } } },
      description: '採用対象外（監査性のため件数とタイトルのみ残す）',
    },
    nowJst: NOW_JST_FIELD,
  },
}

const breaker = await agent(`あなたは Breaker である。実装コードを「読む」のではなく「壊す」。反例・攻撃シナリオ・不変条件違反を列挙する。会話・実装の文脈を持たない独立の立場を保ち、デフォルトは懐疑: 正常系でしか成立しない実装は実在の弱点として扱い、善意・部分的な修正・「後続対応の見込み」に信用を与えない。
## 入力
1. ${target}
2. 関連する要件・仕様・設計意図があれば Issue / ADR / ドキュメントで確認する
${args.focus ? `\n## 重点観点（優先的に攻撃する）\n${args.focus}\n` : ''}## 攻撃観点（横断する）
- セキュリティ: 認可逸脱・インジェクション・秘密情報漏洩・TOCTOU・PII 露出・Confused Deputy
- 仕様: 受け入れ基準未充足・契約違反（入出力・事前事後条件）・後方互換性破壊・version skew / スキーマドリフト
- 回帰: 既存挙動・呼び出し元の破壊
- 運用・保守・可用性: 可観測性の欠落・デプロイ / ロールバックの脆さ・過度な結合・タイムアウト / リトライ欠如・障害時や依存劣化時の挙動・リソース枯渇・単一障害点
- データ整合性・性能: トランザクション境界・原子性・冪等性（二重実行）・並行更新の破れ・部分失敗・再入可能性・不可逆な状態変更・N+1 や過剰 I/O・計算量
- アーキテクチャ: レイヤー責務の逸脱・境界侵犯・未検証の実行パス
## 反例テスト
- 可能な仮説は最小 failing テストとして書く。テストファイル名には必ず .breaker-probe. を含める（例: foo.breaker-probe.test.ts）。${testNote}
- pass した仮説は破棄し、その反例テストは自分で削除して終える。fail した仮説は検証済み反例（verified: fail）として、テストをツリーに残したまま報告する
- 実行で確認できない仮説は verified: UNVERIFIED とする
## 制約
- 反例テスト以外のコード変更をしない。コミット・push はしない
- 「良いコード」「可読性」系は出さない（このスキルの対象外）
- 反証不能な指摘は verified: UNVERIFIED とし、Judge がノイズとして切る前提で確信度を低く扱う
最終出力: counterexamples に反例リスト（重複統合・カテゴリ分類はしない。それは Judge の役割）。${TIME_NOTE}`,
  { label: 'breaker', phase: 'Break', model: 'opus', effort: 'max', schema: BREAK_SCHEMA })
if (breaker === null) return { status: 'agent-failed', at: 'breaker' }
log(`[${breaker.nowJst} JST] breaker 完了（反例${breaker.counterexamples.length}件）`)

// Judge をバッチ並列化（≤4 件/バッチ・effort max・evidence 限定照合・見落とし探索なし）し、Breaker 見落としの独立探索（miss-finder・effort max・diff スコープ・同じ 4 分類で自己分類）を並列の独立エージェントへ分離する。両者をフラット parallel の異種 thunk 群として同時起動する（#88 の no-throw parallel 契約に依存し try/catch で囲まない）
const judgeBatchPrompt = (batch, batchNum, batchTotal) => `あなたは Judge（裁定者）である。別のエージェント（Breaker）が生成した反例・攻撃シナリオを、リポジトリの実コードと照合して裁定する。Breaker に迎合せず、独立した視点で判断する。あなたは実装にも反例生成にも関与していない。これは Breaker の反例をバッチ分割した ${batchNum}/${batchTotal} 番目のバッチである。
## 入力
1. ${target}
2. このバッチで裁定する反例（これ以外は扱わない）:
${JSON.stringify(batch, null, 2)}
## 裁定タスク
各反例を実コードと照合し、次の 4 カテゴリに分類する:
- 真の欠陥: 仕様違反・セキュリティ・回帰・運用 / 保守 / 可用性・データ整合性 / 性能・テストカバレッジ不足・アーキテクチャ逸脱として妥当で、修正価値がある
- 仕様未定: 仕様が曖昧で、Breaker が勝手な前提を置いている（要仕様確認）
- 低優先度: 妥当だが重大度が低く、修正コストに見合わない
- ノイズ: 反証不能・誤解・的外れ（除外）
## 照合の限定（着実に進める）
- 裁定対象は上記インラインのバッチの反例のみ。他バッチの反例は読まない・扱わない
- 照合は各反例の evidence が指すファイル / 行に限定する。evidence が無い反例は変更範囲とシナリオ本文が名指しする箇所に照合を限定する。いずれの場合も無関係な広域 grep・全サービス横断の探索はしない
- 3 分以内に着実に tool を進める（一つの探索で止まり続けない）
- Breaker が見落とした欠陥の独立探索はこのバッチでは行わない（別エージェント〔miss-finder〕が担当するため重複を避ける）
## 制約
- 可読性・命名・スタイルは対象外
- 「真の欠陥」は次の 4 点に答えられるものだけにする: (1) 何が起きるか (2) なぜそのコードパスが脆弱か (3) 想定される影響 (4) リスクを下げる具体策。答えられない懸念は低優先度またはノイズに分類する
- 弱い指摘を複数並べるより、根拠を防御できる強い指摘を優先する
- コード・ファイルを変更しない（裁定のみ）。コミットしない
- items には「真の欠陥」「仕様未定」のみを入れ（category を設定し、真の欠陥には fix を付ける）、低優先度・ノイズは dismissed に件数とタイトルだけ残す
${TIME_NOTE}`

const missFinderPrompt = () => `あなたは Judge（裁定者・見落とし探索担当）である。別のエージェント（Breaker）が反例を生成したが、あなたの役割は Breaker が見落とした欠陥を独立に探すことである。あなたは実装にも反例生成にも関与していない。
## 入力
1. ${target}
2. Breaker が既に挙げた反例（重複を避けるための参照。これらの再裁定はしない）:
${JSON.stringify(breaker.counterexamples, null, 2)}
## タスク
- 変更セット（diff）にスコープして、Breaker が挙げていない欠陥を独立に探す。見つけた欠陥は Breaker の反例と同じ 4 カテゴリ基準で自己分類する:
  - 真の欠陥: 仕様違反・セキュリティ・回帰・運用 / 保守 / 可用性・データ整合性 / 性能・テストカバレッジ不足・アーキテクチャ逸脱として妥当で、修正価値がある
  - 仕様未定: 仕様が曖昧で、勝手な前提が必要なもの（要仕様確認）
  - 低優先度 / ノイズ: 上記に満たないもの
## 探索の限定（ストール回避）
- 探索は変更セット（diff）の範囲に限定する。無関係な広域 grep・全サービス横断の探索はしない
- 3 分以内に着実に tool を進める（一つの探索で止まり続けない）
- 既に Breaker が挙げた反例は再掲しない（新規の見落としのみ）
## 制約
- 可読性・命名・スタイルは対象外
- 「真の欠陥」は次の 4 点に答えられるものだけにする: (1) 何が起きるか (2) なぜそのコードパスが脆弱か (3) 想定される影響 (4) リスクを下げる具体策。答えられない懸念は低優先度またはノイズに分類する
- コード・ファイルを変更しない（裁定のみ）。コミットしない
- items には「真の欠陥」「仕様未定」のみを入れ（category を設定し、真の欠陥には fix を付ける）、低優先度・ノイズは dismissed に件数とタイトルだけ残す
${TIME_NOTE}`

const scen = breaker.counterexamples || []
const BATCH = 4
const batches = []
for (let b = 0; b < scen.length; b += BATCH) batches.push(scen.slice(b, b + BATCH))
const thunks = [
  ...batches.map((batch, bi) => () =>
    agent(judgeBatchPrompt(batch, bi + 1, batches.length), { label: `judge:b${bi + 1}`, phase: 'Judge', model: 'opus', effort: 'max', schema: FINDINGS_SCHEMA })),
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
if (times.length) log(`[${times[times.length - 1]} JST] judge+miss 完了（judge ${okJudge.length}/${batches.length} バッチ・miss-finder ${missResult ? '完了' : '失敗'}）`)
const items = [...okJudge.flatMap((r) => r.items || []), ...((missResult && missResult.items) || [])]
const dismissed = [...okJudge.flatMap((r) => r.dismissed || []), ...((missResult && missResult.dismissed) || [])]

return { status: 'ok', items, dismissed, counterexamples: breaker.counterexamples, judgeDegraded, missSearchFailed }
```

返却の扱い:

- `status: 'ok'` → オーケストレーターが `items`（真の欠陥 / 仕様未定）と `dismissed`（低優先度 / ノイズの件数）を SKILL.md「Phase 3 — 最終出力」の構造に整形し、Phase 4（PR 投稿ゲート）を通常どおり実施する。Phase 3 サマリの「Judge:」欄は `独立 Opus エージェント（コンテキスト隔離・バッチ並列 + miss-finder）` と記す。出力・投稿の前に `.breaker-probe.` を含む反例テストが変更セットに残っていれば取り除く（単発レビューの使い捨て。回帰テスト化は呼び出し元の判断）
- `judgeDegraded: true` → 一部の Judge バッチが失敗し、その反例（最大 4 件/バッチ）が未裁定のまま結果が返った。未裁定の反例が残る旨を Phase 3 出力に明記し、PR 投稿ゲート前にユーザーへ確認する（硬い recall 欠損）
- `missSearchFailed: true` → miss-finder（Breaker 見落としの独立探索）が失敗した。全反例は裁定済みで独立探索ぶんのみ喪失する（`judgeDegraded` より軽い劣化）。Phase 3 出力に明記する
- `status: 'agent-failed'` → 1 回だけ `resumeFromRunId` で再開を試み、それでも失敗ならメインセッションでの代行はせず、SKILL.md「Judge 利用不能時のフォールバック」の停止ケースに従う（全 Judge バッチ失敗〔`ok.length === 0`〕のみ agent-failed。一部バッチ失敗・miss-finder 失敗は上記フラグで続行する）

## 同期ノート

Breaker / Judge プロンプトの攻撃観点・4 分類裁定基準は smart-issue-resolve 雛形 B（`sir-claude-review-set`）と共通である。変更時は CLAUDE.md「スキル改修時の注意」の同期対象（smart-issue-resolve 雛形 B/C・smart-issue-plan `sip-plan-review-set`・code-reviewer の隔離モード）と揃える。標準レビュー（可読性を含む観点）は本スキルの対象外で `/code-reviewer` に委ねる点は codex-judge モードと同じ。

**Judge のバッチ並列化 + miss-finder 分離（cra 固有・Issue #107）**: 単発 Judge を「Judge バッチ（`breaker.counterexamples` を ≤4 件/バッチに分割・フラット `parallel`・`effort: 'max'`・evidence 限定照合・見落とし探索なし）∥ miss-finder（1 体・`effort: 'max'`・diff スコープ・同じ 4 分類で自己分類）」の異種 thunk 群に置換した。裁定基準の**内容**は 4 分類のまま不変なので resolve/plan への内容同期は不要（バッチ分割・miss-finder 分離は cra 側の構造変更）。劣化伝播は `judgeDegraded`（バッチ失敗で未裁定の反例が残る＝硬い recall 欠損）・`missSearchFailed`（見落とし探索のみ喪失＝より軽い劣化）で区別する。`breaker` はレンズ分割しない（resolve/plan とは非対称・Issue #107 の対象表で cra 行は Judge 側のみを指示）。`no-throw parallel` 契約（Issue #88）に依存し `await parallel(...)` を try/catch で囲まない。**Breaker・Judge バッチ・miss-finder の opus 化と Judge バッチの effort high→max 化は Issue #111**（精度優先。miss-finder の effort max は元のまま維持）。
