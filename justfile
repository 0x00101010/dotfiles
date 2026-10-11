# Run from the repo root: `just <recipe>`. `just` alone lists recipes.

default:
    @just --list

# First-time or changed answers: chezmoi init (pass --prompt to re-answer everything)
setup *args:
    chezmoi init {{ args }}

# Apply dotfiles to $HOME (extra args go to chezmoi apply)
apply *args:
    chezmoi apply -v --no-pager {{ args }}

# Show what apply would change
diff *args:
    chezmoi diff --no-pager {{ args }}

# Run every check; none touch the real home
test:
    tests/bootstrap/run.sh
    python3 tests/agents/test_wiring.py
    tests/devslot/run.sh
    tests/skillsync/run.sh
    tests/reposync/run.sh

# Sync the repos in ~/.config/dotfiles/reposync now
sync:
    ~/.local/bin/reposync

# Recent reposync runs from cron
sync-log:
    tail -n 40 ~/.local/state/reposync/log

# Amp runner status and the directories it serves
runner:
    systemctl --user status amp-runner --no-pager
    amp runner list

# Recent Amp runner log
runner-log:
    journalctl --user -u amp-runner -n 40 --no-pager

# Copy skills from the repos in ~/.config/dotfiles/skill-sources
skills:
    ai/bin/skillsync

# Open the local config files (reposync, skill-sources)
config:
    ${EDITOR:-vi} ~/.config/dotfiles
