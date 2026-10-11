---
name: execute-plan
description: Execute an existing implementation plan phase by phase. Use for "execute the plan", "run the plan", "implement <plan>", or when handed a plan path. Resolves each phase's repo and workspace, runs each PR-ready slice through the pr skill, and records progress in the plan file.
---

Read `~/.agents/skills/_shared/instructions.md` for the plan root, repo registry, and checkout layout. Refer to `plan` for the plan format and `pr` for how each slice is shipped. Invoking this skill authorizes creating branches, pushing them, opening draft PRs for the plan's slices, and rebasing stacked PRs once their parent merges — nothing else.

## 1. Resolve the plan

`$ARGUMENTS` is a plan path or a name under the plan root (`<plan-root>/*/plans/<name>.md`). Read it in full.

- No `## Phase` headings → run `plan` first and confirm before executing.
- `## Open questions` lists a blocker → stop and ask; do not guess.
- A phase already marked `**Status:** done` → skip it.
- The user names a phase → run only that phase.

## 2. Build the waves

Each phase is one slice unless its `**PR boundary:**` says `Not a PR boundary`, in which case merge it into the next phase's slice.

A slice is ready when every `**Depends on:**` entry is met: `(merged)` → that phase's PR is merged (`gh pr view <url> --json state`); `(stacked)` → that phase is done. Older plans without `**Depends on:**`: follow `## Implementation order` and `**Parallelizable:**`, treating each sequential phase as `(merged)` on the one before.

First, for each done `(stacked)` phase whose parent PR has merged: in a workspace from step 3, check out its branch, run `git rebase --onto origin/<default> <parent-head>` (parent head: `gh pr view <parent-url> --json headRefOid`), `git push --force-with-lease`, and `gh pr edit <url> --base <default>`. Conflicts → `git rebase --abort` and report it.

Start every ready slice at once; when one finishes, start whatever became ready. Slot repos limit themselves (`devslot claim` waits when no slot is free). Repos without slots run one slice at a time per repo, because one checkout holds one branch. Slices still waiting on an unmerged PR stay pending: report them and stop; rerunning the skill picks them up.

## 3. Workspace per slice

Resolve `**Repo:**` through the registry (fall back to `in <repo>` text or the current repo; ambiguous → ask). Then:

- Slot repo (`dev<N>` beside the default worktree): `path=$(devslot claim <branch> <repo-root> --note "<plan>:<phase>")`; stacked → then `git -C "$path" reset -q --hard origin/<base>` on the fresh branch.
- Otherwise: in the default checkout, require a clean tree, then `git fetch origin && git switch -c <branch> origin/<base>`.

Base: `<default>`, or for a `(stacked)` dependency, that phase's branch. Branch: `<prefix>/<slug>`, prefix from `## Handoff to PR skill`; default prefix is the user's usual one in that repo (`git log --author`), slug from the phase name.

## 4. Run the slice

Hand the slice to a subagent with the available subagent tool. Give it: the absolute workspace path, the branch, the base branch when stacked (for `gh pr create --base`), the phase text verbatim (objective, actions, verification, exit criteria), and the instruction to follow the `pr` skill and work only in that directory. Require its final message to contain the PR URL, the checks it ran, and anything left undone.

When it returns:

- Slot repo → `devslot release <path>` (it refuses dirty or unpushed trees; resolve that first, do not force).
- Otherwise → `git switch <default>` in that checkout.
- Append under the phase heading: `**Status:** done — <PR URL>`, or `**Status:** blocked — <one line>` and stop the dependent waves.

Only these status lines may be written into the plan; leave every other line as is.

## 5. Report

When no slice is ready: list each phase with its PR URL, blocker, or the merge it waits on; slots released; stacked PRs rebased or with rebase conflicts; and anything the user must decide. Do not merge, transition issues, or force-push beyond the stacked rebase.

## Rules

- Never fabricate PR URLs or check results; quote the subagent's evidence.
- One slice per branch; never reuse a workspace for two slices at once.
- Do not edit plan prose, reorder phases, or start phases the plan marks blocked.
- Stop and ask when a wave fails rather than retrying with a different design.
