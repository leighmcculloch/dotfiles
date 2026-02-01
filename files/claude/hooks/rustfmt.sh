#!/bin/bash
# Format Rust files after Edit|Write
f=$(jq -r '.tool_input.file_path // empty')
[ -n "$f" ] && [[ "$f" == *.rs ]] && rustfmt "$f" || true
