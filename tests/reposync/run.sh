#!/usr/bin/env bash
# reposync and its cron hook against throwaway repos and a stub crontab.
# Usage: tests/reposync/run.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
REPOSYNC="$REPO/home/dot_local/bin/executable_reposync"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
fails=0

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
       GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t HOME="$TMP/home"
unset XDG_CONFIG_HOME XDG_STATE_HOME REPOSYNC_CONFIG
CONFIG="$HOME/.config/dotfiles/reposync"
LOG="$HOME/.local/state/reposync/log"
mkdir -p "$HOME"

old() { touch -t 200001010000 "$@"; }  # outside the 1-minute quiet window
sync() { "$REPOSYNC" > /dev/null; }
remote_commit() {  # file content: commit to origin from another clone
  echo "$2" > "$TMP/other/$1" && git -C "$TMP/other" add -A && git -C "$TMP/other" commit -qm "remote $1"
  git -C "$TMP/other" push -q origin main
}
subjects() { git -C "$1" log --format=%s "${2:-HEAD}"; }

check "missing config is a no-op" sync

git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/other" 2>/dev/null
remote_commit base.txt base
git clone -q "$TMP/origin.git" "$TMP/local"
mkdir -p "$(dirname "$CONFIG")"
printf '# comment\n%s\n%s\n' "$TMP/local/" "$TMP/missing" > "$CONFIG"

# Uncommitted edit + new upstream commit: auto-commit stacks on top and is pushed.
echo mine > "$TMP/local/mine.txt"; old "$TMP/local/mine.txt"
remote_commit theirs.txt theirs
check "missing repo makes the run fail" bash -c "! '$REPOSYNC' >/dev/null"
check "missing repo is logged" grep -q "$TMP/missing: not a git checkout" "$LOG"
check "local changes committed as auto-sync" bash -c "git -C '$TMP/local' log -1 --format=%s | grep -q '^auto-sync: 1 files \['"
check "auto-sync commit rebased on upstream" [ "$(subjects "$TMP/local" | sed -n 2p)" = "remote theirs.txt" ]
check "history stays linear" [ "$(git -C "$TMP/local" rev-list --merges --count HEAD)" = 0 ]
check "pushed to origin" [ "$(git -C "$TMP/origin.git" rev-parse main)" = "$(git -C "$TMP/local" rev-parse HEAD)" ]
check "worktree clean after sync" [ -z "$(git -C "$TMP/local" status --porcelain)" ]

printf '%s\n' "$TMP/local" > "$CONFIG"
check "in-sync repo is a successful no-op" sync

# Files edited within the last minute are left alone.
echo wip > "$TMP/local/wip.txt"
before=$(git -C "$TMP/local" rev-parse HEAD)
sync
check "fresh edits defer the commit" bash -c "[ \"\$(git -C '$TMP/local' rev-parse HEAD)\" = $before ] && grep -q 'deferred' '$LOG'"
old "$TMP/local/wip.txt"; sync

# Conflict: rebase is aborted, the local commit is kept, nothing is pushed.
git -C "$TMP/other" pull -q
remote_commit base.txt from-remote
echo from-local > "$TMP/local/base.txt"; old "$TMP/local/base.txt"
origin_before=$(git -C "$TMP/origin.git" rev-parse main)
check "conflict makes the run fail" bash -c "! '$REPOSYNC' >/dev/null"
check "conflict logged" grep -q "rebase onto origin/main failed" "$LOG"
check "no rebase left in progress" bash -c "[ ! -d '$TMP/local/.git/rebase-merge' ] && [ ! -d '$TMP/local/.git/rebase-apply' ]"
check "local change kept in a commit" bash -c "[ \"\$(git -C '$TMP/local' show HEAD:base.txt)\" = from-local ] && [ -z \"\$(git -C '$TMP/local' status --porcelain)\" ]"
check "origin untouched (no force push)" [ "$(git -C "$TMP/origin.git" rev-parse main)" = "$origin_before" ]

# Repo mid-merge is skipped without touching anything.
touch "$TMP/local/.git/MERGE_HEAD"
check "repo mid-merge is skipped" bash -c "! '$REPOSYNC' >/dev/null && grep -q 'skipped, MERGE_HEAD present' '$LOG'"
rm "$TMP/local/.git/MERGE_HEAD"

# Cron hook: adds one entry, keeps others, idempotent.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/crontab" <<EOF
#!/bin/sh
if [ "\$1" = -l ]; then cat "$TMP/crontab" 2>/dev/null || { echo "no crontab" >&2; exit 1; }; else cat > "$TMP/crontab"; fi
EOF
chmod +x "$TMP/bin/crontab"
hook() { PATH="$TMP/bin:$PATH" bash "$REPO/home/.chezmoiscripts/run_after_40_schedule_reposync.sh" > /dev/null; }
hook
check "cron entry added to empty crontab" bash -c "[ \$(wc -l < '$TMP/crontab') = 1 ] && grep -q '^\*/5 \* \* \* \* \"\$HOME/.local/bin/reposync\"' '$TMP/crontab'"
printf '0 1 * * * other-job\n*/10 * * * * old/reposync # reposync (managed by chezmoi)\n' > "$TMP/crontab"
hook; hook
check "other entries kept, stale entry replaced, no duplicates" bash -c "[ \$(wc -l < '$TMP/crontab') = 2 ] && grep -q other-job '$TMP/crontab' && ! grep -q old/reposync '$TMP/crontab'"

[ "$fails" = 0 ] || { echo "$fails failure(s)"; exit 1; }
