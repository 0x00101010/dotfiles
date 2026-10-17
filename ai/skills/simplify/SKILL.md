---
name: simplify
description: Make code smaller and easier to read without changing behavior - delete dead code, reuse existing helpers, inline single-use layers, drop checks for impossible states. Checks each change on its own and keeps or reverts it. Use for "/simplify", "simplify this branch or path", or a scheduled simplify run.
---

`$ARGUMENTS`: `[<scope>] [output=report|pr]`.

**Scope:**

- Default: files changed on the current branch against `origin/<default>`.
- `since=<duration>`: files changed by commits on `origin/<default>` in that window (`git log origin/<default> --since=<duration> --name-only --format=`), minus deleted files.
- `<path or glob>`: every file under it.

Exclude generated, vendored, lockfile, and snapshot files.

**Output:** omitted → work on the current branch in place. `report` → an isolated branch, nothing pushed, results sent with `notify`. `pr` → an isolated branch shipped as a ready PR.

Unattended (an automation, or the prompt says so): never ask. Anything that would need a question → stop and say why in the result.

## 1. Prepare

1. No `output` → require a clean tree and stay on the current branch. Otherwise → the `workspace` skill with branch `refactor/simplify-<yyyymmdd>`.
2. Run the `check` skill with `baseline` on the scope's packages. Not green → stop and report it; do not fix it.

## 2. Find candidates

Within scope:

- code nothing reaches: unused functions, branches, flags, parameters;
- logic that duplicates an existing helper or the standard library;
- one-caller wrappers, single-use abstractions, needless indirection;
- options, fallbacks, or defensive checks for states that cannot happen;
- comments that narrate code, restate names, or reference history or tickets.

Rank by lines removed, then by layers a reader no longer has to trace. Skip a candidate when no test exercises it (the repo's coverage tool when it is fast, otherwise no test references the function or module) and list it as `uncovered`.

## 3. Apply, one candidate at a time

1. Make the smallest change that realizes the candidate.
2. Run `check` on the scope's packages.
3. Keep only if it is green and the keep rule holds → commit it alone (`git add <paths>`, imperative subject). Otherwise → `git reset --hard HEAD`.

Stop when candidates run out or the next change would push the diff past the `pr` size rule.

**Keep rule:**

- Net lines go down, or branches or abstractions go down with no net line increase.
- No change to a public surface: exported symbols, wire or storage formats, CLI flags, config keys, log or metric names.
- No new dependency, file, or abstraction.

Out of bounds: test assertions, renames for taste, formatting, and anything a formatter or linter would do.

## 4. Review

Nothing kept → skip. Otherwise run the `review` skill on the kept commits (`panel=dual` when unattended, `single` otherwise) and add: "Does any change alter observable behavior: return values, errors, ordering, side effects, timing-sensitive paths, or anything a caller outside the file could notice?" A verified blocker → `git revert` that commit and rerun `check`.

## 5. Output

- Omitted → reply with the summary below.
- `report` → send the summary with `notify`; push nothing; release the workspace.
- `pr` with kept commits → follow `pr` steps 5–6 (step 4 is done). Evidence: the review result and `check`'s `Beyond CI` line. Then `notify` with the PR link.

```text
Simplify: <scope> | output: <mode>
Kept: <n>
- <sha> <one line> (-<lines>)
Reverted: <n> (<candidate: reason>, ...)
Uncovered: <candidates skipped, or none>
Review: <result line, or skipped>
Branch: <name> | PR: <url or none>
```

## Loop

For the `loop` skill. Under `loop`, skip steps 1, 4, and 5, and make only the one change `loop` asks for.

- Keep rule: the keep rule above.
- Metric: none.
- PR: one per run.
- Review question: the step 4 question.
- Branch type: `refactor`.
