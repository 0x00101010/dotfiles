---
name: pr
description: Implement work, ship it as a draft PR, then iterate on review and CI until ready.
---

## 1. Input + repo

`$ARGUMENTS` describes the work: free text, an issue tracker ID/URL, or a GitHub issue (`gh issue view`). Fetch the spec when given a reference. Ambiguous → ask ONE clarifying question.

Parse an `in <repo>` suffix (e.g. `/pr add cache in base`). Otherwise use the current repo, or the repo registry named in the profile context. Ambiguous → ask.

## 2. Implement

Work in the current directory. Minimum code that solves the problem: no speculative abstractions, no unrelated cleanup, no jargon-heavy comments. Test and verify with diagnostics/build before committing.

For non-trivial changes, get an independent review of the diff before pushing. Fix critical/important findings or justify deferral; suggestions must not derail the PR.

## 3. Draft PR

Commit messages: imperative subject of at most 80 characters. Add a body only when the business rationale cannot fit in the subject; omit implementation summaries and test plans.

Commit. Push. `gh pr create --draft`.

Each PR stands alone. Even if it came from a multi-PR plan, the title and body MUST NOT reveal that — no `(PR B)`, `[1/3]`, `Part 2 of 4`, "follow-up PRs land next", or any plan/sequencing reference. Reviewers see one self-contained change.

**Title**: at most 80 characters, plain words describing the change. Conventional-commit prefix optional (`feat(scope):`, `fix(scope):`). Nothing else.

**Body**: business purpose in at most 3 sentences, then up to 5 concise bullets for what changed. Omit implementation details, ticket numbers, boilerplate, verification/test sections, and commands run. CI reports verification; reviewers read the diff for details.

For complex changes only, put longer context after the concise body in a collapsed section:

```html
<details>
<summary>AI explanation</summary>

Longer context that materially helps reviewers.

</details>
```

**Good example** (entire body):

> - Add a `--conductor-rpc` bootstrap flag.
> - Derive the live raft peer list from one conductor via `DiscoveryConfig`.

## 4. Iterate until ready (mandatory loop)

After the draft PR is open, do NOT return control to the user until **both**:

- CI is green
- Every unresolved review thread has been addressed (code change OR reply with reasoning) AND resolved

Loop:

1. Wait for CI to complete.
2. Any check failed → fix the root cause (never skip or disable tests), push, GOTO 1.
3. Pull all review threads (top-level + inline).
4. For each unresolved thread: address with code OR reply with concise reasoning, then resolve it.
5. Anything pushed in step 2 or 4 → GOTO 1.
6. CI green AND no unresolved threads → report the PR URL and stop.

Return to the user early ONLY when:

- Feedback requires a scope/design decision you cannot make alone.
- The same CI failure persists after 3 fix attempts → summarize what was tried, ask.
- A thread asks a question only the user can answer.
