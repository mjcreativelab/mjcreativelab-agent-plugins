#!/usr/bin/env bash
# Claude Code status line script

input=$(cat)

# --- Colors ---
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# --- Helper: pick color by percentage ---
color_for_pct() {
  local pct="$1"
  if [ -z "$pct" ]; then
    printf "%s" "$RESET"
  elif awk "BEGIN{exit !($pct > 80)}"; then
    printf "%s" "$RED"
  elif awk "BEGIN{exit !($pct > 50)}"; then
    printf "%s" "$YELLOW"
  else
    printf "%s" "$GREEN"
  fi
}

# --- Helper: render block bar (10 blocks) ---
block_bar() {
  local pct="$1"
  local color="$2"
  if [ -z "$pct" ]; then
    printf "%s" "----------"
    return
  fi
  local filled
  filled=$(awk "BEGIN{printf \"%d\", int($pct / 10 + 0.5)}")
  [ "$filled" -gt 10 ] && filled=10
  local empty=$((10 - filled))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  printf "%b%s%b" "$color" "$bar" "$RESET"
}

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Effort ---
effort=$(echo "$input" | jq -r '.effort.level // empty')

# --- Context window usage ---
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_color=$(color_for_pct "$ctx_used")
ctx_bar=$(block_bar "$ctx_used" "$ctx_color")
if [ -n "$ctx_used" ]; then
  ctx_pct_str=$(printf "%b%.0f%%%b" "$ctx_color" "$ctx_used" "$RESET")
else
  ctx_pct_str="--"
fi

# --- Rate limits ---
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

five_str=""
if [ -n "$five_pct" ]; then
  five_c=$(color_for_pct "$five_pct")
  five_bar=$(block_bar "$five_pct" "$five_c")
  five_str=$(printf "5h:%b%.0f%%%b %s" "$five_c" "$five_pct" "$RESET" "$five_bar")
fi

seven_str=""
if [ -n "$seven_pct" ]; then
  seven_c=$(color_for_pct "$seven_pct")
  seven_bar=$(block_bar "$seven_pct" "$seven_c")
  seven_str=$(printf "7d:%b%.0f%%%b %s" "$seven_c" "$seven_pct" "$RESET" "$seven_bar")
fi

# --- Assemble output ---
model_str=""
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    model_str="${model} [${effort}]"
  else
    model_str="$model"
  fi
fi

parts=()
[ -n "$model_str" ]    && parts+=("$model_str")
parts+=("CTX:${ctx_pct_str} ${ctx_bar}")
[ -n "$five_str" ]     && parts+=("$five_str")
[ -n "$seven_str" ]    && parts+=("$seven_str")

result=""
sep=""
for part in "${parts[@]}"; do
  result="${result}${sep}${part}"
  sep=" | "
done
printf "%s" "$result"
