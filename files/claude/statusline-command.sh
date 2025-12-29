#!/bin/bash

# StatusLine script for Claude Code
# Complements Starship prompt color scheme

# Colors matching Starship config
BLUE='\033[1;38;2;151;209;239m'  # #97d1ef - directory color
PURPLE='\033[1;35m'              # purple - git branch color
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Read JSON from stdin
input=$(cat)

# Parse values using jq
cwd=$(echo "$input" | jq -r '.cwd // "-"')
model_display_name=$(echo "$input" | jq -r '.model.display_name // "-"')
cost_usd=$(echo "$input" | jq -r 'if .cost.total_cost_usd then ((.cost.total_cost_usd) | . * 100 | ceil | . / 100 | tostring | if contains(".") then . else . + ".00" end | if test("\\.[0-9]$") then . + "0" else . end) else "-" end')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# Context window info
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
total_input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
total_tokens=$((total_input_tokens + total_output_tokens))
context_percent=$((total_tokens * 100 / context_window_size))

# Format duration in human-friendly units
if [ "$duration_ms" -ge 3600000 ]; then
  # Hours (with one decimal)
  duration_formatted=$(echo "scale=1; $duration_ms / 3600000" | bc)h
elif [ "$duration_ms" -ge 60000 ]; then
  # Minutes (with one decimal)
  duration_formatted=$(echo "scale=1; $duration_ms / 60000" | bc)m
elif [ "$duration_ms" -ge 1000 ]; then
  # Seconds (with one decimal)
  duration_formatted=$(echo "scale=1; $duration_ms / 1000" | bc)s
else
  # Milliseconds
  duration_formatted="${duration_ms}ms"
fi

# Shorten paths with home directory to ~
if [ "$cwd" != "-" ]; then
  cwd="${cwd/#$HOME/~}"
fi

# Color for context percentage based on usage level
if [ "$context_percent" -ge 80 ]; then
  CONTEXT_COLOR="$RED"
elif [ "$context_percent" -ge 50 ]; then
  CONTEXT_COLOR="$YELLOW"
else
  CONTEXT_COLOR="$GREEN"
fi

# Output statusline
printf "${BLUE}%s${RESET} ${DIM}•${RESET} ${GREEN}+%s${RESET} ${RED}-%s${RESET} ${DIM}•${RESET} ${DIM}%s${RESET} ${DIM}•${RESET} ${PURPLE}%s${RESET} ${DIM}•${RESET} ${DIM}%s${RESET} ${DIM}•${RESET} ${CONTEXT_COLOR}%s%%${RESET}" "$cwd" "$lines_added" "$lines_removed" "$duration_formatted" "$model_display_name" "$([ "$cost_usd" = "-" ] && echo "-" || echo "\$$cost_usd")" "$context_percent"
