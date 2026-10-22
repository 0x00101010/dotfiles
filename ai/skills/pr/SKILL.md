---
name: pr
description: Implement work, simplify and self-review it, ship it as a PR ready for review, then iterate on review and CI until ready. In repos you own and auto-sync, push commits straight to the default branch instead. Use for "work on <issue>" with a Linear or GitHub issue ID.
---

Goal: a PR a reviewer can approve on first read. Small diff, self-reviewed, concise prose.

## Rules

These apply to every step, including fixes made while iterating.

**Simplicity.** The smallest correct diff wins. Simplifying must not add complexity: no clever one-liners, no abstraction to save a few duplicated lines.

- Delete before adding; reuse existing helpers, utilities, and patterns.
- No speculative abstractions, options, flags, or handling for cases that cannot happen.
- No unrelated cleanup, renames, or formatting.
- When two approaches are both correct, pick the one with fewer new names, files, layers, and tests.

**Size.** A reviewer should finish a PR in one sitting: at most 200 changed lines (additions plus deletions) of hand-written source, and at most 400 including tests. Lockfiles, generated code, snapshots, vendored files, and pure renames or moves do not count. Mechanical changes (codemods, bulk renames, regenerated files) have no cap but get their own PR, never mixed with logic.

UI exception: when the hand-written lines are mostly presentational (components, styles, layout, copy, render-only state) and any logic still fits the 200-line cap, the soft limit is 600 changed lines including tests, covering one user-facing flow and at most 3 changed views. The PR must carry [visual evidence](#ui-evidence); without it, the normal limits apply.

**Comments.** Default to none. Comment only what the code cannot say: a non-obvious reason, invariant, constraint, or workaround (with a link). Never narrate what the code does, restate names, record history ("now uses X", "added for Y"), or reference tickets, plans, or the PR. Follow repo conventions for public API docs.

**Writing.** Applies to commits, PR descriptions, code comments, and review replies. Cut until any further cut would lose information. Plain words; no jargon, hype, or filler. Specifics over summaries.

**Standalone.** Each PR stands alone. Even if it came from a multi-PR plan, nothing may reveal that: no `(PR B)`, `[1/3]`, `Part 2 of 4`, "follow-up PRs land next", or other sequencing references.

## Workflow

### 1. Resolve input

`$ARGUMENTS` describes the work: free text, an issue tracker ID/URL, or a GitHub issue (`gh issue view`). Fetch the spec when given a reference. Ambiguous → ask ONE clarifying question.

Linear issue → before implementing, assign it to me (`assignee: "me"`) and move it to its team's started state (usually "In Progress"), skipping what is already set. Assigned to someone else → ask first.

Parse an `in <repo>` suffix (e.g. `/pr add cache in base`). Otherwise use the current repo, or the repo registry named in the profile context. Ambiguous → ask.

The `workspace` skill identifies a direct repo (one that reposync auto-commits): follow [Direct repos](#direct-repos) where it differs from the steps below.

### 2. Implement

Read the repo's guidance files first. Get a checkout and a `<type>/<slug>` branch from the `workspace` skill, and release it after step 6. Bug fix → write a reproducing test first. Verify with the `check` skill on the changed packages.

### 3. Simplify

Run the `simplify` skill in place with `review=skip`; it reuses step 2's green check. Pass its behavior question to step 4. Then reread the diff once more for comments that break the comment rule. Skip `simplify` only for the diffs step 4 may skip, and say so in your report.

Then measure against the size rule with `git diff --numstat -M origin/<base>...`. Over the limit → split into stacked PRs. Prefer, in order: a pure refactor before the behavior change; new code before the change that wires it in, only if the first PR stands alone; one module or layer per PR; for UI-exception diffs, one flow per PR. Each slice gets its own branch off the previous one, passes checks on its own, and follows the standalone rule. Run steps 4–6 for each slice, bottom of the stack first. No coherent split → keep one PR and say why in your report, not in the PR.

#### Evidence

Every PR carries proof of what CI does not show. Collect it before step 5:

- **Verification beyond CI:** `check`'s `Beyond CI` line (journeys from a `verify-<repo>` skill), a bug reproduced on the base and gone on the head, a benchmark or metric on base vs head, or a run of the real binary or service. Record what was verified, how, and the result.
- **Review:** the result line from step 4, or `skipped (<reason>)`.
- **From a caller:** anything it hands over, such as a loop's metric baseline → final.
- **UI changes:** screenshots and recordings, below.

Never list the repo's standard tests, lint, typecheck, or build; CI shows those. Nothing verified beyond CI → say so.

##### UI evidence

For a UI-exception PR, capture evidence before step 4, from the app running locally:

- Repo depends on Playwright → write a throwaway capture script in the repo so it resolves the repo's Playwright: `setViewportSize` per width, `page.route` to force each state, `page.screenshot`, and the `recordVideo` context option for recordings. Run it once on the base branch for "before" and once on the PR head for "after", then delete it before committing.
- Otherwise → drive each changed flow with the `agent-browser` skill (`agent-browser record` for recordings).

Capture:

- PNG before/after screenshots of every changed view, in each state the diff touches (empty, loading, error, populated); add mobile and desktop widths when layout changes.
- Interactive changes (animation, drag, multi-step flows): also a `.webm` recording of the interaction, under 10 MB.
- Internal or sensitive data → use synthetic data and say so.
- Save evidence outside the repo (e.g. `$TMPDIR/pr-evidence/`); never commit it.

Screenshots must come from the running app at the PR's head; no mockups.

### 4. Self-review

Run the `review` skill on the diff, adding the question `simplify` handed over in step 3, and act on its findings. Skip only typo or docs-only diffs and one-line config changes.

### 5. Open the PR

Gate: before `gh pr create`, the Evidence `Review:` line holds step 4's result line or `skipped (<reason>)` with a reason step 4 allows. Otherwise run steps 3–4 first. This holds when a PR is requested mid-conversation too.

Commit, push, `gh pr create` (with `--base <branch>` when given a base other than the default or when stacked on a parent slice), using the formats below. Open it ready for review, not as a draft, so review bots run while you iterate. Before writing the body, load every installed `*-pr-conventions` skill and follow those whose scope matches this repo.

Upload evidence files (screenshots, recordings, logs) as GitHub PR attachments with `gh pr create --attach <file>`, one flag per file. Reference each screenshot in the body by the same path, as in `![Empty state, after](<path>)`; `gh` rewrites it to the uploaded URL. Recordings render as a player and are appended to the end of the body. Replacing evidence later: `gh pr edit <N> --attach <file>`. A non-zero exit after the PR URL prints means some uploads failed: rerun those with `gh pr edit`.

### 6. Iterate until ready (mandatory)

Do NOT return control until CI is green AND every review thread is fixed and resolved, or answered. After the PR is open, push new commits; never amend, rebase, or force-push, except to rebase a stacked PR after its parent merges.

Exceptions: the task that launched you says to stop once the PR exists → return after step 5. A `pr_track` tool exists (Toshi) → call it with the PR URL and `mode: "auto"`, and use its wakes and `pr_status` instead of `gh pr checks --watch` in sub-step 1; the rest is unchanged.

1. Wait for CI: `gh pr checks --watch`.
2. Check failed → unrelated to the diff (flaky): rerun once with `gh run rerun <run-id> --failed`. Also fails on the base branch: report it instead of fixing it. Otherwise fix the root cause (never skip or disable tests), push, GOTO 1.
3. Pull inline threads with `gh api graphql` on `pullRequest.reviewThreads` (`isResolved`, comments), and top-level comments and review bodies with `gh pr view --comments`, which misses inline threads.
4. For each unresolved thread or top-level comment without your reply: fixed with code → reply with the commit, then resolve the thread (`resolveReviewThread`); not changing it → reply with why and leave it open for the reviewer. Non-trivial fixes go through steps 3–4 first.
5. Pushed anything in step 2 or 4 → GOTO 1.
6. CI green and every thread resolved or answered → report the PR URL and stop.

Return early ONLY when:

- Feedback requires a scope/design decision you cannot make alone.
- The same CI failure persists after 3 fix attempts → summarize what was tried, ask.
- A thread asks a question only the user can answer.

### Direct repos

Owned repos that skip review: no branch, no PR. reposync commits every file left untouched for a minute and pushes it to the upstream within 5 minutes, so commit early or your work lands as an `auto-sync` commit.

- Step 2: `workspace` keeps you on the default branch in the checkout. Leave other uncommitted changes alone; stage only your files (`git add <paths>`).
- Step 3: commit once checks pass. Over the size rule → a stack of commits instead of stacked PRs, split the same way, each committed once it passes checks on its own.
- Step 4: fix findings with new commits.
- Steps 5–6: `git pull --rebase --autostash && git push`; never force-push. If a CI workflow runs on the push, watch it (`gh run list --commit <sha>`, `gh run watch <id>`) and handle failures as step 6.2 does. Report the commit links and stop.

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

Omit ticket numbers, boilerplate, test plans, and checks CI runs; the diff shows details. For complex changes only, longer context that materially helps reviewers goes in `<details><summary>AI explanation</summary> … </details>` before Evidence.

Every body ends with `## Evidence`, so appended recordings land in it:

```markdown
## Evidence
**Review:** ready with comments | high, 85% | standard: claude-opus-5-5 + gpt-6.1-sol

| Verified | How | Result |
|---|---|---|
| Withdrawal end to end | `verify-bridge` journey `withdraw` | fails on base (stale nonce), passes on head |
| p99 block build | `just bench-build`, median of 5 | 41 ms → 33 ms |
```

Nothing verified beyond CI → one line instead of the table: `Not verified beyond CI.` UI changes add a before/after screenshot table with one row per view and state, and one line naming the route, viewport, and data source (real or synthetic). Attached logs are listed by file name.

Example:

```markdown
## Why
Nodes hard-code raft peers, so adding a node requires restarting the cluster.

## What
- Add a `--conductor-rpc` bootstrap flag.
- Derive the live raft peer list from one conductor via `DiscoveryConfig`.
```

**Review reply:** 1–2 sentences. State what changed (with the commit) or why not. No thanks, apologies, or restating the comment.
