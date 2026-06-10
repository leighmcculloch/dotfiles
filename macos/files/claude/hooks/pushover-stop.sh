#!/bin/bash
# Send Pushover notification when Claude stops
# Skip if running in script mode
[ -n "$SCRIPT" ] && exit 0

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
project=$(basename "$cwd")

last_msg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    # .message.content is an array of {type, text} objects
    # Get the last element with type=="text", split by newlines, take the last line
    last_msg=$(tac "$transcript" | grep -m1 '"type":"assistant"' | jq -r '[.message.content[] | select(.type == "text")] | last | .text // empty' 2>/dev/null | tail -n1 | head -c 200)
fi
: "${last_msg:=Claude Code is waiting}"

source ~/.zenv_apikey_pushover && \
curl -s -X POST https://api.pushover.net/1/messages.json \
    -d token="$PUSHOVER_TOKEN" \
    -d user="$PUSHOVER_USER" \
    -d "message=[$project] $last_msg" \
    > /dev/null 2>&1 || true
