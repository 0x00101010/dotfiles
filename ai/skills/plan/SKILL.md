---
name: plan
description: Create concise, phase-by-phase implementation plans before coding. Use for plan, implementation plan, PR breakdown, phased rollout, or workstream requests; interview or research first, then write a PR-skill-compatible plan.
---

Read `~/.agents/skills/_shared/instructions.md` for the active profile, context root, plan root, and repo registry. Claude also exposes it as `../_shared/instructions.md` beside the installed skill. If the reference or context checkout is missing, report it and ask for the destination; never infer a profile or fall back to another context repository.

Refer to `pr` for downstream PR conventions. This skill plans only: no implementation, worktrees, commits, branches, PRs, or issue status changes.

## 1. Resolve input

`$ARGUMENTS` may be free text, an issue tracker ID/URL, GitHub issue/ref, or a context-repository markdown path.

- Linear → fetch via an available Linear integration, respecting the profile's company/personal boundary.
- GitHub → `gh issue view`.
- `in <repo>` suffix → resolve through the active profile's repo registry; otherwise use the current repository when unambiguous. Read its guidance before planning.
- Multiple plausible meanings → ask one clarifying question.

## 2. Interview or research

Use the lightest path that makes the plan reliable.

- **Interview** when goal, scope, constraints, or success criteria are unclear. Ask concise questions, preferably one at a time.
- **Research** when facts are discoverable. Read the code and the active context repository's prior plans/research. Use direct search/read tools for targeted facts and available codebase-search or external-research tools for broader questions. Parallelize independent lookups; no particular agent tool or extra skill is required.
- **Escalate** to an available expert tool when explicitly requested, or when direct investigation leaves a specific unresolved, consequential decision. Complexity alone is not a reason to delegate.

Collect background/specialist results before drafting. Stop when further research stops changing the plan.

## 3. Place the plan

Default location: `<plan-root>/<project>/plans/<plan-name>.md`, using the **Plan root** from the shared instructions. The work profile uses its company context's `projects/`; the personal profile uses its personal context's `projects/personal/`. Do not hard-code either checkout path into this skill.

Read the context repository's guidance first. Reuse an existing project and its imported layout when applicable, rather than creating a duplicate project. Keep company plans out of personal context and personal plans out of company context.

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

Use `## Workstream <letter>: <name>` headings for safe parallel work. Describe ownership and dependencies for the user or executing agents; writing a plan does not start those agents.

## 6. PR compatibility

- Each PR-ready slice must stand alone.
- Reviewer-facing PR titles/bodies must not mention sequencing: no `(PR B)`, `[1/3]`, `Part 2`, “follow-up PR,” etc.
- Prefer small focused slices, minimum implementation, no speculative abstractions, no unrelated cleanup.
- Each slice needs its own verification.

## 7. Link back

After writing:

- Print the plan path and any unresolved questions.
- Todo → append ` | PLAN:<relative-path>` only when requested, relative to the active context root; do not mark done.
- Linear/GitHub → draft a comment with an appropriate link and 1–3 sentence TL;DR. Post only when authorized; do not change status or disclose private context to a broader audience.

## Rules

- Never fabricate findings, paths, sources, or priorities.
- Surface assumptions and open questions.
- Surgical writes only: plan file plus requested link-back.
- Preserve the user's voice.
- Stop after the plan is written and linked.
