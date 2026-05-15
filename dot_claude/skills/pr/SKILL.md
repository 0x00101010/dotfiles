---
name: pr
description: Set up a worktree, implement the work, ship as a draft PR, then iterate on review and CI until ready.
---

## 1. Input + repo

`$ARGUMENTS` describes the work. Accept:

- Free text (e.g. `add cache to base`)
- Linear identifier or URL (e.g. `ENG-1234`, `https://linear.app/...`) → fetch via Linear MCP for spec
- GitHub issue URL → fetch via `gh issue view` for spec

Ambiguous → ask ONE clarifying question. Do NOT search for or read local plan files.

Parse `in <repo>` suffix (e.g. `/pr add cache in base`). Otherwise load `repos` skill. Ambiguous → ask.

## 2. New worktree (always)

Bare layout (`.bare/` exists): `cd ~/src/<repo>/main`. Standard: `cd ~/src/<repo>`. Run `gwa <prefix>/<slug>`. Capture `$WORKTREE_PATH` via `pwd`.

Branch prefixes: `feat|fix|refactor|chore|docs|perf|test|ci|hotfix|style`. Slug ≤40 chars, lowercase, hyphens.

## 3. Implement

Use absolute paths from `$WORKTREE_PATH`. Test and verify with diagnostics/build before committing.

Solution: succinct. Minimum code that solves the problem. No speculative abstractions, no unrelated cleanup, no jargon-heavy comments.

## 4. Draft PR

Commit. Push. `gh pr create --draft`.

Each PR stands alone. Even if it came from a multi-PR plan, the title and body MUST NOT reveal that — no `(PR B)`, `[1/3]`, `Part 2 of 4`, "follow-up PRs land next", or any plan/sequencing reference. Reviewers see one self-contained change.

**Title**: plain words describing the change. Conventional-commit prefix optional (`feat(scope):`, `fix(scope):`). Nothing else.

**Body**: 1–3 sentences explaining *why* and *what*. No headers, no tables, no bullet lists, no `## Summary` / `## What` / `## Tests` sections, no ticket numbers, no test-run output, no boilerplate. Reviewers read the diff for details.

**Good example** (entire body):

> Adds a --conductor-rpc bootstrap flag and DiscoveryConfig so basectl can derive the live raft peer list from a single conductor by polling clusterMembership and applying port templates.

## 5. Iterate until ready (mandatory loop)

After the draft PR is open, you MUST NOT return control to the user until **both**:

- CI is green
- Every unresolved review thread has been addressed (code change OR reply with reasoning) AND resolved

Loop:

1. Wait for CI to complete.
2. If any check failed → diagnose, fix the root cause (no skipping/disabling tests), push, GOTO 1.
3. Pull all review threads (top-level + inline).
4. For each unresolved thread: address with code OR reply with concise reasoning, then resolve it.
5. If anything was pushed in step 2 or 4 → GOTO 1.
6. When CI is green AND no unresolved threads remain → report PR URL and stop.

Return to the user early ONLY when:

- A reviewer's feedback requires a scope/design decision you cannot make alone.
- Same CI failure persists after 3 fix attempts → summarize what was tried, ask.
- A thread asks a question only the user can answer.

Do not return on a green-but-unresolved PR. Do not return on an unresolved-but-green PR. Both must hold.
