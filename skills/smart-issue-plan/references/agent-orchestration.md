# エージェントオーケストレーション（計画レビュー用 Workflow スクリプト雛形）

smart-issue-plan の **claude 系計画レビューループ**を担う役割別エージェントの起動手順と Workflow スクリプト雛形。SKILL.md の「claude 系レビューループ」節から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md を参照）。

> 計画作成（手順 4 探索・手順 5 作成）はオーケストレーター（メインセッション）が従来どおり担う。本ファイルの雛形が起動するのは**確定した初期計画を対象にしたレビューループの 1 セット**のみ。計画作成のオーケストレーション化ではない。

## 前提とゲート

- 起動前に `{作業Dir}/context.md` と `{作業Dir}/plan.md` が両方存在すること（SKILL.md の claude 系レビューループ節で作成）。どちらか無ければ Workflow を起動せず、作成に戻る
- スクリプトはこのファイルの雛形を**そのまま** `script` に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない）
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- ツール結果に返る `scriptPath` を控えておくと、同じ雛形の再起動（レビューセット続行など）は `{scriptPath, args}` で再送できる。中断・失敗からの再開は `resumeFromRunId` を使う

## 作業ディレクトリと引き継ぎファイル

作業ディレクトリはオーケストレーターが `mktemp -d "${TMPDIR:-/tmp}/sip-issue-<番号>.XXXXXX"` で作成する（OS の一時領域に任せ、スキル側で削除手順は持たない）。`context.md` と `plan.md` は以下の書式で書き出す:

`context.md`:

```markdown
# smart-issue-plan コンテキスト（Issue #<番号>）

## Issue 要件
- タイトル: <タイトル>
- 要件・受け入れ基準: <要約（箇条書き）>
- ラベル: <ラベル一覧>

## 追加指示（-p）
<{プロンプト}。無ければ「なし」。仕様未定のユーザー確認で確定した内容もここへ追記する>

## プロジェクト固有基準
<SKILL.md「レビュー基準の収集」で収集した規約・レビュー基準の要点。無ければ「なし」>
```

`plan.md`: オーケストレーターが確定した初期計画の**全文**（[assets/plan-template.md](../assets/plan-template.md) の構成）。plan-editor がこのファイルを直接編集し、レビュワー / Breaker / Judge はこのファイルを読む。収束後にオーケストレーターがこのファイルを読んで投稿する。

エージェント間の引き継ぎファイル（すべて `{作業Dir}` 配下）:

| ファイル | 書き手 | 読み手 |
|---|---|---|
| `context.md` | オーケストレーター | 全エージェント |
| `plan.md` | オーケストレーター（初期）・plan-editor（修正） | 全エージェント・オーケストレーター（収束後の投稿） |
| `security-audit.md` | セキュリティ監査役 | Breaker |
| `breaker-round-<N>.md` | Breaker | Judge |

## 雛形: 計画レビューセット（sip-plan-review-set）

1 セット = 最大 3 ラウンド。「レビュー（標準: レビュワー / 敵対: Breaker→Judge）→ plan-editor の採用判定・計画修正」を収束（採用 0 件）まで回して返る。収束時は最終 QA を回さず、オーケストレーターがそのまま `plan.md` を投稿する（計画にはテスト対象コードが無いため）。3 ラウンドごとの続行確認はオーケストレーターがセット間に行う。

`args`: `{ workDir, issueNumber, mode, startRound, priorSummary, securityAudit, securityReason }`
（`mode`: `'standard' | 'adversarial'`。`startRound`: 通算ラウンドの開始値（1, 4, 7, …）。`priorSummary`: 前セットまでの経緯要約（初回は空文字）。`securityAudit`: セキュリティ自動発動時の初回セットのみ true。`securityReason`: 自動発動の理由〔検出したシグナル〕。監査役プロンプトに埋め込まれるため `securityAudit: true` のときは必ず渡す）

```js
export const meta = {
  name: 'sip-plan-review-set',
  description: 'smart-issue-plan claude 系計画レビューループ 1 セット（最大 3 ラウンド）',
  phases: [
    { title: 'Audit', detail: 'セキュリティ監査観点の注入（自動発動時・初回セットのみ）' },
    { title: 'Review', detail: 'Sonnet レビュワー（標準）/ Breaker×Judge（敵対）' },
    { title: 'Edit', detail: 'plan-editor による採用判定・計画修正' },
  ],
}

const ctx = args.workDir + '/context.md'
const plan = args.workDir + '/plan.md'
const target = `レビュー対象は実装計画 ${plan} の本文である。計画が言及するファイル・関数・設定はリポジトリの実コードと照合し、「依拠した前提」の正否も検証する。`

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['items'],
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
          basis: { type: 'string', description: 'ファイルパス・行番号など一次情報、または計画の該当箇所' },
          detail: { type: 'string' },
        },
      },
    },
    dismissed: {
      type: 'array',
      items: { type: 'object', required: ['title', 'category'], properties: { title: { type: 'string' }, category: { type: 'string', enum: ['低優先度', 'ノイズ'] } } },
      description: '採用対象外（監査性のため件数とタイトルのみ残す）',
    },
  },
}

const FIX_SCHEMA = {
  type: 'object',
  required: ['adopted', 'rejected'],
  properties: {
    adopted: {
      type: 'array',
      items: { type: 'object', required: ['title', 'action'], properties: { title: { type: 'string' }, action: { type: 'string' } } },
    },
    rejected: {
      type: 'array',
      items: { type: 'object', required: ['title', 'reason'], properties: { title: { type: 'string' }, reason: { type: 'string' } } },
    },
    notes: { type: 'string' },
  },
}

const BREAK_SCHEMA = {
  type: 'object',
  required: ['scenarios'],
  properties: {
    scenarios: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'scenario', 'unaddressed'],
        properties: {
          title: { type: 'string' },
          scenario: { type: 'string', description: '設計への攻撃シナリオ・脅威・欠落コントロールの内容' },
          unaddressed: { type: 'string', description: '計画のどの手順・前提が対処できていないか' },
          evidence: { type: 'string', description: 'ファイルパス・行・計画の該当箇所など根拠' },
        },
      },
    },
  },
}

const records = []
const priorSummary = args.priorSummary || ''
const history = () => records.map((r) => `ラウンド${r.round}: 指摘 ${r.findings} 件 / 採用 ${r.adopted} 件`).join('\n')
const prior = () => (priorSummary || history()) ? `\n## 前ラウンドまでの経緯\n${priorSummary}${priorSummary && history() ? '\n' : ''}${history()}\n` : ''

const reviewerPrompt = (round) => `あなたは GitHub Issue #${args.issueNumber} の実装計画のレビュワーである。計画の作成には関与していない独立の立場から、リポジトリの実コードと照合し、計画の欠陥のみを指摘する。
## 入力
1. ${ctx} を読む（Issue 要件・追加指示・プロジェクト固有基準）
2. ${target}（ラウンド ${round}）
${prior()}
## レビュー観点
- 実現可能性: 計画の手順は現在のコードベースで実際に成立するか。計画が言及するファイル・関数・設定の実在と「依拠した前提」の正否をコードと照合して検証する
- 影響範囲の抜け: 変更が波及するのに計画の影響範囲に含まれていないファイル・モジュールはないか
- 手順の妥当性: 手順の順序・粒度に無理や依存の逆転がないか
- リスクの見落とし: 移行・後方互換性・品質ゲート（テスト・lint・CI）への影響で計画が触れていないものはないか
- 運用・保守・可用性: 可観測性（ログ・メトリクス・アラート）・デプロイ / ロールバック・設定管理・保守性（結合・テスト容易性・変更波及）・可用性（障害時の劣化・タイムアウト / リトライ・リソース上限・単一障害点）の設計を欠いていないか
- データ整合性・性能: トランザクション境界・原子性・冪等性（二重実行防止）・並行更新の整合性・N+1・不要な全件取得・過剰なラウンドトリップ・計算量への配慮を欠いていないか
- テストカバレッジ: 計画のテストが新規 / 変更ロジックの正常系・異常系・境界値を網羅する設計か
- アーキテクチャ境界: 計画がレイヤー責務の逸脱・境界侵犯を招かないか
- プロジェクト固有基準との整合（context.md に提示がある場合のみ）
## 制約
- 指摘は計画の欠陥に限定する（文体・体裁・好みは対象外）
- 各指摘に根拠（ファイルパス・行番号など一次情報、または計画の該当箇所）と重大度を付ける
- 計画・コードを変更しない（レビューのみ）。コミットしない
- 指摘が無ければ items を空配列にする`

const breakerPrompt = (round, auditNote) => `あなたは Breaker である。GitHub Issue #${args.issueNumber} の実装計画を「読む」のではなく「壊す」。設計が耐えるべき具体的な攻撃シナリオ・脅威・欠落コントロールを列挙する。計画の作成には関与していない独立の立場を保ち、デフォルトは懐疑: 正常系（happy path）しか想定していない手順は実在の弱点として扱い、「後で対応する」前提や部分的な対処に信用を与えない。計画にはテスト対象のコードが無いため、反例テストは書かない（攻撃シナリオで指摘する）。
## 入力
1. ${ctx} を読む（Issue 要件・追加指示・プロジェクト固有基準）
2. ${target}（ラウンド ${round}）
${prior()}${auditNote}
## 攻撃観点（横断する）
- セキュリティ: STRIDE（なりすまし・改ざん・否認・情報漏洩・DoS・権限昇格）・信頼境界・認可漏れ・PII / 秘密情報の露出・注入面（${args.workDir}/security-audit.md があれば必ず参照し、記載の脅威・攻撃シナリオも反映する）
- 仕様: 受け入れ基準未充足・契約違反・後方互換性破壊・version skew / スキーマドリフト
- 運用・保守・可用性: 可観測性の欠落・デプロイ / ロールバックの脆さ・過度な結合・タイムアウト / リトライ欠如・障害時や依存劣化時の挙動・リソース枯渇・単一障害点
- データ整合性・性能: トランザクション境界・原子性・冪等性（二重実行）・並行更新の破れ・部分失敗・再入可能性・不可逆な状態変更・N+1 や過剰 I/O・計算量
- 品質ゲートの抜け・テストカバレッジ計画の不足
- アーキテクチャ: レイヤー責務の逸脱・境界侵犯
- プロジェクト固有基準（context.md に提示がある場合、その違反も攻撃シナリオに含める）
## 出力
- ${args.workDir}/breaker-round-${round}.md に攻撃シナリオのリスト（シナリオ・対処できていない計画の手順 / 前提・根拠）を書く
- 構造化出力の scenarios に同じ内容を返す。各シナリオに unaddressed（計画のどの手順・前提が対処できていないか）を必ず付す
制約: 計画・コードを変更しない。コミットしない。`

const judgePrompt = (round, breaker) => `あなたは Judge（裁定者）である。別のエージェント（Breaker）が生成した設計への攻撃シナリオを、リポジトリの実コードと計画本文に照合して裁定する。Breaker に迎合せず、独立した視点で判断する。あなたは計画作成にも攻撃シナリオ生成にも関与していない。
## 入力
1. ${ctx} を読む（Issue 要件・追加指示・プロジェクト固有基準）
2. ${target}（ラウンド ${round}）
3. Breaker の攻撃シナリオ（詳細は ${args.workDir}/breaker-round-${round}.md）:
${JSON.stringify(breaker.scenarios, null, 2)}
${prior()}
## 裁定タスク
1. 各シナリオを実コードと計画本文に照合し、次の 4 カテゴリに分類する:
   - 真の欠陥: 計画が対処すべきなのに手順・前提に欠落・誤りがあり、修正価値がある（仕様違反・セキュリティ・後方互換性・運用 / 保守 / 可用性・データ整合性 / 性能・テストカバレッジ不足・アーキテクチャ逸脱・プロジェクト固有基準違反）
   - 仕様未定: 要件・仕様が曖昧で、Breaker が勝手な前提を置いている（要仕様確認）
   - 低優先度: 妥当だが重大度が低く、計画に反映するコストに見合わない
   - ノイズ: 反証不能・誤解・的外れ、または計画が既に対処済み（除外）
2. Breaker が見落とした計画の欠陥があれば、独立レビューとして追加で挙げる（同じ 4 カテゴリで分類する）
## 制約
- 指摘は計画の欠陥に限定する（文体・体裁・好みは対象外）
- 「真の欠陥」は次の 4 点に答えられるものだけにする: (1) 実装時に何が起きるか (2) なぜ計画のその手順・前提が脆弱か (3) 想定される影響 (4) 計画をどう直せばリスクが下がるか。答えられない懸念は低優先度またはノイズに分類する
- 弱い指摘を複数並べるより、根拠を防御できる強い指摘を優先する
- 計画・コードを変更しない（裁定のみ）。コミットしない
- items には「真の欠陥」「仕様未定」のみを入れ（category を設定）、低優先度・ノイズは dismissed に件数とタイトルだけ残す`

const editPrompt = (round, items) => `あなたは GitHub Issue #${args.issueNumber} の実装計画を作成した担当者（レビュイー）である。ラウンド ${round} のレビュー指摘を判定し、計画 ${plan} に反映する:
${JSON.stringify(items, null, 2)}
1. ${ctx} と ${plan} を読み、計画の文脈を復元する
2. 指摘を 1 件ずつ「採用 / 不採用」に分類する:
   - 採用: 計画の誤り・抜け・リスクを根拠付きで正しく突いている指摘
   - 不採用: 妥当性がない・オーバーエンジニアリングを招く・Issue のスコープ外（理由を 1 行で記録する。Judge が「真の欠陥」と裁定した指摘でも、対応が過剰になるなら不採用にしてよい）
3. 採用指摘を ${plan} に反映する（計画本文を編集する。実装コードは変更しない）
4. 反映後も計画の構成（[assets/plan-template.md](../assets/plan-template.md) 準拠）を保つ
制約: 実装コードは変更しない。コミット・push はしない。指摘の再解釈・要約による弱体化をしない（判定は採用 / 不採用の分類と理由の明記のみ）。`

let auditNote = ''
let auditFailed = false
if (args.securityAudit) {
  const audit = await agent(`あなたはセキュリティ監査役である。実装計画の敵対的レビューに先立ち、攻撃シナリオの観点を提供する。
1. ${ctx} を読む
2. ${target}
3. STRIDE・認証 / 認可・データフロー・秘密情報・PII の観点で、この計画が対処すべき脅威と検証すべき攻撃シナリオを列挙する
4. ${args.workDir}/security-audit.md に書く
自動発動の理由: ${args.securityReason}
制約: リポジトリのコード・計画を変更しない（security-audit.md への書き出しは可）。コミット・push はしない。最終出力: 攻撃シナリオの要点（15 行以内）。`,
    { label: 'security:audit', phase: 'Audit', model: 'sonnet', effort: 'max' })
  if (audit) {
    auditNote = `\n## セキュリティ監査観点（攻撃シナリオに必ず含める）\n${audit}\n詳細: ${args.workDir}/security-audit.md\n`
  } else {
    auditFailed = true
  }
}

let converged = false
let status = 'ok'
const specQuestions = []

for (let i = 0; i < 3; i++) {
  const round = args.startRound + i
  log(`計画レビューラウンド ${round}（${args.mode}）`)
  let findings = null
  if (args.mode === 'adversarial') {
    const breaker = await agent(breakerPrompt(round, auditNote), { label: `breaker:r${round}`, phase: 'Review', model: 'sonnet', effort: 'max', schema: BREAK_SCHEMA })
    if (breaker === null) { status = 'agent-failed'; break }
    findings = await agent(judgePrompt(round, breaker), { label: `judge:r${round}`, phase: 'Review', model: 'sonnet', effort: 'max', schema: FINDINGS_SCHEMA })
  } else {
    findings = await agent(reviewerPrompt(round), { label: `reviewer:r${round}`, phase: 'Review', model: 'sonnet', effort: 'max', schema: FINDINGS_SCHEMA })
  }
  if (findings === null) { status = 'agent-failed'; break }
  if (findings.items.length === 0) {
    records.push({ round, findings: 0, adopted: 0, rejected: [], dismissed: (findings.dismissed || []).length })
    converged = true
    break
  }
  specQuestions.push(...findings.items.filter((it) => it.category === '仕様未定'))
  const trueDefects = findings.items.filter((it) => it.category !== '仕様未定')
  if (trueDefects.length === 0) {
    records.push({ round, findings: findings.items.length, adopted: 0, rejected: [], dismissed: (findings.dismissed || []).length })
    converged = true
    break
  }
  const fix = await agent(editPrompt(round, trueDefects), { label: `plan-editor:r${round}`, phase: 'Edit', model: 'opus', effort: 'max', schema: FIX_SCHEMA })
  if (fix === null) { status = 'agent-failed'; break }
  records.push({ round, findings: findings.items.length, adopted: fix.adopted.length, rejected: fix.rejected, dismissed: (findings.dismissed || []).length })
  if (fix.adopted.length === 0) { converged = true; break }
}

return { converged, status, records, specQuestions, auditFailed }
```

返却の扱い:

- `converged: true` → まず `specQuestions` が空であることを確認する（非空なら下記の `specQuestions` 処理を先に行い、仕様確定で修正が生じたら未収束として次セットへ回す）。空なら収束確定 → オーケストレーターが `{作業Dir}/plan.md` を読んで投稿する（計画レビューのため最終 QA は回さない）
- `converged: false` かつ `status: 'ok'`（3 ラウンド消化）→ 上限チェック: `records` の残指摘を要約提示して AskUserQuestion（続行 / 打ち切り / 中止）。続行なら `startRound` を +3、`priorSummary` に経緯要約を入れて同じ scriptPath で再起動する。打ち切りなら未収束のまま投稿（表記は「未収束で打ち切り」）
- `specQuestions` が空でない → 裁定「仕様未定」の項目。オーケストレーターが AskUserQuestion でユーザーに仕様を確認し、確定内容を `{作業Dir}/context.md`（追加指示）へ追記する。修正が必要になった場合は未収束として扱い、次セットで plan-editor が `plan.md` へ反映する
- `auditFailed: true` → セキュリティ監査役が失敗し、Breaker 内蔵のセキュリティ観点のみで実施された。完了報告に明記する
- `status: 'agent-failed'` → 1 回だけ `resumeFromRunId` で再開、それでも失敗なら SKILL.md の「フォールバック（claude 系）」へ

## 完了報告への反映

オーケストレーターは Workflow の返却を集約し、完了報告に含める:

- レビューループ: 各ラウンドのモード・指摘数・採用数・不採用理由（`records`）
- `specQuestions` でユーザーに確認した仕様と、その反映
- `auditFailed: true` の場合はその旨

## 同期ノート

本ファイルの計画レビューセット雛形（`sip-plan-review-set`）は、`smart-issue-resolve/references/agent-orchestration.md` の**雛形 B（`sir-claude-review-set`）の計画レビュー用移植**である。次の**構造**を同期する（片方を変えたら両方更新すること）:

- セット制御: `startRound` / `priorSummary` / `records` / `history()` / `prior()` の経緯引き継ぎ
- 収束判定: レビュー指摘 0 件 → 収束、`category: '仕様未定'` を除いた真の欠陥 0 件 → 収束、採用 0 件 → 収束（3 ラウンド 1 セット）
- null ガード（各 `agent()` 返却の null 判定と `status: 'agent-failed'`）・`auditFailed` フラグ・`specQuestions` の返却経路・セキュリティ監査役の注入（`securityAudit` / `securityReason`）

同期しないもの（**意図的に異なる**）:

- **レビュー対象**: resolve = git diff（実装コード）、plan = 計画テキスト（`plan.md`）
- **レビュイー**: resolve = 開発者（コード修正）、plan = plan-editor（`plan.md` 編集）
- **レビュー観点の内容**: plan は計画用（実現可能性・影響範囲の抜け・手順の妥当性など）で、diff 用の観点とは文言が異なる
- **コード専用機構は持ち込まない**: resolve 側にあるコード検証用の仕組み（反例テストのファイル・そのテスト実行・独立 QA / 最終 QA フェーズ・反例テストの後始末エージェント・FIX の「テスト通過」フラグ・BREAK の反例検証ステータス）は本ファイルには**一切含めない**。BREAK スキーマは反例検証ステータスの代わりに `unaddressed`（対処できていない計画の手順・前提）を持つ。収束後は最終 QA を回さず、オーケストレーターがそのまま計画を投稿する
