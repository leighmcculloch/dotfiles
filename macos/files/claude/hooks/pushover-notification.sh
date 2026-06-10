#!/bin/bash
# Send Pushover notification for Claude notifications
# Skip if running in script mode
[ -n "$SCRIPT" ] && exit 0

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
msg=$(echo "$input" | jq -r '.message // "Claude Code notification"')
project=$(basename "$cwd")

# If this is a question notification, extract all questions being asked
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    questions=$(tac "$transcript" | grep -m1 '"name":"AskUserQuestion"' | jq -r '.message.content[] | select(.name == "AskUserQuestion") | .input.questions[].question // empty' 2>/dev/null | tr '\n' ' ' | head -c 200)
    if [ -n "$questions" ]; then
        msg="$questions"
    fi
fi

source ~/.zenv_apikey_pushover && \
curl -s -X POST https://api.pushover.net/1/messages.json \
    -d token="$PUSHOVER_TOKEN" \
    -d user="$PUSHOVER_USER" \
    -d "message=[$project] $msg" \
    > /dev/null 2>&1 || true
