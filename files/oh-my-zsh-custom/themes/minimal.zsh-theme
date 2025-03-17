ZSH_THEME_GIT_PROMPT_PREFIX=""
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_SEPARATOR=" "
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg[magenta]%}"
ZSH_THEME_GIT_PROMPT_STAGED="%{$fg[green]%}%{●%G%}"
ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg[red]%}%{✖%G%}"
ZSH_THEME_GIT_PROMPT_CHANGED="%{$fg[cyan]%}%{✚%G%}"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[cyan]%}%{-%G%}"
ZSH_THEME_GIT_PROMPT_BEHIND="%{↓%G%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{↑%G%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%}%{u%G%}"
ZSH_THEME_GIT_PROMPT_STASHED="%{$fg[blue]%}%{⚑%G%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_UPSTREAM_SEPARATOR="->"

PROMPT='
%F{178}%2~ $(git_super_status) $fg[green][n:$(~/.cargo/bin/stellar env STELLAR_NETWORK 2&>/dev/null || true) a:$(~/.cargo/bin/stellar env STELLAR_ACCOUNT 2&>/dev/null || true)]
%F{178}$ %{$reset_color%}'
RPROMPT=''

