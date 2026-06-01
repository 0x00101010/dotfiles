---
name: plan
description: Create concise, phase-by-phase implementation plans before coding. Use for plan, implementation plan, PR breakdown, phased rollout, or workstream requests; interview or research first, then write a PR-skill-compatible plan.
---

See `_shared/workspace.md` for source/repo resolution and workspace layout. Refer to `pr` for downstream PR conventions. This skill plans only: no worktrees, commits, branches, PRs, or issue status changes.

## 1. Resolve input

`$ARGUMENTS` may be free text, Linear ID/URL, GitHub issue/ref, or a workspace markdown path.

- Linear → fetch via Linear MCP.
- GitHub → `gh issue view`.
- `in <repo>` suffix → resolve that repo; otherwise load `repos` if ambiguous.
- Multiple plausible meanings → ask one clarifying question.

## 2. Interview or research

Use the lightest path that makes the plan reliable.

- **Interview** when goal, scope, constraints, or success criteria are unclear. Ask concise questions, preferably one at a time.
- **Research** when facts are discoverable. Run useful sources in parallel: `explore` for codebase patterns, `librarian` for external docs/OSS, `qmd` for prior notes, and direct grep/read/LSP for targeted facts.
- **Escalate** to `oracle` for complex architecture/debugging/security/performance tradeoffs, or artistry-style unconventional thinking when the obvious plan seems wrong.

Collect background/specialist results before drafting. Stop when further research stops changing the plan.

## 3. Place the plan

Default location: `~/src/workspace/projects/{work,personal}/<project>/plans/<plan-name>.md`.

Plan name: lowercase, hyphen-separated, concise, accomplishment-based (`add-staged-sync.md`, `fix-enclave-build.md`). Ask if project or name is unclear.

Present the draft path + plan and get confirmation before writing, unless the user explicitly asked to write and the destination is unambiguous.

## 4. Plan format

Use this shape; omit empty sections.

```markdown
# <Title>

> Source: <free text | Linear | GitHub | path>
> Status: Draft

## Context
Evidence-backed background and constraints.

## Goal
Outcome and success criteria.

## Non-goals
Scope exclusions.

## Open questions
- `None`, or blockers before execution.

## Phase 1: <name>
**Objective:** ...
**Actions:**
1. ...
**Verification:** ...
**Exit criteria:** ...
**PR boundary:** Standalone PR description, or `Not a PR boundary`.
**Parallelizable:** Yes/No; if yes, name the workstream.

## Phase 2: <name>
...

## Workstream A: <name>
Only include `## Workstream` headings when safe parallel execution exists. State dependencies, touched areas, integration contract, deliverable, and verification.

## Implementation order
1. Dependency-aware order.

## Verification plan
- Required tests/checks/manual validation.

## Risks and rollback
- Risk → mitigation / rollback.

## Handoff to PR skill
- Suggested branch prefix/slug.
- PR-ready slices.
```

## 5. Parallelism rules

Mark work parallel only when workstreams are independent and have clear integration contracts. Do not parallelize unresolved product/design decisions, shared core-file edits without ownership, or phases that depend on APIs/types not yet defined.

Use `## Workstream <letter>: <name>` headings for safe parallel work because `workon` detects them as swarm signals.

## 6. PR compatibility

- Each PR-ready slice must stand alone.
- Reviewer-facing PR titles/bodies must not mention sequencing: no `(PR B)`, `[1/3]`, `Part 2`, “follow-up PR,” etc.
- Prefer small focused slices, minimum implementation, no speculative abstractions, no unrelated cleanup.
- Each slice needs its own verification.

## 7. Link back

After writing:

- Todo → append ` | PLAN:<relative-path>`; do not mark done.
- Linear/GitHub → comment with plan path + 1–3 sentence TL;DR if appropriate; do not change status.
- Freeform → print the plan path.

## Rules

- Never fabricate findings, paths, sources, or priorities.
- Surface assumptions and open questions.
- Surgical writes only: plan file plus requested link-back.
- Preserve the user's voice.
- Stop after the plan is written and linked.
