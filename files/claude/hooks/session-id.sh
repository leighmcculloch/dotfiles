#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$CLAUDE_ENV_FILE" ] && [ -n "$session_id" ]; then
  echo "export CLAUDE_SESSION_ID=$session_id" >> "$CLAUDE_ENV_FILE"
fi
exit 0
