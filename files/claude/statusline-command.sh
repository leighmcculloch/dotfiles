#!/bin/bash

# StatusLine script for Claude Code
# Complements Starship prompt color scheme

# Colors matching Starship config
BLUE='\033[1;38;2;151;209;239m'  # #97d1ef - directory color
PURPLE='\033[1;35m'              # purple - git branch color
DIM='\033[2m'
RESET='\033[0m'

# Read JSON from stdin
input=$(cat)

# Parse values using jq
model_display_name=$(echo "$input" | jq -r '.model.display_name // "-"')
cwd=$(echo "$input" | jq -r '.cwd // "-"')
session_id=$(echo "$input" | jq -r '.session_id // "-"')
cost_usd=$(echo "$input" | jq -r 'if .cost.total_cost_usd then ((.cost.total_cost_usd) | . * 100 | ceil | . / 100 | tostring | if contains(".") then . else . + ".00" end | if test("\\.[0-9]$") then . + "0" else . end) else "-" end')

# Shorten paths with home directory to ~
if [ "$cwd" != "-" ]; then
  cwd="${cwd/#$HOME/~}"
fi

# Output statusline
printf "${PURPLE}%s${RESET} ${DIM}|${RESET} ${BLUE}%s${RESET} ${DIM}|${RESET} %s ${DIM}|${RESET} %s" "$model_display_name" "$cwd" "$session_id" "$([ "$cost_usd" = "-" ] && echo "-" || echo "\$$cost_usd")"
