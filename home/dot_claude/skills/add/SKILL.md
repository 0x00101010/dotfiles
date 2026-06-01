---
name: add
description: Quick-capture a task to workspace todos
---

See `_shared/workspace.md` for todo format and Linear conventions.

## 1. Parse `$ARGUMENTS`

Type prefix forms (route directly):
- `work: <desc>` or `work/<category>: <desc>` → work
- `personal: <desc>` → personal
- `trickle: <desc>` → trickle
- `recurring: <desc>` → recurring

No prefix → ask: Work (which category?) / Personal / Trickle / Recurring.

## 2. Append

All paths relative to `~/src/workspace/todos/`.

- **work.md** — find `### Category` headings under `## items`. Match user's category case-insensitively. No match → show categories, ask. Doesn't fit any → ask if they want a new `### NewCategory`. Append `- [ ] <desc>` under chosen heading.
- **personal.md / trickle-list.md / recurring.md** — append `* <desc>` to end of file.

## 3. Work tasks: offer Linear

Ask: "Create a Linear issue for this?" If yes → `mcp__linear__save_issue` with description as title, `assignee: "me"`.

## 4. Confirm + offer another

Confirm what was added and where. Ask "Add another?" → loop to step 1 if yes.
