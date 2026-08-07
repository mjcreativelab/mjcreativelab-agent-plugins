---
name: disk-space-cleanup
description: ディスク空き容量の確保。開発系キャッシュ（npm/Docker/brew/Xcode 等）をスキャンし、削除可能な理由とリスクを添えてリストアップ → ユーザー確認後に削除。macOS / Linux 対応。「ディスクが足りない」「容量を空けたい」「/disk-space-cleanup」で起動。
argument-hint: "[-p <観点・追加調査パス>]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

# Disk Space Cleanup

使用端末のディスク空き容量を確保する。開発系キャッシュを読み取り専用でスキャンし、削除して良い理由とリスクを添えてリストアップ → ユーザー確認後に削除する。

## 引数の解析

`$ARGUMENTS` を解析する:

- `-p <プロンプト>`: 調査観点・追加調査パスの指定（例: `-p ~/Downloads も見て`）。`-p` より後を `{観点}` とする
- `-p` がない場合 → `{観点}` は空

`{観点}` で事前定義カテゴリ外のパスが指定された場合、**調査・提示まで**は行うが、削除はユーザーの明示指示がない限り行わない。

## フロー

### Step 1: before スナップショット

`df -h` と `df -i` を実行し、現在の空き容量・inode 使用状況を記録する。

**inode 枯渇の兆候チェック**: 見える範囲のフォルダサイズ合計が `df -h` の実使用量と大きく乖離する場合（例: 目視できるフォルダを全部足しても実使用量の一部にしかならない）、`df -i` の inode 使用率を確認する。個人開発機で inode 使用数が数百万件を大きく超える場合、`uv cache` 等のハードリンク/clonefile 系キャッシュに大量の小ファイル・隔離環境が蓄積している可能性が高い（詳細は [references/cleanup-targets.md](references/cleanup-targets.md) の「既知の注意点」）。

### Step 2: スキャン

[assets/scan-disk-usage.sh](assets/scan-disk-usage.sh) を `bash` で実行する。出力は以下の形式:

- `CANDIDATE<TAB>カテゴリ<TAB>パス<TAB>サイズ<TAB>削除方法` — 削除実行の候補（Step 4 の選択肢）
- `PRESENT_ONLY<TAB>カテゴリ<TAB>対象<TAB>提示コマンド` — 提示のみ（Docker volumes・sudo 必要な Linux 領域）。**Step 4 の選択肢に含めず、Step 5 でも実行しない**
- `SKIP<TAB>カテゴリ<TAB>理由` — ツール不在・OS 非対象・取得失敗（silent skip しない）
- `DOCKER_DF_*` / `DOCKER_PS_*` / `BREW_DRYRUN_*` / `CACHE_TOP_*` / `TRANSCRIPT_CLAUDE_*` / `TRANSCRIPT_CODEX_*` — 補助ブロック
- 最終行 `SCAN_COMPLETE`

「削除方法」列は表示用ヒント。実際のパスは独立した `パス` フィールドにあり、`rm` を組み立てる際はそちらを使う（コマンド列の文字列をそのまま実行しない）。

### Step 3: リストアップ

[references/cleanup-targets.md](references/cleanup-targets.md) と突合し、削除候補をサイズ降順テーブルで提示する。

列: **カテゴリ / パス / サイズ / 削除して良い理由 / リスク / 復元可否 / 削除コマンド**

- `パス` 列は scan 出力の `パス` と対応させる
- Docker 停止コンテナは `DOCKER_PS_*` ブロックの名前・作成日時・サイズの内訳を提示する
- `PRESENT_ONLY` 行は別セクション「提示のみ（手動実行）」としてコマンドを表示する（削除候補テーブルには載せない）
- `SKIP` 行は末尾に要約表示する（「未対象: npm 未インストール, …」）

scan の `カテゴリ` 値（`npm cache` / `pnpm store` / `yarn cache` / `pip cache` / `go cache` / `cargo registry` / `uv cache` / `Docker build cache` / `Docker dangling images` / `Docker stopped containers` / `Homebrew cleanup` / `Xcode DerivedData` / `Xcode iOS DeviceSupport` / `unavailable simulators` / `Trash` / `Claude Code transcripts` / `Codex session transcripts`）は [references/cleanup-targets.md](references/cleanup-targets.md) の「scan カテゴリ」列と一致する。これを使ってリスク・復元可否を引く。

`uv cache` 等のハードリンク/clonefile 系キャッシュは、`du` のサイズ表示が実ディスク容量を超える異常値を返すことがある（[references/cleanup-targets.md](references/cleanup-targets.md) 既知の注意点を参照）。この値は参考情報として提示するに留め、「削除して解放される容量」の根拠としては使わない（根拠は Step 6 の before/after `df` 差分）。

トランスクリプトカテゴリは `TRANSCRIPT_CLAUDE_BEGIN` / `TRANSCRIPT_CODEX_BEGIN` 補助ブロックを使って詳細を表示する。ブロック内の値は `総ファイル数<TAB>総サイズ<TAB>7日以前のファイル数<TAB>7日以前のサイズ` の形式。削除候補テーブルではサイズ列に「合計 X MB（うち 7 日以前: Y ファイル / Z MB）」の形式で補足する。

### Step 4: 承認ゲート（カテゴリ単位）

削除するカテゴリをユーザーに選択させる。

- Claude Code では `AskUserQuestion`（multiSelect）を使う。他エージェントではテキストで「削除するカテゴリ番号を挙げてください」と確認する（graceful degradation）
- リスク「中」のカテゴリは**デフォルト非選択**
- **選択が 0 件（全キャンセル）の場合は何も削除せず Step 6 のレポートへ進む（no-op 終了）**
- **トランスクリプトカテゴリが選択された場合、保持日数を追加で確認する**（AskUserQuestion single-select / 選択肢: `7 日（推奨）` / `14 日` / `30 日` / `全削除（0 日）`）。確認した日数を `{N}` として Step 5 で使用する。

### Step 5: 実行

承認済みカテゴリを 1 つずつ処理し、都度結果を確認する。承認は Step 4 のカテゴリ選択が唯一の承認であり、単一パス・単一コマンドのカテゴリでは再承認を求めない。例外は次の 2 つで、いずれも**実行直前に対象を再表示して個別の最終確認**を挟む:

- **(a) 複数パスを束ねたカテゴリ**（複数ツールのキャッシュ束・`Caches`/`.cache` 上位 10 サブディレクトリ等）: パス単位で削除対象を選択・除外できるようにする
- **(b) 復元不能操作（ゴミ箱を空にする）とリスク「中」カテゴリ**: 個別の最終確認を必須とする

公式クリーンコマンドがあるカテゴリは [references/cleanup-targets.md](references/cleanup-targets.md) の「削除方法」列のコマンドを実行する。

#### トランスクリプトカテゴリの実行ルール

`Claude Code transcripts` / `Codex session transcripts` は `find -delete` で処理する（`rm` ルールは適用しない）:

- `{N}` = Step 4 で確認した保持日数。全削除（0 日）の場合は `-mtime +0` ではなく `find <path> -name "*.jsonl" -delete` で全件削除する
- 実行コマンド（N 日保持）:
  ```
  find <path> -name "*.jsonl" -mtime +{N} -delete
  find <path> -type d -empty -delete   # Codex のみ: 空ディレクトリを掃除
  ```
- 実行直前に削除対象ファイル数・サイズを再表示する（`find <path> -name "*.jsonl" -mtime +{N} | wc -l` と `xargs du -ch | tail -1` で確認）
- 失敗した場合は再試行せず Step 6 に記録する

#### `rm` 実行ルール

公式コマンドがないカテゴリ（DerivedData 等）で `rm` を使う場合:

- 形式は `rm -rf -- <フルパス>` に固定（`--` 区切り必須・変数展開やワイルドカード禁止）
- 対象は cleanup-targets.md で定義された既知パス、またはその直下のサブディレクトリのみ
- `/`・`$HOME` そのもの、および `$HOME` 直下のディレクトリ丸ごと（`~/Documents` 等）を対象にしない
- 対象パスが symlink の場合は削除せずスキップして報告する
- 権限エラーが出た場合は **sudo を提案せず**、スキップして報告する
- 実行直前に対象パスを再表示する
- 失敗したカテゴリは再試行せず、失敗内容を Step 6 のレポートに記録する
- **ファイル数が極端に多いカテゴリ（`uv cache` 等）は削除に数十分〜数時間かかる場合がある**: バイト数ではなくファイル数（unlink 回数）がボトルネックになるため、事前にこの可能性をユーザーに伝える。バックグラウンド実行にし、都度の進捗確認は残りサブディレクトリ数や `df -i` の inode 空き数の推移で行う（完了を待つ間、他の作業を止める必要はない旨を伝える）

「提示のみ」カテゴリ（Docker volumes・sudo 必要な Linux 領域）は**コマンドを提示するだけ**で、スキルからは実行しない。

### Step 6: after レポート

`df -h` と `df -i` を再実行し、レポートを出力する:

- 解放容量サマリ（before → after、空き容量・inode 空き数の両方）— `uv cache` 等 `du` サイズが信頼できないカテゴリを削除した場合は特にこの実測差分を根拠とする
- 実行した削除コマンド一覧
- 失敗・スキップした項目とその理由
- 削除処理がバックグラウンドで継続中（Step 5 の長時間カテゴリ）の場合はその旨を明記し、完了確認の方法（再度 `df -h`/`df -i` を確認する等）を伝える

## 安全設計（要約）

- 削除は承認カテゴリのみ。スキャンスクリプトに破壊的コマンドは含まれない
- 削除対象は cleanup-targets.md の既知パスのみ。ユーザーデータ領域（`~/Documents`・`~/Desktop`・クラウド同期ディレクトリ・dotfiles・アプリ設定）は対象にしない
- sudo が必要な領域は「提示のみ」。権限エラー時も sudo を提案しない
