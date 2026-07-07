# エージェントオーケストレーション（dream 差分レビュー用 Workflow スクリプト雛形）

memory-dream の **claude 系レビューループ**（`--claude-review-loop`）を担うレビュワーエージェントの起動手順と Workflow スクリプト雛形。SKILL.md の「レビューループ」節から参照される。**Claude Code の Workflow ツール前提**（利用できない環境の degradation は SKILL.md のフォールバックを参照）。

> dream 本体（Phase 0〜4）・指摘の妥当性判定・修正 commit はオーケストレーター（メインセッション）が従来どおり担う。本ファイルの雛形が起動するのは**コンテキスト隔離されたレビュワーによる 1 ラウンド分のレビュー**のみ。ループ制御（収束判定・3 ラウンドごとの上限チェック）は SKILL.md 側の骨格で行う。

## 前提とゲート

- 起動前に Phase 0 の inventory（`${TMPDIR:-/tmp}/memory-dream-inventory.md`）が存在し、dream の全変更が commit 済みであること（レビュー対象は `git diff <開始時 HEAD>..HEAD`）
- スクリプトはこのファイルの雛形を**そのまま** `script` に渡し、可変値はすべて `args` で渡す（スクリプト本文を書き換えない。プロンプト文はスクリプトに内蔵済み）
- `args` は JSON 値として渡す（文字列化した JSON を渡さない。届いた `args` が文字列でも雛形冒頭のシムが吸収する）
- Workflow スクリプト内では `Date.now()` / `Math.random()` / 引数なし `new Date()` は使えない（雛形は使用していない）
- ツール結果に返る `scriptPath` を控えておくと、2 ラウンド目以降は `{scriptPath, args}` で再送できる。中断・失敗からの再開は `resumeFromRunId` を使う

## 雛形: dream 差分レビュー（md-dream-review）

1 起動 = 1 ラウンド。隔離された Sonnet（effort max）レビュワーが dream 差分を記憶階層の git 履歴と照合してレビューし、構造化された指摘を返す。指摘の採用 / 不採用の判定と修正 commit はオーケストレーターが行う（レビュワーはファイルを変更しない）。

`args`: `{ memoryRoot, startHead, inventoryPath, round, workSummary, priorSummary }`
（`memoryRoot`: 記憶階層ルートの絶対パス。`startHead`: dream 開始時 HEAD の commit hash。`inventoryPath`: Phase 0 の inventory ファイルの絶対パス。`round`: 通算ラウンド番号（1, 2, …）。`workSummary`: Mine で抽出した事実・Consolidate / Dedup で行った主な変更の要約。`priorSummary`: 前ラウンドまでに採用した指摘と反映内容の要約（初回は空文字））

```js
export const meta = {
  name: 'md-dream-review',
  description: 'memory-dream claude 系レビューループの 1 ラウンド（隔離 Sonnet レビュワーによる dream 差分レビュー）',
  phases: [
    { title: 'Review', detail: 'Sonnet（effort max）レビュワーが dream 差分を git 履歴と照合' },
  ],
}

const $a = typeof args === 'string' ? JSON.parse(args) : (args || {})

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
          basis: { type: 'string', description: 'ファイルパス・行・照合した commit など一次情報' },
          detail: { type: 'string', description: '何が問題か・どう直すべきか' },
        },
      },
    },
  },
}

const prior = $a.priorSummary
  ? `\n### 3. 前ラウンドまでの経緯（採用した指摘と反映内容の要約）\n${$a.priorSummary}\n`
  : ''

const findings = await agent(`あなたはエージェント記憶階層の consolidation（memory dream）結果のレビュワーである。dream の実施には関与していない独立の立場から、記憶階層リポジトリの git 履歴・内容と照合し、dream 差分の欠陥のみを指摘する。
## 入力
### 1. 記憶階層
- ルート: ${$a.memoryRoot}
- レビュー対象差分: ルートで \`git diff ${$a.startHead}..HEAD\` を実行して取得する
- レイヤ構成と更新禁止レイヤ: ${$a.inventoryPath} を読む（dream 開始時に作成された inventory）
### 2. dream の作業要約（ラウンド ${$a.round}）
${$a.workSummary}
${prior}
## レビュー観点
- 更新禁止レイヤへの変更: 差分に更新禁止レイヤ（inventory に記載）のファイルが含まれていないか
- hallucination の混入: 差分で追加・書き換えられた記述に、git 履歴・既存記憶のどこにも出典がない「新事実」が混入していないか
- 誤削除: 削除された記述のうち、現存する参照・現行で有効な知見が含まれていないか（参照先の実在は git 履歴・リポジトリ内容から検証する）
- 日付変換の誤り: 相対日付 → 絶対日付の変換が、当該行の追記 commit 日時（git log / git blame）と整合しているか
- 矛盾解決の新旧誤り: 矛盾の解決で「古い側」の値が採用されていないか（当該行の追記日時で検証する）
- 重複・経緯の残留: 上位レイヤのルール再掲、経緯・履歴（Why / 失敗談 / 学習日・セッション ID 等）、重複回避のメタ注記が成果ファイルに残っていないか
- 索引の同期漏れ: 索引（MEMORY.md 系・notes 一覧）とファイル実体が一致しているか
## 制約
- 指摘は dream 差分の欠陥に限定する（dream 以前から存在する記憶の欠陥・文体・好みは対象外）
- 各指摘に根拠（ファイルパス・行・照合した commit など一次情報）と重大度を付ける
- 記憶階層のファイルを変更しない（レビューのみ）。コミット・push はしない
- 指摘が無ければ items を空配列にする`,
  { label: `dream-reviewer:r${$a.round}`, phase: 'Review', model: 'sonnet', effort: 'max', schema: FINDINGS_SCHEMA })

if (findings === null) return { status: 'agent-failed', items: [] }
return { status: 'ok', items: findings.items }
```

返却の扱い:

- `status: 'ok'` → `items` を SKILL.md のループ骨格・手順 2（妥当性判定）に渡す。`items` が空配列ならそのラウンドは指摘 0 件（採用 0 件 = 収束）
- `status: 'agent-failed'` → 1 回だけ `resumeFromRunId` で再開し、それでも失敗なら SKILL.md の「フォールバック（claude 系）」へ

## 同期ノート

- 雛形内のレビュワープロンプト（レビュー観点 7 項目・制約）は [assets/codex-review-prompt.md](../assets/codex-review-prompt.md) の codex 系テンプレートと**同一の観点**を持つ。片方を変えたらもう片方も更新すること（系統によってレビュー観点が変わらないことが同期の目的）
- 本雛形は memory-dream 専用の標準レビュー（記憶差分向け観点）であり、コードレビュー系スキルの観点骨格（CLAUDE.md「レビュープロンプトの二重化と同期」のマスター対象）とは**意図的に別物**。同マスターリストへの同期対象ではない
- 冒頭の `$a` シムは「Workflow の `args` が JSON 文字列で届く環境がある」既知問題（#76）への対応。恒久修正が入っても無害（JSON 値で届けばそのまま通す）
