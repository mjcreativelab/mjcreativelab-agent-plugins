# 削除候補カテゴリ表

scan-disk-usage.sh の `CANDIDATE` 行と突合して使う。各行の「削除して良い理由」が SKILL.md Step 3 の理由提示の根拠。

## 削除実行の対象（承認後にスキルが実行する）

`scan カテゴリ` 列が scan-disk-usage.sh の `CANDIDATE` 行のカテゴリ値と一致する。

| scan カテゴリ | 削除方法 | リスク | 復元可否 | 削除して良い理由 |
|---|---|---|---|---|
| `npm cache` / `pnpm store` / `yarn cache` / `pip cache` / `go cache` | 各公式 clean コマンド（npm cache clean --force ほか） | 低 | 再取得可 | ネットワーク接続時に再取得・再生成される。オフライン環境・社内 proxy 配下では再取得に制約がある点を注記 |
| `cargo registry` | 公式 clean コマンドなし → SKILL.md の `rm` ルールで削除 | 低 | 再取得可 | registry キャッシュは再取得可能（オフライン環境では再取得に制約あり） |
| `uv cache` | `uv cache prune`（未使用エントリのみ安全に削除）。サンドボックス環境で `uv` コマンド自体が panic する場合、または極端な肥大化（下記注記）で prune では追いつかない場合は SKILL.md の `rm` ルールで対象パス（`uv cache dir` 出力、取得不可なら `~/.cache/uv`）を直接削除する | 低 | 再取得可 | `uv` はパッケージ・ビルド成果物・隔離仮想環境（`environments-v2/` 等）を**自動削除しない設計**。無関係な複数プロジェクト・複数 Python バージョンでの利用が積み重なると際限なく肥大化する（実例: inode 使用数 1 億 3500 万件超、`du` 換算で物理ディスク容量を超える値まで到達）。再取得はネットワーク接続時のみ |
| `Docker build cache` / `Docker dangling images` | `docker builder prune` / `docker image prune` | 低 | 再生成可 | どのタグからも参照されていない中間生成物。削除後の初回ビルドは遅くなる |
| `Docker stopped containers` | `docker container prune` | 中 | 不可 | 停止中でも再利用予定がある場合がある。Step 3 で名前・作成日時・サイズの内訳を提示 |
| `Homebrew cleanup` | `brew cleanup -s` | 低 | 再取得可 | 旧バージョンと DL キャッシュは再取得可能（旧バージョンへの rollback はしにくくなる） |
| `Xcode DerivedData` | SKILL.md の `rm` ルール | 低 | 再生成可 | ビルド時に再生成される |
| `Xcode iOS DeviceSupport` | SKILL.md の `rm` ルール（古いバージョンを個別に） | 中 | 困難な場合あり | 接続時に再取得されるが、古い iOS・実機のシンボルは再取得が困難な場合がある |
| `unavailable simulators` | `xcrun simctl delete unavailable` | 低 | 再生成可 | 現行 Xcode で利用不能なランタイムの残骸 |
| ユーザーキャッシュ上位 10（`CACHE_TOP_*` ブロック。macOS: `~/Library/Caches` / Linux: `~/.cache` 直下） | SKILL.md の `rm` ルール | 中 | 再生成可 | アプリキャッシュは再生成されるが一部アプリで再ログイン等が必要。パス単位で選択・除外する |
| `Trash`（macOS: `~/.Trash` / Linux: `~/.local/share/Trash`） | 承認後に中身を削除 | 中 | **不可** | ユーザーが既に削除したファイルだが、空にすると復元不能。実行直前の個別最終確認を必須とする |
| `Claude Code transcripts` | `find ~/.claude/projects -name "*.jsonl" -mtime +{N} -delete`（N = 保持日数） | 低 | 不可 | セッション履歴ログ。削除後の開発作業への影響はないが復元不能。`-c`/`-r` 再開時に古いセッションが消える点を注記する |
| `Codex session transcripts` | `find ~/.codex/sessions -name "*.jsonl" -mtime +{N} -delete && find ~/.codex/sessions -type d -empty -delete`（N = 保持日数） | 低 | 不可 | Codex タスクのロールアウトログ。削除後の開発作業への影響はない。空ディレクトリも合わせて掃除する |

## 提示のみ（`PRESENT_ONLY` 行・スキルは実行しない）

| scan カテゴリ | 提示するコマンド | 実行しない理由 |
|---|---|---|
| `Docker volumes` | `docker volume ls` で確認 | データ消失リスクが高い |
| `apt cache` / `dnf cache` / `pacman cache`（Linux） | `sudo apt-get clean` / `sudo dnf clean all` / `sudo pacman -Sc` | sudo が必要なため提示のみ |
| `systemd journal`（Linux） | `sudo journalctl --vacuum-size=200M` | sudo が必要なため提示のみ |

## 既知の注意点（uv cache 等のハードリンク/clonefile 系キャッシュ）

- **`du` のサイズ表示が物理ディスク容量を超えることがある**: `uv`（および同様に APFS clonefile / ハードリンクでキャッシュを複数箇所にリンクするツール）は、キャッシュ本体とプロジェクトごとの venv とで同じ物理ブロックを共有する。`du` はこれを重複カウントするため、論理サイズが実ディスク容量を大きく超える異常値（例: 494GB のディスクで 1.7TB 相当）を返すことがある。この数値は**実際の解放見込み容量の根拠にしない**——削除前後の `df -h` 実測値の差分のみを信頼する。
- **inode 枯渇はディスク逼迫の隠れた主因になりうる**: 見える範囲のフォルダサイズ合計が `df -h` の実使用量と大きく乖離する場合、`df -i` で inode 使用率も確認する。個人開発機で数百万件を大きく超える inode 使用（例: 1 億件超）は、ハードリンク/clonefile 系キャッシュが大量の小ファイル・隔離環境を蓄積しているサインである。Step 1 の before スナップショットは `df -h` に加えて `df -i` も記録する。
- **削除（`rm -rf`）に数時間かかる場合がある**: ファイル数が極端に多いキャッシュ（`uv cache` の `archive-v0`/`environments-v2` 等、パッケージ展開物や隔離 venv を大量に含む）の削除は、バイト数ではなくファイル数（unlink 回数）がボトルネックになり、数十分〜数時間かかることがある。実行前にこの可能性をユーザーに伝え、バックグラウンド実行で進捗（残りサブディレクトリ数・`df -i` の inode 空き数の推移）を都度確認する運用にする。

## リスク区分

- **低**: 再取得・再生成可能。デフォルトで選択候補にしてよい
- **中**: 再生成可だが副作用（再ログイン・再取得困難・復元不能）あり。デフォルト非選択。実行直前に個別最終確認
- **高**: 対象外。提示のみ
