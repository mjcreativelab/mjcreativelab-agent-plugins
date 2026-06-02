---
name: code-reviewer-adversarial
description: Breaker（Claude）× Judge（Codex）の二者構造で、反例生成とテスト実行により「本当の欠陥」のみを抽出する敵対的コードレビュー。重要変更・最終ゲート・見逃したくない場面に使う。対象が PR なら確認ゲート経由で PR にレビューを投稿する。通常のレビューは /code-reviewer を使うこと。
argument-hint: "[<PR番号|branch|ref..ref|path>] [--test <cmd>] [-p <重点観点>]"
disable-model-invocation: true
---

# 敵対的コードレビュー（Breaker × Judge）

あなたはこのスキルの実行責任者として、**Breaker**（反例生成器）と **Judge**（裁定者）を組み合わせて敵対的レビューを行う。
役割は明確に分離する:

- **Breaker（あなた＝ Claude Opus 4.7）**: コードを「読む」のではなく「壊す」。反例・攻撃シナリオ・不変条件違反を生成し、可能な限り failing テストとして実行する。
- **Judge（Codex gpt-5.4、`codex:rescue` 経由）**: Breaker の指摘を「真の欠陥 / 仕様未定 / 低優先度 / ノイズ」に分類し、修正コストと見合うかを裁定する。

評価関数を意図的にずらしている点が肝。指摘件数ではなく、**本当の欠陥を見逃さないこと**と **false positive を抑えること** の両立を狙う。

## 引数の解析

`$ARGUMENTS` を以下のルールで解析する:

1. `-p` がある場合 → `-p` より後の部分を `{重点観点}` として保持する（Breaker persona に追加注入する）
2. `--test <cmd>` がある場合 → 以降の1トークンを `{テストコマンド}` として保持する（自動検出より優先）
3. 残りの最初の位置引数を `{対象}` として解析する

### `{対象}` の判別順

| 判定 | 解釈 | 書き出しモード |
|---|---|---|
| 省略 | 未コミット変更 + 現在ブランチ vs `main` を対象にする | 現在ブランチに open PR が 1 件 → 有効 |
| 存在するファイル/ディレクトリパス | そのパス配下の変更のみ | 無効（PR に紐付かない）|
| 数字のみ | GitHub PR 番号として扱う（GitHub MCP ツールで diff を取得） | 有効 |
| `<ref>..<ref>` を含む | commit 範囲の diff | 無効（PR に紐付かない）|
| ローカル or `origin/` で解決できるブランチ名 | そのブランチ vs `main` の差分 | そのブランチに open PR が 1 件 → 有効 |
| 上記いずれでもない | `AskUserQuestion` で解釈を確認する | 解釈に応じて再判定 |

複数 PR / 0 件 / GitHub MCP 未接続などの失敗ケースの挙動は `## PR 書き出しモード` の「フォールバック」を参照。

例:
- `/code-reviewer-adversarial` — 現在の未コミット変更を対象
- `/code-reviewer-adversarial 42` — PR #42
- `/code-reviewer-adversarial main..HEAD` — 現在ブランチの全コミット
- `/code-reviewer-adversarial packages/mjc-git-workflow-tools/ -p N+1` — 特定パス + 重点観点
- `/code-reviewer-adversarial --test "pnpm test" feature/add-foo` — テストコマンド明示 + ブランチ指定

## フロー

### Phase 0 — 前提把握

1. **引数解析**（上記ルール）で `{対象}`, `{テストコマンド}`, `{重点観点}` を確定
2. **変更範囲の取得** — `{対象}` に応じて `git diff` / GitHub MCP の PR diff を取得し、変更ファイル・行・hunk を特定（大きい PR ではレスポンスから diff テキストと変更ファイルリストのみ保持し、メタデータは Breaker/Judge の材料として必要な範囲に絞る）
3. **書き出しモード判定** — `{対象}` が PR に紐付き得るケース（省略 / ブランチ名 / PR 番号）では、`mcp__plugin_github_github__list_pull_requests` で open PR を確認して書き出しモードの有効/無効を確定する。省略時の現在ブランチは `git rev-parse --abbrev-ref HEAD` で取得する（詳細は `## PR 書き出しモード`）
4. **仕様・設計の確認** — 関連 Issue / ADR / 要件ドキュメント / 会話コンテキストの設計意図を突き合わせる
5. **テストランナーの確定**:
   - `{テストコマンド}` が明示されていればそれを使う
   - なければ `bash ${CLAUDE_SKILL_DIR}/assets/detect-test-runner.sh` で自動検出
   - 検出できなければ AskUserQuestion でユーザーに確認
   - 確認で「不要」「わからない」等が返った場合は **テスト記述のみモード**（Phase 1 で反例テスト "生成" はするが "実行" はスキップ）にフォールバック
6. **ゲート出力** — ここまでの確定値を1ブロックで表示し、ユーザーが確認できるようにする。フォーマットは以下:

   ```
   対象: <対象の識別子>（PR 対象なら "PR #N \"タイトル\"" を併記）
   テストコマンド: <確定値 or "記述のみモード">
   重点観点: <指定があれば記載、なければ "（指定なし）">
   書き出しモード: <有効（投稿先: PR #N "タイトル"）| 無効（理由: ...）>
   ```

### Phase 1 — Breaker（反例生成器）

Breaker は3つの persona を順に切り替えて実行する（persona 定義は [assets/breaker-personas.md](assets/breaker-personas.md)）:

1. **Security persona** — 認可逸脱・インジェクション・秘密情報漏洩・TOCTOU・Confused Deputy
2. **Performance persona** — N+1・境界外入力・競合・メモリリーク・タイムアウト・移行性能
3. **Specification persona** — 仕様未充足・契約違反（入出力・事前事後条件）・後方互換性破壊・移行失敗

各 persona で以下の手順を実行する:

1. **反例アイデアの列挙** — そのレンズで「壊れそうな入力・状態・呼び出し順序」を列挙する
2. **反例テストの生成** — 最小反例を failing テストコードとして書く（言語・フレームワークは Phase 0 で確定した `{テストコマンド}` に合わせる）
3. **テストの実行** — `{テストコマンド}` で生成したテストを実行する
   - `fail` したものは「検証済み反例」として採用
   - `pass` したものは「仮説は外れた」として破棄（Breaker のノイズを自己フィルタする）
   - テスト記述のみモードではこの手順をスキップ
4. **7フィールド形式で整形** — `[references/output-schema.md](references/output-schema.md)` のスキーマに従い、1指摘を1レコードとして書き下す

全 persona に横断するルール:

- `{重点観点}` が指定されていれば、各 persona の手順 1（列挙）に追加注入して優先度を上げる
- そのレンズで反例が 1 件も出せなかった persona は、**「検出 0 件」を明記して報告書に残す**（Judge 側での監査性を保つため、空欄にせず 0 件と書く）

全 persona 終了後、Breaker は **persona 単位の指摘リストをそのまま並べた Breaker 報告書** を作成する。同根の指摘が複数 persona から出た場合はタイトルに `(Security+Specification)` のような persona 注記だけを付け、**重複統合・ノイズ除外・カテゴリ分類は Judge に委ねる**（共犯化回避のため、Breaker 側で分類判断を先取りしない）。テストコードは一時領域に残し、Judge が参照可能にする。

**Breaker に課す制約**（ノイズ防止）:
- 反証不能な指摘（「〜かもしれない」の感想）は **確信度 Low** で出す。Judge がノイズとして切る想定
- 推測に頼る指摘には `[UNVERIFIED]` タグを付け、実行で確認できなかったことを明記する
- 「良いコード」「可読性」系は出さない（このスキルの対象外。`/code-reviewer` に委ねる）

### Phase 2 — Judge（裁定者）

`codex:rescue` スキルを呼び出し、Codex に裁定させる。呼び出しテンプレートは [assets/judge-prompt.md](assets/judge-prompt.md) を参照。

Judge への入力:
- 変更 diff（Phase 0 で取得）
- 仕様・設計意図の要約
- Breaker 報告書（全7フィールドの指摘リスト）
- 生成された反例テストコード（およびその実行結果）

Judge は各指摘を次の4カテゴリに分類する:

| カテゴリ | 意味 | 最終出力への扱い |
|---|---|---|
| 真の欠陥 | 仕様違反・セキュリティリスク・性能問題として妥当で、修正価値あり | 最終出力に含める |
| 仕様未定 | 仕様が曖昧で、Breaker が勝手な前提を置いている | 「仕様確認が必要」として分離 |
| 低優先度 | 妥当だが重大度が低く、修正コストに見合わない | サマリに件数のみ |
| ノイズ | 反証不能・誤解・的外れ | 最終出力から除外（件数のみ報告） |

Judge には **分類理由** と **修正コスト見積（S/M/L）** を必ず付けさせる。Judge が独断で「低優先度」「ノイズ」と切ったものは、理由を読めば妥当性が検証できる形にする。

#### Judge 呼び出し不能時のフォールバック

`codex:rescue` が呼び出せない環境（Codex CLI 未設定・ネットワーク断・サブエージェント内実行など）では、**Phase 2 で停止し、Phase 3 を出力しない**。次の 2 点をユーザーに提示して終了する:

1. Breaker 報告書（Phase 1 の成果物をそのまま）
2. 完成した Judge 呼び出し用 task 文字列（`assets/judge-prompt.md` に従って埋めたもの）

Claude 側で Judge 裁定を模擬・代行してはならない（共犯化を回避するため、別系統モデルによる独立裁定が本スキルの核）。ユーザーが別セッションで codex:rescue を呼ぶか、環境を整えて再実行することを案内する。

**このケースでは書き出しモードも自動的に無効化する**。Breaker 単独結果を PR に投稿すると共犯化回避の原則が崩れるため、投稿ゲート（Phase 4）まで到達させない。

### Phase 3 — 最終出力

Judge の裁定結果をもとに、次の構造で出力する:

```markdown
## Adversarial Review 結果

### サマリ
- 対象: <対象の識別子>
- 真の欠陥: N 件 / 仕様未定: N 件 / 低優先度: N 件（詳細省略） / ノイズ: N 件（除外）
- テスト実行: <実行済み / 記述のみ>
- Judge: Codex (via codex:rescue)

### 🚫 真の欠陥
（7フィールド形式、Judge 分類理由つき）

### ❓ 仕様未定
（確認が必要な前提と、Breaker が置いた仮定）

### 📉 低優先度（件数のみ）
- N 件: <1行タイトル羅列>

### 🔇 ノイズ（除外理由のみ）
- N 件: <1行タイトル + 除外理由>

### 💡 修正推奨の順序
Judge の修正コスト（S/M/L）と重大度から、着手順序の提案を添える
```

各「真の欠陥」は [references/output-schema.md](references/output-schema.md) の7フィールドで表示する。重大度・確信度の基準は [references/severity-rubric.md](references/severity-rubric.md) を参照。

### Phase 4 — PR 投稿ゲート

書き出しモードが **有効** の場合に限り、Phase 3 の最終出力を PR へ投稿する。無効なら Phase 3 の出力後にスキルを終了する。Phase 2 のフォールバック（Judge 呼び出し不能）で Phase 3 を出さなかった場合もここには到達しない。

フロー・投稿ツール・本文テンプレート・確認ゲート UX・フォールバックは `## PR 書き出しモード` に従う。

## PR 書き出しモード

Phase 4 で Phase 3 の最終出力を PR へ投稿する際の仕様。

### 投稿ツール

- `mcp__plugin_github_github__pull_request_review_write` を使用する
  - `method: "create"`
  - `owner`, `repo`: `git remote get-url origin` からパース（HTTPS: `https://github.com/foo/bar.git` / SSH: `git@github.com:foo/bar.git` どちらも `owner=foo`, `repo=bar`。末尾の `.git` は任意）
  - `pull_number`: 対象 PR 番号
  - `event: "COMMENT"`（approve / request_changes は人間レビュアーの判断に残す）
  - `body`: 下記テンプレートに従って生成した markdown
  - `comments: []`（行コメントは使わない）
- PR 検出は `mcp__plugin_github_github__list_pull_requests` を `owner`, `repo`（上記と同様に origin から取得）, `head: <branch>`, `state: "open"` で呼ぶ（Phase 0 の対象判別で実施）。現在ブランチは `git rev-parse --abbrev-ref HEAD` で取得する

### 投稿本文テンプレート

````markdown
<!-- claude-code-review:code-reviewer-adversarial -->
> 🤖 Generated by `/code-reviewer-adversarial` — <ISO8601 タイムスタンプ>

## Adversarial Review 結果

{Phase 3 の最終出力をそのままコピーして貼る。サマリ / 🚫 真の欠陥 / ❓ 仕様未定 / 📉 低優先度 / 🔇 ノイズ / 💡 修正推奨の順序}

---
_このレビューは Claude Code プラグイン `mjc-code-develop-tools` が生成しました。approve / request_changes 判断は含みません。_
````

- 識別マーカー `<!-- claude-code-review:code-reviewer-adversarial -->` は必ず先頭に入れる（HTML コメントなので PR 表示上は不可視）
- ローカル表示と PR 投稿は同じ本文を使い回す（二重生成しない）

### 確認ゲート

投稿前に必ず `AskUserQuestion` で以下を出す:

- 質問文: `"PR #<番号> にこのレビュー内容を投稿しますか？（投稿先: <PR タイトル>）"`
- 選択肢: `[投稿する]` / `[投稿しない]` / `[本文を修正してから投稿]`

「本文を修正してから投稿」を選んだ場合、ユーザーに修正指示を求め、本文を再生成して再度確認ゲートに戻る。修正ループは最大 3 回、超えたら投稿を中止する。

### 成功・切り詰めの表示

- 成功: `✅ レビューを投稿しました: <Review URL>` を 1 行表示
- 本文が 65,536 文字を超える場合: 反例テストコード等を `<details>` で折りたたむ、もしくは末尾を切り詰めて「以降は省略（ローカル出力を参照）」と明記する。切り詰めが発生したら `⚠️ 本文が長すぎたため末尾を切り詰めました。完全版はローカル出力を参照してください` を併記する

### フォールバック

| ケース | 挙動 |
|---|---|
| GitHub MCP ツール未接続 | 書き出しモード無効化。Phase 0 ゲート出力に理由を明示し、レビュー処理は通常実行 |
| 対象ブランチの open PR が 0 件（引数省略時）| 書き出しモード無効化。エラーにしない |
| 対象ブランチの open PR が複数 | `AskUserQuestion` で PR 番号を選ばせる（「書き出し不要」選択肢も出す）|
| 指定 PR 番号が存在しない / アクセス権なし | 書き出しモード無効化し理由を明示、レビュー処理は続行 |
| Judge（Phase 2）呼び出し不能 | 書き出しモード自動無効化（詳細: Phase 2 の `#### Judge 呼び出し不能時のフォールバック` を参照）|
| 投稿権限 403 等 | 失敗メッセージを 1 行表示、ローカル出力は残す |
| API 一時エラー | 1 回だけリトライ、再失敗で諦めて手動投稿を案内 |
| 確認ゲートで「投稿しない」 | 正常終了、ローカル出力のみ |
| 修正ループ 3 回超 | 投稿中止、最後の本文をローカルに残す |

原則: **PR 書き出しが失敗してもレビュー処理自体は止めない**。エラーメッセージは 1〜2 行でチャットに出し、追加の `AskUserQuestion` は出さない。

## やらないこと

- 実装の書き直し（最小反例と修正案までに留める）
- 可読性・命名レベルの指摘（`/code-reviewer` の役割）
- 感想・一般論（反証可能な指摘のみ）
- Builder（実装者）との対話ループ（このスキルの入力は実装済みコードのみ。対話は呼び出し元の責務）

## 原則

- **壊すレビューに寄せる**: 読むレビューではない。反例が出ない指摘は弱く扱う
- **共犯化を避ける**: Breaker（Claude）と Judge（Codex）は別系統モデル。両者が同意した指摘を優先する
- **ゲーム化を防ぐ**: Judge の好みに合わせてコードを書く方向に最適化されないよう、裁定基準は固定スキーマで運用する
- **仕様の不在は自覚する**: 仕様が曖昧なら「仕様未定」として分離し、無理に欠陥判定しない

## 使い分け

- 通常レビュー・コミット前セルフレビュー → `/code-reviewer`
- 重要変更（認証 / 認可 / 決済 / スキーマ / 外部 API）・最終ゲート・高コスト領域 → `/code-reviewer-adversarial`

通常フローの「最終ステップで Codex レビュー」は、このスキルを使う場合 Judge 呼び出しが相当する。別途追加の Codex レビューは不要。
