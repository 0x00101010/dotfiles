# Set Ghostty's tab/window title for plain shells.
# Inside tmux, we let tmux's set-titles drive the title instead
# (configured in ~/.config/tmux/tmux.conf).

_ghostty_title_host() {
  local host="${PROMPT_HOST:-${HOST%%.*}}"
  print -r -- "${host#\[mosh\] }"
}

_set_ghostty_title() {
  [[ -n "$TMUX" ]] && return
  local host dir branch
  host="$(_ghostty_title_host)"
  dir="${PWD/#$HOME/~}"
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  # OSC 0: set both window and icon (tab) title.
  printf '\e]0;%s · %s%s\a' "$host" "$dir" "${branch:+ · $branch}"
}

_sync_tmux_title_host() {
  [[ -n "$TMUX" ]] || return
  tmux set-option -gq @title_host "$(_ghostty_title_host)"
}

_run_amp_with_title_guard() {
  local amp_bin
  amp_bin=$(whence -p amp) || return 127

  if [[ -n "$TMUX" ]]; then
    local passthrough
    passthrough=$(tmux show-options -pv -t "$TMUX_PANE" allow-passthrough 2>/dev/null || print -r -- on)
    _sync_tmux_title_host
    tmux set-option -pt "$TMUX_PANE" allow-passthrough off
    command "$amp_bin" "$@"
    local status=$?
    tmux set-option -pt "$TMUX_PANE" allow-passthrough "$passthrough" >/dev/null 2>&1
    _sync_tmux_title_host
    tmux refresh-client -S >/dev/null 2>&1
    return $status
  fi

  local guard_pid
  (
    while :; do
      _set_ghostty_title >/dev/tty 2>/dev/null || break
      sleep 1
    done
  ) &
  guard_pid=$!

  command "$amp_bin" "$@"
  local status=$?
  kill "$guard_pid" >/dev/null 2>&1
  wait "$guard_pid" 2>/dev/null
  _set_ghostty_title >/dev/tty 2>/dev/null || true
  return $status
}

amp() {
  _run_amp_with_title_guard "$@"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _sync_tmux_title_host
add-zsh-hook precmd _set_ghostty_title
_sync_tmux_title_host
_set_ghostty_title
