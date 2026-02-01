#!/bin/bash
# Send Pushover notification for Claude notifications
# Skip if running in script mode
[ -n "$SCRIPT" ] && exit 0

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
msg=$(echo "$input" | jq -r '.message // "Claude Code notification"')
project=$(basename "$cwd")

source ~/.zenv_apikey_pushover && \
curl -s -X POST https://api.pushover.net/1/messages.json \
    -d token="$PUSHOVER_TOKEN" \
    -d user="$PUSHOVER_USER" \
    -d "message=[$project] $msg" \
    > /dev/null 2>&1 || true
