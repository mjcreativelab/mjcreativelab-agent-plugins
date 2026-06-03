#!/usr/bin/env bash
# disk-space-cleanup: 読み取り専用ディスク使用量スキャン
# 出力形式（タブ区切り）:
#   CANDIDATE<TAB>カテゴリ<TAB>パス<TAB>サイズ<TAB>削除方法     ... 削除実行の候補
#   PRESENT_ONLY<TAB>カテゴリ<TAB>対象<TAB>提示コマンド         ... 提示のみ（スキルは実行しない）
#   SKIP<TAB>カテゴリ<TAB>理由                                  ... ツール不在・OS 非対象・取得失敗
# 「削除方法」列はあくまで表示用ヒント。実際のパスは独立フィールド（パス列）にある。
# 破壊的コマンドは一切含めない。
set -u

# HOME 未定義環境（一部 CI コンテナ等）では成立しないため明示チェック
: "${HOME:?HOME 環境変数が必要です}"

OS="$(uname -s)"

emit_candidate()    { printf 'CANDIDATE\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }
emit_present_only() { printf 'PRESENT_ONLY\t%s\t%s\t%s\n' "$1" "$2" "$3"; }
emit_skip()         { printf 'SKIP\t%s\t%s\n' "$1" "$2"; }

# パスが存在すれば du -sh で実サイズを返す。なければ空。
dir_size() { [ -d "$1" ] && du -sh "$1" 2>/dev/null | cut -f1 || printf ''; }

has() { command -v "$1" >/dev/null 2>&1; }

# 公式 clean コマンドありのキャッシュ。パス取得失敗・空・不存在は SKIP。
emit_cache() {
  cat="$1"; path="$2"; method="$3"
  if [ -z "$path" ] || [ ! -d "$path" ]; then
    emit_skip "$cat" "パス取得失敗または不存在"
    return
  fi
  emit_candidate "$cat" "$path" "$(dir_size "$path")" "$method"
}

# --- パッケージマネージャキャッシュ ---
if has npm;   then emit_cache "npm cache"   "$(npm config get cache 2>/dev/null)"             "npm cache clean --force"; else emit_skip "npm cache" "npm 未インストール"; fi
if has pnpm;  then emit_cache "pnpm store"  "$(pnpm store path 2>/dev/null)"                   "pnpm store prune"; else emit_skip "pnpm store" "pnpm 未インストール"; fi
if has yarn;  then emit_cache "yarn cache"  "$(yarn cache dir 2>/dev/null)"                    "yarn cache clean"; else emit_skip "yarn cache" "yarn 未インストール"; fi
if has pip;   then emit_cache "pip cache"   "$(pip cache dir 2>/dev/null)"                     "pip cache purge"; else emit_skip "pip cache" "pip 未インストール"; fi
if has go;    then emit_cache "go cache"    "$(go env GOCACHE 2>/dev/null)"                    "go clean -cache"; else emit_skip "go cache" "go 未インストール"; fi
# cargo は公式 clean コマンドがないため rm（SKILL.md の rm ルールで実行）
if has cargo; then emit_cache "cargo registry" "${CARGO_HOME:-$HOME/.cargo}/registry"         "rm（公式コマンドなし: SKILL.md rm ルール）"; else emit_skip "cargo registry" "cargo 未インストール"; fi

# --- Docker（公式 prune コマンドあり / volumes は提示のみ） ---
if has docker && docker info >/dev/null 2>&1; then
  printf 'DOCKER_DF_BEGIN\n'; docker system df 2>/dev/null; printf 'DOCKER_DF_END\n'
  emit_candidate "Docker build cache"      "build cache"        "（docker system df 参照）" "docker builder prune"
  emit_candidate "Docker dangling images"  "dangling images"    "（docker system df 参照）" "docker image prune"
  emit_candidate "Docker stopped containers" "stopped containers" "（下記 PS 参照）"          "docker container prune"
  emit_present_only "Docker volumes" "docker volume" "docker volume ls"
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
  [ -d "$DD" ] && emit_candidate "Xcode DerivedData" "$DD" "$(dir_size "$DD")" "rm（SKILL.md rm ルール）" || emit_skip "Xcode DerivedData" "DerivedData なし"
  DS="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  [ -d "$DS" ] && emit_candidate "Xcode iOS DeviceSupport" "$DS" "$(dir_size "$DS")" "rm（古いバージョンを個別に・SKILL.md rm ルール）" || emit_skip "Xcode iOS DeviceSupport" "DeviceSupport なし"
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
[ -d "$TRASH" ] && emit_candidate "Trash" "$TRASH" "$(dir_size "$TRASH")" "中身を削除（復元不能・実行直前に最終確認）" || emit_skip "Trash" "$TRASH なし"

# --- Linux: sudo 必要なもの（提示のみ・削除候補にしない） ---
if [ "$OS" = "Linux" ]; then
  has apt-get    && emit_present_only "apt cache"      "/var/cache/apt" "sudo apt-get clean"
  has dnf        && emit_present_only "dnf cache"      "dnf"            "sudo dnf clean all"
  has pacman     && emit_present_only "pacman cache"   "pacman"         "sudo pacman -Sc"
  has journalctl && emit_present_only "systemd journal" "journal"       "sudo journalctl --vacuum-size=200M"
fi

printf 'SCAN_COMPLETE\n'
