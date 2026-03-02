---
name: task
description: Pick up a task from workspace todos or Linear, set up a worktree, and work on it
---

You are a coding agent picking up a task. Follow these steps in order.

## Step 1 — Find the task

Given: `$ARGUMENTS`

- **Linear issue ID** (e.g. `ENG-123`): fetch via `mcp__linear__get_issue`. Also check `~/src/workspace/todos/work.md` and `personal.md` for a related checkbox entry.
- **Otherwise**: search all three sources below for matches:
  1. `~/src/workspace/todos/work.md` and `~/src/workspace/todos/personal.md` — checkbox lines matching the text
  2. `~/src/workspace/plans/` — list all `.md` files recursively, match `$ARGUMENTS` against filenames (slugified, e.g. "extend blockhash" matches `extend-blockhash.md`)
- If **multiple matches** across todos and plans: show all candidates and let the user pick.
- If a **plan file** is selected: read its contents and use them as the task specification in Step 5.
- If **no match**: ask the user to clarify.

## Step 2 — Resolve the repo

There is no static mapping. Figure it out dynamically:

1. Run `ls ~/src/` to see available repos.
2. Use the task context (category name from the todos heading, description, keywords) to infer which repo is relevant.
3. The user can also specify the repo inline (e.g. `/task extend blockhash in base`). Parse the `in <repo>` suffix if present.
4. If the task spans multiple repos, ask which to start with.
5. If ambiguous, ask — one question, not a config file.

## Step 3 — Create a worktree

1. `cd` to the resolved repo's main worktree. For bare-repo layouts (`.bare` directory), `cd ~/src/<repo>/main`. For standard repos, `cd ~/src/<repo>`.
2. Run `gwa <prefix>/<slug>` to create and enter the worktree. This shell function is defined in `~/.zsh/git-worktree.zsh` and handles worktree creation + cd.

**Branch naming** — pick the prefix based on task nature:

| Prefix | When |
|---|---|
| `feat/` | New feature or capability |
| `fix/` | Bug fix |
| `refactor/` | Code restructuring, no behavior change |
| `chore/` | Maintenance, deps, config |
| `docs/` | Documentation only |
| `perf/` | Performance improvement |
| `test/` | Adding or fixing tests |
| `ci/` | CI/CD pipeline changes |
| `hotfix/` | Urgent production fix |
| `style/` | Formatting, no logic change |

**Slug rules**: lowercase, hyphens, max ~40 chars. Examples: `feat/extend-blockhash`, `fix/qmdb-key-format`.

Never include Linear issue IDs in branch names — reference them in PR descriptions instead.

## Step 4 — Mark in-progress

- If a corresponding Linear issue exists: update status to "In Progress" via `mcp__linear__save_issue`.
- Todos file: leave as `- [ ]` (no change).

## Step 5 — Work on the task

Proceed with the actual work described by `$ARGUMENTS`. You are now in the worktree — implement, test, iterate.

## Step 6 — When the user says done

**Never auto-complete.** Only act when the user explicitly says the task is done.

When they do:
- Mark `- [ ]` to `- [x]` in the corresponding `~/src/workspace/todos/{work,personal}.md` file.
- If a corresponding Linear issue exists: update its status via `mcp__linear__save_issue`.
- If working from a plan file: move it to `~/src/workspace/plans/done/<project>/<plan-name>.md` (create the `done/<project>/` directory if needed).
- Commit changes in the worktree.
- If the work involved design/analysis: **suggest** (don't auto-create) a plan file at `~/src/workspace/projects/{work,personal}/<project>/<name>.md`.
- Do NOT create PRs, clean up worktrees, or perform other lifecycle actions unless explicitly asked.
