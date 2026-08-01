# smart-issue-resolve: -wt/--worktree オプション 実装ノート

- 日付: 2026-08-01（JST）
- 依頼: smart-issue-resolve スキルに、worktree での作業を指示する `-wt` / `--worktree` オプションを追加する
- 設計スペック: なし（口頭依頼をそのまま実装。実装前に advisor でアーキテクチャレビューを実施）
- 実行方法: メインセッションでの直接実装（brainstorming 等の別スキルは未使用。既存スキルへの小規模なオプション追加のため）

## 変更内容

- `skills/smart-issue-resolve/SKILL.md`:
  - frontmatter（description・argument-hint・`allowed-tools` に `EnterWorktree` を追加）
  - 「引数の解析」に `--worktree`/`-wt` の解析ルールを追加
  - 手順3（作業ツリーの状態確認）: `{worktree}` = true のとき stash 判定・退避を丸ごとスキップする分岐を追加
  - 手順5（ブランチ作成・チェックアウト）: `{worktree}` = true のとき `.claude/worktrees/<ブランチ名>` に `git worktree add` でブランチを作成し、`EnterWorktree({ path })` でセッションを切り替えるフローを追加
  - 手順7（完了案内）・「収束後のコミット・PR 作成」・「注意事項」: worktree パスの案内、`ExitWorktree` を本スキルからは呼ばない旨、`/smart-git-sync` へのクリーンアップ委譲を追記
- `skills/smart-issue-resolve/README.md`: 使い方・オプション表・フロー・関連スキル・前提条件を同期

## 仕様に明記されていなかったため自分で判断した事項

1. **`EnterWorktree` は常に `path` 指定で呼ぶ（`name` は使わない）**: `name` 指定での新規作成は「セッションが既に worktree にいる場合は使えない」という制約があるが、`path` 指定での切り替えはその制約を受けない。また `name` 指定は起点ブランチが `worktree.baseRef` 設定（既定 `fresh` = 最新の `origin/<デフォルトブランチ>`、`head` = 現在の HEAD）に依存し、環境のカスタム設定次第で本スキルの既存の「最新デフォルトブランチから分岐する」という前提が崩れうる。そこで常に `git worktree add ... origin/<デフォルトブランチ>`（または既存ブランチ）を自前で実行してから `EnterWorktree({ path })` で切り替える設計にした。挙動が設定に依存せず、非 worktree モードの手順5とロジックを揃えられる
2. **`ExitWorktree` は本スキルから呼ばない**: ツール自身の説明に「ユーザーが明示的に求めたときのみ呼ぶ」と明記されているため、完了時も呼ばずセッションを worktree に留める。完了案内で worktree パスと「元に戻るには `ExitWorktree({ action: "keep" })` か新規セッション」を明示することで代替した
3. **worktree・ブランチの削除は `/smart-git-sync` に委譲し、本スキルには実装しない**: `smart-git-sync` が直近（2026-07-31）で worktree 連携のクリーンアップ機能を実装済みのため、二重実装を避けて既存機能に一本化した
4. **worktree パスは `{メインルート}/.claude/worktrees/<ブランチ名>` に固定（メインルート起点）**: `EnterWorktree` が `path` で切り替え可能な worktree に課す制約（"the target must be a worktree under `.claude/worktrees/` of the same repository"）を満たすため。当初はカレントディレクトリからの相対パス `.claude/worktrees/<ブランチ名>` で書いていたが、セッションが既に別の linked worktree にいる場合は相対パスがその worktree 内に解決されてしまい、(a) 入れ子 worktree になり上記制約を満たせない、(b) linked worktree では `.git` がファイルであり `.git/info/exclude` への追記がそのまま失敗する、という 2 つの不具合を advisor 指摘で実機確認した。`git worktree list --porcelain | head -1` で得るメイン worktree の絶対パスを起点にし、除外ファイルの追記先も `git rev-parse --git-common-dir`（main tree・linked worktree のどちらからでも共有 `.git` を正しく指す）に切り替えて解消した
5. **`{作業Dir}`（レビュー・context.md 用の一時ディレクトリ）は worktree の有無に関わらず `mktemp` の OS 一時領域のまま**: worktree 内に置く設計も検討したが、レビュー成果物をコードの worktree に混在させない現行方針（`/tmp` 配下）をそのまま踏襲した方が、`{worktree}` = false のときと差分が生まれず単純
6. **`smart-spec-to-pr` の転送語彙同期はスコープ外**: CLAUDE.md の同期ルールは smart-issue-resolve のレビューループフラグ名（`-cdxrl` 等）に限定されており、`-wt` は対象外。ユーザーからの依頼も本スキル単体だったため、`smart-spec-to-pr` 側は今回変更していない（advisor 指摘を受けての明示的なスコープ判断）

## トレードオフの選択

- **`.git/info/exclude` へのローカル追記**: `git worktree add .claude/worktrees/<name>` は、対象リポジトリの `.gitignore` に `.claude/` 除外が無い場合、`.claude/` ディレクトリが `git status` に未追跡として現れる（実機検証で確認）。追跡対象の `.gitignore`（コミットされ他の開発者にも影響する）を勝手に書き換えるのは越権と判断し、ローカル限定の `.git/info/exclude`（正確には `git rev-parse --git-common-dir` が指す共有 `.git` の `info/exclude`）に `.claude/worktrees/` を追記する方式にした（既に無視されていれば `git check-ignore` で検知しスキップ）
- **既存ブランチの worktree 化が別ツリーで衝突する場合はエラーで停止**: `git worktree add` は対象ブランチが既に他の worktree（現在の作業ツリーを含む）でチェックアウト中だと失敗する。自動でリカバリ（強制解除等）はせず、「`-wt` を外すか、そちらの作業ツリー側で作業してください」と案内して停止する設計にした。ブランチの二重チェックアウト状態を無断で解消するのは safety 面で望ましくないため
- **Workflow エージェントの cwd 継承は事前に実機検証で確認**: Workflow エージェントが post-EnterWorktree の cwd を継承するかは未文書化だったため、使い捨ての worktree を作って 1 エージェントの Workflow（`pwd && git branch --show-current`）を実行し、オーケストレーターと同じ cwd・ブランチを返すことを確認してから実装した（継承されない場合は `references/agent-orchestration.md` の全雛形に cwd 明示指示を追加する必要があったが、不要と判明した）
- **worktree パスはメイン worktree 起点の絶対パスに固定**: 当初はカレントディレクトリからの相対パス `.claude/worktrees/<ブランチ名>` で書いていたが、セッションが既に別の linked worktree にいる場合に相対パスがその worktree 内へ解決されてしまい、(a) 入れ子 worktree になり `EnterWorktree` の「切り替え先は同一リポジトリの `.claude/worktrees/` 配下」という制約を満たせない、(b) linked worktree では `.git` がファイルであり `.git/info/exclude` への素朴な追記がそのまま失敗する、という 2 つの不具合を実機検証で確認した。`git worktree list --porcelain | head -1` で得るメイン worktree の絶対パスを起点にし、除外ファイルの追記先も `git rev-parse --git-common-dir`（main tree・linked worktree のどちらからでも共有 `.git` を正しく指す）に切り替えて解消した
- **`smart-spec-to-pr` の転送語彙同期はスコープ外**: CLAUDE.md の同期ルールは smart-issue-resolve のレビューループフラグ名（`-cdxrl` 等）に限定されており、`-wt` は対象外。ユーザーからの依頼も本スキル単体だったため、`smart-spec-to-pr` 側は今回変更していない（意図的なスコープ限定）

## 実装中に発見し修正した記述ミス

- `git check-ignore -q <path>` は、対象パスが `.gitignore`/`exclude` 側でディレクトリ限定パターン（末尾 `/`）にしか一致しない場合、**クエリ側にも末尾 `/` が無いと** ディレクトリが未作成の間は「無視されていない」と誤判定する（末尾 `/` を付けるか、配下のダミーファイルパスを渡せば未作成でも正しく判定できる）ことを実機検証で発見した。SKILL.md 手順5の当初案は `git check-ignore -q .claude/worktrees`（末尾 `/` 無し）だったため、worktree 未作成の初回実行時に必ず「無視されていない」と誤判定して不要な追記を行う欠陥があった。`git check-ignore -q .claude/worktrees/`（末尾 `/` 付き）に修正し、両パターン（付き/無し・ディレクトリ作成前後）を実機で再検証した
- ブランチ名にスラッシュを含むケース（本スキルの命名規則 `{type}/issue-{番号}-{説明}` の実際の形）を未検証のまま書いていた。`git worktree add -b feature/issue-1-x .claude/worktrees/feature/issue-1-x HEAD` を実機実行し、中間ディレクトリが自動作成されて正常に動作することを確認した（修正不要と判明）
- worktree モードの分岐（手順5）が `origin/<デフォルトブランチ>` から直接分岐するにもかかわらず、`git fetch` を明示していなかった。非 worktree モードは「デフォルトブランチを最新にしてから」という共通の前置き文がある一方、実際にリモート参照を更新するコマンドがどこにも書かれていなかったため、両モードに影響する前置き文自体に `git fetch` を明記する形で修正した（worktree モードでの「古い `origin/main` から静かに分岐する」という実害が大きいシナリオを解消）

## 検証

- `bash -n` 等の構文チェック対象なし（SKILL.md/README.md のみの変更）
- 実機検証（使い捨て worktree・使い捨て git リポジトリ）:
  - `EnterWorktree({ name })` → セッション cwd が worktree に切り替わることを `pwd`/`git branch --show-current` で確認
  - 上記 worktree 内で 1 エージェントの Workflow を実行し、エージェントの `pwd`/`git branch --show-current` がオーケストレーターと一致することを確認（cwd 継承の実証）
  - 本リポジトリで手動 `git worktree add .claude/worktrees/<name>` を実行し、`git status --porcelain` が汚染されないこと（本リポジトリは既存の `.git/info/exclude` により無汚染）を確認
  - 素の一時 git リポジトリ（`.git/info/exclude` に事前設定なし）で同じ手動 `git worktree add` を行い、`.claude/` が `git status --porcelain` に `?? .claude/` として現れることを確認（除外追記が必要なケースの再現）
  - `git worktree add -b <branch> <path> <commit-ish>`（新規ブランチ・スラッシュ含みブランチ名でも）・`git worktree add <path> <branch>`（既存ブランチ）・衝突時のエラーメッセージ（`fatal: '<branch>' is already used by worktree at '<path>'`）・`git check-ignore -q <path>/` の判定ロジックを、それぞれ使い捨て git リポジトリで個別に実行して SKILL.md 記載どおりに動作することを確認
  - linked worktree 内から `git worktree list --porcelain | head -1 | cut -d' ' -f2-` でメインルートを取得し、そこを起点に新規 worktree を作成すると（linked worktree の中に入れ子にならず）メインルート直下の `.claude/worktrees/` に正しく作られることを確認。`git -C "$ROOT" check-ignore -q .claude/worktrees/` と `$(git rev-parse --git-common-dir)/info/exclude` への追記も、linked worktree 内・main tree 内の両方から実行して動作することを確認
  - 検証用の worktree・一時リポジトリはすべて `ExitWorktree({ action: "remove" })` または `rm -rf` で後始末済み
- SKILL.md の行数: 379 行（500 行ガイドライン内）
