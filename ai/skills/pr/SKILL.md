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

**Comments.** Default to none. Comment only what the code cannot say: a non-obvious reason, invariant, constraint, or workaround (with a link). Never narrate what the code does, restate names, record history ("now uses X", "added for Y"), or reference tickets, plans, or the PR. Follow repo conventions for public API docs.

**Writing.** Applies to commits, PR descriptions, code comments, and review replies. Cut until any further cut would lose information. Plain words; no jargon, hype, or filler. Specifics over summaries.

**Standalone.** Each PR stands alone. Even if it came from a multi-PR plan, nothing may reveal that: no `(PR B)`, `[1/3]`, `Part 2 of 4`, "follow-up PRs land next", or other sequencing references.

## Workflow

### 1. Resolve input

`$ARGUMENTS` describes the work: free text, an issue tracker ID/URL, or a GitHub issue (`gh issue view`). Fetch the spec when given a reference. Ambiguous → ask ONE clarifying question.

Linear issue → before implementing, assign it to me (`assignee: "me"`) and move it to its team's started state (usually "In Progress"), skipping what is already set. Assigned to someone else → ask first.

Parse an `in <repo>` suffix (e.g. `/pr add cache in base`). Otherwise use the current repo, or the repo registry named in the profile context. Ambiguous → ask.

Repo top level listed in `~/.config/dotfiles/reposync` (`~` is home; ignore trailing slashes and `#` comments) → it is a direct repo: follow [Direct repos](#direct-repos) where it differs from the steps below.

### 2. Implement

Read the repo's guidance files first. Work in the current directory, unless it is a repo's default worktree with `dev<N>` worktrees beside it: then `cd "$(devslot claim <branch>)"` to reuse a warm build, and `devslot release` after step 6. Otherwise, on the default branch: require a clean tree, then `git fetch origin && git switch -c <branch> origin/<default>`. Branch: `<prefix>/<slug>`, with your usual prefix in this repo (`git log --author`). Create no other worktrees. Bug fix → write a reproducing test first. Run the repo's tests, lint, and typecheck/build.

### 3. Simplify

Reread the full diff against the base branch as a reviewer seeing it for the first time. For each hunk, ask: can it be deleted, shrunk, or replaced with existing code and stay correct? Apply the cuts, remove comments that break the comment rule, and rerun checks.

Then measure against the size rule with `git diff --numstat -M origin/<base>...`. Over the limit → split into stacked PRs. Prefer, in order: a pure refactor before the behavior change; new code before the change that wires it in, only if the first PR stands alone; one module or layer per PR. Each slice gets its own branch off the previous one, passes checks on its own, and follows the standalone rule. Run steps 4–6 for each slice, bottom of the stack first. No coherent split → keep one PR and say why in your report, not in the PR.

### 4. Self-review

Follow [review.md](review.md). Skip trivial and docs-only diffs (typo, one-line config, prose).

### 5. Open the PR

Commit, push, `gh pr create` (with `--base <branch>` when given a base other than the default or when stacked on a parent slice), using the formats below. Open it ready for review, not as a draft, so review bots run while you iterate. Before writing the body, load every installed `*-pr-conventions` skill and follow those whose scope matches this repo.

### 6. Iterate until ready (mandatory)

Do NOT return control until CI is green AND every review thread is fixed and resolved, or answered. After the PR is open, push new commits; never amend, rebase, or force-push, except to rebase a stacked PR after its parent merges.

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

- Step 2: work on the default branch in the checkout; `git pull --rebase --autostash` first. Leave other uncommitted changes alone; stage only your files (`git add <paths>`).
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
