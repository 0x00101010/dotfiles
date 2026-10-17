---
name: review
description: Review a diff or PR for real defects with one model or a two-model panel. Returns a verdict, a confidence, and verified findings. Used by pr for self-review, by loop to judge loop output, and by PR-review automations. Use for "review this diff" or "review <PR URL>".
---

`$ARGUMENTS`: `[panel=single|dual] [<PR URL | diff range>]`.

- Target: default `git diff origin/<default>...HEAD`. A PR URL → check out its head read-only in a scratch worktree.
- `panel`: `single` (default) or `dual`.

Reviewers never edit, commit, push, comment, or spawn other reviewers. Lenses are checklist sections within one brief, never separate reviewers.

## Choose lenses

Always run correctness and fit. Add the others when the diff touches:

- **Architecture:** new modules, public APIs, data models, persistence, cross-module flows, concurrency model.
- **Security:** untrusted input, authn/authz, secrets, crypto, shell/SQL/templates, network, file paths, dependencies, CI workflows.
- **Performance:** hot paths, loops over unbounded data, I/O or queries in loops, caching, allocation, locking.

## Brief the reviewer

Give it the intent (1–3 sentences), the diff command, the repo guidance files, any question the caller adds, and the **Shared rules** and every selected lens copied verbatim from this file in one combined brief.

UI-exception diff → also pass the evidence file paths and add to the brief: "Should-fix: a changed view or state with no screenshot, or a screenshot that contradicts the diff (copy, layout, missing state)."

## Run the review

Use the `pr-reviewer` agent when the `subagent` tool lists it; otherwise a read-only subagent; if subagents are unavailable, review it yourself (`single` only).

- **single:** one reviewer on its default model unless the user names one.
- **dual:** two reviewers in parallel on the same brief, models from different providers. Deep tier `anthropic/claude-opus-5-5` + `cbhq-openai/gpt-6.1-sol` when any holds: it deletes production resources; it touches sequencer, consensus, node, or smart-contract code; it changes auth, keys, IAM, secrets, or CI workflows; it has more than 200 changed hand-written lines; an earlier review of this change returned changes needed. Otherwise light tier `anthropic/claude-sonnet-5-5` + `cbhq-openai/gpt-6-luna`.

In an unattended run, write the parallel-launch workflow script to a file first, then launch it by path (`workflow: "./<file>.js"`) in a later step. Inline workflow blocks were not picked up in automations.

A reviewer that fails or times out → rerun it once with the same brief and model. Still failing → `single`: report the lenses as unreviewed; `dual`: continue with the other and note `single reviewer (<model> failed)`.

## Shared rules

- Review only lines the diff adds or changes. Pre-existing issues are out of scope unless the diff makes them worse.
- Every finding needs a concrete failure: this input or state → this wrong outcome. No "might", "consider", or generic best practice.
- Read surrounding code before flagging; confirm nothing else already handles it.
- Not findings: what linters, formatters, or type checkers catch; taste; nits a senior engineer would skip; hypothetical future needs.
- Prefer zero findings over weak ones.

Return a verdict for each selected lens, your confidence that the verdicts are right given what you could check, and one deduplicated findings list:

```text
<lens>: ready | changes needed
Confidence: high | med | low, NN%

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

## Validate and merge

1. Verify each finding against the code yourself; discard any you cannot confirm.
2. `dual` → merge: per lens the stricter verdict, the lower confidence, findings deduplicated. A blocker one reviewer raised and the other contradicts → keep it if you confirmed it, and say they disagreed.
3. Overall verdict: `changes needed` with any blocker, `ready with comments` with only should-fixes, otherwise `ready`.

Result for the caller:

```text
Review: <ready | ready with comments | changes needed> | <high|med|low>, NN% | <model(s)>
Findings: <verified list, or none>
```

## Acting on findings

When the change is your own: fix blockers and should-fixes; defer only with a reason worth stating in the PR's Notes. When findings conflict, simplicity wins unless correctness or security is at stake. After fixing blockers, run at most one follow-up review on the new diff with the same panel, covering only the affected lenses.

When it is someone else's PR: report, never push.
