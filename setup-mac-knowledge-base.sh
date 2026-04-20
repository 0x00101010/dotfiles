#!/usr/bin/env bash
# setup-mac-knowledge-base.sh
#
# Explicit, re-runnable installer for the workspace knowledge-base sync system
# on macOS. Sets up:
#   1. ~/src/workspace clone (or your chosen path)
#   2. ~/.local/bin/workspace-sync       (the sync script)
#   3. ~/Library/LaunchAgents/com.francis.workspace-sync.plist  (5min timer)
#
# Idempotent: safe to re-run. Won't re-clone an existing repo, won't duplicate
# launchd entries. Re-running overwrites the script + plist with the latest
# templates from this dotfiles checkout.
#
# Companion: setup-linux-knowledge-base.sh
# Plan:      plans/workspace-sync.md

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KB_DIR="$SCRIPT_DIR/knowledge-base"
readonly DEFAULT_REPO="$HOME/src/workspace"
readonly REPO_URL="git@github.com:0x00101010/workspace.git"
readonly LABEL="com.francis.workspace-sync"
readonly PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
readonly SCRIPT_DEST="$HOME/.local/bin/workspace-sync"
readonly STATE_DIR="$HOME/.local/state/workspace-sync"

REPO=""

# ----- helpers ------------------------------------------------------------
c_red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
c_green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
c_yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
c_bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

abort() { c_red "ERROR: $*"; exit 1; }
step()  { echo; c_bold "==> $*"; }

confirm() {
  local prompt="$1" default="${2:-y}" reply
  read -r -p "$prompt " reply
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ----- prereq checks ------------------------------------------------------
check_prereqs() {
  step "Checking prerequisites"
  local missing=()

  command -v git >/dev/null               || missing+=("git")
  command -v qmd >/dev/null               || missing+=("qmd")
  command -v terminal-notifier >/dev/null || missing+=("terminal-notifier")
  command -v launchctl >/dev/null         || missing+=("launchctl")
  command -v flock >/dev/null \
    || c_yellow "  (optional) flock not found — script will use mkdir-lock fallback"

  if (( ${#missing[@]} > 0 )); then
    c_red "Missing required tools: ${missing[*]}"
    echo
    echo "Install with:"
    for tool in "${missing[@]}"; do
      case "$tool" in
        git)               echo "  xcode-select --install   # or: brew install git" ;;
        qmd)               echo "  # qmd: https://github.com/tobi/qmd (manual install — no Homebrew formula yet)" ;;
        terminal-notifier) echo "  brew install terminal-notifier" ;;
        launchctl)         echo "  # launchctl is part of macOS — your install is broken" ;;
      esac
    done
    abort "Install the above and re-run."
  fi
  c_green "  all required tools present"
}

check_templates() {
  step "Verifying templates"
  local missing=()
  for f in workspace-sync "$LABEL.plist"; do
    [[ -f "$KB_DIR/$f" ]] || missing+=("$f")
  done
  if (( ${#missing[@]} > 0 )); then
    abort "Missing template(s) in $KB_DIR: ${missing[*]}"
  fi
  c_green "  templates found in $KB_DIR"
}

# ----- repo clone ---------------------------------------------------------
setup_repo() {
  step "Configuring workspace repo"
  local repo_path
  read -r -p "Path to workspace repo [$DEFAULT_REPO]: " repo_path
  repo_path="${repo_path:-$DEFAULT_REPO}"
  repo_path="${repo_path/#\~/$HOME}"

  if [[ -d "$repo_path/.git" ]]; then
    c_green "  repo already exists at $repo_path — leaving it alone"
  elif [[ -e "$repo_path" ]]; then
    abort "$repo_path exists but is not a git repo. Move it or pick another path."
  else
    if confirm "  Clone $REPO_URL → $repo_path? [Y/n]" "y"; then
      mkdir -p "$(dirname "$repo_path")"
      git clone "$REPO_URL" "$repo_path"
      c_green "  cloned"
    else
      abort "Cannot proceed without a workspace repo."
    fi
  fi

  REPO="$repo_path"
}

# ----- install script -----------------------------------------------------
install_script() {
  step "Installing workspace-sync script"
  mkdir -p "$(dirname "$SCRIPT_DEST")" "$STATE_DIR"
  sed "s|@@REPO@@|$REPO|g" "$KB_DIR/workspace-sync" > "$SCRIPT_DEST"
  chmod +x "$SCRIPT_DEST"
  c_green "  installed → $SCRIPT_DEST"
}

# ----- install launchd ----------------------------------------------------
install_launchd() {
  step "Installing LaunchAgent"
  mkdir -p "$(dirname "$PLIST")"
  sed -e "s|@@HOME@@|$HOME|g" \
      -e "s|@@REPO@@|$REPO|g" \
      "$KB_DIR/$LABEL.plist" > "$PLIST"

  # Idempotent (re)load.
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load -w "$PLIST"
  c_green "  loaded → $LABEL"
}

# ----- smoke test ---------------------------------------------------------
smoke_test() {
  step "Running smoke test"
  if "$SCRIPT_DEST"; then
    c_green "  ok"
    if [[ -f "$STATE_DIR/last-run.json" ]]; then
      cat "$STATE_DIR/last-run.json"
    fi
  else
    c_yellow "  smoke test exited non-zero. Check $STATE_DIR/sync.log"
  fi
}

# ----- summary ------------------------------------------------------------
summary() {
  echo
  c_green "Done."
  echo "  Repo:      $REPO"
  echo "  Script:    $SCRIPT_DEST"
  echo "  LaunchAgent: $PLIST"
  echo "  State dir: $STATE_DIR"
  echo
  echo "Sync runs every 5 minutes plus on edits to todos/ and journal/."
  echo
  echo "Useful commands:"
  echo "  tail -f $STATE_DIR/sync.log         # watch sync activity"
  echo "  cat    $STATE_DIR/last-run.json     # last status"
  echo "  $SCRIPT_DEST                        # run sync manually"
  echo "  launchctl list | grep $LABEL        # verify loaded"
  echo "  launchctl unload $PLIST             # pause"
}

# ----- main ---------------------------------------------------------------
main() {
  c_bold "workspace knowledge-base setup (macOS)"
  check_prereqs
  check_templates
  setup_repo
  install_script
  install_launchd
  smoke_test
  summary
}

main "$@"
