# Set Ghostty's tab/window title for plain shells.
# Inside tmux, we let tmux's set-titles drive the title instead
# (configured in ~/.config/tmux/tmux.conf).

_set_ghostty_title() {
  [[ -n "$TMUX" ]] && return
  local host="${HOST%%.*}"
  local dir="${PWD/#$HOME/~}"
  # OSC 0: set both window and icon (tab) title.
  printf '\e]0;%s · %s\a' "$host" "$dir"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _set_ghostty_title
_set_ghostty_title
