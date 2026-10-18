---
name: check
description: Find and run the checks that prove a repo still works for a scope - tests, lint, typecheck or build, and verify-<repo> journeys - and say what they prove beyond CI. Can take a baseline that detects red or flaky starting points. Used by pr, simplify, and loop.
---

`$ARGUMENTS`: `[scope=<paths or packages>] [fast] [baseline]`. Default scope: the whole repo.

- Full (default): every command below.
- `fast`: only the typecheck or build and the tests of the packages in scope (`cargo check -p` plus `cargo nextest run -p`, `tsc --noEmit` plus the scope's test files). No lint, docs, or repo-wide suites, no verify journeys. For per-change checks; a full check must follow before anything ships.

## Find

1. Read the repo's guidance files (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`), then `justfile`, `Makefile`, package scripts, and CI workflows. Collect the test, lint, and typecheck or build commands. Prefer the repo's own wrappers (`just test`, `make lint`) over raw tool calls.
2. Narrow each command to the scope's packages when the toolchain supports it (`cargo test -p`, `go test ./pkg/...`, `pnpm --filter`, test file paths). Otherwise run it repo-wide.
3. A `verify-<repo>` skill exists (installed, or under the repo's `.agents/skills/` or `.claude/skills/`) → add the journeys whose features the scope touches, and follow that skill to run them.

## Run

Run each command once, in the workspace's environment:

- `local` → run it here.
- Remote (`workspace` reported an environment and remote path) → `envrun sync <env> <local dir> <remote path>`, then `envrun run <env> <remote path> <name> -- <cmd>` and `envrun wait <env> <name>` (from a background process for anything over a minute). `<name>` is unique per command, e.g. `<repo>-<branch>-<command>-<n>`. The printed log tail and exit code are the result; `envrun tail` reads more. Runs live in tmux on the remote, so a dropped connection loses nothing. Never build or test that repo locally.

- A failing command → rerun just that command once. Passes the second time → `flaky`, naming the test; continue.
- `baseline` (before any change): a command CI runs is red → stop and return `red`. A command CI does not run is red (a local-only linter, a version mismatch) → drop it for this run and list it under `Failures`.

Never edit tests, assertions, lint config, or CI to make a check pass.

## Return

```text
Check: green | red | flaky
Commands: <each command>
Beyond CI: <verify journeys or other runs CI does not do, with results, or none>
Failures: <first failure per failing command, or none>
```

`Beyond CI` feeds the `pr` Evidence section. The standard commands are not evidence; CI repeats them.
