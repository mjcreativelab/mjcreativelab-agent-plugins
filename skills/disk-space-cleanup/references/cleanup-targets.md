# 削除候補カテゴリ表

scan-disk-usage.sh の `CANDIDATE` 行と突合して使う。各行の「削除して良い理由」が SKILL.md Step 3 の理由提示の根拠。

## 削除実行の対象（承認後にスキルが実行する）

`scan カテゴリ` 列が scan-disk-usage.sh の `CANDIDATE` 行のカテゴリ値と一致する。

| scan カテゴリ | 削除方法 | リスク | 復元可否 | 削除して良い理由 |
|---|---|---|---|---|
| `npm cache` / `pnpm store` / `yarn cache` / `pip cache` / `go cache` | 各公式 clean コマンド（npm cache clean --force ほか） | 低 | 再取得可 | ネットワーク接続時に再取得・再生成される。オフライン環境・社内 proxy 配下では再取得に制約がある点を注記 |
| `cargo registry` | 公式 clean コマンドなし → SKILL.md の `rm` ルールで削除 | 低 | 再取得可 | registry キャッシュは再取得可能（オフライン環境では再取得に制約あり） |
| `Docker build cache` / `Docker dangling images` | `docker builder prune` / `docker image prune` | 低 | 再生成可 | どのタグからも参照されていない中間生成物。削除後の初回ビルドは遅くなる |
| `Docker stopped containers` | `docker container prune` | 中 | 不可 | 停止中でも再利用予定がある場合がある。Step 3 で名前・作成日時・サイズの内訳を提示 |
| `Homebrew cleanup` | `brew cleanup -s` | 低 | 再取得可 | 旧バージョンと DL キャッシュは再取得可能（旧バージョンへの rollback はしにくくなる） |
| `Xcode DerivedData` | SKILL.md の `rm` ルール | 低 | 再生成可 | ビルド時に再生成される |
| `Xcode iOS DeviceSupport` | SKILL.md の `rm` ルール（古いバージョンを個別に） | 中 | 困難な場合あり | 接続時に再取得されるが、古い iOS・実機のシンボルは再取得が困難な場合がある |
| `unavailable simulators` | `xcrun simctl delete unavailable` | 低 | 再生成可 | 現行 Xcode で利用不能なランタイムの残骸 |
| ユーザーキャッシュ上位 10（`CACHE_TOP_*` ブロック。macOS: `~/Library/Caches` / Linux: `~/.cache` 直下） | SKILL.md の `rm` ルール | 中 | 再生成可 | アプリキャッシュは再生成されるが一部アプリで再ログイン等が必要。パス単位で選択・除外する |
| `Trash`（macOS: `~/.Trash` / Linux: `~/.local/share/Trash`） | 承認後に中身を削除 | 中 | **不可** | ユーザーが既に削除したファイルだが、空にすると復元不能。実行直前の個別最終確認を必須とする |

## 提示のみ（`PRESENT_ONLY` 行・スキルは実行しない）

| scan カテゴリ | 提示するコマンド | 実行しない理由 |
|---|---|---|
| `Docker volumes` | `docker volume ls` で確認 | データ消失リスクが高い |
| `apt cache` / `dnf cache` / `pacman cache`（Linux） | `sudo apt-get clean` / `sudo dnf clean all` / `sudo pacman -Sc` | sudo が必要なため提示のみ |
| `systemd journal`（Linux） | `sudo journalctl --vacuum-size=200M` | sudo が必要なため提示のみ |

## リスク区分

- **低**: 再取得・再生成可能。デフォルトで選択候補にしてよい
- **中**: 再生成可だが副作用（再ログイン・再取得困難・復元不能）あり。デフォルト非選択。実行直前に個別最終確認
- **高**: 対象外。提示のみ
