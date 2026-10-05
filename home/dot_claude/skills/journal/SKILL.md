---
name: journal
description: Capture a daily journal entry — what happened, wins, reflections. Closes the plan-execute-reflect loop.
---

Read `../_shared/instructions.md` for the active context root and retired-task-list policy.
All paths below are relative to that root. This skill is personal-only;
do not import company tasks or Linear activity into the journal.

## Target date

`$ARGUMENTS` empty → today. `"yesterday"` → yesterday.

## 1. Gather context

Read to understand what was planned:
- `schedules/<YYYY>/<target-date>.md`
- Most recent journal entry before target date in `journal/`

Skip missing context files. Old todo lists were deleted as stale; do not reconstruct
them from history or create an archive. The journal records the user's account.

## 2. Interview

Summarize what was planned, then ask conversationally (one at a time, skip redundant ones):

1. What did you get done?
2. Anything unexpected — blockers, surprises, pivots?
3. Wins worth noting?
4. Reflections, ideas, frustrations?

## 3. Write entry

File: `journal/<YYYY>/<MM>/<YYYY-MM-DD>.md` (create dirs).

```markdown
# Journal — DayOfWeek, Month DD, YYYY
## Done
## Didn't get to
## Wins
## Notes
```

Omit empty sections. User's words, not embellishments.
