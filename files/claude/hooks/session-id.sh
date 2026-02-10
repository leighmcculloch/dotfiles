#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
model=$(echo "$input" | jq -r '.model // empty')
if [ -n "$CLAUDE_ENV_FILE" ]; then
  if [ -n "$session_id" ]; then
    echo "export CLAUDE_SESSION_ID=$session_id" >> "$CLAUDE_ENV_FILE"
  fi
  if [ -n "$model" ]; then
    echo "export CLAUDE_CODE_MODEL=$model" >> "$CLAUDE_ENV_FILE"
  fi
fi
exit 0
