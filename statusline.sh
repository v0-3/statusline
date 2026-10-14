#!/usr/bin/env bash
# A two-line Claude Code statusline (Catppuccin Macchiato).
# Claude Code pipes session JSON to stdin and displays whatever this prints.
# statusline.ps1 is the Windows version; keep the two in sync.

command -v jq >/dev/null || { echo 'statusline: jq is required (https://jqlang.org)'; exit 0; }

input=$(cat)

# Catppuccin Macchiato as 24-bit ANSI colors (1 = bold, 2 = dim).
mauve='38;2;198;160;246' yellow='38;2;238;212;159' peach='1;38;2;245;169;127'
blue='38;2;138;173;244' green='38;2;166;218;149' red='38;2;237;135;150' dim='2;38;2;202;211;245'

# get <jq filter>: print a value from the input, or nothing if it's missing.
get() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

# c <style> <text>: print text in an ANSI style, then reset.
c() { printf '\033[%sm%s\033[0m' "$1" "$2"; }

# meter <label> <percent> <width> <style>: e.g. "5h ━━━─────── 32%".
# Turns yellow from 50% and red from 80%.
meter() {
  local pct=${2:-0} width=$3 style=$4 filled bar='' i
  filled=$(((pct * width + 50) / 100))
  if ((pct >= 80)); then style=$red; elif ((pct >= 50)); then style=$yellow; fi
  for ((i = 0; i < width; i++)); do
    if ((i < filled)); then bar+='━'; else bar+='─'; fi
  done
  c "$style" "$1 $bar $pct%"
}

# limit <label> <window>: " · 5h ━━━─────── 32% ↻ 2h10m", or nothing without data.
limit() {
  local pct secs
  pct=$(get ".rate_limits.$2.used_percentage // empty | round")
  [ -n "$pct" ] || return 0
  secs=$(get ".rate_limits.$2.resets_at // empty | . - now | floor")
  c "$dim" ' · '
  meter "$1" "$pct" 10 "$green"
  if ((secs >= 86400)); then c "$dim" " ↻ $((secs / 86400))d$((secs % 86400 / 3600))h"
  elif ((secs >= 3600)); then c "$dim" " ↻ $((secs / 3600))h$((secs % 3600 / 60))m"
  elif ((secs > 0)); then c "$dim" " ↻ $((secs / 60))m"
  fi
}

dir=$(get .workspace.current_dir)
branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
effort=$(get 'select(.thinking.enabled == true) | .effort.level')

# Line 1: [folder]:branch · Model / effort
c "$mauve" "[${dir##*/}]"
[ -n "$branch" ] && c "$yellow" ":$branch"
c "$dim" ' · '
c "$peach" "$(get .model.display_name)"
[ -n "$effort" ] && c "$dim" " / $effort"
echo

# Line 2: context window · 5-hour limit · 7-day limit
meter ctx "$(get '.context_window.used_percentage // 0 | round')" 20 "$blue"
limit 5h five_hour
limit 7d seven_day
