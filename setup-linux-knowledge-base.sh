#!/usr/bin/env bash
# setup-linux-knowledge-base.sh
#
# Explicit, re-runnable installer for the workspace knowledge-base sync system
# on Linux (cron). Sets up:
#   1. ~/src/workspace clone (or your chosen path)
#   2. ~/.local/bin/workspace-sync   (the sync script)
#   3. A user crontab entry that runs it every 5 minutes
#
# Idempotent: safe to re-run. Won't re-clone an existing repo. Re-running
# overwrites the script with the latest template and replaces (not duplicates)
# the cron entry via a marker comment.
#
# Companion: setup-mac-knowledge-base.sh
# Plan:      plans/workspace-sync.md

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KB_DIR="$SCRIPT_DIR/knowledge-base"
readonly DEFAULT_REPO="$HOME/src/workspace"
readonly REPO_URL="git@github.com:0x00101010/workspace.git"
readonly SCRIPT_DEST="$HOME/.local/bin/workspace-sync"
readonly STATE_DIR="$HOME/.local/state/workspace-sync"
readonly CRON_MARKER="# workspace-sync (managed by setup-linux-knowledge-base.sh)"

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

  command -v git         >/dev/null || missing+=("git")
  command -v qmd         >/dev/null || missing+=("qmd")
  command -v crontab     >/dev/null || missing+=("crontab")
  command -v flock       >/dev/null || missing+=("flock")
  command -v notify-send >/dev/null \
    || c_yellow "  (optional) notify-send not found — conflicts will be log-only"

  if (( ${#missing[@]} > 0 )); then
    c_red "Missing required tools: ${missing[*]}"
    echo
    echo "Install with (Debian/Ubuntu):"
    echo "  sudo apt install git cron util-linux libnotify-bin"
    echo "qmd: https://github.com/tobi/qmd (manual install — no apt package)"
    abort "Install the above and re-run."
  fi
  c_green "  all required tools present"
}

check_templates() {
  step "Verifying templates"
  [[ -f "$KB_DIR/workspace-sync" ]] || abort "Missing template: $KB_DIR/workspace-sync"
  c_green "  template found in $KB_DIR"
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

# ----- install cron entry -------------------------------------------------
install_cron() {
  step "Installing cron entry (every 5 minutes)"

  # Inline PATH ensures qmd/notify-send/git are findable under cron's stripped env.
  local entry="*/5 * * * * PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin $SCRIPT_DEST >>$STATE_DIR/cron.log 2>&1 $CRON_MARKER"

  local current
  current=$(crontab -l 2>/dev/null | grep -vF "$CRON_MARKER" || true)

  {
    if [[ -n "$current" ]]; then printf '%s\n' "$current"; fi
    printf '%s\n' "$entry"
  } | crontab -

  c_green "  cron entry installed"
  echo "  $entry"
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
  echo "  Cron:      every 5 min (see 'crontab -l')"
  echo "  State dir: $STATE_DIR"
  echo
  echo "Useful commands:"
  echo "  crontab -l                                    # view installed entry"
  echo "  tail -f $STATE_DIR/sync.log"
  echo "  tail -f $STATE_DIR/cron.log                   # cron's own stderr"
  echo "  $SCRIPT_DEST                                  # run sync manually"
  echo
  echo "To remove the cron entry:"
  echo "  crontab -l | grep -vF '$CRON_MARKER' | crontab -"
}

# ----- main ---------------------------------------------------------------
main() {
  c_bold "workspace knowledge-base setup (Linux, cron)"
  check_prereqs
  check_templates
  setup_repo
  install_script
  install_cron
  smoke_test
  summary
}

main "$@"
