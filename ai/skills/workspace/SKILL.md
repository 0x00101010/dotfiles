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

## Environment

`envrun env <org/repo>` names where this repo is worked on (`~/.config/dotfiles/environments`; unlisted repos are `local`; no `envrun` on PATH means everything is `local`). `local` → the cases above.

Any other environment → the workspace is a dev slot on that host, and nothing is checked out locally: `envrun claim <env> <org/repo> <branch> origin/<base> --note "<note>"` prints the remote slot path (the branch starts at `origin/<base>`). Report the environment and that path. All work then happens there:

- Read and search: `envrun exec <env> <path> -- <cmd>` (`rg -n`, `sed -n 'a,bp' <file>`, `git diff`, `git log`). Keep output small; narrow with `rg` before reading. Anything multi-line or with nested quotes goes on stdin: `envrun exec <env> <path> -- <<'SH' ... SH`.
- Edit: write a unified diff and pipe it to `envrun patch <env> <path>`; it runs `git apply --check` first, so a stale diff changes nothing, and recounts hunk line numbers, so only the context and `-`/`+` lines must be exact. Reread the hunk after it applies. New and deleted files go through the same diff.
- Git: commit and push there with `envrun exec` (`git add <paths> && git commit -m ...`, `git push -u origin <branch>`). Create the PR from here with `gh pr create -R <org>/<repo> --head <branch>`.
- Builds and tests: the `check` skill runs them in the slot.
- Every command another skill gives (`git reset --hard HEAD`, `git revert`, `git diff --numstat`, `git log`) runs in the slot through `envrun exec`; never against a local copy.

## Release

When the caller is done:

- Slot → `devslot release <path>`. It refuses dirty or unpushed trees; resolve that, never force. A run that pushes nothing (a report) first runs `git -C <path> switch -q --detach origin/<default>`: the branch keeps its commits and the slot frees.
- Temporary worktree → `git worktree remove <path>`. The branch stays.
- Case 4 → `git switch <default>`.
- Direct repo or Toshi worktree → nothing.
- Remote slot → `envrun release <env> <path>`. It refuses uncommitted or unpushed work; after a run that pushes nothing (a report), use `--keep-branch`, which keeps the commits on the branch.

## Rules

- One change per workspace; never use one workspace for two changes at once.
- Never edit a checkout that has uncommitted changes you did not make.
- Create worktrees only through case 5.
