---
name: pr
description: Set up a worktree, implement the work, ship as a draft PR, then iterate on review and CI until ready.
---

## 1. Input + repo

`$ARGUMENTS` describes the work. Plan file path → read as spec. Free text → search `~/src/workspace/projects/**/plans/*.md`. Ambiguous → ask. No plan found → draft one at `~/src/workspace/projects/{work,personal}/<project>/plans/<plan-name>.md`, present it, and wait for explicit confirmation before proceeding.

Parse `in <repo>` suffix (e.g. `/pr add cache in base`). Otherwise load `repos` skill. Ambiguous → ask.

## 2. New worktree (always)

Bare layout (`.bare/` exists): `cd ~/src/<repo>/main`. Standard: `cd ~/src/<repo>`. Run `gwa <prefix>/<slug>`. Capture `$WORKTREE_PATH` via `pwd`.

Branch prefixes: `feat|fix|refactor|chore|docs|perf|test|ci|hotfix|style`. Slug ≤40 chars, lowercase, hyphens.

## 3. Implement

Use absolute paths from `$WORKTREE_PATH`. Test and verify with diagnostics/build before committing.

## 4. Draft PR

Commit. Push. `gh pr create --draft`.

Description: succinct. Title states the change. Body is 1–3 sentences (why + what). No ticket numbers, no external references.

## 5. CI green

`gh pr checks --watch`. On failure: fix, push, repeat until green.

## 6. Iterate on reviews

Poll `gh pr view --comments` and `gh api repos/{owner}/{repo}/pulls/{N}/comments`. For each unresolved thread:

- Address with code OR reply with reasoning
- Push, re-watch CI
- Resolve thread when handled

Loop until all threads resolved AND CI green.
