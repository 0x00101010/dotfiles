# Workspace conventions

Shared reference for `add`, `journal`, `prio`, `workon`, `investigate`, `repos` skills.
Read on demand — don't inline its contents into individual skills.

## Layout

All paths relative to `~/src/workspace/`.

```
todos/
  work.md, personal.md, recurring.md, trickle-list.md, archive.md
  inbox.md
schedules/
  <YYYY-MM-DD>.md          ← daily
  <YYYY-MM-DD>-week.md     ← weekly (Monday date)
journal/<YYYY>/<MM>/<YYYY-MM-DD>.md
identity/goals/
  5-year.md, <yyyy>.md, <yyyy>-Q<n>.md
identity/
  career-strategy.md, board-of-directors.md
strategies/
  ideas.md, *.md
projects/{work,personal}/<project>/
  plans/<plan>.md, plans/done/
  research/<topic>.md
knowledge/
  research/<topic>.md
  references/repos.md      ← repo registry (used by `repos` skill)
```

## Todo format

```
- [ ] P{0-3} | description | optional:SOURCE-REF
  > optional context line(s)
```

`SOURCE-REF` examples: `LINEAR:ENG-123`, `PLAN:add-staged-sync`, `INVESTIGATION:<relative-path>`, `GH:owner/repo#123`.

Priority map (Linear): `P0=Urgent(1)`, `P1=High(2)`, `P2=Medium(3)`, `P3=Low(4)`.

## Source resolution

Used by `workon` and `investigate`. Given `$ARGUMENTS`:

1. **Linear ID** (matches `^[A-Z]+-\d+$`, e.g. `ENG-123`) → fetch via Linear API. Cross-check `todos/work.md` for matching `LINEAR:` ref (may carry extra context lines).
2. **GitHub issue** (`gh#N`, `owner/repo#N`) → `gh issue view`.
3. **Workspace path** (file exists, ends `.md`) → read file as the spec; remember project root.
4. **Free text** → search description fields in `todos/{work,personal}.md` and filenames in `projects/**/plans/*.md`.
5. **Multiple matches** → list candidates, ask user. **No matches** → ask.

If input mentions a repo by short name/topic ("the prover work", "qmdb stuff"), load the `repos` skill.

## Archive procedure

Used by `journal`, `prio`, `workon` step "done".

Move completed lines (with their `> context` lines) from `todos/{work,personal}.md` → `todos/archive.md`.

Format in archive:
```
## YYYY-MM
- [x] P{n} | description | optional:ref | YYYY-MM-DD
  > preserved context
```

**Always ask before archiving.** Never auto-archive.

## Linear conventions

- `assignee: "me"` for current user.
- Never auto-complete or auto-transition status.
- When resolving a Linear-sourced task, `todos/work.md` may have a `LINEAR:` ref — check for additional context lines there.

## Repo resolution

Use the `repos` skill. It reads `knowledge/references/repos.md`.

Bare-repo layout (has `.bare/`): work in `~/src/<repo>/main`. Standard repos: `~/src/<repo>`.

Don't guess silently — ambiguous topic → list candidates and ask.

## Universal rules

- Never fabricate entries, findings, or sources.
- Never auto-complete the user's todos or Linear issues.
- Always present drafts and get confirmation before destructive writes.
- Surgical writes only — touch only the files the skill is meant to touch.
- Preserve the user's voice; don't embellish prose.
