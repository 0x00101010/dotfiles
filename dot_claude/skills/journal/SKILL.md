---
name: journal
description: Capture a daily journal entry — what happened, wins, reflections. Closes the plan-execute-reflect loop.
---

See `_shared/workspace.md` for archive procedure and Linear conventions.

## Target date

`$ARGUMENTS` empty → today. `"yesterday"` → yesterday.

## 1. Gather context

Read to understand what was planned:
- `~/src/workspace/schedules/<target-date>.md`
- Most recent journal entry before target date in `~/src/workspace/journal/`
- `~/src/workspace/todos/{work,personal}.md`
- Linear: `list_issues(assignee: "me", state: "completed", updatedAt: "-P1D")`

## 2. Interview

Summarize what was planned, then ask conversationally (one at a time, skip redundant ones):

1. What did you get done?
2. Anything unexpected — blockers, surprises, pivots?
3. Wins worth noting?
4. Reflections, ideas, frustrations?

## 3. Write entry

File: `~/src/workspace/journal/<YYYY>/<MM>/<YYYY-MM-DD>.md` (create dirs).

```markdown
# Journal — DayOfWeek, Month DD, YYYY
## Done
## Didn't get to
## Wins
## Notes
```

Omit empty sections. User's words, not embellishments.

## 4. Archive completed todos

Apply archive procedure from workspace.md. **Always ask first.**
