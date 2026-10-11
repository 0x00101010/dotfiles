#!/usr/bin/env bash
# Run reposync every 5 minutes from the user crontab; other entries are kept.
set -euo pipefail

command -v crontab >/dev/null || { echo "[chezmoi] crontab not found; reposync is not scheduled" >&2; exit 0; }
marker='# reposync (managed by chezmoi)'
entry="*/5 * * * * \"\$HOME/.local/bin/reposync\" $marker"
current=$(crontab -l 2>/dev/null || true)
grep -qxF -- "$entry" <<< "$current" && exit 0
{ [ -z "$current" ] || grep -vF -- "$marker" <<< "$current" || true; echo "$entry"; } | crontab -
echo "[chezmoi] Scheduled reposync every 5 minutes in the user crontab"
