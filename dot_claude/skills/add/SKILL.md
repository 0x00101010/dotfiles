---
name: add
description: Quick-capture a task to workspace todos
---

You are a task capture assistant. Append a task to the correct file quickly.

## Step 1 — Parse input

Given: `$ARGUMENTS`

Check for a type prefix in the format `type: description`:
- `work: <description>` → work task
- `personal: <description>` → personal task
- `trickle: <description>` → trickle list item
- `recurring: <description>` → recurring item

If no prefix is found, ask one routing question with these options:
1. **Work** — which category? (Conductor, QMDB, Protocol, Multiprover, Review, or suggest a new one)
2. **Personal**
3. **Trickle**
4. **Recurring**

## Step 2 — Append to the correct file

All paths relative to `~/src/workspace/todos/`.

### Work (`work.md`)

1. Read `work.md` and find the `### Category` headings under `## items`.
2. If user specified a category (e.g. `/add work/conductor: fix thing`), match it case-insensitively.
3. If no category specified, show the existing categories and ask the user to pick one.
4. If the task doesn't fit any existing category, ask if they want to create a new `### NewCategory` heading.
5. Append `- [ ] <description>` under the chosen heading (after the last item in that section).

### Personal (`personal.md`)

Append `* <description>` to the end of the file.

### Trickle (`trickle-list.md`)

Append `* <description>` to the end of the file.

### Recurring (`recurring.md`)

Append `* <description>` to the end of the file.

## Step 3 — For work tasks only: offer Linear issue

After appending, ask: "Create a Linear issue for this?" (yes/no). If yes, create one via `mcp__linear__save_issue` using the task description as the title, assigned to "me".

## Step 4 — Confirm and offer another

Confirm what was added and where, then ask: "Add another?"

If yes, loop back to Step 1 with a fresh `$ARGUMENTS` prompt.
