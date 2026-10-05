---
name: prio
description: Check planning horizons, fill gaps top-down, then generate or adjust today's schedule. Accepts optional "tomorrow" argument.
---

Read `../_shared/instructions.md` for the active context root, layout, and retired-task-list policy.
All paths below are relative to that root. This skill is personal-only;
do not import company tasks or Linear activity into personal schedules.

`$ARGUMENTS` empty → target = today. `"tomorrow"` → tomorrow.

## Flow

1. Check horizons top-down for staleness
2. Fill highest gap first (each level depends on the one above)
3. Everything current → generate/update target date's schedule
4. Target schedule exists → adjust mode

## Horizons

| Horizon | File | Stale when |
|---------|------|------------|
| 5yr | `identity/5-year-plan.md` | Missing or >1 year old |
| year | `identity/goals/<yyyy>.md` | Missing for current year |
| quarter | `identity/goals/<yyyy>-Q<n>.md` | Missing for current quarter |
| week | `schedules/<yyyy>/<yyyy-mm-dd>-week.md` | Missing for current week (Monday date) |
| target | `schedules/<yyyy>/<yyyy-mm-dd>.md` | Missing for target date |

Check all five. Stop at highest gap and guide the user through filling it before proceeding.

## Filling gaps

Each horizon reads from the one above + its own sources. **Always present draft and get confirmation before writing.**

- **5yr** — Read: `identity/career-strategy.md`, `identity/wealth-strategy.md`, `identity/health-and-energy.md`, `identity/marriage-and-family.md`, `identity/friendships.md`, `strategies/ideas.md`, `identity/board-of-directors.md`. Output: vision, life areas, directional bets.
- **Year** — Read: 5yr, all `identity/*.md` life-area docs (career, wealth, health, marriage-and-family, friendships), `strategies/*`, relevant `projects/personal/` plans. Output: 3-5 themes spanning life areas, milestones, success criteria.
- **Quarter** — Read: year plan, life-area docs, relevant `projects/personal/` plans. Output: 3-5 OKRs covering personal life areas.
- **Week** — Read: quarter plan, life-area docs, recent schedules + journals. Output: 2-3 focus areas, deliverables, user-confirmed carryover, "not this week".

Write file, re-check cascade, fill next gap. Repeat until current.

## Schedule generation

### Review previous day

Find most recent schedule before target date. Summarize: completed, missed, recommendation.

### Gather tasks

Ask for current commitments and use the goals and personal plans reviewed above.
Old todo lists were deleted as stale. Do not reconstruct them from Git history or
treat unchecked items in old schedules or inbox as current without confirmation.

### Prioritize

Present tasks grouped by source/project. Ask:
1. "What's most important [today/tomorrow]?"
2. "Anything blocking or time-sensitive?"

Flag priority conflicts between tasks and personal goals. Limit top 3 focus items.

### Build schedule

**No time blocks.** Output a single flat list ranked by long-term importance — the user schedules their own day. Ranking order:

1. Quarter/year OKR-advancing items (long-term first)
2. Time-sensitive or blocking items — tag with `⏰` and the deadline
3. Everything else, by priority

Format: `# DayOfWeek, Month DD, YYYY`, then `## Ranked (schedule yourself)` with numbered `- [ ] **P0** - description (why: Q3 O2)` items — cap at ~7. Each item states in one parenthetical why it ranks where it does. Monday → add "Check plans & strategies".

**Habits/routine:** do NOT restate daily-schedule.md habits as checkboxes. End the file with one footer line: `Anchors: movement · 2× deep work · 18:00 family stop · 22:30 lights out — see identity/daily-schedule.md`. Habit tracking lives in the journal. Exception: a habit that is an active quarter KR requiring a specific action today gets a ranked-list slot as a real task.

### Alignment commentary

Compare against week/quarter/year goals **and life-area docs** (health, marriage-and-family, friendships, wealth, career). Call out: OKR-advancing items, unconnected items, missing weekly focus coverage, life areas with zero coverage today.

Write to `schedules/<YYYY>/<target-date>.md`.

## Adjust mode

Schedule exists → show state, ask "What changed?", update in place, re-sort by priority.

## Rules

- Never assume priorities — always ask.
- Do not create or archive into retired task lists.
