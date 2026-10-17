---
name: workspace
description: Prepare an isolated checkout and branch for a change, and release it afterwards. Reuses a Toshi worktree or devslot, falls back to a temporary git worktree. Used by pr, execute-plan, simplify, and loop before they edit a repo.
---

Input: the repo (default: the current one), a branch `<type>/<slug>`, and a base (default `<default>`; a stacked change uses its parent's branch). Optional note for slot bookkeeping. Optional `isolated`: the caller may throw the change away (a report run, a loop), so never edit a checkout in place.

**Branch name:** `<type>/<slug>`. `<type>` is the change's conventional-commit type (`feat`, `fix`, `perf`, `refactor`, `chore`, `docs`, `test`); `<slug>` is a short kebab-case summary.

## Prepare

Read the repo's guidance files. Bare layout (`.bare/` plus a `.git` file): never work in the parent; the default worktree is `<repo>/main` or `<repo>/master`. Then use the first case that applies:

0. **Handed a workspace**: the caller gave you a path and branch (e.g. `execute-plan` to `pr-worker`). Use it as is and leave Release to the caller.
1. **Direct repo**, not `isolated`: its top level is listed in `~/.config/dotfiles/reposync` (`~` is home; ignore trailing slashes and `#` comments). Work in the checkout on the default branch after `git pull --rebase --autostash`. No branch. Leave other uncommitted changes alone and stage only your own files.
2. **Toshi or automation worktree**: the repo's resolved path (`git rev-parse --show-toplevel` after `pwd -P`) is under `~/.mux/`. A workspace member that symlinks out of `~/.mux/` does not count. Work there. On a Toshi-generated branch with a clean tree, `git fetch origin && git switch -c <branch> origin/<base>`.
3. **Slot repo**: `dev<N>` worktrees sit beside the default worktree. `path=$(devslot claim <branch> <repo-root> --note "<note>")` and work in `$path`, which reuses a warm build. Stacked → `git -C "$path" reset -q --hard origin/<base>` on the fresh branch.
4. **Interactive, clean default branch**, not `isolated`: someone is watching the session and the checkout is on its default branch with a clean tree. `git fetch origin && git switch -c <branch> origin/<base>` in place.
5. **Otherwise** (an unattended run, a dirty tree, or another branch checked out): `git fetch origin && git worktree add "${TMPDIR:-/tmp}/ws-<repo>-<slug>" -b <branch> origin/<base>` and work there.

Report the path, branch, base, and which case applied.

## Release

When the caller is done:

- Slot → `devslot release <path>`. It refuses dirty or unpushed trees; resolve that, never force. A run that pushes nothing (a report) first runs `git -C <path> switch -q --detach origin/<default>`: the branch keeps its commits and the slot frees.
- Temporary worktree → `git worktree remove <path>`. The branch stays.
- Case 4 → `git switch <default>`.
- Direct repo or Toshi worktree → nothing.

## Rules

- One change per workspace; never use one workspace for two changes at once.
- Never edit a checkout that has uncommitted changes you did not make.
- Create worktrees only through case 5.
