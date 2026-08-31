# worktree 作業時の作業ディレクトリ永続化（2026-08-31）

## 背景

`smart-issue-resolve --worktree`（`-wt`）で作業しているとき、エージェント間の引き継ぎファイル（`context.md` / `impl-notes.md` / `diff.md` / `findings-round-*.md`）は `mktemp -d "${TMPDIR:-/tmp}/sir-issue-<番号>.XXXXXX"` に置かれていた。macOS の `/tmp`（`$TMPDIR`）は端末の再起動で消えるため、レビューループの途中で再起動すると作業ファイルが失われる。

## 決定

作業ディレクトリの配置を「いま操作している作業ツリー」で分岐させた。

| 状況 | `{作業Dir}` |
| --- | --- |
| linked worktree の中（`-wt` で作った / 既にその中にいる） | `{worktreeパス}/.smart-issue-work/<resolve\|plan>-issue-<番号>/` |
| メイン作業ツリー（既定） | 従来どおり `mktemp -d "${TMPDIR:-/tmp}/..."` |

判定は `git rev-parse --git-dir` と `git rev-parse --git-common-dir` の**出力が異なるか**で行う（linked worktree では前者が `<共有.git>/worktrees/<名前>`、後者が `<共有.git>`。メイン作業ツリーではどちらも `.git`）。当初は `--show-toplevel` とメインルート（`git worktree list --porcelain` の先頭エントリ）の文字列比較にしていたが、`/tmp` と `/private/tmp` のようなパス正規化差で「メイン作業ツリー」と誤判定し、**静かに `/tmp` 配置へ戻る**（今回直そうとしている不具合そのものが無言で再発する）ため、正規化に依存しない git-dir 比較に変えた。`{worktreeパス}` の取得自体は `git rev-parse --show-toplevel` で行う。

git 汚染対策として、作成前に `git check-ignore -q .smart-issue-work/` を確認し、無視されていなければ `$(git rev-parse --git-common-dir)/info/exclude` に `.smart-issue-work/` を追記する（追跡対象の `.gitignore` は触らない）。これは既存の `.claude/worktrees/` 登録と同じ手法。

## 仕様に明記されていなかったため判断した事項

- **ディレクトリ名を `.sir-work/` ではなく `.smart-issue-work/` にした**: plan も同じ規則を使うため skill 略称を含めない中立名にし、`info/exclude` のエントリを 1 本で済ませた。スキルの区別はサブディレクトリ（`resolve-issue-<N>` / `plan-issue-<N>`）で行う。
- **既存ディレクトリを黙って再利用しない**: 前セッションの `diff.md` が残ると、レビュー役の鮮度ガード（`diffRound` の期待スタンプ）が前ラウンドのスタンプと一致して古い diff をレビューしてしまう。worktree 既存時（手順 5-3）と同じく「再利用 / 作り直し」をユーザーに確認する。
- **メイン作業ツリーでは `/tmp` のまま**: リポジトリ直下に置くと永続はするが誰も掃除しない（worktree と違い削除イベントが無い）。ユーザーの「作業が終われば worktree ごと消えるので残骸は残らない」という前提が成立するのは worktree 内だけなので、メイン作業ツリーは従来の揮発領域に据え置いた。
- **削除手順はスキルに持たせない**: リポジトリ規約（破壊的コマンドを手順に含めない）に従い、worktree 内は `/smart-git-sync` の `git worktree remove`、`/tmp` は OS に任せる。

## 仕様から変更・調整した内容

**`smart-issue-plan` に `-wt` フラグは追加しなかった**（ユーザーの当初指定からの変更）。plan はブランチを作らず作業ツリーも変更しないため `-wt` に隔離すべき対象がなく、detached worktree を作ると `/smart-git-sync` のブランチ基準クリーンアップから漏れて残骸になる。代わりに上記の共通ルールで**自動追従**させた。結果として、`-wt` で作った worktree の中で plan を回す場合は永続化されるが、メイン作業ツリーから `/smart-issue-plan #42` を実行する通常ケースは従来どおり `/tmp` のままである（この非対称は設計提示時にユーザーへ明示し、承認を得た）。

新フラグを足していないため、CLAUDE.md が定める `smart-spec-to-pr` の転送語彙の同期は不要。`smart-spec-to-pr` 自身の `{作業Dir}` も現状維持（`-wt` を持たないため）。

## 実測して確認したこと

scratch リポジトリ（main + linked worktree）で以下を確認した。`smart-git-sync/SKILL.md` の記述に依存せず git の実挙動を直接確認している:

1. `info/exclude` に `.smart-issue-work/` を追記した状態で worktree 内にファイルを置くと、`git status --porcelain --untracked-files=all` は無出力（→ `gen-diff.sh` の未追跡ファイル一覧にも出ずレビュー対象 diff を汚さない）
2. `git check-ignore -q .smart-issue-work/` が成功する（無視されている）
3. `git worktree remove <path>`（`--force` なし）が成功し、作業ファイルごとディレクトリが削除される（→ 残骸が残らないというユーザーの前提が成立する）
4. worktree 内の `.smart-issue-work/resolve-issue-1/` から `gen-diff.sh` を 2 回実行（`diff.md` が既に存在する状態を含む）しても、生成された `diff.md` に `smart-issue-work` の文字列は現れない — 未追跡ファイル一覧は空、`UNCOMMITTED DIFF` には変更した追跡ファイルのみ。作業ディレクトリが「計測対象のツリーの内側」に移った唯一の経路なので、推論ではなく実測で確認した
5. 判定コマンドの実挙動: linked worktree では `--git-dir` = `<main>/.git/worktrees/wt-b`・`--git-common-dir` = `<main>/.git` で相違、メイン作業ツリーでは両方 `.git` で一致。同条件で `--show-toplevel` はメインルートと異なる値を返すため判定自体は成立するが、パス正規化差に対する頑健性で git-dir 比較を採用した

## 下流リポジトリの実測知見の反映

`bs-vto-app-event-display`（本スキル群のヘビーユーザー）の CLAUDE.md「Harness Guardrails」に、同じ問題を踏んだ実測記録があった。以下を設計・実装へ取り込んだ。

- **今回の変更の妥当性を裏付ける記録**: 「scratchpad はマシン再起動で消える」（#1364 のレビューループで context.md / impl-notes.md / gen-diff.sh / 検証スクリプト 3 本が消失し、以降 2 ラウンドが情報の欠けた状態で走った）、「scratchpad はセッションの切り替えでも消える（パスが session-id 単位のため）」。worktree 内配置はこの両方を解消する。
- **`.claude/` 配下に置かない理由が実測で裏付けられた**: sandbox 有効プロジェクトは `sandbox.filesystem.denyWrite` に `.claude` を入れているのが通例（同リポジトリで確認）。`git apply` が `.claude/*` を含む patch で中断する、`.claude/worktrees/` 配下の worktree では `git restore` が全ファイルで `Operation not permitted` になる、といった記録がある。当初の選択肢だった `.claude/sir-work/` を採らず worktree 直下の `.smart-issue-work/` にしたのは結果的に正しかったため、理由を SKILL.md に明記した。
- **`gen-diff.sh` の `mv` を修正（実装変更）**: 上記の環境では「書き込みは許可されるが既存ファイルの unlink は拒否される」挙動が観測されている。`{作業Dir}` を worktree 内へ移したことで、`mv "${TMP}" "${OUT}"`（rename は宛先の unlink 相当）がラウンド 2 以降で失敗しうる。`mv` 失敗時に切り詰め書き込み（`cat "${TMP}" >"${OUT}"`）へ退避する分岐を追加した。`mv` を必ず失敗させるスタブを PATH に置いて実測し、既存 diff.md が完全に置き換わることを確認済み。
- **worktree 隔離セッションの Bash 制約**: `$TMPDIR` / `$PWD` / `$(...)` などパスに解決される展開が「too complex to verify that it stays inside the worktree」で拒否されることがある（`mktemp -d "${TMPDIR:-/tmp}/x.XXXXXX"` が通らない実例）。`info/exclude` への追記や `-C` 指定は値を先に取得してリテラル絶対パスで書く旨を SKILL.md に追記した。
- **永続の範囲を明示**: 「worktree の未コミット作業はセッション終了時に消えうる（最重要）」（#1049 でレビュー 16 ラウンド分を喪失）。worktree 内配置が守るのは再起動・セッション切替であって worktree 削除ではない。長時間ループでは各セット終了時の WIP コミット、恒久的な判断記録は `docs/implementation-notes/` へ、という運用を SKILL.md に併記した。
- **フォールバック経路を明文化**: sandbox で作成・書き込みが拒否された場合は従来の揮発領域へ退避し、その旨をユーザーに伝える（黙って失敗させない）。

なお同リポジトリの記録には、本 PR のスコープ外だが本スキルに関わる既知の問題も含まれている（手順 5 の手動 `git worktree add` は `.env.example` の checkout が `Operation not permitted` になり worktree ごとロールバックされる。`EnterWorktree` に worktree 作成自体を任せる方が sandbox の書き込み許可リストに自動登録される分だけ確実、という指摘）。別 Issue として扱う。

## 変更ファイル

- `skills/smart-issue-resolve/SKILL.md` — 手順 6-2（配置ルール・sandbox フォールバック・永続範囲の明示）・完了報告テンプレート（作業ファイルのパス併記）
- `skills/smart-issue-resolve/assets/gen-diff.sh` — 既存 diff.md の置き換えで `mv` が失敗した場合に切り詰め書き込みへ退避
- `skills/smart-issue-resolve/references/agent-orchestration.md` — 作業ディレクトリの説明
- `skills/smart-issue-resolve/README.md` — `--worktree` の説明・処理の流れ
- `skills/smart-issue-plan/SKILL.md` — claude 系「準備」手順 1（配置ルール）
- `skills/smart-issue-plan/references/agent-orchestration.md` — 作業ディレクトリの説明
- `skills/smart-issue-plan/README.md` — `-wt` が無いこと / worktree 内実行時の挙動を注記
- `skills/smart-git-sync/SKILL.md` — ignore 済みファイルが worktree 削除で消える既存の注意書きに、`.smart-issue-work/` は意図どおりである旨を追記
- `CLAUDE.md` — `{作業Dir}` の配置規則（resolve / plan 間の同期対象として明記）
