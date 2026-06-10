#!/bin/bash
# Ring the terminal bell on the parent Claude process's tty.
# Claude Code spawns hooks without a controlling terminal, so /dev/tty is
# unavailable — walk up the process tree to find one we can write to.
pid=$PPID
while [ -n "$pid" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ]; do
  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$tty" ] && [ "$tty" != "?" ]; then
    { printf '\a' > "/dev/$tty"; } 2>/dev/null && exit 0
  fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
exit 0
