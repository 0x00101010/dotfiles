#!/usr/bin/env bash
# setup-mac-knowledge-base.sh
#
# Explicit, re-runnable installer for the workspace knowledge-base sync system
# on macOS. Sets up:
#   1. ~/src/workspace clone (or your chosen path)
#   2. ~/.local/bin/workspace-sync   (every 5 min)
#   3. ~/.local/bin/schedule-draft   (22:00 daily)
#   4. ~/.local/bin/auto-reflect     (22:30 daily)
#   5. ~/.local/bin/weekly-digest    (22:00 Sun)
#   6. ~/Library/LaunchAgents/com.francis.{workspace-sync,schedule-draft,auto-reflect,weekly-digest}.plist
#
# Idempotent: safe to re-run. Won't re-clone an existing repo, won't duplicate
# launchd entries. Re-running overwrites each script with the latest template
# from this dotfiles checkout, and rewrites each plist from the inline content
# in install_launchd_agents() below.
#
# Companion: setup-linux-knowledge-base.sh
# Plan:      plans/workspace-sync.md

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KB_DIR="$SCRIPT_DIR/knowledge-base"
readonly DEFAULT_REPO="$HOME/src/workspace"
readonly REPO_URL="git@github.com:0x00101010/workspace.git"
readonly LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

readonly LABEL="com.francis.workspace-sync"
readonly PLIST="$LAUNCH_AGENTS_DIR/$LABEL.plist"
readonly SCRIPT_DEST="$HOME/.local/bin/workspace-sync"
readonly STATE_DIR="$HOME/.local/state/workspace-sync"

readonly SCHEDULE_DRAFT_LABEL="com.francis.schedule-draft"
readonly SCHEDULE_DRAFT_PLIST="$LAUNCH_AGENTS_DIR/$SCHEDULE_DRAFT_LABEL.plist"
readonly SCHEDULE_DRAFT_DEST="$HOME/.local/bin/schedule-draft"
readonly SCHEDULE_DRAFT_STATE_DIR="$HOME/.local/state/schedule-draft"

readonly AUTO_REFLECT_LABEL="com.francis.auto-reflect"
readonly AUTO_REFLECT_PLIST="$LAUNCH_AGENTS_DIR/$AUTO_REFLECT_LABEL.plist"
readonly AUTO_REFLECT_DEST="$HOME/.local/bin/auto-reflect"
readonly AUTO_REFLECT_STATE_DIR="$HOME/.local/state/auto-reflect"

readonly WEEKLY_DIGEST_LABEL="com.francis.weekly-digest"
readonly WEEKLY_DIGEST_PLIST="$LAUNCH_AGENTS_DIR/$WEEKLY_DIGEST_LABEL.plist"
readonly WEEKLY_DIGEST_DEST="$HOME/.local/bin/weekly-digest"
readonly WEEKLY_DIGEST_STATE_DIR="$HOME/.local/state/weekly-digest"

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

  if ! command -v amp >/dev/null && [[ ! -x "$HOME/.local/bin/amp" ]]; then
    c_yellow "  (optional) amp not found — schedule-draft will fail until amp is installed"
    c_yellow "             (expected at $HOME/.local/bin/amp or on PATH; auto-reflect & weekly-digest don't need it)"
  fi

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
  local t
  for t in workspace-sync schedule-draft auto-reflect weekly-digest; do
    [[ -f "$KB_DIR/$t" ]] || abort "Missing template in $KB_DIR: $t"
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
  mkdir -p "$STATE_DIR" "$SCHEDULE_DRAFT_STATE_DIR" "$AUTO_REFLECT_STATE_DIR" "$WEEKLY_DIGEST_STATE_DIR"
}

# ----- install launchd agents ---------------------------------------------
# Use StartCalendarInterval (not StartInterval): launchd makes up one missed
# run on wake from sleep, whereas StartInterval silently drops missed ticks.
# No WatchPaths: it's scope-limited (only direct children, no recursion) and
# the 5-min poll already catches edits anywhere in the repo.
install_one_launchd() {
  local label="$1" plist_path="$2" plist_xml="$3"
  mkdir -p "$(dirname "$plist_path")"
  printf '%s' "$plist_xml" > "$plist_path"
  launchctl unload "$plist_path" 2>/dev/null || true
  launchctl load -w "$plist_path"
  c_green "  loaded → $label"
}

install_launchd_agents() {
  step "Installing LaunchAgents"
  mkdir -p "$LAUNCH_AGENTS_DIR"

  local env_path="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"

  # ----- workspace-sync: every 5 min wall-clock + RunAtLoad ---------------
  local workspace_sync_xml
  IFS= read -r -d '' workspace_sync_xml <<EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$SCRIPT_DEST</string>
  </array>

  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Minute</key><integer>0</integer></dict>
    <dict><key>Minute</key><integer>5</integer></dict>
    <dict><key>Minute</key><integer>10</integer></dict>
    <dict><key>Minute</key><integer>15</integer></dict>
    <dict><key>Minute</key><integer>20</integer></dict>
    <dict><key>Minute</key><integer>25</integer></dict>
    <dict><key>Minute</key><integer>30</integer></dict>
    <dict><key>Minute</key><integer>35</integer></dict>
    <dict><key>Minute</key><integer>40</integer></dict>
    <dict><key>Minute</key><integer>45</integer></dict>
    <dict><key>Minute</key><integer>50</integer></dict>
    <dict><key>Minute</key><integer>55</integer></dict>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>ThrottleInterval</key>
  <integer>30</integer>

  <key>ProcessType</key>
  <string>Background</string>

  <key>LowPriorityIO</key>
  <true/>

  <key>Nice</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>$STATE_DIR/launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>$STATE_DIR/launchd.err.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$env_path</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF
  install_one_launchd "$LABEL" "$PLIST" "$workspace_sync_xml"

  # ----- schedule-draft: 22:00 daily --------------------------------------
  local schedule_draft_xml
  IFS= read -r -d '' schedule_draft_xml <<EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$SCHEDULE_DRAFT_LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$SCHEDULE_DRAFT_DEST</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>22</integer>
    <key>Minute</key><integer>0</integer>
  </dict>

  <key>ProcessType</key>
  <string>Background</string>

  <key>LowPriorityIO</key>
  <true/>

  <key>Nice</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>$SCHEDULE_DRAFT_STATE_DIR/launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>$SCHEDULE_DRAFT_STATE_DIR/launchd.err.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$env_path</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF
  install_one_launchd "$SCHEDULE_DRAFT_LABEL" "$SCHEDULE_DRAFT_PLIST" "$schedule_draft_xml"

  # ----- auto-reflect: 22:30 daily ----------------------------------------
  local auto_reflect_xml
  IFS= read -r -d '' auto_reflect_xml <<EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$AUTO_REFLECT_LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$AUTO_REFLECT_DEST</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>22</integer>
    <key>Minute</key><integer>30</integer>
  </dict>

  <key>ProcessType</key>
  <string>Background</string>

  <key>LowPriorityIO</key>
  <true/>

  <key>Nice</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>$AUTO_REFLECT_STATE_DIR/launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>$AUTO_REFLECT_STATE_DIR/launchd.err.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$env_path</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF
  install_one_launchd "$AUTO_REFLECT_LABEL" "$AUTO_REFLECT_PLIST" "$auto_reflect_xml"

  # ----- weekly-digest: Sunday 22:00 (Weekday=0) --------------------------
  local weekly_digest_xml
  IFS= read -r -d '' weekly_digest_xml <<EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$WEEKLY_DIGEST_LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$WEEKLY_DIGEST_DEST</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>22</integer>
    <key>Minute</key><integer>0</integer>
    <key>Weekday</key><integer>0</integer>
  </dict>

  <key>ProcessType</key>
  <string>Background</string>

  <key>LowPriorityIO</key>
  <true/>

  <key>Nice</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>$WEEKLY_DIGEST_STATE_DIR/launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>$WEEKLY_DIGEST_STATE_DIR/launchd.err.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$env_path</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
</dict>
</plist>
EOF
  install_one_launchd "$WEEKLY_DIGEST_LABEL" "$WEEKLY_DIGEST_PLIST" "$weekly_digest_xml"
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
  smoke_one "workspace-sync" "$SCRIPT_DEST" "$STATE_DIR"
  if [[ -f "$STATE_DIR/last-run.json" ]]; then cat "$STATE_DIR/last-run.json"; fi

  # DRY_RUN=1 so smoke tests don't spawn amp or mutate journal files.
  smoke_one "schedule-draft" "$SCHEDULE_DRAFT_DEST" "$SCHEDULE_DRAFT_STATE_DIR" env DRY_RUN=1
  smoke_one "auto-reflect"   "$AUTO_REFLECT_DEST"   "$AUTO_REFLECT_STATE_DIR"   env DRY_RUN=1
  smoke_one "weekly-digest"  "$WEEKLY_DIGEST_DEST"  "$WEEKLY_DIGEST_STATE_DIR"  env DRY_RUN=1
}

# ----- summary ------------------------------------------------------------
summary() {
  echo
  c_green "Done."
  echo "  Repo:           $REPO"
  echo "  Scripts:"
  echo "    $SCRIPT_DEST                 (every 5 min wall-clock + RunAtLoad)"
  echo "    $SCHEDULE_DRAFT_DEST         (22:00 daily)"
  echo "    $AUTO_REFLECT_DEST           (22:30 daily)"
  echo "    $WEEKLY_DIGEST_DEST          (22:00 Sunday)"
  echo "  LaunchAgents:"
  echo "    $PLIST"
  echo "    $SCHEDULE_DRAFT_PLIST"
  echo "    $AUTO_REFLECT_PLIST"
  echo "    $WEEKLY_DIGEST_PLIST"
  echo
  echo "Useful commands:"
  echo "  tail -f $STATE_DIR/sync.log"
  echo "  tail -f $SCHEDULE_DRAFT_STATE_DIR/run.log"
  echo "  tail -f $AUTO_REFLECT_STATE_DIR/run.log"
  echo "  tail -f $WEEKLY_DIGEST_STATE_DIR/run.log"
  echo "  launchctl list | grep com.francis      # verify loaded"
  echo "  launchctl unload <plist>               # pause an agent"
}

# ----- main ---------------------------------------------------------------
main() {
  c_bold "workspace knowledge-base setup (macOS)"
  check_prereqs
  check_templates
  setup_repo
  install_scripts
  install_launchd_agents
  smoke_test
  summary
}

main "$@"
