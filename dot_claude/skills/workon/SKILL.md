---
name: workon
description: Pick up a task from any source (Linear, GitHub, plan file, todos), set up a worktree, auto-escalate to ultrathink subagents or parallel swarms when the task warrants it, then execute.
---

See `_shared/workspace.md` for todo format, source resolution, archive procedure, Linear conventions, repo resolution.

## 1. Resolve input

`$ARGUMENTS`. Apply source resolution from workspace.md:

- Linear ID (`^[A-Z]+-\d+$`) → Linear API + cross-check `LINEAR:` ref in `todos/work.md`
- GitHub (`gh#N`, `owner/repo#N`) → `gh issue view`
- Plan file path → read as spec
- Free text → search `todos/{work,personal}.md` + `projects/**/plans/*.md`

Multiple matches → list, ask. None → ask.

## 2. Resolve repo

Parse `in <repo>` suffix (e.g. `/workon extend blockhash in base`). Otherwise load `repos` skill. Ambiguous → ask.

## 3. Worktree (always, in git repos)

Bare layout (`.bare/` exists): `cd ~/src/<repo>/main`. Standard: `cd ~/src/<repo>`.

Run `gwa <prefix>/<slug>`. Capture `$WORKTREE_PATH` via `pwd`.

Branch prefixes: `feat|fix|refactor|chore|docs|perf|test|ci|hotfix|style`. Slug ≤40 chars, lowercase, hyphens, no Linear/issue IDs in branch names.

## 4. Mode detection (auto, silent unless one fires)

Compute signals from the resolved input (issue body, plan file, description).

**Swarm signals — fire if ANY:**
- Plan file contains `## Workstream`, `## Track`, or numbered parallel sections
- Description names ≥3 distinct domains (frontend + backend + infra, etc.)
- Keywords: "rewrite", "large refactor", "migration", "across services"

**Ultrathink signals — fire if ANY (only when swarm did NOT fire):**
- Linear priority P0 or P1
- Plan file contains "design", "architecture", "tradeoff", "decision record"
- Description contains "complex", "hard", "investigate", "figure out"
- Linear issue body >500 chars
- Multi-system mention (auth+db, frontend+backend, etc.)

If swarm fires, ultrathink is implied for each swarm member (don't double-announce).

**Announce when activating:**
> *"Detected [signal] → activating [mode]. Reply 'skip' to override and execute directly."*

Wait for explicit acknowledgment OR proceed if user doesn't object within the same turn.

## 5. Mark in-progress

- Linear → "In Progress"
- GitHub → assign self, label `in-progress`
- Todos file → leave as `- [ ]` (don't check)

## 6. Execute

Use absolute paths from `$WORKTREE_PATH`.

- **No mode** → implement directly. Test, iterate, verify with diagnostics/build.
- **Ultrathink** → spawn deep-thinking subagents. Persist learnings between them; share what each discovers. Orchestrate; don't do the work yourself.
- **Swarm** → break into domain-specific swarms. Each swarm: leader, clear objective, success criteria. Define integration contracts upfront (API shapes, shared types, data formats). Share context proactively; kill stalled swarms; rebalance. Integrate deliverables, validate against the original objective.

## 7. When user says done (never auto)

- Apply archive procedure from workspace.md
- Linear/GitHub → status update
- Plan file → move to `plans/done/`
- Commit changes
- Suggest (don't auto-create) plan files if work involved design/analysis
- Do NOT create PRs or remove worktrees unless asked
