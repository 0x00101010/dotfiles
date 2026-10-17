---
name: loop
description: Run a code-changing skill as a bounded, logged loop - "/loop <skill> <args>". One change per pass, checked and kept or reverted, an optional metric with noise rules, a decision log that carries across runs, stop rules, a two-model review, then a report or a PR. Use for "/loop <skill>" or scheduled runs that should make many verified changes.
---

Goal: changes each proven by a check before and after, from runs a reviewer can trust without watching them.

## Input

`$ARGUMENTS`: `<skill> [output=report|pr] [passes=<n>] [skill arguments]`.

- `output`: `report` (default) or `pr`.
- `passes`: the most passes this run makes; default 8.
- Everything else goes to the skill.

Read the skill's `SKILL.md`. It must find ranked candidates and change code, or have a `## Loop` section. Otherwise stop: it cannot be looped.

Unattended (an automation, or the prompt says so): never ask. Anything that would need a question → stop and say why in the report.

## The skill's `## Loop` section

| Field | Meaning | Default |
|---|---|---|
| Keep rule | What a change must achieve beyond a green check | the change is non-empty |
| Metric | A command that prints one number, and which direction is better | none |
| Noise | Samples per measurement | 5 |
| Candidate check | An extra command per candidate, e.g. rerun one test 20 times | none |
| PR | `run`: one PR for the run; `change`: one PR per kept change | `run` |
| Review question | What the review must answer beyond its lenses | "Does each change do what the skill intends without changing other behavior?" |
| Branch type | Conventional-commit type for the branch | `chore` |

## 1. Prepare

1. The `workspace` skill with branch `<type>/<skill>-<yyyymmdd-hhmm>` and `isolated`.
2. The `check` skill with `baseline` on the skill's scope. Not green → stop and report.
3. Metric → take the baseline: run it `Noise` times and record the median and the spread (max − min).
4. Open the log at `~/.local/state/loop/<repo>/<skill>-<scope-slug>.tsv`, the same path for every run with this repo, skill, and scope. New file → write the header:

   ```text
   ts	pass	candidate	decision	why	evidence	result
   ```

   Append a `start` row: branch, check commands, baseline. Read earlier rows: skip any candidate already kept or rejected, unless its files changed on `origin/<default>` since that row.

Rows stay single-line; evidence is a pointer (commit SHA, `path:line`, failing command), never prose. Append only: a wrong row gets a later row that supersedes it.

## 2. Passes

Have the skill list its candidates in scope, ranked, minus the ones the log rules out. Then, one per pass, strictly in sequence: never batch one pass's edit with the previous pass's commit or check.

1. Have the skill make exactly one change: the top remaining candidate.
2. Run `check` on the scope, the candidate check, and the metric (`Noise` samples).
3. Keep only if everything is green, the keep rule holds, and, with a metric, the new median beats the current one by more than the baseline spread. Keep → commit it alone; its median becomes the one to beat. Otherwise → `git reset --hard HEAD`.
4. Log the row either way: `kept` or `reverted`, why, evidence, and the metric before → after.

Stop when any holds: no candidates left; `passes` reached; 3 reverts in a row; with `PR: run`, the next change would push the diff past the `pr` size rule. A plateau with candidates left is not a stop.

## 3. Judge

Nothing kept → skip. Otherwise run the `review` skill with `panel=dual` on `origin/<base>...HEAD`, adding the skill's intent and the review question. A verified blocker → `git revert` that commit, rerun `check`, and log it; do not fix forward. Then run `check` once more on the final head.

## 4. Output

- `report`, or nothing kept → push nothing.
- `pr`, `PR: run` → follow `pr` steps 5–6 (step 4 is done).
- `pr`, `PR: change` → for each kept commit, a fresh `workspace` branch off `origin/<base>` with that commit cherry-picked, then `pr` steps 5–6 for each.

The PR's Evidence: the review result, the metric baseline → final, `check`'s `Beyond CI` line, and the log attached as a file.

Release the workspace. Never merge, force-push, or touch the default branch.

Last, send this report with `notify`:

```text
Loop: <skill> <skill arguments> | output: <mode>
Check: <green> | baseline metric: <median ± spread, or none>
Passes: <n> run, <k> kept, <r> reverted | stop: <reason>
Kept:
- <sha> <one line> (<metric before → after>)
Review: <result line, or skipped>
Log: <path> | Branch: <name> | PR: <url(s) or none>
Next: <best remaining candidate, or none>
```
