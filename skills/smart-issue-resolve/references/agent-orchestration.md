# エージェントオーケストレーション（Workflow スクリプト雛形）

smart-issue-resolve の実装・レビューを担う役割別エージェントの起動手順と Workflow スクリプト雛形。SKILL.md の手順 6 以降から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md を参照）。

## 前提とゲート

- 起動前に `{作業Dir}/context.md` が存在すること（SKILL.md 手順 6 で作成）。存在しなければ Workflow を起動せず、context.md の作成に戻る
- スクリプトはこのファイルの雛形を**そのまま** `script` に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない）。ただし呼び出し経路によっては文字列（`typeof args === 'string'`）で着弾する環境があるため、各雛形は meta 直後に正規化シム（`args = typeof args === 'string' ? JSON.parse(args) : (args || {})`）を持つ。文字列・オブジェクトどちらで届いても本文のトップレベル `args.` 参照が機能する
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- **進捗の可視化**: IDE 拡張では `/workflows` の進捗表示が使えないため、各 `agent()` はプロンプト末尾の指示（`TIME_NOTE`）で `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を構造化出力の `nowJst`（共通フィールド。`NOW_JST_FIELD`）として返す。スクリプト側は `agent()` 呼び出し直後にその値で `log(`[HH:MM JST] ...`)` する（スクリプト自身は時刻を生成できないため、必ずエージェントの返り値から取得する）。新しい `agent()` 呼び出しを追加する場合もこの規約に従う
- ツール結果に返る `scriptPath` を控えておくと、同じ雛形の再起動（レビューセット続行など）は `{scriptPath, args}` で再送できる。中断・失敗からの再開は `resumeFromRunId` を使う

## 作業ディレクトリと context.md

作業ディレクトリはオーケストレーターが `mktemp -d "${TMPDIR:-/tmp}/sir-issue-<番号>.XXXXXX"` で作成する（OS の一時領域に任せ、スキル側で削除手順は持たない）。`context.md` は以下の書式で書き出す:

```markdown
# smart-issue-resolve コンテキスト（Issue #<番号>）

## Issue 要件
- タイトル: <タイトル>
- 要件・受け入れ基準: <要約（箇条書き）>
- ラベル: <ラベル一覧>

## 実装計画（あれば）
<実装手順・影響範囲・リスク・分析時点 SHA・依拠した前提の要約。無ければ「なし」>

## 追加指示（-p）
<{プロンプト}。無ければ「なし」>

## ブランチ / diff 基準
- 作業ブランチ: <ブランチ名>
- デフォルトブランチ: <名前>（diff 基準は origin/<名前>...HEAD + 未コミットの working tree 変更）

## テスト方針
<関連テストのスコープ・実行コマンド。テストが特定できない場合は、ユーザーと合意済みの手動確認方針>

## プロジェクト固有基準
<SKILL.md 手順 6-1 で収集した規約・レビュー基準の要点。無ければ「なし」>
```

エージェント間の引き継ぎファイル（すべて `{作業Dir}` 配下）:

| ファイル | 書き手 | 読み手 |
|---|---|---|
| `context.md` | オーケストレーター | 全エージェント |
| `design.md` | 設計役 | 開発者・設計役（事後レビュー） |
| `impl-notes.md` | 開発者 | 開発者（修正時）・オーケストレーター |
| `security-audit.md` | Breaker レンズ S（claude 系・監査ラウンド）/ セキュリティ監査役（codex 系） | Breaker |
| `breaker-round-<N>[-<lens>].md` | Breaker（claude 系はレンズ別に `-<lens>` 付き・codex 系は単一） | Judge（codex 系では Codex） |
| `findings-round-<N>.md` | オーケストレーター（標準: Codex の指摘全件 / 敵対: 裁定の真の欠陥 + ユーザー確認済みの仕様未定。要約・取捨選択をしない） | 開発者（雛形 D） |

## 雛形 A: 実装フェーズ（sir-implement）

設計（条件付き）→ 実装 → 独立 QA（不合格なら開発者修正、最大 2 回）→ 設計整合・保守可用性レビュー → 反映 → QA 再確認。

`args`: `{ workDir, issueNumber, defaultBranch, needDesign }`

```js
export const meta = {
  name: 'sir-implement',
  description: 'smart-issue-resolve 実装フェーズ（設計→実装→独立QA→設計整合・保守可用性レビュー）',
  phases: [
    { title: 'Design', detail: '設計方針の確定（計画が無い/粗い場合のみ）' },
    { title: 'Implement', detail: 'Opus 開発エージェントによる実装' },
    { title: 'QA', detail: '独立エージェントによるテスト・受け入れ基準検証' },
    { title: 'ArchReview', detail: '設計整合・保守性・可用性レビューと反映' },
  ],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const ctx = args.workDir + '/context.md'
const notes = args.workDir + '/impl-notes.md'

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['items', 'nowJst'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'severity', 'basis', 'detail'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: ['High', 'Medium', 'Low'] },
          basis: { type: 'string', description: 'ファイルパス・行番号など一次情報' },
          detail: { type: 'string' },
        },
      },
    },
    nowJst: NOW_JST_FIELD,
  },
}

const FIX_SCHEMA = {
  type: 'object',
  required: ['adopted', 'rejected', 'testsPassed', 'nowJst'],
  properties: {
    adopted: {
      type: 'array',
      items: { type: 'object', required: ['title', 'action'], properties: { title: { type: 'string' }, action: { type: 'string' } } },
    },
    rejected: {
      type: 'array',
      items: { type: 'object', required: ['title', 'reason'], properties: { title: { type: 'string' }, reason: { type: 'string' } } },
    },
    testsPassed: { type: 'boolean' },
    notes: { type: 'string' },
    nowJst: NOW_JST_FIELD,
  },
}

const QA_SCHEMA = {
  type: 'object',
  required: ['pass', 'executed', 'issues', 'nowJst'],
  properties: {
    pass: { type: 'boolean' },
    executed: { type: 'string', description: '実行したテスト・lint コマンドと結果要約' },
    issues: {
      type: 'array',
      items: { type: 'object', required: ['title', 'detail'], properties: { title: { type: 'string' }, detail: { type: 'string' } } },
    },
    nowJst: NOW_JST_FIELD,
  },
}

const IMPL_SCHEMA = {
  type: 'object',
  required: ['changedFiles', 'summary', 'testResults', 'nowJst'],
  properties: {
    changedFiles: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    testResults: { type: 'string' },
    nowJst: NOW_JST_FIELD,
  },
}

const DESIGN_SCHEMA = {
  type: 'object',
  required: ['summary', 'nowJst'],
  properties: {
    summary: { type: 'string', description: 'design.md の要点（10 行以内）' },
    nowJst: NOW_JST_FIELD,
  },
}

const qaPrompt = (extra) => `あなたは独立 QA エージェントである。開発者の自己申告を信用せず、自分でテストを実行して検証する。
1. ${ctx} を読む（テスト方針・受け入れ基準・diff 基準を把握する）
2. 変更内容を確認する: git diff origin/${args.defaultBranch}...HEAD と、git status / git diff で見える未コミット変更
3. context.md のテスト方針に従い、関連スコープのテスト・lint を自分で実行する（手動確認方針の場合はその確認を可能な範囲で実施する）
4. Issue の受け入れ基準を 1 件ずつ、コードと実行結果に照らして検証する
5. ファイル名に .breaker-probe. を含む使い捨てテストが変更セットに残っていれば issues として報告する
制約: コード・ファイルを変更しない。コミット・push はしない。${extra}
判定: テストが全て通り受け入れ基準を満たすときのみ pass=true。executed に実行コマンドと結果要約、問題は issues に列挙する。${TIME_NOTE}`

log('実装フェーズ開始: Issue #' + args.issueNumber)

let design = null
if (args.needDesign) {
  design = await agent(`あなたは設計役(ソフトウェアアーキテクト)である。実装には着手しない。
1. ${ctx} を読む（Issue 要件・受け入れ基準・プロジェクト固有基準）
2. 関連コードを調査し（エントリポイント・依存グラフ・既存パターン・境界条件）、要件を満たす設計方針を確定する
3. ${args.workDir}/design.md に次を書く: 方針 / 変更対象ファイル / データ・依存の流れ / リスク / テスト方針 / 未確定事項
制約: コードは変更しない。コミット・push はしない。判断できない仕様は独断で確定せず「未確定事項」に列挙する。
最終出力: summary に design.md の要点（10 行以内）。${TIME_NOTE}`,
    { label: 'architect:design', phase: 'Design', model: 'opus', effort: 'max', schema: DESIGN_SCHEMA })
  if (design === null) return { status: 'agent-failed', at: 'design' }
  log(`[${design.nowJst} JST] Design 完了`)
}

const impl = await agent(`あなたは GitHub Issue #${args.issueNumber} を実装する開発者である。
1. ${ctx} を読む${args.needDesign ? `。続いて ${args.workDir}/design.md の設計方針に従う。未確定事項があれば最小の合理的解釈を選び、判断内容を impl-notes.md に記録する` : ''}
2. 計画・設計でカバーされない部分はコードベース調査で補う（エントリポイント・依存グラフ・既存パターン・lint / 型チェック等の品質ゲート）
3. 実装前に context.md のテスト方針に従って関連スコープのテストを一度実行し、ベースライン（既存の失敗）を記録する
4. Issue の要件・受け入れ基準・追加指示に沿って実装する。スコープは Issue 記載内容（と計画・設計の範囲）に限定する
5. 同じスコープのテストを再実行し、既存テストの壊れがないこと・新規要件を満たすことを確認する
6. ${notes} に次を書く: 変更ファイル / 要件対応（受け入れ基準ごと） / 自分で判断した事項 / テスト結果（ベースライン比較）
制約: コミット・push はしない。Issue と無関係な変更を混ぜない。${TIME_NOTE}`,
  { label: 'dev:implement', phase: 'Implement', model: 'opus', effort: 'max', schema: IMPL_SCHEMA })
if (impl === null) return { status: 'agent-failed', at: 'implement' }
log(`[${impl.nowJst} JST] Implement 完了`)

let qa = await agent(qaPrompt(''), { label: 'qa:verify', phase: 'QA', model: 'sonnet', effort: 'high', schema: QA_SCHEMA })
if (qa === null) return { status: 'agent-failed', at: 'qa' }
log(`[${qa.nowJst} JST] QA 完了（pass=${qa.pass}）`)

let qaFixRounds = 0
while (!qa.pass && qaFixRounds < 2) {
  qaFixRounds++
  const fix = await agent(`あなたは Issue #${args.issueNumber} を実装した開発者である。独立 QA から次の指摘が返った:
${JSON.stringify(qa.issues, null, 2)}
1. ${ctx} と ${notes} を読み、実装文脈を復元する
2. 指摘を検証して修正する（QA の誤検出と判断した場合は理由を rejected に記録する）
3. 関連スコープのテストを再実行する
4. ${notes} を更新する
制約: コミット・push はしない。${TIME_NOTE}`,
    { label: 'dev:qa-fix-' + qaFixRounds, phase: 'QA', model: 'opus', effort: 'max', schema: FIX_SCHEMA })
  if (fix === null) return { status: 'agent-failed', at: 'qa-fix' }
  log(`[${fix.nowJst} JST] QA修正${qaFixRounds}回目 完了（採用${fix.adopted.length}件）`)
  qa = await agent(qaPrompt('前回 QA の指摘への対応後の再検証である。'), { label: 'qa:re-verify-' + qaFixRounds, phase: 'QA', model: 'sonnet', effort: 'high', schema: QA_SCHEMA })
  if (qa === null) return { status: 'agent-failed', at: 'qa' }
  log(`[${qa.nowJst} JST] QA再検証${qaFixRounds}回目 完了（pass=${qa.pass}）`)
}
if (!qa.pass) return { status: 'qa-failed', impl, qa }

const arch = await agent(`あなたは設計役である。実装完了後の変更を、設計整合と保守・可用性の観点でレビューする。
1. ${ctx} を読む${args.needDesign ? `。${args.workDir}/design.md の設計方針とも照合する` : ''}
2. git diff origin/${args.defaultBranch}...HEAD と未コミット変更を確認する
3. 次の観点で「修正価値のある欠陥」のみ指摘する:
   - 設計整合: 設計方針・実装計画・既存アーキテクチャ（レイヤー責務・依存方向）からの逸脱
   - 保守性: 過度な結合・テスト容易性の低下・変更波及の広さ・不要な抽象化
   - 可用性・運用: タイムアウト / リトライ欠如・障害時や依存劣化時の挙動・リソース枯渇・可観測性（ログ・メトリクス）の欠落・デプロイ / ロールバックの脆さ
制約: コードは変更しない。コミット・push はしない。可読性・命名・スタイルは対象外。各指摘に根拠（ファイル・行）と重大度を付ける。指摘が無ければ items を空配列にする。${TIME_NOTE}`,
  { label: 'architect:review', phase: 'ArchReview', model: 'opus', effort: 'max', schema: FINDINGS_SCHEMA })
if (arch === null) return { status: 'agent-failed', at: 'arch-review' }
log(`[${arch.nowJst} JST] ArchReview 完了（指摘${arch.items.length}件）`)

let archFix = null
if (arch.items.length > 0) {
  archFix = await agent(`あなたは Issue #${args.issueNumber} を実装した開発者（レビュイー）である。設計役のレビュー指摘を判定・反映する:
${JSON.stringify(arch.items, null, 2)}
1. ${ctx} と ${notes} を読み、指摘を 1 件ずつ「採用 / 不採用」に分類する
   - 採用: 仕様未充足・バグ・回帰リスク・設計 / 保守 / 可用性の欠陥を根拠付きで正しく突いている指摘
   - 不採用: 妥当性がない・オーバーエンジニアリングを招く・Issue のスコープ外（理由を 1 行で記録する）
2. 採用指摘を修正し、関連スコープのテストを再実行する
3. ${notes} を更新する
制約: コミット・push はしない。${TIME_NOTE}`,
    { label: 'dev:arch-fix', phase: 'ArchReview', model: 'opus', effort: 'max', schema: FIX_SCHEMA })
  if (archFix === null) return { status: 'agent-failed', at: 'arch-fix' }
  log(`[${archFix.nowJst} JST] ArchFix 完了（採用${archFix.adopted.length}件）`)
  if (archFix.adopted.length > 0) {
    qa = await agent(qaPrompt('設計整合レビュー反映後の再検証である。'), { label: 'qa:post-arch', phase: 'ArchReview', model: 'sonnet', effort: 'high', schema: QA_SCHEMA })
    if (qa === null) return { status: 'agent-failed', at: 'qa' }
    log(`[${qa.nowJst} JST] QA(post-arch) 完了（pass=${qa.pass}）`)
    if (!qa.pass) return { status: 'qa-failed', impl, qa, archFix }
  }
}

return { status: 'ok', impl, qa, designed: design !== null, archFindings: arch.items.length, archFix }
```

返却の扱い: `status: 'ok'` → レビューモードの確定へ。`'qa-failed'` → QA の `issues` を提示してユーザーに相談。`'agent-failed'` → 1 回だけ `resumeFromRunId` で再開を試み、それでも失敗なら degradation（SKILL.md 手順 6）。

## 雛形 B: claude 系レビューセット（sir-claude-review-set）

1 セット = 最大 3 ラウンド。「レビュー（標準: レビュワー / 敵対: Breaker→Judge）→ 開発者の採用判定・修正・テスト」を収束（採用 0 件）まで回し、収束時はセット内で最終 QA まで実施して返る。3 ラウンドごとの続行確認はオーケストレーターがセット間に行う。

`args`: `{ workDir, issueNumber, branch, defaultBranch, mode, startRound, priorSummary, cleanStreak, securityAudit, securityReason }`
（`mode`: `'standard' | 'adversarial'`。`startRound`: 通算ラウンドの開始値（1, 4, 7, …）。`priorSummary`: 前セットまでの経緯要約（初回は空文字。継続セットでは**前セット最終ラウンドの採用修正内容〔title/action〕も含める** — 差分スコープをセット跨ぎで連続させるため）。`cleanStreak`: 連続クリーンラウンド数の引き継ぎ値（初回は 0 / 省略可。前セットが `cleanStreak: 1` で 3 ラウンド上限に達した場合、続行セットへ渡すと round 1 が差分スコープ解除の確認ラウンドになり dry-twice 収束がセット境界を跨いで機能する）。`securityAudit`: セキュリティ自動発動時の初回セットのみ true。`securityReason`: 自動発動の理由〔検出したシグナル〕。レンズ S の Breaker プロンプト（監査統合ラウンド）に埋め込まれるため `securityAudit: true` のときは必ず渡す）

```js
export const meta = {
  name: 'sir-claude-review-set',
  description: 'smart-issue-resolve claude 系レビューループ 1 セット（最大 3 ラウンド + 収束時の最終 QA）',
  phases: [
    { title: 'Review', detail: 'Breaker レンズ S/C/O 並列（敵対）→ Judge バッチ並列裁定 / レビュワー観点グループ G1/G2/G3 並列（標準）。レンズ S は初回セット round 1 でセキュリティ監査を内蔵' },
    { title: 'Fix', detail: '開発者エージェントによる採用判定・修正・テスト' },
    { title: 'FinalQA', detail: '収束時の独立最終検証' },
  ],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const ctx = args.workDir + '/context.md'
const notes = args.workDir + '/impl-notes.md'
const diffNote = `レビュー対象は現在ブランチ ${args.branch} の変更全体（git diff origin/${args.defaultBranch}...HEAD と、git status / git diff で見える未コミット変更）。ローカル ${args.defaultBranch} は origin より古いことがあるため、必ず origin/${args.defaultBranch} を基準にする。`

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['items', 'nowJst'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'severity', 'basis', 'detail'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: ['High', 'Medium', 'Low'] },
          category: { type: 'string', enum: ['真の欠陥', '仕様未定'], description: '敵対モードの Judge のみ設定' },
          basis: { type: 'string', description: 'ファイルパス・行番号など一次情報' },
          detail: { type: 'string' },
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

const FIX_SCHEMA = {
  type: 'object',
  required: ['adopted', 'rejected', 'testsPassed', 'nowJst'],
  properties: {
    adopted: {
      type: 'array',
      items: { type: 'object', required: ['title', 'action'], properties: { title: { type: 'string' }, action: { type: 'string' } } },
    },
    rejected: {
      type: 'array',
      items: { type: 'object', required: ['title', 'reason'], properties: { title: { type: 'string' }, reason: { type: 'string' } } },
    },
    testsPassed: { type: 'boolean' },
    notes: { type: 'string' },
    nowJst: NOW_JST_FIELD,
  },
}

const QA_SCHEMA = {
  type: 'object',
  required: ['pass', 'executed', 'issues', 'nowJst'],
  properties: {
    pass: { type: 'boolean' },
    executed: { type: 'string' },
    issues: {
      type: 'array',
      items: { type: 'object', required: ['title', 'detail'], properties: { title: { type: 'string' }, detail: { type: 'string' } } },
    },
    nowJst: NOW_JST_FIELD,
  },
}

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

// レンズ S（セキュリティ）専用スキーマ。監査ラウンドでは security-audit.md を書き出したか（auditWritten）も返す
const BREAK_S_SCHEMA = {
  type: 'object',
  required: ['counterexamples', 'nowJst'],
  properties: {
    counterexamples: BREAK_SCHEMA.properties.counterexamples,
    auditWritten: { type: 'boolean', description: 'セキュリティ監査ラウンドで security-audit.md を書き出せたか（監査ラウンドのレンズ S のみ設定）' },
    nowJst: NOW_JST_FIELD,
  },
}

const records = []
const priorSummary = args.priorSummary || ''
const history = () => records.map((r) => `ラウンド${r.round}: 指摘 ${r.findings} 件 / 採用 ${r.adopted} 件`).join('\n')
const prior = () => (priorSummary || history()) ? `\n## 前ラウンドまでの経緯\n${priorSummary}${priorSummary && history() ? '\n' : ''}${history()}\n` : ''

// 攻撃観点のレンズ分割（S/C/O）。union = 現行 Breaker の全観点（内容の追加・削除・改変なし）。レンズ S は監査役を統合
const LENSES = [
  { id: 'S', token: 'sec', label: 'Security',
    aspects: `- セキュリティ: 認可逸脱・インジェクション・秘密情報漏洩・TOCTOU・PII 露出・Confused Deputy（${args.workDir}/security-audit.md があれば必ず参照し、記載の脅威・攻撃シナリオも反映する）
- プロジェクト固有基準のうちセキュリティに関わるもの（context.md に提示がある場合、その違反も攻撃シナリオに含める）` },
  { id: 'C', token: 'corr', label: 'Correctness/Data',
    aspects: `- 仕様: 受け入れ基準未充足・契約違反・後方互換性破壊・version skew / スキーマドリフト
- 回帰: 既存挙動・呼び出し元の破壊
- データ整合性・性能: トランザクション境界・原子性・冪等性（二重実行）・並行更新の破れ・部分失敗・再入可能性・不可逆な状態変更・N+1 や過剰 I/O・計算量
- アーキテクチャ: レイヤー責務の逸脱・境界侵犯・未検証の実行パス` },
  { id: 'O', token: 'ops', label: 'Ops/Maintainability',
    aspects: `- 運用・保守・可用性: 可観測性の欠落・デプロイ / ロールバックの脆さ・過度な結合・タイムアウト / リトライ欠如・障害時や依存劣化時の挙動・リソース枯渇・単一障害点
- プロジェクト固有基準（context.md に提示がある場合、その違反も攻撃シナリオに含める）` },
]

// 差分スコープ化: ラウンド 1（初回セット）は全 diff 包括レビュー、以降は直前ラウンドの採用修正差分を重点対象にする（重点付けであり抑制ではない。diff 基準は全体維持）
const fixDelta = (i) => {
  if (args.startRound === 1 && i === 0) return ''
  const last = records[records.length - 1]
  const adoptedItems = (last && last.adoptedItems) || []
  const deltaList = adoptedItems.length
    ? adoptedItems.map((a) => `- ${a.title}: ${a.action}`).join('\n')
    : '（前セットまでの採用修正。上記「前ラウンドまでの経緯」を参照）'
  return `\n## 差分スコープ（このラウンドの重点）\n直前ラウンドで以下の修正が入った。これらが触れたファイル・領域とその波及（呼び出し元・依存）を重点対象とし、修正が新たに導入した回帰・不整合を最優先で探す:\n${deltaList}\n重点付けであって抑制ではない: スコープ外でも明白な重大欠陥に気づけば報告してよい。ただし未関連ファイルの網羅的な再読込・新規の反例テスト作成はこの重点領域に絞り、無駄な広域探索をしない。\n`
}

// 標準レビュワーの観点グループ分割（G1/G2/G3）。union = 現行の全 9 観点（内容の追加・削除・改変なし）。Breaker のレンズ分割（S/C/O）と同型で、標準モードのレビュワーを 3 グループの並列エージェントにする
const REVIEWER_GROUPS = [
  { id: 'g1', label: '仕様/バグ/テスト',
    aspects: `- 仕様充足: Issue の要件・受け入れ基準を満たしているか
- バグ: ロジック誤り・エッジケース・境界条件・エラーハンドリング漏れ
- テストカバレッジ: 新規 / 変更ロジックの検証網羅（正常系・異常系・境界値）` },
  { id: 'g2', label: '回帰/データ整合性・性能/危険箇所',
    aspects: `- 回帰リスク: 既存の挙動・テスト・呼び出し元を壊す変更はないか
- データ整合性・性能: トランザクション境界・原子性・冪等性・並行更新の整合性、N+1・過剰な I/O・計算量
- 実装レベルの危険箇所: インジェクション・秘密情報の混入・認可漏れ・依存脆弱性` },
  { id: 'g3', label: '運用・保守・可用性/アーキテクチャ境界/固有基準',
    aspects: `- 運用・保守・可用性: 可観測性の欠落、デプロイ / ロールバック・設定管理、過度な結合・テスト容易性、タイムアウト・リトライ・障害時の劣化・リソース枯渇・単一障害点
- アーキテクチャ境界: レイヤー責務の逸脱・境界侵犯
- プロジェクト固有基準との整合（context.md に提示がある場合のみ）` },
]

const reviewerGroupPrompt = (round, group, delta) => `あなたは GitHub Issue #${args.issueNumber} 対応の実装コードのレビュワー（観点グループ ${group.id}: ${group.label}）である。実装には関与していない独立の立場から、担当グループの観点に絞って修正価値のある欠陥のみを指摘する。
## 入力
1. ${ctx} を読む（Issue 要件・実装計画・プロジェクト固有基準）
2. ${diffNote}（ラウンド ${round}）
${prior()}${delta}
## レビュー観点（担当グループ ${group.id} に集中する。他グループの観点は別レビュワーが担当するため深追いしない）
${group.aspects}
## 制約
- 可読性・命名・スタイルは対象外（修正価値のある欠陥のみ）
- 各指摘に根拠（ファイルパス・行番号など一次情報）と重大度を付ける
- コード・ファイルを変更しない（レビューのみ）。コミットしない
- 指摘が無ければ items を空配列にする
${TIME_NOTE}`

// レンズ別 Breaker プロンプト。プロンプト本体は共通で、攻撃観点だけレンズ定義（lens.aspects）に差し替える。
// レンズ S かつ isAuditRound（securityAudit 初回セット round 1）のときは、監査役を統合して STRIDE 監査 → security-audit.md 書き出し → セキュリティ break を 1 エージェントで実施する（独立の前段監査スロットを消す）
const breakerLensPrompt = (round, lens, delta, isAuditRound) => `あなたは Breaker（レンズ ${lens.id}: ${lens.label}）である。GitHub Issue #${args.issueNumber} 対応の実装を「読む」のではなく「壊す」。担当レンズの観点に絞って反例・攻撃シナリオ・不変条件違反を列挙する。実装には関与していない独立の立場を保ち、デフォルトは懐疑: 正常系でしか成立しない実装は実在の弱点として扱い、善意・部分的な修正・「後続対応の見込み」に信用を与えない。
## 入力
1. ${ctx} を読む（Issue 要件・実装計画・プロジェクト固有基準）
2. ${diffNote}（ラウンド ${round}）
${prior()}${delta}${isAuditRound ? `\n## セキュリティ監査（このラウンドで break の前に実施する）\nSTRIDE・認証 / 認可・データフロー・秘密情報・PII の観点で、この変更に対する脅威と検証すべき攻撃シナリオを列挙し、${args.workDir}/security-audit.md に書き出してから下記のセキュリティ観点で break する。自動発動の理由: ${args.securityReason}。監査を security-audit.md に書き出せたら auditWritten を true、書き出せなかった場合も auditWritten を false にして内蔵セキュリティ観点での break は必ず続行する。\n` : ''}## 攻撃観点（担当レンズ ${lens.id} に集中する。他レンズの観点は別 Breaker が担当するため深追いしない）
${lens.aspects}
## 反例テスト
- 可能な仮説は最小 failing テストとして書き、context.md のテストスコープで実行して検証する。テストファイル名はレンズ固有トークン \`${lens.token}-\` を前方に付け、\`.breaker-probe.\` を必ず部分文字列として保持する（例: \`${lens.token}-foo.breaker-probe.test.ts\`）。\`.breaker-probe-xxx.\` のようにトークンを \`.breaker-probe.\` の間へ挟まない（後始末・QA が \`.breaker-probe.\` のサブストリング一致で検出するため壊さない）
- 全レンズが同一ワークツリーで同時にテストするため、自分のレンズの probe（\`${lens.token}-*.breaker-probe.\`）のみを対象に実行する。テストランナーの競合で実行できない仮説は verified: UNVERIFIED とする（Judge が保守的に扱う）
- pass した仮説は破棄し、その反例テストは自分で削除して終える。fail した仮説は検証済み反例（verified: fail）として、テストをツリーに残したまま報告する（後続の開発者が採用時に正規回帰テスト化 / 不採用時に削除する）
- 実行で確認できない仮説は verified: UNVERIFIED とする
## 出力
- ${args.workDir}/breaker-round-${round}-${lens.token}.md に反例リスト（シナリオ・根拠・テスト実行結果）を書く（レンズごとに別ファイル。並列レンズ間の上書き競合を避ける）
- 構造化出力の counterexamples に同じ内容を返す${isAuditRound ? '。security-audit.md を書き出せたかを auditWritten に返す' : ''}
制約: 反例テスト以外のコード変更をしない（security-audit.md への書き出しは可）。コミットしない。${TIME_NOTE}`

const judgeBatchPrompt = (round, batch, batchNum, batchTotal) => `あなたは Judge（裁定者）である。別のエージェント（Breaker）が生成した反例・攻撃シナリオを、リポジトリの実コードと照合して裁定する。Breaker に迎合せず、独立した視点で判断する。あなたは実装にも反例生成にも関与していない。これはラウンド ${round} の反例をバッチ分割した ${batchNum}/${batchTotal} 番目のバッチである。
## 入力
1. ${ctx} を読む（Issue 要件・実装計画・プロジェクト固有基準）
2. ${diffNote}（ラウンド ${round}）
3. このバッチで裁定する反例（これ以外は扱わない）:
${JSON.stringify(batch, null, 2)}
${prior()}
## 裁定タスク
各反例を実コードと照合し、次の 4 カテゴリに分類する:
- 真の欠陥: 仕様違反・セキュリティ・回帰・運用 / 保守 / 可用性・データ整合性 / 性能・テストカバレッジ不足・アーキテクチャ逸脱・プロジェクト固有基準違反として妥当で、修正価値がある
- 仕様未定: 仕様が曖昧で、Breaker が勝手な前提を置いている（要仕様確認）
- 低優先度: 妥当だが重大度が低く、修正コストに見合わない
- ノイズ: 反証不能・誤解・的外れ（除外）
## 照合の限定（着実に進める）
- 裁定対象は上記インラインのバッチの反例のみ。他バッチの反例・${args.workDir}/breaker-round-${round}-*.md（レンズ別の Breaker 出力）の他項目は読まない・扱わない
- 照合は各反例の evidence が指すファイル / 行に限定する。evidence が無い反例は diff の変更範囲とシナリオ本文が名指しする箇所に照合を限定する。いずれの場合も無関係な広域 grep・全サービス横断の探索はしない
- 3 分以内に着実に tool を進める（一つの探索で止まり続けない）
- Breaker が見落とした欠陥の独立探索はこのバッチでは行わない（バッチ間の重複を避けるため）
## 制約
- 可読性・命名・スタイルは対象外
- 「真の欠陥」は次の 4 点に答えられるものだけにする: (1) 何が起きるか (2) なぜそのコードパスが脆弱か (3) 想定される影響 (4) リスクを下げる具体策。答えられない懸念は低優先度またはノイズに分類する
- 弱い指摘を複数並べるより、根拠を防御できる強い指摘を優先する
- コード・ファイルを変更しない（裁定のみ）。コミットしない
- items には「真の欠陥」「仕様未定」のみを入れ（category を設定）、低優先度・ノイズは dismissed に件数とタイトルだけ残す
${TIME_NOTE}`

const fixPrompt = (round, items) => `あなたは GitHub Issue #${args.issueNumber} を実装した開発者（レビュイー）である。ラウンド ${round} のレビュー指摘を判定・反映する:
${JSON.stringify(items, null, 2)}
1. ${ctx} と ${notes} を読み、実装文脈を復元する
2. 指摘を 1 件ずつ「採用 / 不採用」に分類する:
   - 採用: 仕様未充足・バグ・回帰リスク・実装レベルの危険箇所を根拠付きで正しく突いている指摘
   - 不採用: 妥当性がない・オーバーエンジニアリングを招く・Issue のスコープ外（理由を 1 行で記録する。Judge が「真の欠陥」と裁定した指摘でも、修正が過剰対応になるなら不採用にしてよい）
3. 採用指摘を修正し、関連スコープのテストを再実行する（壊れたまま終えない）
4. .breaker-probe. を含む反例テストを整理する: 採用した欠陥に対応するものは正規の回帰テストへ変換（リネーム・配置換え）し、それ以外は削除する
5. ${notes} を更新する
制約: コミット・push はしない。指摘の再解釈・要約による弱体化をしない（判定は採用 / 不採用の分類と理由の明記のみ）。${TIME_NOTE}`

const qaPrompt = () => `あなたは独立 QA エージェントである。レビューループ収束後・コミット前の最終検証を行う。
1. ${ctx} を読む（テスト方針・受け入れ基準・diff 基準）
2. ${diffNote}
3. context.md のテスト方針に従い、関連スコープのテスト・lint を自分で実行する
4. Issue の受け入れ基準を 1 件ずつ検証する
5. .breaker-probe. を含むファイルが変更セットに残っていれば issues として報告する
制約: コード・ファイルを変更しない。コミットしない。
判定: テストが全て通り受け入れ基準を満たすときのみ pass=true。${TIME_NOTE}`

// セキュリティ監査はレンズ S の Breaker に統合済み（securityAudit 初回セット round 1 で STRIDE 監査 → security-audit.md 書き出し → セキュリティ break を 1 エージェントで実施）。独立の前段監査スロットは持たない。auditFailed はレンズ S が監査を書き出せなかった場合に立てる
let auditFailed = false

let converged = false
let status = 'ok'
let judgeDegraded = false
let breakerDegraded = false
let reviewerDegraded = false
let cleanStreak = args.cleanStreak || 0
const specQuestions = []

for (let i = 0; i < 3; i++) {
  const round = args.startRound + i
  // dry-twice: 前ラウンドがクリーン（指摘0/採用0）だった直後は確認ラウンド。差分スコープを解除しフルスコープで見直す（揺らぎ由来の見逃しを拾う）
  const isConfirmRound = cleanStreak === 1
  log(`レビューラウンド ${round}（${args.mode}）開始${isConfirmRound ? '（確認ラウンド: 連続クリーン確認・差分スコープ解除）' : ''}`)
  let findings = null
  const delta = isConfirmRound ? '' : fixDelta(i)
  if (args.mode === 'adversarial') {
    // Breaker を観点別レンズ（S/C/O）に分割しフラット parallel で同時起動する。レンズ S は securityAudit 初回セット round 1 のとき監査を内蔵実施する（前段の独立監査スロットを消す）
    const isAuditRound = !!args.securityAudit && i === 0
    const lensResults = await parallel(LENSES.map((lens) => () =>
      agent(breakerLensPrompt(round, lens, delta, isAuditRound && lens.id === 'S'),
        { label: `breaker:r${round}-${lens.token}`, phase: 'Review', model: 'opus', effort: 'max',
          schema: (isAuditRound && lens.id === 'S') ? BREAK_S_SCHEMA : BREAK_SCHEMA })))
    const okLenses = lensResults.filter(Boolean)
    if (okLenses.length === 0) { status = 'agent-failed'; break }
    if (okLenses.length < LENSES.length) { breakerDegraded = true; log(`breaker r${round}: ${LENSES.length - okLenses.length}/${LENSES.length} レンズ失敗（部分反例で続行・未探索の観点あり）`) }
    if (isAuditRound) {
      const sResult = lensResults[LENSES.findIndex((l) => l.id === 'S')]
      if (sResult === null || sResult.auditWritten === false) { auditFailed = true; log(`レンズ S の監査書き出しに失敗（内蔵セキュリティ観点のみで続行）`) }
    }
    const breakerTimes = okLenses.map((r) => r.nowJst).filter(Boolean).sort()
    if (breakerTimes.length) log(`[${breakerTimes[breakerTimes.length - 1]} JST] breaker r${round} 完了（${okLenses.length}/${LENSES.length} レンズ・反例${okLenses.reduce((n, r) => n + (r.counterexamples || []).length, 0)}件）`)
    const scen = okLenses.flatMap((r) => r.counterexamples || [])
    const BATCH = 4
    const batches = []
    for (let b = 0; b < scen.length; b += BATCH) batches.push(scen.slice(b, b + BATCH))
    const batchResults = batches.length === 0 ? [] : await parallel(batches.map((batch, bi) => () =>
      agent(judgeBatchPrompt(round, batch, bi + 1, batches.length),
        { label: `judge:r${round}-b${bi + 1}`, phase: 'Review', model: 'opus', effort: 'max', schema: FINDINGS_SCHEMA })))
    const ok = batchResults.filter(Boolean)
    if (batches.length > 0 && ok.length === 0) { status = 'agent-failed'; break }
    if (ok.length < batches.length) { judgeDegraded = true; log(`judge r${round}: ${batches.length - ok.length}/${batches.length} バッチ失敗（部分裁定で続行・未裁定の反例あり）`) }
    const judgeTimes = ok.map((r) => r.nowJst).filter(Boolean).sort()
    if (judgeTimes.length) log(`[${judgeTimes[judgeTimes.length - 1]} JST] judge r${round} 完了（${ok.length}/${batches.length} バッチ）`)
    findings = { items: ok.flatMap((r) => r.items || []), dismissed: ok.flatMap((r) => r.dismissed || []) }
  } else {
    // 標準レビュワーを観点別グループ（G1/G2/G3）に分割しフラット parallel で同時起動する。union = 現行 9 観点で内容は不変。Judge 段は無く各グループの items を単純結合する（グループ間の重複指摘は fix の採用判定で統合。敵対レンズ重複と同じ扱い）。一部グループ失敗は reviewerDegraded で伝播
    const groupResults = await parallel(REVIEWER_GROUPS.map((group) => () =>
      agent(reviewerGroupPrompt(round, group, delta),
        { label: `reviewer:r${round}-${group.id}`, phase: 'Review', model: 'opus', effort: 'max', schema: FINDINGS_SCHEMA })))
    const okGroups = groupResults.filter(Boolean)
    if (okGroups.length === 0) { status = 'agent-failed'; break }
    if (okGroups.length < REVIEWER_GROUPS.length) { reviewerDegraded = true; log(`reviewer r${round}: ${REVIEWER_GROUPS.length - okGroups.length}/${REVIEWER_GROUPS.length} グループ失敗（部分レビューで続行・未探索の観点あり）`) }
    const reviewerTimes = okGroups.map((r) => r.nowJst).filter(Boolean).sort()
    if (reviewerTimes.length) log(`[${reviewerTimes[reviewerTimes.length - 1]} JST] reviewer r${round} 完了（${okGroups.length}/${REVIEWER_GROUPS.length} グループ・指摘${okGroups.reduce((n, r) => n + (r.items || []).length, 0)}件）`)
    findings = { items: okGroups.flatMap((r) => r.items || []), dismissed: okGroups.flatMap((r) => r.dismissed || []) }
  }
  if (findings === null) { status = 'agent-failed'; break }
  // クリーン判定: 「指摘0件」「真の欠陥0件（仕様未定のみ）」「採用0件」を統一的に「クリーン」とし、連続 2 回（cleanStreak >= 2）で収束する。1 回目クリーンでは即 break せず確認ラウンドへ進む
  specQuestions.push(...findings.items.filter((it) => it.category === '仕様未定'))
  const trueDefects = findings.items.filter((it) => it.category !== '仕様未定')
  let clean = false
  if (findings.items.length === 0 || trueDefects.length === 0) {
    records.push({ round, findings: findings.items.length, adopted: 0, rejected: [], dismissed: (findings.dismissed || []).length })
    clean = true
  } else {
    const fix = await agent(fixPrompt(round, trueDefects), { label: `dev:fix-r${round}`, phase: 'Fix', model: 'opus', effort: 'max', schema: FIX_SCHEMA })
    if (fix === null) { status = 'agent-failed'; break }
    log(`[${fix.nowJst} JST] dev fix r${round} 完了（採用${fix.adopted.length}件）`)
    records.push({ round, findings: findings.items.length, adopted: fix.adopted.length, rejected: fix.rejected, dismissed: (findings.dismissed || []).length, adoptedItems: fix.adopted })
    if (!fix.testsPassed) { status = 'tests-failing'; break }
    if (fix.adopted.length === 0) clean = true
  }
  if (clean) {
    cleanStreak++
    if (cleanStreak >= 2) { converged = true; break }
    log(`ラウンド ${round}: クリーン（連続 ${cleanStreak} 回）。差分スコープを解除した確認ラウンドで再検証する`)
  } else {
    cleanStreak = 0
  }
}

let finalQa = null
if (converged) {
  if (args.mode === 'adversarial') {
    await agent(`現在の変更セット（git status / git diff で確認）にファイル名へ .breaker-probe. を含むファイルが残っていれば、それらをすべて削除する。採用された欠陥の回帰テストは開発者が正規名へ変換済みのため、.breaker-probe. が名前に残るファイルは使い捨てと定義されている。それ以外の変更は一切しない。残っていなければ何もしない。コミット・push はしない。`,
      { label: 'dev:probe-cleanup', phase: 'FinalQA', model: 'sonnet', effort: 'low' })
  }
  finalQa = await agent(qaPrompt(), { label: 'qa:final', phase: 'FinalQA', model: 'sonnet', effort: 'high', schema: QA_SCHEMA })
  if (finalQa === null) { status = 'agent-failed' } else { log(`[${finalQa.nowJst} JST] FinalQA 完了（pass=${finalQa.pass}）`) }
}

// 仕様未定は確認ラウンド（未変更コードの再レビュー）等で同一項目が再収集されうるため、返却前に title で重複排除する（確認ラウンドで新規に見つかった仕様確認は保持し、完全な重複のみ除く）
const uniqueSpecQuestions = specQuestions.filter((q, i) => specQuestions.findIndex((o) => o.title === q.title) === i)
return { converged, status, records, finalQa, specQuestions: uniqueSpecQuestions, auditFailed, judgeDegraded, breakerDegraded, reviewerDegraded, cleanStreak }
```

返却の扱い:

- `converged: true` → まず `specQuestions` が空であることを確認する（非空なら下記の `specQuestions` 処理を先に行い、仕様確定で修正が生じたら未収束として次セットへ回す。この経路ではコミットしない）。空なら `finalQa.pass` を確認して「収束後のコミット・PR 作成」へ（`pass: false` なら自動コミットを中止し issues を提示して相談）。加えて `judgeDegraded: true` のときは未裁定の反例が残るため、収束していても自動コミット前にユーザーへ確認する（下記 `judgeDegraded`）
- `converged: false` かつ `status: 'ok'`（3 ラウンド消化）→ 上限チェック: `records` の残指摘を要約提示して AskUserQuestion（続行 / 打ち切り / 中止）。続行なら `startRound` を +3、`priorSummary` に経緯要約 + **前セット最終ラウンドの採用修正内容（`records` 末尾の `adoptedItems` の title/action）** を入れ、**返却の `cleanStreak` も次セットの `args` に引き継いで**同じ scriptPath で再起動する（差分スコープをセット跨ぎで連続させる。`cleanStreak: 1` を引き継ぐと次セット round 1 が差分スコープ解除の確認ラウンドになり dry-twice 収束がセット境界を跨いで機能する）
- `specQuestions` が空でない → 裁定「仕様未定」の項目。オーケストレーターが AskUserQuestion でユーザーに仕様を確認し、確定内容を `{作業Dir}/context.md`（追加指示）へ追記する。修正が必要になった場合は未収束として扱い、次セット（または開発者修正 1 回 + 再収束確認）へ進む
- `auditFailed: true` → レンズ S の Breaker がセキュリティ監査（`security-audit.md` の書き出し）を完了できず、内蔵のセキュリティ観点のみで break された（監査の欠落）。完了報告に明記する
- `breakerDegraded: true` → 一部の Breaker レンズ（S/C/O のいずれか）が失敗し、その観点の反例が生成されないまま収束扱いになった。未探索の攻撃観点が残り、`finalQa`（テスト・受け入れ基準の検証）は当該クラスの欠陥をバックストップしない。完了報告に明記し、自動コミット前にユーザーへ確認する（`auditFailed` / `judgeDegraded` と同型の劣化伝播）
- `reviewerDegraded: true` → 標準モードで一部のレビュワー観点グループ（G1/G2/G3 のいずれか）が失敗し、その観点の指摘が生成されないまま収束扱いになった。未探索のレビュー観点が残り、`finalQa`（テスト・受け入れ基準の検証）は当該クラスの欠陥をバックストップしない。完了報告に明記し、自動コミット前にユーザーへ確認する（`breakerDegraded` と同型の劣化伝播）
- `judgeDegraded: true` → 一部の Judge バッチが失敗し、その反例（最大 4 件/バッチ）が未裁定のまま収束扱いになった。`finalQa` はテスト・受け入れ基準の検証で、敵対レビューが対象とする設計・保守・可用性クラスの未裁定欠陥はバックストップしない。完了報告に明記し、自動コミット前にユーザーへ確認する（`auditFailed` と同型の劣化伝播）
- `status: 'tests-failing'` → テストが壊れたままなので状況を提示して相談（そのまま次セットへ進まない）
- `status: 'agent-failed'` → 1 回だけ `resumeFromRunId` で再開、それでも失敗なら「フォールバック」（claude 系）へ。`converged: true` で `finalQa` が取得できなかった場合は、雛形 E を単発起動して最終 QA を補完する（QA 未実施のまま自動コミットしない）

> **同期ノート**: 雛形 B（`sir-claude-review-set`）の構造は `smart-issue-plan/references/agent-orchestration.md` の計画レビューセット雛形（`sip-plan-review-set`）へ移植済み。次を**両者で同期する**（片方の構造を変えたら両方更新すること）:
> - セット制御（`startRound` / `priorSummary` / `cleanStreak` / `records`）・収束判定・null ガード・`auditFailed` / `specQuestions` / `judgeDegraded` / `breakerDegraded` / `reviewerDegraded` の経路
> - 敵対モード Judge のバッチ並列化（Breaker 出力を ≤4 件/バッチに分割し `parallel` で並列裁定・`effort: 'max'`・evidence 限定照合・一部バッチ失敗は `judgeDegraded` フラグで伝播）
> - **Breaker のレンズ分割並列化**（攻撃観点を S/C/O の 3 レンズに分割し `LENSES` 定義 + フラット `parallel` で同時起動。union = 現行 Breaker の全観点で内容は不変。一部レンズ失敗は `breakerDegraded` で伝播）
> - **標準レビュワーのグループ分割並列化**（標準モードのレビュワーを観点別グループ G1/G2/G3 の 3 グループに分割し `REVIEWER_GROUPS` 定義 + フラット `parallel` で同時起動。union = 現行の全 9 観点で内容は不変。Judge 段は無く各グループの `items` を単純結合し、グループ間の重複指摘は fix / plan-editor の採用判定で統合する〔敵対レンズ重複と同じ扱い〕。一部グループ失敗は `reviewerDegraded` で伝播）
> - **dry-twice 収束判定**（「指摘 0 / 真の欠陥 0〔仕様未定のみ〕/ 採用 0」を統一的に「クリーン」とし、連続 2 回〔`cleanStreak >= 2`〕で収束する。1 回目クリーン後の確認ラウンドは差分スコープを解除〔`delta = ''`〕した fresh エージェントで再検証する。`cleanStreak` を `args` と返却で引き継ぎ、`cleanStreak: 1` のまま 3 ラウンド上限に達したケースはセット境界を跨いで連続 2 クリーンを成立させる）
> - **レビュー役のモデル opus 化 + Judge effort max 化**（標準レビュワー各グループ・Breaker レンズ〔S 含む〕・Judge バッチを `model: 'opus'` に、Judge バッチの `effort` を `'max'` に。QA・probe-cleanup は検証・掃除役のため sonnet 維持〔対象外〕。fix / dev は既に opus）
> - **セキュリティ監査役のレンズ S 統合**（`securityAudit` 初回セット round 1 でレンズ S が STRIDE 監査 → `security-audit.md` 書き出し → break を 1 エージェントで実施。独立の前段監査スロットは削除。`auditWritten` フラグで「監査のみ失敗」を `auditFailed` として区別）
> - **差分スコープ化**（`records[].adoptedItems` に採用修正の title/action を保持し、ラウンド 2+ の Breaker/レビュワーを直前ラウンドの修正差分とその波及に重点付けする `fixDelta()`。ラウンド 1 は全 diff 包括レビュー。diff 基準は全体維持で重点付けであり抑制ではない）
>
> plan 側はレビュー対象が計画テキスト（diff ではない）で、コード検証用の機構（反例テスト・probe 命名の不変条件・QA / 最終 QA・probe 後始末等）を持たない点が意図的に異なる（差分スコープは「plan-editor の採用計画修正が触れた計画節＋影響領域」に読み替える。Breaker のフィールド名は resolve = `counterexamples` / plan = `scenarios`）。
>
> **probe 命名の不変条件（resolve のみ・硬い制約）**: レンズ Breaker は反例テストを同一ワークツリーに書くため、レンズ固有トークン（`sec-` / `corr-` / `ops-`）を **`.breaker-probe.` の外側（前方セグメント）** に付け、`.breaker-probe.` を部分文字列として必ず保持する（例: `sec-foo.breaker-probe.test.ts`）。probe-cleanup・QA・fix は `.breaker-probe.` のサブストリング一致で検出するため、トークンを `.breaker-probe.` の**間へ挟む**（`.breaker-probe-sec.`）と検出漏れ→使い捨てテスト残留を招く。
>
> **claude / codex 系の非対称**: 雛形 C（`sir-codex-breaker`）の Breaker はレンズ分割せず単発のまま（Codex 利用制限中のため本 Issue では現状維持）。claude 系だけがレンズ分割・差分スコープ化される非対称を許容する。
>
> また、雛形 B の `reviewerGroupPrompt` / `breakerLensPrompt` / `judgeBatchPrompt`（レビュー観点・攻撃観点・4 分類裁定基準）と雛形 C（`sir-codex-breaker`）の Breaker プロンプトは、単体スキル `code-reviewer`（`--isolated` の単発隔離レビュー）・`code-reviewer-adversarial`（`--claude-judge` の Breaker×Judge）へも移植済み。攻撃観点（レンズの union で表現される内容）・裁定基準を変更したら、これら単体スキルの `references/agent-orchestration.md` も同期する（レンズ分割・差分スコープ・バッチ並列化は resolve/plan 間の構造同期で、攻撃観点・裁定基準の内容を変えないため単体スキルへの内容同期は不要。cra の Judge バッチ並列化 + miss-finder 分離は cra 側で別途実装）。マスターの同期対象一覧は CLAUDE.md「スキル改修時の注意」を参照。

## 雛形 C: codex 敵対モードの Breaker（sir-codex-breaker）

codex 敵対モード（--codex-advs-review-loop / セキュリティ自動発動）のラウンドで、Judge（Codex）に渡す反例を独立 Sonnet エージェントが生成する。1 ラウンド 1 起動。

`args`: `{ workDir, issueNumber, branch, defaultBranch, round, priorSummary, securityAudit, securityReason }`（`securityAudit` はセキュリティ自動発動時のラウンド 1 のみ true。`securityReason`: 自動発動の理由〔検出したシグナル〕。監査役プロンプトに埋め込まれるため `securityAudit: true` のときは必ず渡す）

```js
export const meta = {
  name: 'sir-codex-breaker',
  description: 'codex 敵対モードの Breaker（独立 Sonnet）1 ラウンド分',
  phases: [
    { title: 'Audit', detail: 'セキュリティ監査観点の注入（自動発動時・ラウンド 1 のみ）' },
    { title: 'Break', detail: '反例・攻撃シナリオ生成と反例テスト実行' },
  ],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const ctx = args.workDir + '/context.md'
const diffNote = `レビュー対象は現在ブランチ ${args.branch} の変更全体（git diff origin/${args.defaultBranch}...HEAD と、git status / git diff で見える未コミット変更）。ローカル ${args.defaultBranch} は origin より古いことがあるため、必ず origin/${args.defaultBranch} を基準にする。`

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

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
          scenario: { type: 'string' },
          verified: { type: 'string', enum: ['fail', 'UNVERIFIED'] },
          evidence: { type: 'string' },
        },
      },
    },
    nowJst: NOW_JST_FIELD,
  },
}

const AUDIT_SCHEMA = {
  type: 'object',
  required: ['summary', 'nowJst'],
  properties: {
    summary: { type: 'string', description: '攻撃シナリオの要点（15 行以内）' },
    nowJst: NOW_JST_FIELD,
  },
}

let auditNote = ''
let auditFailed = false
if (args.securityAudit) {
  const audit = await agent(`あなたはセキュリティ監査役である。実装コードの敵対的レビューに先立ち、攻撃シナリオの観点を提供する。
1. ${ctx} を読む
2. ${diffNote}
3. STRIDE・認証 / 認可・データフロー・秘密情報・PII の観点で、この変更に対する脅威と検証すべき攻撃シナリオを列挙する
4. ${args.workDir}/security-audit.md に書く
自動発動の理由: ${args.securityReason}
制約: リポジトリのコード（ソースファイル）を変更しない（security-audit.md への書き出しは可）。コミット・push はしない。最終出力: summary に攻撃シナリオの要点（15 行以内）。${TIME_NOTE}`,
    { label: 'security:audit', phase: 'Audit', model: 'sonnet', effort: 'max', schema: AUDIT_SCHEMA })
  if (audit) {
    auditNote = `\n## セキュリティ監査観点（攻撃シナリオに必ず含める）\n${audit.summary}\n詳細: ${args.workDir}/security-audit.md\n`
    log(`[${audit.nowJst} JST] セキュリティ監査 完了`)
  } else {
    auditFailed = true
  }
}

const breaker = await agent(`あなたは Breaker である。GitHub Issue #${args.issueNumber} 対応の実装を「読む」のではなく「壊す」。反例・攻撃シナリオ・不変条件違反を列挙する。実装には関与していない独立の立場を保ち、デフォルトは懐疑: 正常系でしか成立しない実装は実在の弱点として扱い、善意・部分的な修正・「後続対応の見込み」に信用を与えない。
## 入力
1. ${ctx} を読む（Issue 要件・実装計画・プロジェクト固有基準）
2. ${diffNote}（ラウンド ${args.round}）
${args.priorSummary ? `\n## 前ラウンドまでの経緯\n${args.priorSummary}\n` : ''}${auditNote}
## 攻撃観点(横断する)
- セキュリティ: 認可逸脱・インジェクション・秘密情報漏洩・TOCTOU・PII 露出・Confused Deputy（${args.workDir}/security-audit.md があれば必ず参照し、記載の脅威・攻撃シナリオも反映する）
- 仕様: 受け入れ基準未充足・契約違反・後方互換性破壊・version skew / スキーマドリフト
- 回帰: 既存挙動・呼び出し元の破壊
- 運用・保守・可用性: 可観測性の欠落・デプロイ / ロールバックの脆さ・過度な結合・タイムアウト / リトライ欠如・障害時や依存劣化時の挙動・リソース枯渇・単一障害点
- データ整合性・性能: トランザクション境界・原子性・冪等性（二重実行）・並行更新の破れ・部分失敗・再入可能性・不可逆な状態変更・N+1 や過剰 I/O・計算量
- アーキテクチャ: レイヤー責務の逸脱・境界侵犯・未検証の実行パス
- プロジェクト固有基準（context.md に提示がある場合、その違反も攻撃シナリオに含める）
## 反例テスト
- 可能な仮説は最小 failing テストとして書き、context.md のテストスコープで実行して検証する。テストファイル名には必ず .breaker-probe. を含める
- pass した仮説は破棄し、その反例テストは自分で削除して終える。fail した仮説は検証済み反例（verified: fail）として、テストをツリーに残したまま報告する
- 実行で確認できない仮説は verified: UNVERIFIED とする
## 出力
- ${args.workDir}/breaker-round-${args.round}.md に反例リスト（シナリオ・根拠・テスト実行結果）を書く
- 構造化出力の counterexamples に同じ内容を返す
制約: 反例テスト以外のコード変更をしない。コミットしない。${TIME_NOTE}`,
  { label: 'breaker:r' + args.round, phase: 'Break', model: 'sonnet', effort: 'max', schema: BREAK_SCHEMA })
if (breaker === null) return { status: 'agent-failed' }
log(`[${breaker.nowJst} JST] breaker r${args.round} 完了（反例${breaker.counterexamples.length}件）`)

return { status: 'ok', counterexamples: breaker.counterexamples, breakerFile: args.workDir + '/breaker-round-' + args.round + '.md', auditFailed }
```

返却の `counterexamples`（と `breakerFile` の内容）を [../assets/codex-judge-prompt.md](../assets/codex-judge-prompt.md) の「4. Breaker の反例リスト」に埋めて `codex:rescue` を呼ぶ。

## 雛形 D: 開発者の採用判定・修正（sir-dev-fix）

codex 系ラウンドで、Codex のレビュー結果を開発者エージェントが判定・反映する。起動前にオーケストレーターがレビュー結果を `{作業Dir}/findings-round-<N>.md` に書き出しておく（標準モード: Codex の指摘全件、敵対モード: 裁定の真の欠陥 + ユーザー確認で仕様が確定した項目。いずれも要約・取捨選択・再解釈をしない。物理ゲート: このファイルが無ければ起動しない）。

`args`: `{ workDir, issueNumber, round }`

```js
export const meta = {
  name: 'sir-dev-fix',
  description: 'レビュー指摘の採用判定と修正（開発者エージェント・codex 系ラウンド用）',
  phases: [{ title: 'Fix', detail: '採用 / 不採用の判定・修正・テスト再実行' }],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const ctx = args.workDir + '/context.md'
const notes = args.workDir + '/impl-notes.md'

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

const FIX_SCHEMA = {
  type: 'object',
  required: ['adopted', 'rejected', 'testsPassed', 'nowJst'],
  properties: {
    adopted: {
      type: 'array',
      items: { type: 'object', required: ['title', 'action'], properties: { title: { type: 'string' }, action: { type: 'string' } } },
    },
    rejected: {
      type: 'array',
      items: { type: 'object', required: ['title', 'reason'], properties: { title: { type: 'string' }, reason: { type: 'string' } } },
    },
    testsPassed: { type: 'boolean' },
    notes: { type: 'string' },
    nowJst: NOW_JST_FIELD,
  },
}

const fix = await agent(`あなたは GitHub Issue #${args.issueNumber} を実装した開発者（レビュイー）である。ラウンド ${args.round} のレビュー指摘を判定・反映する。
1. ${ctx} と ${notes} を読み、実装文脈を復元する
2. ${args.workDir}/findings-round-${args.round}.md のレビュー指摘を 1 件ずつ「採用 / 不採用」に分類する:
   - 採用: 仕様未充足・バグ・回帰リスク・実装レベルの危険箇所を根拠付きで正しく突いている指摘
   - 不採用: 妥当性がない・オーバーエンジニアリングを招く・Issue のスコープ外（理由を 1 行で記録する。Judge が「真の欠陥」と裁定した指摘でも、修正が過剰対応になるなら不採用にしてよい）
3. 採用指摘を修正し、context.md のテスト方針に従って関連スコープのテストを再実行する（壊れたまま終えない）
4. .breaker-probe. を含む反例テストを整理する: 採用した欠陥に対応するものは正規の回帰テストへ変換し、それ以外は削除する
5. ${notes} を更新する
制約: コミット・push はしない。指摘の再解釈・要約による弱体化をしない（判定は採用 / 不採用の分類と理由の明記のみ）。${TIME_NOTE}`,
  { label: 'dev:fix-r' + args.round, phase: 'Fix', model: 'opus', effort: 'max', schema: FIX_SCHEMA })
if (fix === null) return { status: 'agent-failed' }
log(`[${fix.nowJst} JST] dev fix r${args.round} 完了（採用${fix.adopted.length}件）`)

return { status: 'ok', fix }
```

## 雛形 E: 収束後の最終 QA（sir-qa-final）

codex 系ループの収束（または打ち切りで完了処理を選択した）後、および claude 系で**打ち切り**を選択した（雛形 B の最終 QA が未実施の）場合に、自動コミット・PR の前に独立検証を行う。claude 系の収束時は雛形 B が内蔵実行するため不要。

`args`: `{ workDir, issueNumber, defaultBranch }`

```js
export const meta = {
  name: 'sir-qa-final',
  description: '自動コミット・PR 前の独立 QA 最終検証',
  phases: [{ title: 'FinalQA', detail: 'テスト・受け入れ基準・混入物の最終確認' }],
}

// args は文字列で届く環境があるため正規化する（トップレベルの args. 参照を機能させる防御シム）
args = typeof args === 'string' ? JSON.parse(args) : (args || {})

const ctx = args.workDir + '/context.md'

const NOW_JST_FIELD = { type: 'string', description: '完了時刻(JST)。`TZ=Asia/Tokyo date \'+%H:%M\'` の出力をそのまま入れる' }
const TIME_NOTE = "最後に `TZ=Asia/Tokyo date '+%H:%M'` を実行し、結果を nowJst に入れる。"

const QA_SCHEMA = {
  type: 'object',
  required: ['pass', 'executed', 'issues', 'nowJst'],
  properties: {
    pass: { type: 'boolean' },
    executed: { type: 'string' },
    issues: {
      type: 'array',
      items: { type: 'object', required: ['title', 'detail'], properties: { title: { type: 'string' }, detail: { type: 'string' } } },
    },
    nowJst: NOW_JST_FIELD,
  },
}

const qa = await agent(`あなたは独立 QA エージェントである。レビューループ完了後・コミット前の最終検証を行う。
1. ${ctx} を読む（テスト方針・受け入れ基準・diff 基準）
2. 変更内容を確認する: git diff origin/${args.defaultBranch}...HEAD と、git status / git diff で見える未コミット変更
3. context.md のテスト方針に従い、関連スコープのテスト・lint を自分で実行する
4. Issue #${args.issueNumber} の受け入れ基準を 1 件ずつ、コードと実行結果に照らして検証する
5. .breaker-probe. を含むファイルが変更セットに残っていれば issues として報告する
制約: コード・ファイルを変更しない。コミット・push はしない。
判定: テストが全て通り受け入れ基準を満たすときのみ pass=true。${TIME_NOTE}`,
  { label: 'qa:final', phase: 'FinalQA', model: 'sonnet', effort: 'high', schema: QA_SCHEMA })
if (qa === null) return { status: 'agent-failed' }
log(`[${qa.nowJst} JST] FinalQA 完了（pass=${qa.pass}）`)

return { status: 'ok', qa }
```

## 完了報告への反映

オーケストレーターは各 Workflow の返却を集約し、完了報告に含める:

- 実装フェーズ: 変更ファイル・要件対応（`impl`）、QA 結果（`qa.executed`）、設計整合レビューの指摘数と採用 / 不採用（`archFindings` / `archFix`）
- レビューループ: 各ラウンドのモード・指摘数・採用数・不採用理由（`records`）、最終 QA 結果（`finalQa`）
- `{作業Dir}/impl-notes.md` の「自分で判断した事項」はユーザーが把握すべき決定事項として完了報告で言及する
