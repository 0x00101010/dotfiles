---
name: task
description: Pick up a task from workspace todos, set up a worktree, and work on it
---

## 1. Find the task

Given `$ARGUMENTS`. Task format: `- [ ] P{0-3} | description | optional:SOURCE-REF` with optional `  > context` lines.

- **Linear issue ID** (e.g. `ENG-123`): fetch via Linear API. Also check `~/src/workspace/todos/work.md` for matching `LINEAR:` ref.
- **Otherwise**: search `~/src/workspace/todos/{work,personal}.md` (description field) and `~/src/workspace/projects/**/plans/*.md` (match against filenames).
- Multiple matches → show candidates, let user pick. Plan file selected → use as task spec. No match → ask.

## 2. Resolve the repo

Parse `in <repo>` suffix (e.g. `/task extend blockhash in base`) → use directly.

Otherwise load the `repos` skill and use the registry to map the task topic → repo. Ambiguous after that → ask.

## 3. Create a worktree

For bare-repo layouts (`.bare` dir): `cd ~/src/<repo>/main`. Standard repos: `cd ~/src/<repo>`.

Run `gwa <prefix>/<slug>` to create worktree. Capture `$WORKTREE_PATH` via `pwd`.

Branch prefixes: `feat/`, `fix/`, `refactor/`, `chore/`, `docs/`, `perf/`, `test/`, `ci/`, `hotfix/`, `style/`. Slug: lowercase, hyphens, ~40 chars max. No Linear IDs in branch names.

## 4. Mark in-progress

Linear issue exists → update to "In Progress". Todos file: leave as `- [ ]`.

## 5. Work

Implement, test, iterate. Use absolute paths based on `$WORKTREE_PATH`.

## 6. When user says done

**Never auto-complete.** Only when user explicitly says done:

- Archive task: move line + context from `todos/{work,personal}.md` → `todos/archive.md` as `- [x] P{n} | description | optional:ref | YYYY-MM-DD` under `## YYYY-MM` heading.
- Linear issue → update status. Plan file → move to `plans/done/`.
- Commit changes. Suggest (don't auto-create) plan files if work involved design/analysis.
- Do NOT create PRs or clean up worktrees unless asked.
