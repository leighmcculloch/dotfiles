#!/bin/bash
# Format Go files after Edit|Write
f=$(jq -r '.tool_input.file_path // empty')
[ -n "$f" ] && [[ "$f" == *.go ]] && go fmt "$f" || true
