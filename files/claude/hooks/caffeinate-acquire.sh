#!/bin/bash
# Acquire a caffeinate hold for this Claude Code session.
# Multiple sessions coordinate via marker files in /tmp/claude-caffeinate/sessions/.
# caffeinate is started if not already running, and kept alive until all sessions release.

set -e

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

DIR="/tmp/claude-caffeinate"
mkdir -p "$DIR/sessions"

# Register this session as active.
touch "$DIR/sessions/$SESSION_ID"

# If caffeinate is already running, nothing to do.
if [ -f "$DIR/caffeinate.pid" ]; then
    PID=$(cat "$DIR/caffeinate.pid")
    if kill -0 "$PID" 2>/dev/null; then
        exit 0
    fi
    # Stale pid file, clean up.
    rm -f "$DIR/caffeinate.pid"
fi

# Start caffeinate to prevent idle sleep.
caffeinate -i &
echo $! > "$DIR/caffeinate.pid"

exit 0
