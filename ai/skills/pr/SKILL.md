---
name: pr
description: Implement work, simplify and self-review it, ship it as a draft PR, then iterate on review and CI until ready.
---

Goal: a PR a reviewer can approve on first read. Small diff, self-reviewed, concise prose.

## Rules

These apply to every step, including fixes made while iterating.

**Simplicity.** The smallest correct diff wins. Simplifying must not add complexity: no clever one-liners, no abstraction to save a few duplicated lines.

- Delete before adding; reuse existing helpers, utilities, and patterns.
- No speculative abstractions, options, flags, or handling for cases that cannot happen.
- No unrelated cleanup, renames, or formatting.
- When two approaches are both correct, pick the one with fewer new names, files, layers, and tests.

**Comments.** Default to none. Comment only what the code cannot say: a non-obvious reason, invariant, constraint, or workaround (with a link). Never narrate what the code does, restate names, record history ("now uses X", "added for Y"), or reference tickets, plans, or the PR. Follow repo conventions for public API docs.

**Writing.** Applies to commits, PR descriptions, code comments, and review replies. Cut until any further cut would lose information. Plain words; no jargon, hype, or filler. Specifics over summaries.

**Standalone.** Each PR stands alone. Even if it came from a multi-PR plan, nothing may reveal that: no `(PR B)`, `[1/3]`, `Part 2 of 4`, "follow-up PRs land next", or other sequencing references.

## Workflow

### 1. Resolve input

`$ARGUMENTS` describes the work: free text, an issue tracker ID/URL, or a GitHub issue (`gh issue view`). Fetch the spec when given a reference. Ambiguous → ask ONE clarifying question.

Parse an `in <repo>` suffix (e.g. `/pr add cache in base`). Otherwise use the current repo, or the repo registry named in the profile context. Ambiguous → ask.

### 2. Implement

Read the repo's guidance files first. Work in the current directory. Bug fix → write a reproducing test first. Run the repo's tests, lint, and typecheck/build.

### 3. Simplify

Reread the full diff against the base branch as a reviewer seeing it for the first time. For each hunk, ask: can it be deleted, shrunk, or replaced with existing code and stay correct? Apply the cuts, remove comments that break the comment rule, and rerun checks.

### 4. Self-review

Follow [review.md](review.md). Skip only trivial diffs (typo, one-line config).

### 5. Open a draft PR

Commit, push, `gh pr create --draft`, using the formats below.

### 6. Iterate until ready (mandatory)

Do NOT return control until CI is green AND every unresolved review thread is addressed (code change or reply) and resolved.

1. Wait for CI to complete.
2. Check failed → fix the root cause (never skip or disable tests), push, GOTO 1.
3. Pull all review threads (top-level + inline).
4. For each unresolved thread: fix it or reply with reasoning, then resolve it. Non-trivial fixes go through steps 3–4 first.
5. Pushed anything in step 2 or 4 → GOTO 1.
6. CI green and no unresolved threads → report the PR URL and stop.

Return early ONLY when:

- Feedback requires a scope/design decision you cannot make alone.
- The same CI failure persists after 3 fix attempts → summarize what was tried, ask.
- A thread asks a question only the user can answer.

## Formats

**Commit:** imperative subject, at most 80 characters. Add a body only when the reason cannot fit in the subject; no implementation summaries or test plans.

**Title:** at most 80 characters, plain words describing the change. Conventional-commit prefix optional (`feat(scope):`, `fix(scope):`).

**Body:**

```markdown
## Why
1–3 sentences: the problem and why this change solves it.

## What
- At most 5 bullets, one per reviewer-visible change.

## Notes
Optional, at most 3 bullets: risks, trade-offs, or rejected alternatives a reviewer should know.
```

Omit ticket numbers, boilerplate, test plans, and commands run. CI shows verification; the diff shows details. For complex changes only, longer context that materially helps reviewers goes last in `<details><summary>AI explanation</summary> … </details>`.

Example:

```markdown
## Why
Nodes hard-code raft peers, so adding a node requires restarting the cluster.

## What
- Add a `--conductor-rpc` bootstrap flag.
- Derive the live raft peer list from one conductor via `DiscoveryConfig`.
```

**Review reply:** 1–2 sentences. State what changed (with the commit) or why not. No thanks, apologies, or restating the comment.
