---
name: prio
description: Check planning horizons, fill gaps top-down, then generate or adjust today's schedule. Accepts optional "tomorrow" argument.
---

See `_shared/workspace.md` for layout, todo format, archive procedure, Linear conventions.

`$ARGUMENTS` empty → target = today. `"tomorrow"` → tomorrow.

## Flow

1. Check horizons top-down for staleness
2. Fill highest gap first (each level depends on the one above)
3. Everything current → generate/update target date's schedule
4. Target schedule exists → adjust mode

## Horizons

| Horizon | File | Stale when |
|---------|------|------------|
| 5yr | `identity/goals/5-year.md` | Missing or >1 year old |
| year | `identity/goals/<yyyy>.md` | Missing for current year |
| quarter | `identity/goals/<yyyy>-Q<n>.md` | Missing for current quarter |
| week | `schedules/<yyyy-mm-dd>-week.md` | Missing for current week (Monday date) |
| target | `schedules/<yyyy-mm-dd>.md` | Missing for target date |

Check all five. Stop at highest gap and guide the user through filling it before proceeding.

## Filling gaps

Each horizon reads from the one above + its own sources. **Always present draft and get confirmation before writing.**

- **5yr** — Read: `identity/career-strategy.md`, `strategies/ideas.md`, `identity/board-of-directors.md`. Output: vision, life areas, directional bets.
- **Year** — Read: 5yr, `identity/career-strategy.md`, `strategies/*`, `projects/work/priorities.md`. Output: 3-5 themes, milestones, success criteria.
- **Quarter** — Read: year plan, `todos/{work,personal}.md`, Linear. Output: 3-5 OKRs.
- **Week** — Read: quarter plan, all `todos/*`, Linear, trickle list, recent schedules + journals. Output: 2-3 focus areas, deliverables, carryover, "not this week".

Write file, re-check cascade, fill next gap. Repeat until current.

## Schedule generation

### Review previous day

Find most recent schedule before target date. Summarize: completed, missed, recommendation.

### Gather tasks

Collect unchecked items from:
- `todos/work.md`, `todos/personal.md`
- `todos/recurring.md` (if due), `todos/trickle-list.md` (always), `inbox.md` (note count)
- Linear: started/unstarted/backlog assigned to me, sorted by priority

De-duplicate: skip Linear results that already have a `LINEAR:` ref in work.md.

### Prioritize

Present tasks grouped by source/project. Ask:
1. "What's most important [today/tomorrow]?"
2. "Anything blocking or time-sensitive?"

Flag priority conflicts (workspace says P0, Linear says P3, etc.). Limit top 3 work items.

### Build schedule

Format: `# DayOfWeek, Month DD, YYYY` with `- [ ] **P0** - description`. Groups: **Morning**, **Afternoon - Work** (by project), **Evening - Personal**. Trickle list as `## Trickle List (pick 1-2)`. Monday → add "Check plans & strategies".

### Alignment commentary

Compare against week/quarter/year goals. Call out: OKR-advancing items, unconnected items, missing weekly focus coverage.

Write to `schedules/<target-date>.md`.

## Adjust mode

Schedule exists → show state, ask "What changed?", update in place, re-sort by priority.

## Rules

- Never assume priorities — always ask.
- Archive completed tasks per workspace.md (never delete).
