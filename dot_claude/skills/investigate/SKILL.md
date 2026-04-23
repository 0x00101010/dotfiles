---
name: investigate
description: Open-ended investigation of a question, problem, or reference. Researches adaptively (light by default, escalates when hard) and writes a findings report into the workspace, co-located with the originating project when possible.
---

## 1. Resolve the input

`$ARGUMENTS` may be any of:

- **Freeform question** (e.g. `why does opencode lose tool context after compress?`) → use as the investigation prompt directly.
- **Workspace path** to a plan/note (e.g. `projects/work/2026/qmdb/plans/some-question.md`) → read the file; treat its contents as the investigation spec. Remember the project root.
- **Todo reference** → search `~/src/workspace/todos/{work,personal,recurring}.md` for a line whose description matches `$ARGUMENTS`. Multiple matches → show candidates, let user pick.
- **Linear issue ID** (matches `^[A-Z]+-\d+$`, e.g. `ENG-123`) → fetch via Linear API, use issue title + description as the prompt.

Also check `~/src/workspace/todos/work.md` for a `LINEAR:` ref matching the issue ID — it may carry extra context.

If the input is genuinely ambiguous (multiple valid interpretations, very different scope), ask **one** clarifying question. Otherwise proceed and note assumptions in the report.

## 2. Decide the output location

Pick the most specific applicable destination:

1. **From a plan file or referenced project** → `<project-root>/research/<topic-slug>.md` (create `research/` next to `plans/` if missing).
2. **From a todo with a project hint** (e.g. `... in qmdb`, or context lines mention a project) → same as above.
3. **Otherwise** → `~/src/workspace/knowledge/research/<topic-slug>.md` (create dirs as needed).

Slug: lowercase, hyphen-separated, derived from the question. Date-prefix only when the investigation is time-sensitive (e.g. `2026-04-23-opencode-compress-bug.md`); otherwise omit the date so it reads as evergreen knowledge.

If a file already exists at that path, append a new dated section rather than overwrite.

## 3. Investigate (adaptive depth)

**Default — light pass, parallel:**

- `explore` (background) for any internal codebase angles
- `librarian` (background) for external docs / OSS examples / library behavior
- `qmd` for prior notes already in the workspace
- Web search for current/external info

Fire these in parallel from the start. Continue working while they run; collect with `background_output`.

**Escalate when:**

- 2+ light passes leave the core question unanswered → consult `oracle` for reasoning.
- The problem is genuinely hard, multi-system, or requires deep synthesis → spawn `ultrathink` for deep-thinking subagents.
- The investigation needs structured experimentation in a repo → consider following with the `task` skill instead.

Stop when: the question is answered, sources start repeating, or further search yields no new signal. Do not over-explore.

## 4. Write the report

Structure (omit empty sections):

```markdown
# <Question / topic>

> Investigated: YYYY-MM-DD · Source: <freeform | path | todo line | LINEAR-ID>

## TL;DR
1–3 sentence answer.

## Findings
The substance — organized by sub-question or theme, not by tool used.

## Evidence
Concrete pointers: file paths with line refs, URLs, prior workspace notes, command output. Each claim should be traceable.

## Open questions
What's still unknown, what would need a deeper investigation or experiment.

## Recommendation / next steps
Only when the input asked for a decision or action. Otherwise omit.
```

Write the user's voice, not embellished prose. Cite — don't paraphrase away — exact errors, quotes, code snippets when they're load-bearing.

## 5. Link back

- **From a plan file** → append `> Investigation: <relative-path-to-report>` near the top of the plan.
- **From a todo line** → append ` | INVESTIGATION:<relative-path>` to the line (don't mark it done).
- **From a Linear issue** → post a comment with the report path and TL;DR. Don't change issue status.
- **Freeform / no source** → just print the report path at the end.

## Rules

- Never auto-complete the originating todo/issue — investigations inform, they don't close work.
- Never fabricate findings or sources. If something is inferred, label it as such.
- Surgical writes only: create the report file and link back. Don't touch unrelated workspace files.
- Prefer `knowledge/research/` over `strategies/` — strategies are for the user's own thinking, research is for evidence.
