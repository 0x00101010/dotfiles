---
name: check
description: Find and run the checks that prove a repo still works for a scope - tests, lint, typecheck or build, and verify-<repo> journeys - and say what they prove beyond CI. Can take a baseline that detects red or flaky starting points. Used by pr, simplify, and loop.
---

`$ARGUMENTS`: `[scope=<paths or packages>] [baseline]`. Default scope: the whole repo.

## Find

1. Read the repo's guidance files (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`), then `justfile`, `Makefile`, package scripts, and CI workflows. Collect the test, lint, and typecheck or build commands. Prefer the repo's own wrappers (`just test`, `make lint`) over raw tool calls.
2. Narrow each command to the scope's packages when the toolchain supports it (`cargo test -p`, `go test ./pkg/...`, `pnpm --filter`, test file paths). Otherwise run it repo-wide.
3. A `verify-<repo>` skill exists (installed, or under the repo's `.agents/skills/` or `.claude/skills/`) → add the journeys whose features the scope touches, and follow that skill to run them.

## Run

- `baseline`: run everything twice before any change. Red → stop and return `red`. The two runs disagree → return `flaky` with the test that changed.
- Otherwise: run everything once.

Never edit tests, assertions, lint config, or CI to make a check pass.

## Return

```text
Check: green | red | flaky
Commands: <each command>
Beyond CI: <verify journeys or other runs CI does not do, with results, or none>
Failures: <first failure per failing command, or none>
```

`Beyond CI` feeds the `pr` Evidence section. The standard commands are not evidence; CI repeats them.
