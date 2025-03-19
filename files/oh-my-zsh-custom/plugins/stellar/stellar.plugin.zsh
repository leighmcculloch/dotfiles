source <(stellar completion --shell zsh)

function stellar_prompt() {
  local n=$(stellar env STELLAR_NETWORK 2&>/dev/null || true)
  local a=$(stellar env STELLAR_ACCOUNT 2&>/dev/null || true)
  if ! [ -z "$n" ]; then
    echo -n "n=$n"
  fi
  if ! [ -z "$n" ] && ! [ -z "$a" ]; then
    echo -n " "
  fi
  if ! [ -z "$a" ]; then
    echo -n "a=$a"
  fi
}
