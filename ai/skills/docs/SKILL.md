---
name: docs
description: Fix statements in a repo's Markdown docs that the code proves wrong - missing commands and targets, dead paths, unknown flags, env vars, or config keys, broken internal links, renamed symbols. Docs change to match code, never the reverse. Use for "/docs", "fix stale docs", or a scheduled docs run.
---

`$ARGUMENTS`: `[since=<n>h|<n>d|all] [output=report|pr] [review=skip]`.

**Scope:** the repo's own Markdown: `README*`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING*`, and `docs/**`. Exclude changelogs, release notes, vendored, generated, and `node_modules` files.

- Default `since=7d`: docs changed by commits on `origin/<default>` in that window, plus docs that mention a file, command, or symbol changed in it. Spell the window out for git (`--since="7 days ago"`); git silently misparses `7d`.
- `all`: every doc in scope.

**Output and review:** as in the `simplify` skill: omitted → in place on the current branch; `report` → an isolated branch, nothing pushed; `pr` → an isolated branch shipped as a ready PR; `review=skip` → the caller reviews.

Unattended (an automation, or the prompt says so): never ask. Anything that would need a question → list it as `unresolved` in the result.

## 1. Prepare

1. No `output` → require a clean tree and stay on the current branch. Otherwise → the `workspace` skill with branch `docs/docs-<yyyymmdd>` and `isolated`.
2. Find the repo's docs checks (a docs script, a link checker such as `lychee`, a Markdown linter) the way the `check` skill finds commands, and run them once. Red → note the failures as candidates; do not stop.

## 2. Find candidates

Extract checkable claims from docs in scope and verify each against the repo:

1. Commands: `npm run`/`pnpm` scripts, `just` recipes, `make` targets, `cargo` aliases, and repo scripts that do not exist (`package.json`, `just --list`, `make -n <target>`, the file itself).
2. File and directory paths, app routes, and pages or features named in prose ("the Upgrades page") that no longer exist.
3. CLI flags, env vars, and config keys that no code reads (grep the code, or `<binary> --help` when it is already built).
4. Internal links and anchors that do not resolve.
5. Symbols (functions, types, crates, packages) that were renamed or deleted.

Verification never has side effects: read files, grep, list recipes, dry-run (`make -n`), `--help`. Never run a documented command to see whether it works.

Rank by harm: a reader following the doc fails (commands, paths) before a reader is misled (flags, symbols) before a dead link.

## 3. Fix, one claim at a time

1. Make the smallest edit that makes the statement true: the right command, path, or name, proven by the code. When the thing is gone with no replacement, delete the statement.
2. Rerun the docs checks and re-verify the claim.
3. Keep only if both pass and the keep rule holds → commit it alone, citing the proving `path:line` in the message. Otherwise → `git reset --hard HEAD`.

The replacement is ambiguous (two candidate commands, intent unclear) → leave the doc unchanged and list the claim as `unresolved` with what you found.

**Keep rule:** the changed statement is now true according to the code; nothing else is reworded; no new sections or explanations. Out of bounds: style, tone, formatting, reorganizing, and any code change.

Stop when candidates run out or the next fix would push the diff past the `pr` size rule.

## 4. Review

Nothing kept, or `review=skip` → skip. Otherwise run the `review` skill on the kept commits and add: "Is every changed statement now true according to the code, with nothing else reworded?" A verified blocker → `git revert` that commit.

## 5. Output

- Omitted or `report` → reply with the summary below. `report` pushes nothing and releases the workspace.
- `pr` with kept commits → follow `pr` steps 5–6 (step 4 is done). Evidence: the review result and, per fix, the proving `path:line`.

Unattended → also append a row to `~/.local/state/loop/runs.tsv` in the format the `loop` skill defines (skill `docs`).

```text
Docs: <scope> | output: <mode>
Kept: <n>
- <sha> <doc path>: <claim> → <fix> (proof: <path:line>)
Reverted: <n> (<claim: reason>, ...)
Unresolved: <claims with what was found, or none>
Review: <result line, or skipped>
Branch: <name> | PR: <url or none>
```

## Loop

For the `loop` skill. Under `loop`, skip steps 1, 4, and 5, and make only the one fix `loop` asks for. Use `check fast` = the docs checks plus re-verifying the claim; the final full check is the docs checks.

- Keep rule: the keep rule above.
- Metric: none.
- PR: one per run.
- Review question: the step 4 question.
- Branch type: `docs`.
