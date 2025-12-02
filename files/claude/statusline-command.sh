#!/bin/bash

# StatusLine script for Claude Code
# Complements Starship prompt color scheme

# Colors matching Starship config
BLUE='\033[1;38;2;151;209;239m'  # #97d1ef - directory color
PURPLE='\033[1;35m'              # purple - git branch color
GREEN='\033[32m'
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

# Shorten paths with home directory to ~
if [ "$cwd" != "-" ]; then
  cwd="${cwd/#$HOME/~}"
fi

# Output statusline
printf "${BLUE}%s${RESET} ${DIM}•${RESET} ${GREEN}+%s${RESET} ${RED}-%s${RESET} ${DIM}•${RESET} ${PURPLE}%s${RESET} ${DIM}•${RESET} ${DIM}%s${RESET}" "$cwd" "$lines_added" "$lines_removed" "$model_display_name" "$([ "$cost_usd" = "-" ] && echo "-" || echo "\$$cost_usd")"
