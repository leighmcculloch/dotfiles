#!/bin/bash

# StatusLine script for Claude Code
# Complements Starship prompt color scheme

# Colors matching Starship config
BLUE='\033[1;38;2;151;209;239m'  # #97d1ef - directory color
PURPLE='\033[1;35m'              # purple - git branch color
GREEN='\033[32m'
RED='\033[31m'
DIM='\033[2m'
RED_BG='\033[41;97m'             # red background, bright white text
RESET='\033[0m'

# Read JSON from stdin
input=$(cat)

# Parse all values in a single jq call
eval "$(echo "$input" | jq -r '
  @sh "cwd=\(.cwd // "-")",
  @sh "model_display_name=\(.model.display_name // "-")",
  @sh "cost_usd=\(if .cost.total_cost_usd then ((.cost.total_cost_usd) | . * 100 | ceil | . / 100 | tostring | if contains(".") then . else . + ".00" end | if test("\\.[0-9]$") then . + "0" else . end) else "-" end)",
  @sh "lines_added=\(.cost.total_lines_added // 0)",
  @sh "lines_removed=\(.cost.total_lines_removed // 0)",
  @sh "duration_ms=\(.cost.total_duration_ms // 0)",
  @sh "api_duration_ms=\(.cost.total_api_duration_ms // 0)",
  @sh "context_percent=\(.context_window.used_percentage // 0)",
  @sh "exceeds_200k=\(.exceeds_200k_tokens // false)",
  @sh "agent_name=\(.agent.name // "")",
  @sh "five_hour_pct=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "seven_day_pct=\(.rate_limits.seven_day.used_percentage // "")"
')"

# Format duration in human-friendly units (pure bash, no bc)
format_duration() {
  local ms=$1
  if [ "$ms" -ge 3600000 ]; then
    echo "$((ms / 3600000)).$((ms % 3600000 / 360000))h"
  elif [ "$ms" -ge 60000 ]; then
    echo "$((ms / 60000)).$((ms % 60000 / 6000))m"
  elif [ "$ms" -ge 1000 ]; then
    echo "$((ms / 1000)).$((ms % 1000 / 100))s"
  else
    echo "${ms}ms"
  fi
}

duration_formatted=$(format_duration "$duration_ms")
api_duration_formatted=$(format_duration "$api_duration_ms")

# Shorten paths with home directory to ~. The tilde lives in a variable
# because bare `~` in a parameter-expansion replacement is tilde-expanded
# back to $HOME (making the substitution a no-op), and `\~` is preserved
# literally on bash >=5.2 with patsub_replacement on (leaving a visible
# backslash). A pre-expanded variable sidesteps both.
tilde='~'
if [ "$cwd" != "-" ] && [ -n "${HOME:-}" ]; then
  cwd="${cwd/#$HOME/$tilde}"
fi

# Current git branch, if the cwd is inside a repo. Re-expand the leading ~
# so git sees a real path.
branch=""
if [ "$cwd" != "-" ]; then
  branch=$(git -C "${cwd/#$tilde/$HOME}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
fi

# Build context display (red background if exceeds 200k tokens)
if [ "$exceeds_200k" = "true" ]; then
  context_display="${RED_BG} ${context_percent}% ${RESET}"
else
  context_display="${DIM}${context_percent}%${RESET}"
fi

# Build model/agent display
model_display="${PURPLE}${model_display_name}${RESET}"
if [ -n "$agent_name" ]; then
  model_display="${model_display} ${DIM}(${agent_name})${RESET}"
fi

# Leading slot: branch when we have one, otherwise the cwd takes its place so
# the top line is never empty. The cwd is always repeated on the second line.
if [ -n "$branch" ]; then
  leading_display="${PURPLE}${branch}${RESET}"
else
  leading_display="${BLUE}${cwd}${RESET}"
fi

# Build usage display
usage_display=""
if [ -n "$five_hour_pct" ] && [ -n "$seven_day_pct" ]; then
  usage_display=" ${DIM}•${RESET} ${DIM}5h:${RESET}${five_hour_pct}% ${DIM}7d:${RESET}${seven_day_pct}%"
fi

# Output statusline. Second line carries the cwd under the branch/stats row.
# When no branch is known the leading slot already holds the cwd, so skip
# the second line to avoid duplicating it.
printf "%b ${DIM}•${RESET} ${GREEN}+%s${RESET} ${RED}-%s${RESET} ${DIM}•${RESET} ${DIM}%s${RESET} ${DIM}(%s)${RESET} ${DIM}•${RESET} %b ${DIM}•${RESET} %b ${DIM}•${RESET} ${DIM}%s${RESET}%b" "$leading_display" "$lines_added" "$lines_removed" "$duration_formatted" "$api_duration_formatted" "$model_display" "$context_display" "$([ "$cost_usd" = "-" ] && echo "-" || echo "\$$cost_usd")" "$usage_display"
if [ -n "$branch" ]; then
  printf "\n${BLUE}%s${RESET}" "$cwd"
fi
