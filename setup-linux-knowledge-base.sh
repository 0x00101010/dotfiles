#!/usr/bin/env bash
# setup-linux-knowledge-base.sh
#
# Explicit, re-runnable installer for the workspace knowledge-base sync system
# on Linux (cron). Sets up:
#   1. ~/src/workspace clone (or your chosen path)
#   2. ~/.local/bin/workspace-sync   (every 5 min: commit/rebase/push)
#   3. ~/.local/bin/schedule-draft   (22:00 daily: draft tomorrow's schedule)
#   4. ~/.local/bin/auto-reflect     (22:30 daily: write mechanical journal)
#   5. ~/.local/bin/weekly-digest    (22:00 Sun:  aggregate week journals)
#   6. ~/.local/bin/monthly-digest   (06:00 day-1: aggregate previous month)
#   7. User crontab entries for the above
#
# Idempotent: safe to re-run. Won't re-clone an existing repo. Re-running
# overwrites each script with the latest template and replaces (not duplicates)
# the cron entries via per-service marker comments.
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

readonly SCHEDULE_DRAFT_DEST="$HOME/.local/bin/schedule-draft"
readonly SCHEDULE_DRAFT_STATE_DIR="$HOME/.local/state/schedule-draft"
readonly SCHEDULE_DRAFT_MARKER="# schedule-draft (managed by setup-linux-knowledge-base.sh)"

readonly AUTO_REFLECT_DEST="$HOME/.local/bin/auto-reflect"
readonly AUTO_REFLECT_STATE_DIR="$HOME/.local/state/auto-reflect"
readonly AUTO_REFLECT_MARKER="# auto-reflect (managed by setup-linux-knowledge-base.sh)"

readonly WEEKLY_DIGEST_DEST="$HOME/.local/bin/weekly-digest"
readonly WEEKLY_DIGEST_STATE_DIR="$HOME/.local/state/weekly-digest"
readonly WEEKLY_DIGEST_MARKER="# weekly-digest (managed by setup-linux-knowledge-base.sh)"

readonly MONTHLY_DIGEST_DEST="$HOME/.local/bin/monthly-digest"
readonly MONTHLY_DIGEST_STATE_DIR="$HOME/.local/state/monthly-digest"
readonly MONTHLY_DIGEST_MARKER="# monthly-digest (managed by setup-linux-knowledge-base.sh)"

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
  command -v notify-send >/dev/null \
    || c_yellow "  (optional) notify-send not found — conflicts will be log-only"

  if ! command -v amp >/dev/null && [[ ! -x "$HOME/.local/bin/amp" ]]; then
    c_yellow "  (optional) amp not found — schedule-draft will fail until amp is installed"
    c_yellow "             (expected at $HOME/.local/bin/amp or on PATH; auto-reflect & weekly-digest don't need it)"
  fi

  if (( ${#missing[@]} > 0 )); then
    c_red "Missing required tools: ${missing[*]}"
    echo
    echo "Install with (Debian/Ubuntu):"
    echo "  sudo apt install git cron libnotify-bin"
    echo "qmd: https://github.com/tobi/qmd (manual install — no apt package)"
    abort "Install the above and re-run."
  fi
  c_green "  all required tools present"
}

check_templates() {
  step "Verifying templates"
  local t
  for t in workspace-sync schedule-draft auto-reflect weekly-digest monthly-digest; do
    [[ -f "$KB_DIR/$t" ]] || abort "Missing template: $KB_DIR/$t"
  done
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

# ----- install scripts ----------------------------------------------------
install_one_script() {
  local name="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  sed "s|@@REPO@@|$REPO|g" "$KB_DIR/$name" > "$dest"
  chmod +x "$dest"
  c_green "  installed → $dest"
}

install_scripts() {
  step "Installing knowledge-base scripts"
  install_one_script "workspace-sync" "$SCRIPT_DEST"
  install_one_script "schedule-draft" "$SCHEDULE_DRAFT_DEST"
  install_one_script "auto-reflect"   "$AUTO_REFLECT_DEST"
  install_one_script "weekly-digest"  "$WEEKLY_DIGEST_DEST"
  install_one_script "monthly-digest" "$MONTHLY_DIGEST_DEST"
  mkdir -p "$STATE_DIR" "$SCHEDULE_DRAFT_STATE_DIR" "$AUTO_REFLECT_STATE_DIR" \
           "$WEEKLY_DIGEST_STATE_DIR" "$MONTHLY_DIGEST_STATE_DIR"
}

# ----- install cron entries -----------------------------------------------
install_cron() {
  step "Installing cron entries"

  # Inline PATH ensures qmd/notify-send/git/amp are findable under cron's stripped env.
  local cron_path="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"

  local sync_entry="*/5 * * * * PATH=$cron_path $SCRIPT_DEST >>$STATE_DIR/cron.log 2>&1 $CRON_MARKER"
  local sched_entry="0 22 * * * PATH=$cron_path $SCHEDULE_DRAFT_DEST >>$SCHEDULE_DRAFT_STATE_DIR/cron.log 2>&1 $SCHEDULE_DRAFT_MARKER"
  local reflect_entry="30 22 * * * PATH=$cron_path $AUTO_REFLECT_DEST >>$AUTO_REFLECT_STATE_DIR/cron.log 2>&1 $AUTO_REFLECT_MARKER"
  local digest_entry="0 22 * * 0 PATH=$cron_path $WEEKLY_DIGEST_DEST >>$WEEKLY_DIGEST_STATE_DIR/cron.log 2>&1 $WEEKLY_DIGEST_MARKER"
  local monthly_entry="0 6 1 * * PATH=$cron_path $MONTHLY_DIGEST_DEST >>$MONTHLY_DIGEST_STATE_DIR/cron.log 2>&1 $MONTHLY_DIGEST_MARKER"

  # Strip ALL managed marker lines from the existing crontab so re-runs
  # replace (not duplicate) every entry, independently.
  local current
  current=$(crontab -l 2>/dev/null \
    | grep -vF "$CRON_MARKER" \
    | grep -vF "$SCHEDULE_DRAFT_MARKER" \
    | grep -vF "$AUTO_REFLECT_MARKER" \
    | grep -vF "$WEEKLY_DIGEST_MARKER" \
    | grep -vF "$MONTHLY_DIGEST_MARKER" \
    || true)

  {
    if [[ -n "$current" ]]; then printf '%s\n' "$current"; fi
    printf '%s\n' "$sync_entry"
    printf '%s\n' "$sched_entry"
    printf '%s\n' "$reflect_entry"
    printf '%s\n' "$digest_entry"
    printf '%s\n' "$monthly_entry"
  } | crontab -

  c_green "  cron entries installed"
  echo "  $sync_entry"
  echo "  $sched_entry"
  echo "  $reflect_entry"
  echo "  $digest_entry"
  echo "  $monthly_entry"
}

# ----- smoke test ---------------------------------------------------------
smoke_one() {
  local name="$1" cmd_path="$2" state_dir="$3"
  shift 3
  c_bold "  smoke: $name"
  if "$@" "$cmd_path"; then
    c_green "    ok"
  else
    c_yellow "    $name smoke test exited non-zero (check $state_dir/)"
  fi
}

smoke_test() {
  step "Running smoke tests"
  # workspace-sync runs for real (network-light, idempotent).
  smoke_one "workspace-sync" "$SCRIPT_DEST" "$STATE_DIR"
  if [[ -f "$STATE_DIR/last-run.json" ]]; then cat "$STATE_DIR/last-run.json"; fi

  # The three new scripts use DRY_RUN=1 so they don't spawn amp or mutate
  # journal files during install. Non-zero exits are reported but don't fail
  # the installer — a clean workspace can legitimately produce them.
  smoke_one "schedule-draft" "$SCHEDULE_DRAFT_DEST" "$SCHEDULE_DRAFT_STATE_DIR" env DRY_RUN=1
  smoke_one "auto-reflect"   "$AUTO_REFLECT_DEST"   "$AUTO_REFLECT_STATE_DIR"   env DRY_RUN=1
  smoke_one "weekly-digest"  "$WEEKLY_DIGEST_DEST"  "$WEEKLY_DIGEST_STATE_DIR"  env DRY_RUN=1
  smoke_one "monthly-digest" "$MONTHLY_DIGEST_DEST" "$MONTHLY_DIGEST_STATE_DIR" env DRY_RUN=1
}

# ----- summary ------------------------------------------------------------
summary() {
  echo
  c_green "Done."
  echo "  Repo:           $REPO"
  echo "  Scripts:"
  echo "    $SCRIPT_DEST                 (every 5 min)"
  echo "    $SCHEDULE_DRAFT_DEST         (22:00 daily)"
  echo "    $AUTO_REFLECT_DEST           (22:30 daily)"
  echo "    $WEEKLY_DIGEST_DEST          (22:00 Sun)"
  echo "    $MONTHLY_DIGEST_DEST         (06:00 on day 1 of each month)"
  echo "  State dirs:"
  echo "    $STATE_DIR"
  echo "    $SCHEDULE_DRAFT_STATE_DIR"
  echo "    $AUTO_REFLECT_STATE_DIR"
  echo "    $WEEKLY_DIGEST_STATE_DIR"
  echo "    $MONTHLY_DIGEST_STATE_DIR"
  echo
  echo "Useful commands:"
  echo "  crontab -l                                    # view installed entries"
  echo "  tail -f $STATE_DIR/sync.log"
  echo "  tail -f $SCHEDULE_DRAFT_STATE_DIR/run.log"
  echo "  tail -f $AUTO_REFLECT_STATE_DIR/run.log"
  echo "  tail -f $WEEKLY_DIGEST_STATE_DIR/run.log"
  echo "  tail -f $MONTHLY_DIGEST_STATE_DIR/run.log"
  echo
  echo "To remove all managed cron entries:"
  echo "  crontab -l \\"
  echo "    | grep -vF '$CRON_MARKER' \\"
  echo "    | grep -vF '$SCHEDULE_DRAFT_MARKER' \\"
  echo "    | grep -vF '$AUTO_REFLECT_MARKER' \\"
  echo "    | grep -vF '$WEEKLY_DIGEST_MARKER' \\"
  echo "    | grep -vF '$MONTHLY_DIGEST_MARKER' \\"
  echo "    | crontab -"
}

# ----- main ---------------------------------------------------------------
main() {
  c_bold "workspace knowledge-base setup (Linux, cron)"
  check_prereqs
  check_templates
  setup_repo
  install_scripts
  install_cron
  smoke_test
  summary
}

main "$@"
