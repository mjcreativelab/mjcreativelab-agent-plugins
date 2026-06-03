#!/usr/bin/env bash
# disk-space-cleanup: 読み取り専用ディスク使用量スキャン
# 出力形式（タブ区切り）:
#   CANDIDATE<TAB>カテゴリ<TAB>パス or 対象<TAB>サイズ<TAB>削除コマンド
#   SKIP<TAB>カテゴリ<TAB>理由
# 破壊的コマンドは一切含めない。
set -u

OS="$(uname -s)"

emit_candidate() { printf 'CANDIDATE\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }
emit_skip()      { printf 'SKIP\t%s\t%s\n' "$1" "$2"; }

# パスが存在すれば du -sh で実サイズを返す。なければ空。
dir_size() { [ -d "$1" ] && du -sh "$1" 2>/dev/null | cut -f1 || printf ''; }

has() { command -v "$1" >/dev/null 2>&1; }

# --- パッケージマネージャキャッシュ（公式 clean コマンドあり） ---
if has npm;   then emit_candidate "npm cache"   "$(npm config get cache 2>/dev/null)" "$(dir_size "$(npm config get cache 2>/dev/null)")" "npm cache clean --force"; else emit_skip "npm cache" "npm 未インストール"; fi
if has pnpm;  then emit_candidate "pnpm store"  "$(pnpm store path 2>/dev/null)" "$(dir_size "$(pnpm store path 2>/dev/null)")" "pnpm store prune"; else emit_skip "pnpm store" "pnpm 未インストール"; fi
if has yarn;  then emit_candidate "yarn cache"  "$(yarn cache dir 2>/dev/null)" "$(dir_size "$(yarn cache dir 2>/dev/null)")" "yarn cache clean"; else emit_skip "yarn cache" "yarn 未インストール"; fi
if has pip;   then emit_candidate "pip cache"   "pip cache" "$(pip cache dir >/dev/null 2>&1 && dir_size "$(pip cache dir 2>/dev/null)")" "pip cache purge"; else emit_skip "pip cache" "pip 未インストール"; fi
if has go;    then emit_candidate "go cache"    "$(go env GOCACHE 2>/dev/null)" "$(dir_size "$(go env GOCACHE 2>/dev/null)")" "go clean -cache"; else emit_skip "go cache" "go 未インストール"; fi
if has cargo; then emit_candidate "cargo registry" "${CARGO_HOME:-$HOME/.cargo}/registry" "$(dir_size "${CARGO_HOME:-$HOME/.cargo}/registry")" "（cargo-cache 未導入なら提示のみ）"; else emit_skip "cargo registry" "cargo 未インストール"; fi

# --- Docker（公式 prune コマンドあり） ---
if has docker && docker info >/dev/null 2>&1; then
  printf 'DOCKER_DF_BEGIN\n'; docker system df 2>/dev/null; printf 'DOCKER_DF_END\n'
  emit_candidate "Docker build cache"   "build cache"        "（docker system df 参照）" "docker builder prune"
  emit_candidate "Docker dangling images" "dangling images"  "（docker system df 参照）" "docker image prune"
  emit_candidate "Docker stopped containers" "stopped containers" "（下記 PS 参照）" "docker container prune"
  printf 'DOCKER_PS_BEGIN\n'; docker ps -a --filter status=exited --filter status=created --format '{{.Names}}\t{{.CreatedAt}}\t{{.Size}}' 2>/dev/null; printf 'DOCKER_PS_END\n'
else
  emit_skip "Docker" "docker 未インストールまたはデーモン未起動"
fi

# --- Homebrew（OS でなく command -v で検出: Linuxbrew 対応） ---
if has brew; then
  emit_candidate "Homebrew cleanup" "brew cache + 旧バージョン" "（brew cleanup --dry-run 参照）" "brew cleanup -s"
  printf 'BREW_DRYRUN_BEGIN\n'; brew cleanup --dry-run 2>/dev/null | tail -n 3; printf 'BREW_DRYRUN_END\n'
else
  emit_skip "Homebrew cleanup" "brew 未インストール"
fi

# --- macOS 専用 ---
if [ "$OS" = "Darwin" ]; then
  DD="$HOME/Library/Developer/Xcode/DerivedData"
  [ -d "$DD" ] && emit_candidate "Xcode DerivedData" "$DD" "$(dir_size "$DD")" "rm -rf -- $DD" || emit_skip "Xcode DerivedData" "DerivedData なし"
  DS="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  [ -d "$DS" ] && emit_candidate "Xcode iOS DeviceSupport" "$DS" "$(dir_size "$DS")" "（古いバージョンを個別に rm -rf --）" || emit_skip "Xcode iOS DeviceSupport" "DeviceSupport なし"
  if has xcrun; then emit_candidate "unavailable simulators" "simctl" "（提示のみ）" "xcrun simctl delete unavailable"; else emit_skip "unavailable simulators" "xcrun 未インストール"; fi
  CACHE="$HOME/Library/Caches"
  TRASH="$HOME/.Trash"
else
  emit_skip "Xcode 系" "macOS 専用"
  CACHE="$HOME/.cache"
  TRASH="$HOME/.local/share/Trash"
fi

# --- ユーザーキャッシュ上位 10 サブディレクトリ（macOS/Linux 共通の枠） ---
if [ -d "$CACHE" ]; then
  printf 'CACHE_TOP_BEGIN\t%s\n' "$CACHE"
  du -sh "$CACHE"/* 2>/dev/null | sort -rh | head -n 10
  printf 'CACHE_TOP_END\n'
else
  emit_skip "user caches" "$CACHE なし"
fi

# --- ゴミ箱 ---
[ -d "$TRASH" ] && emit_candidate "Trash" "$TRASH" "$(dir_size "$TRASH")" "（承認後に中身を削除・復元不能）" || emit_skip "Trash" "$TRASH なし"

# --- Linux: sudo 必要なもの（提示のみ） ---
if [ "$OS" = "Linux" ]; then
  has apt-get && emit_candidate "apt cache (提示のみ)" "/var/cache/apt" "（sudo 必要）" "sudo apt-get clean"
  has dnf     && emit_candidate "dnf cache (提示のみ)" "dnf"           "（sudo 必要）" "sudo dnf clean all"
  has pacman  && emit_candidate "pacman cache (提示のみ)" "pacman"     "（sudo 必要）" "sudo pacman -Sc"
  has journalctl && emit_candidate "systemd journal (提示のみ)" "journal" "（sudo 必要）" "sudo journalctl --vacuum-size=200M"
fi

printf 'SCAN_COMPLETE\n'
