bindkey '^E' end-of-line
bindkey '^U' backward-kill-line

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^xe' edit-command-line