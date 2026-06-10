# AI helper widget: take current BUFFER, send to an AI CLI, replace line.
# Bound to Ctrl-S.

ai_cmd_widget() {
  local input="$LBUFFER"
  [[ -z "$input" ]] && return

  # Comment the prompt immediately and show thinking indicator
  local commented_input="$input"
  if [[ "$input" != \#* ]]; then
    commented_input="# $input"
  fi
  BUFFER="$commented_input"$'\n'"# Thinking..."
  CURSOR=${#BUFFER}
  zle reset-prompt

  # Capture the last 30 lines of the current tmux pane for context
  local pane_context=""
  if [[ -n "$TMUX" ]]; then
    pane_context="$(tmux capture-pane -p -S -30 2>/dev/null)"
  fi

  # Call Claude in JSON mode
  local json_schema='{"type":"object","properties":{"command":{"type":"string","description":"The shell command"}},"required":["command"]}'
  local resp err
  resp="$(claude --model claude-sonnet-4-6 -p "Given this shell command fragment, return exactly one improved or completed shell command. Fragment: $input"$'\n\n'"Recent terminal output (last 30 lines of the current tmux pane) for context:"$'\n'"$pane_context" --output-format json --json-schema "$json_schema" 2>&1)"
  if [[ $? -ne 0 ]]; then
    BUFFER="$commented_input"$'\n'"# Error: $resp"
    CURSOR=${#BUFFER}
    zle reset-prompt
    return
  fi

  local cmd
  cmd="$(print -r -- "$resp" | jq -r '.structured_output.command' 2>&1)"
  if [[ $? -ne 0 || -z "$cmd" || "$cmd" == "null" ]]; then
    BUFFER="$commented_input"$'\n'"# Error: ${cmd:-no command in response}"$'\n'"# Response: $resp"
    CURSOR=${#BUFFER}
    zle reset-prompt
    return
  fi

  BUFFER="$commented_input"$'\n'"$cmd"
  CURSOR=${#BUFFER}
  zle reset-prompt
}

zle -N ai_cmd_widget
bindkey '^S' ai_cmd_widget
