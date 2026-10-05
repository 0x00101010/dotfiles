---
name: add
description: Quick-capture a task to workspace todos
---

Read `../_shared/instructions.md` for the active context root, layout, and todo conventions.
This skill is personal-only. Do not capture company tasks in personal context;
for a work request, stop and ask the user to use the work profile.

## 1. Parse `$ARGUMENTS`

Type prefix forms (route directly):
- `personal: <desc>` → personal
- `trickle: <desc>` → trickle
- `recurring: <desc>` → recurring

No prefix → ask: Personal / Trickle / Recurring.

## 2. Append

All paths relative to `todos/` under the context root in the shared instructions.

- **personal.md / trickle-list.md / recurring.md** — append `* <desc>` to end of file.

## 3. Confirm + offer another

Confirm what was added and where. Ask "Add another?" → loop to step 1 if yes.
