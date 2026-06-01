fzf-history-widget() {
  BUFFER=$(history -n 1 | fzf --tac --no-sort +m)
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

# # requires fzf installed
# fzf-history-widget() {
#   local selected
#   selected=$(fc -rl 1 | awk '{$1=""; sub(/^ /,""); print}' | fzf --tac --no-sort --height=60% --reverse --inline-info)
#   if [[ -n $selected ]]; then
#     BUFFER=$selected
#     CURSOR=${#BUFFER}
#   fi
#   zle redisplay
# }
# zle -N fzf-history-widget

# # When line is empty, Up opens fzf; otherwise keep normal Up behavior
# zle-up-or-fzf() {
#   if [[ -z $BUFFER ]]; then
#     zle fzf-history-widget
#   else
#     zle up-line-or-history
#   fi
# }
# zle -N zle-up-or-fzf
# bindkey '\e[A' zle-up-or-fzf      # Up arrow
# bindkey '^[OA' zle-up-or-fzf      # some terminals send this for Up

