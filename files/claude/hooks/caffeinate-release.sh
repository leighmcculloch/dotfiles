#!/bin/bash
# Release the caffeinate hold for this Claude Code session.
# caffeinate is only killed when no other sessions remain active.

set -e

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

DIR="/tmp/claude-caffeinate"

# Unregister this session.
rm -f "$DIR/sessions/$SESSION_ID"

# If other sessions are still active, keep caffeinate running.
if [ -d "$DIR/sessions" ]; then
    REMAINING=$(find "$DIR/sessions" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING" -gt 0 ]; then
        exit 0
    fi
fi

# No more active sessions. Kill caffeinate.
if [ -f "$DIR/caffeinate.pid" ]; then
    PID=$(cat "$DIR/caffeinate.pid")
    kill "$PID" 2>/dev/null || true
    rm -f "$DIR/caffeinate.pid"
fi

exit 0
