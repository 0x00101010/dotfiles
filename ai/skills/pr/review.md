# Self-review

Run one read-only reviewer on one model for the entire diff. Lenses are checklist sections within that task, not separate subagents. Do not fan out by lens or model. Reviewers never edit, commit, push, comment, or spawn other reviewers.

## Choose lenses

Always run correctness and fit. Add the others when the diff touches:

- **Architecture:** new modules, public APIs, data models, persistence, cross-module flows, concurrency model.
- **Security:** untrusted input, authn/authz, secrets, crypto, shell/SQL/templates, network, file paths, dependencies, CI workflows.
- **Performance:** hot paths, loops over unbounded data, I/O or queries in loops, caching, allocation, locking.

## Brief the reviewer

Give it the intent (1–3 sentences), the diff command (e.g. `git diff <base>...HEAD`), the repo guidance files, and the **Shared rules** and every selected lens copied verbatim from this file in one combined brief.

## Run the review

If the `subagent` tool lists `pr-reviewer`, launch it once with the combined brief. Use its configured default model unless the user specifies one. Otherwise use one read-only subagent on its default model; if subagents are unavailable, do one combined review yourself. Wait for the review before proceeding.

A reviewer that fails or times out → rerun it once with the same combined brief and model; still failing → report the selected lenses and model as unreviewed.

## Shared rules

- Review only lines the diff adds or changes. Pre-existing issues are out of scope unless the diff makes them worse.
- Every finding needs a concrete failure: this input or state → this wrong outcome. No "might", "consider", or generic best practice.
- Read surrounding code before flagging; confirm nothing else already handles it.
- Not findings: what linters, formatters, or type checkers catch; taste; nits a senior engineer would skip; hypothetical future needs.
- Prefer zero findings over weak ones.

Return a verdict for each selected lens, followed by one deduplicated findings list:

```text
<lens>: ready | changes needed

Findings:
- [blocker|should-fix] <lens> path:line: issue; consequence; minimal fix
```

Blocker: wrong behavior, data loss, security hole, broken build or tests. Should-fix: a real maintainability or reviewer-cost problem. Drop anything weaker.

## Lenses

### Correctness

Requirements met; edge, boundary, and error cases; errors swallowed or masked by fallbacks/defaults; ordering and concurrency; backward compatibility. Tests: bug fixes have a reproducing test; new behavior has a test that fails when the behavior breaks; assertions check behavior, not implementation.

### Fit

Simplicity: code that can be deleted, inlined, or replaced by existing helpers or the standard library; single-use abstractions; unused flexibility, options, or defensive checks for impossible states; unrelated changes; comments that narrate code, restate names, or reference history, tickets, or plans. A proposed fix must reduce total complexity, not move it.

Idiom: before flagging, compare against 2–5 existing examples in the repo. File placement, naming, error handling, logging, test style, language and framework idioms. The repo's convention beats general preference.

### Architecture

Boundaries and ownership; API and data shape; lifecycle and integration risk; compatibility; fit with existing patterns; whether a simpler design exists. Cite existing code as evidence.

### Security

Report only a concrete path: attacker-controlled source → dangerous sink → realistic impact. Env vars, CLI flags, and repo config are trusted. Not findings: generic hardening, DoS or rate limits, theoretical races, dependency versions, test-only code, memory safety in memory-safe languages. Secrets or PII in logs are findings.

### Performance

Report only with a size and frequency argument: what grows, how often it runs, what it costs. Examples: N+1 queries, I/O in loops, unbounded memory, quadratic work on unbounded input, lock contention or allocation on hot paths. Not findings: micro-optimizations off hot paths.

## Validate and act

1. Verify each finding against the code yourself; discard any you cannot confirm.
2. Fix blockers and should-fixes. Defer only with a reason worth stating in the PR's Notes.
3. When findings conflict, simplicity wins unless correctness or security is at stake.
4. If you fixed blockers, run at most one follow-up review on the new diff, with one reviewer on one model covering only the affected lenses.
