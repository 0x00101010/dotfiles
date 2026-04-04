---
name: prio
description: Check planning horizons, fill gaps top-down, then generate or adjust today's schedule. Accepts optional "tomorrow" argument.
---

`$ARGUMENTS` empty → target = today. "tomorrow" → target = tomorrow.

## Flow

1. Check horizons top-down for staleness
2. Fill highest gap first (each level depends on the one above)
3. Everything current → generate/update target date's schedule
4. Target schedule exists → adjust mode

## Horizons

All paths relative to `~/src/workspace/`.

| Horizon | File | Stale when |
|---------|------|------------|
| 5yr | `identity/goals/5-year.md` | Missing or >1 year old |
| year | `identity/goals/<yyyy>.md` | Missing for current year |
| quarter | `identity/goals/<yyyy>-Q<n>.md` | Missing for current quarter |
| week | `schedules/<yyyy-mm-dd>-week.md` | Missing for current week (Monday date) |
| target | `schedules/<yyyy-mm-dd>.md` | Missing for target date |

Check all five. Stop at highest gap and guide user through filling it before proceeding.

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
- `todos/work.md` and `todos/personal.md` (format: `- [ ] P{0-3} | description | optional:SOURCE-REF` with `> context` lines)
- `todos/recurring.md` (if due), `todos/trickle-list.md` (always), `inbox.md` (note count)
- Linear: fetch started/unstarted/backlog assigned to me, sort by priority

De-duplicate: tasks with `LINEAR:` ref in work.md → skip from Linear results.

### Prioritize

Present tasks grouped by source/project. Ask:
1. "What's most important [today/tomorrow]?"
2. "Anything blocking or time-sensitive?"

Linear mapping: P0=Urgent(1), P1=High(2), P2=Medium(3), P3=Low(4). Flag conflicts. Limit top 3 work items.

### Build schedule

Format: `# DayOfWeek, Month DD, YYYY` with `- [ ] **P0** - description`. Groups: **Morning**, **Afternoon - Work** (by project), **Evening - Personal**. Trickle list as `## Trickle List (pick 1-2)`. Monday → add "Check plans & strategies".

### Alignment commentary

Compare against week/quarter/year goals. Call out: OKR-advancing items, unconnected items, missing weekly focus coverage.

Write to `schedules/<target-date>.md`.

## Adjust mode

Schedule exists → show state, ask "What changed?", update in place, re-sort by priority.

## Rules

- **Never assume priorities** — always ask
- **Never auto-mark done or auto-complete Linear issues**
- **Archive, never delete** — completed tasks move from `todos/{work,personal}.md` → `todos/archive.md` as `- [x] P{n} | description | optional:ref | YYYY-MM-DD` under `## YYYY-MM`. Preserve context lines.
