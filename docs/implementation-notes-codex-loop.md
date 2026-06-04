# implementation-notes: smart-issue-plan / smart-issue-resolve への `-codex-loop` オプション追加

> 作業ブランチ: `feature/add-codex-loop-option`（2026-06-04）/ PR: #60
> `-codex-loop` 実装時の設計判断・トレードオフ・Codex レビュー記録

## 仕様（ユーザー要求 + AskUserQuestion での確定事項)

- オプション名は `-codex-loop`（ハイフン 1 つ。当初の `--codex-loop` から修正指示あり）
- Claude の作業完了後に Codex レビューへ回し、採用すべき指摘がなくなるまでループ → 収束後に Issue へのプラン投稿 / PR 作成。投稿物に Codex レビュー済みであることを記載
- Codex 呼び出し: `codex:rescue` 直接（専用依頼テンプレート）
- ループ上限: 3 ラウンドで未収束なら AskUserQuestion（続行 / 打ち切り / 中止）
- 収束後は承認ゲートなしで自動投稿 / 自動 PR 作成（オプション指定を事前オプトインとみなす）
- PR 作成は smart-commit → smart-pr の Skill 呼び出しで実施。呼出時に「承認省略可・安全系ゲートは維持」を明示指示

## 仕様に明記されていなかったため自分で判断した事項

1. **採用判定の基準**: グローバル CLAUDE.md の Code Review Feedback 原則（妥当性確認・オーバーエンジニアリング排除）をループ手順 2 に内蔵した。不採用には理由 1 行を記録する
2. **codex:rescue 不能時のフォールバック**: `code-reviewer-adversarial` の確立済み原則を踏襲 — Claude が模擬レビューを代行しない。通常フロー（承認ゲートあり）に切り替え、レビュー済み表記は付けない
3. **打ち切り時の表記**: 「未収束で打ち切り」と正直に記載する（収束時と区別: `🤖 Codex レビュー済み（N ラウンド、最終ラウンド採用指摘 0 件）` vs `🤖 Codex レビュー実施（N ラウンド、未収束で打ち切り）`）
4. **依頼テンプレートの配置**: `judge-prompt.md`（code-reviewer-adversarial）と同パターンで各スキルの `assets/codex-review-prompt.md` に切り出し。npx 配布はスキル単位で自己完結のため共有せず各自同梱
5. **resolve のレビュー対象**: diff を依頼文に貼り込まず、Codex 自身に `origin/<デフォルトブランチ>...HEAD` + working tree を確認させる（グローバル CLAUDE.md「diff 基準は origin/main...HEAD と明示」の知見を反映。巨大 diff のコンテキスト圧迫も回避）
6. **plan の手順 3（出力先確認）は維持**: フロー冒頭の対話なので自動化の妨げにならないと判断
7. **smart-pr の behind マージ確認・競合対応は承認省略の対象外**: 履歴を書き換えうる操作のため通常どおりユーザー確認を維持
8. **更新モード（plan 手順 8）にも適用**: 8b 再評価後にループ、8c の承認ゲートをスキップ
9. **手順番号は振り直さない**: ループは独立セクション「## Codex レビューループ（-codex-loop）」とし、手順 5/6/7/8 から参照する形にした（既存の手順番号への参照を壊さないため）
10. **allowed-tools に `Skill` を追加**: codex:rescue / smart-commit / smart-pr の呼び出しに使用するため（両スキル）

## トレードオフ（採用 vs 却下）

| 論点 | 採用 | 却下案と理由 |
|---|---|---|
| Codex 呼び出し | codex:rescue 直接 + 専用テンプレ | code-reviewer-adversarial 経由 — plan（コード以外）に使えず二方式が混在する |
| サブスキル承認ゲート | 呼出時にスキップ指示（安全系は維持） | smart-commit / smart-pr への `-y` オプション正式追加 — 改修範囲が 4 スキルに拡大 |
| ループ詳細の配置 | SKILL.md 内セクション + assets/ テンプレ | references/ への全切り出し — オプション機能でありフェーズスキップ防止ゲートは不要、行数も 210/198 で余裕 |

## ユーザーが把握しておくべきこと

- `-codex-loop` なしの挙動は完全に従来どおり（変更なし）。smart-commit / smart-pr 本体は無変更
- `-codex-loop` は Claude Code + Codex プラグイン環境前提（クロスツール配布では graceful degradation: フォールバックで通常フローに切り替わる）
- resolve の「push はしない」原則に `-codex-loop` 例外を明記した（注意事項参照）

## Codex レビュー記録（1 ラウンド・採用 2 / 不採用 0）

1. **Medium — サブスキル承認ゲートとの衝突**: 採用。resolve SKILL.md の「収束後のコミット・PR 作成」を「`-codex-loop` 指定をサブスキルの承認ゲートが要求するユーザー承認（事前オプトイン）として扱う。計画・内容は提示のみ・応答待ちなし」に修正し、意味論の衝突を解消（サブスキル本体は無変更の方針を維持）
2. **Low — 「最大 3 ラウンド」表現の不一致**: 採用。停止規則の実態「3 ラウンドごとにユーザー確認」に README・SKILL.md 双方を統一

## 追補: Codex silent death 対応の運用ノート（ユーザー調査結果の反映）

ユーザーによる障害調査（companion レジストリが running のまま `updatedAt` 固定 / 実プロセス死亡 / transcript が reasoning 途中で途切れる silent death）を受け、`codex:rescue` を呼ぶ 3 箇所に「運用ノート: silent death からの復旧」を追加:

- `skills/smart-issue-plan/assets/codex-review-prompt.md` / `skills/smart-issue-resolve/assets/codex-review-prompt.md` / `skills/code-reviewer-adversarial/assets/judge-prompt.md` — 検知（stall 3 条件）→ 回収（rollout transcript 末尾確認）→ 復旧（cancel → `task-resume-candidate` 復活 → `--resume` 再投入）→ 予防（timeout 600000ms 明示・`--background` 検討）の 4 段
- 各 SKILL.md のフォールバック節に「ハング時はまず復旧を試み、復旧 2 回で完了しなければフォールバック」のゲート行を追加（即諦めて Codex レビューなしに切り替わるのを防ぐ）

判断: code-reviewer-adversarial は本 PR のスコープ外の既存スキルだが、同一の Codex 連携経路を持ち同じ障害に当たるため、同 PR に含めた（PR 本文に明記）。CLAUDE.md（グローバル）には stall 判定・transcript 回収が記載済みのため、スキル側には差分（resume フロー・timeout）のみ追加。

### Codex レビュー 2 ラウンド目（増分レビュー・採用 3 / 不採用 3）

- **Medium × 3（採用）**: 「呼び出し成功後のハング」と「呼び出し不能環境」が同一フォールバックブロックに混在 → 3 スキルのフォールバック節を「利用不能時」に改名し、発動条件を「呼び出し不能 / 復旧不能なハング」の 2 項目に明示分離（参照箇所・README・judge-prompt.md 内セクション名も追従）
- **Low × 3（不採用）**: companion 挙動が diff 単体で検証不能 → 一次情報はユーザーの実地調査（resume 復旧の成功実績）と companion forwarder の実装契約（task-resume-candidate / --resume）で検証済みのため

## 検証

- `npx skills add ./ --list` で両スキル検出・更新後 description 反映を確認
- SKILL.md 行数: plan 210 行 / resolve 198 行（500 行制限内）
- frontmatter: `disable-model-invocation: true`・`allowed-tools`・`argument-hint` 更新を確認
- シェルスクリプト変更なし（`bash -n` 対象なし）
- 実行テスト（実 Issue でのループ動作）は未実施 — GitHub への副作用（コメント投稿・PR 作成）を伴うため、サンドボックス Issue での動作確認を推奨
