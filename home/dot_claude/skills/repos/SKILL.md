---
name: repos
description: Resolve repo nicknames, find which repo a topic/project lives in, and look up cross-references between repos. Auto-invoke when the user references a repo or project by short name, mentions a topic that could span multiple repos, or when the working repo for a task is ambiguous.
---

## When to invoke

- User says "the prover work", "qmdb stuff", "base contracts" — short topic, unclear repo.
- User mentions a project name that doesn't match any cwd you know.
- A task references files but doesn't specify the repo.
- Composing skill (`task`, `investigate`) explicitly requested a repo lookup.
- Before delegating work that needs a `cwd`.

## How

Read `~/src/workspace/knowledge/references/repos.md`. It contains:

- One line per repo with purpose + layout type (bare vs standard).
- Cross-reference section mapping topics → set of related repos.
- Notes on ownership (work / personal / infra).

Use it to answer the calling question. Return the resolved repo path (e.g. `~/src/base/main` for bare layouts, `~/src/<repo>` otherwise) plus a one-line "why this repo" justification.

## When the registry doesn't have the answer

- Repo exists in `~/src/` but missing from registry → tell the user, suggest adding a line.
- Topic genuinely ambiguous → list the candidate repos and ask the user to pick.
- Never guess silently.

## Rules

- Read-only. This skill never modifies the registry — that's a manual edit by the user.
- Don't dump the whole registry into your reply. Extract only what the caller needs.
