# Self-review

Run each lens as an independent read-only reviewer: parallel subagents when available, otherwise separate passes of your own. Reviewers never edit, commit, push, or comment.

## Choose lenses

Always run correctness, simplicity, and idiomacy. Add the others when the diff touches:

- **Architecture:** new modules, public APIs, data models, persistence, cross-module flows, concurrency model.
- **Security:** untrusted input, authn/authz, secrets, crypto, shell/SQL/templates, network, file paths, dependencies, CI workflows.
- **Performance:** hot paths, loops over unbounded data, I/O or queries in loops, caching, allocation, locking.

## Brief each reviewer

Give it the intent (1–3 sentences), the diff command (e.g. `git diff <base>...HEAD`), the repo guidance files, and the **Shared rules** and its lens copied verbatim from this file.

## Pick a model tier

If a `review_with_models` tool is available, call it with the tier below and one task per lens, each prompt being the full brief. It runs every task on two models from different providers. Otherwise skip tiers and use your subagents on their default model.

Use `deep` if any holds; otherwise `light`. Unsure → `deep`: a missed bug costs more than the tokens.

- Security boundary: authn/authz, crypto, secrets, permissions, parsing untrusted input.
- Funds, consensus, or state that is hard to repair: schemas, migrations, deletion.
- Concurrency, ordering, retries, cache invalidation.
- Public API, wire format, or config format that others depend on.
- New non-trivial logic (state machine, algorithm) rather than wiring.
- Production infrastructure, deploys, or CI permissions.
- Roughly 300+ hand-written changed lines, or changes across several modules.
- Touched code has weak tests.

Typical `light`, when no trigger above applies: docs, test-only changes, mechanical refactors covered by tests, small fixes with a reproducing test, local config, routine dependency bumps.

## Shared rules

- Review only lines the diff adds or changes. Pre-existing issues are out of scope unless the diff makes them worse.
- Every finding needs a concrete failure: this input or state → this wrong outcome. No "might", "consider", or generic best practice.
- Read surrounding code before flagging; confirm nothing else already handles it.
- Not findings: what linters, formatters, or type checkers catch; taste; nits a senior engineer would skip; hypothetical future needs.
- Prefer zero findings over weak ones.

Output:

```text
<lens>: ready | changes needed
- [blocker|should-fix] path:line: issue; consequence; minimal fix
```

Blocker: wrong behavior, data loss, security hole, broken build or tests. Should-fix: a real maintainability or reviewer-cost problem. Drop anything weaker.

## Lenses

### Correctness

Requirements met; edge, boundary, and error cases; errors swallowed or masked by fallbacks/defaults; ordering and concurrency; backward compatibility. Tests: bug fixes have a reproducing test; new behavior has a test that fails when the behavior breaks; assertions check behavior, not implementation.

### Simplicity

Code that can be deleted, inlined, or replaced by existing helpers or the standard library; single-use abstractions; unused flexibility, options, or defensive checks for impossible states; unrelated changes; comments that narrate code, restate names, or reference history, tickets, or plans. A proposed fix must reduce total complexity, not move it.

### Idiomacy

Before flagging, compare against 2–5 existing examples in the repo. File placement, naming, error handling, logging, test style, language and framework idioms. The repo's convention beats general preference.

### Architecture

Boundaries and ownership; API and data shape; lifecycle and integration risk; compatibility; fit with existing patterns; whether a simpler design exists. Cite existing code as evidence.

### Security

Report only a concrete path: attacker-controlled source → dangerous sink → realistic impact. Env vars, CLI flags, and repo config are trusted. Not findings: generic hardening, DoS or rate limits, theoretical races, dependency versions, test-only code, memory safety in memory-safe languages. Secrets or PII in logs are findings.

### Performance

Report only with a size and frequency argument: what grows, how often it runs, what it costs. Examples: N+1 queries, I/O in loops, unbounded memory, quadratic work on unbounded input, lock contention or allocation on hot paths. Not findings: micro-optimizations off hot paths.

## Validate and act

1. Merge duplicates across reviewers. Verify each finding against the code yourself; discard any you cannot confirm, even if two models agree.
2. Fix blockers and should-fixes. Defer only with a reason worth stating in the PR's Notes.
3. When findings conflict, simplicity wins unless correctness or security is at stake.
4. If fixes were substantial, rerun the affected lenses on the new diff. At most 2 rounds.
