# dotfiles

Cross-platform dotfiles and environment setup for macOS & Linux. Managed with
chezmoi and mise for consistent tooling, shells, and developer workflows across
all machines.

## Quick install (macOS & Linux)

Run this on a fresh machine — it installs prerequisites, clones the repo to
`~/src/0x00101010/dotfiles`, and applies everything via chezmoi:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/0x00101010/dotfiles/main/install.sh)"
```

The `sh -c "$(curl …)"` form keeps stdin attached to your terminal so chezmoi
can prompt you for `email`, `fullName`, and `signingkey`. The pipe form also
works (`curl … | bash`) — it falls back to `/dev/tty` for prompts.

## What it does

1. Detects your OS (`linux` / `darwin`).
2. Installs the minimum prerequisites (`curl`, `git`, and on macOS the Xcode
   Command Line Tools + Homebrew).
3. Installs [chezmoi](https://chezmoi.io).
4. Clones this repo to `~/src/0x00101010/dotfiles` and symlinks
   `~/.local/share/chezmoi → ~/src/0x00101010/dotfiles/home` so bootstrap files such as
   `install.sh` are not applied into `$HOME`.
5. Runs `chezmoi init && chezmoi apply -v`, which triggers the
   `run_once_*` bootstrap scripts (Homebrew packages, apt packages, mise,
   tmux/oh-my-zsh plugins, Docker, etc.).

## Day-to-day commands

From the repo root, `just` lists every recipe:

| Recipe | Does |
| --- | --- |
| `just setup` | `chezmoi init`; add `--prompt` to re-answer saved questions |
| `just apply` / `just diff` | `chezmoi apply -v` / preview the changes |
| `just test` | every check below, none touching your home |
| `just sync` / `just sync-log` | run reposync now / show its recent cron log |
| `just skills` | rerun skillsync |
| `just config` | open `~/.config/dotfiles` |

## Local config: `~/.config/dotfiles/`

Machine-specific lists that may name private checkouts live here, one file per
tool, outside this repo: `reposync` and `skill-sources`. Chezmoi creates
`reposync` once with usage comments and never overwrites it. Existing
`~/.config/agents/skill-sources` files are not moved; move them by hand.

## reposync

`~/.local/bin/reposync` runs from the user crontab every 5 minutes (the entry
tagged `# reposync (managed by chezmoi)`; other entries are kept). For each repo
listed in `~/.config/dotfiles/reposync` it commits all changes as
`auto-sync: N files [host] <time>`, fetches, rebases onto the checked-out
branch's upstream, and pushes without force. Repos are skipped mid-rebase/merge,
on a detached HEAD, or without an upstream; any file edited within the last
minute defers the commit. A rebase conflict is aborted, leaving the local work
in a commit for you to resolve. Rebased commits are re-signed, so signing must
work without a prompt. Log: `~/.local/state/reposync/log`.

## Manual / legacy entry points

The OS-specific helpers still exist if you prefer to read or tweak them
before running anything:

- `./scripts/setup-mac.sh`
- `./scripts/setup-linux.sh`

## Coding agents

`chezmoi init` asks for an explicit `work` or `personal` profile. On first setup,
it automatically selects supported agents (`claude`, `codex`, `amp`) already on
`PATH`, without prompting or running their binaries. If none are found, it asks
with a multi-select prompt. Saved selections, including an empty list, are kept
on subsequent runs. Use `chezmoi init --prompt` to choose explicitly instead;
include `--prompt` when supplying a `--promptMultichoice` answer to override detection.
Agent selection controls binary installation and the wiring below. Authentication
is separate; cbcode remains unconfigured until its internal setup is verified.

`ai/instructions/AGENTS.md` is the common source. Chezmoi adds profile context:

- **Work:** `~/src/0x00101010/coinbase`, with plans below `projects/<project>/plans/`.
- **Personal:** `~/src/0x00101010/workspace`, with plans below `projects/personal/<project>/plans/`.

The instructions also name the profile's repo registry and research destinations.
A missing context checkout never selects the other profile's checkout.

| Agent | Default instructions | Coding skills |
| --- | --- | --- |
| Claude | `~/.claude/CLAUDE.md` | `~/.claude/skills/` |
| Codex | `~/.codex/AGENTS.md` | `~/.agents/skills/` |
| Amp | `~/.config/amp/AGENTS.md` | Shared with Codex; Amp also reads `~/.claude/skills/` |

Selecting Amp renders the same instructions to `~/.config/amp/AGENTS.md` and links
`~/.config/amp/plugins/pr-review.ts` to `ai/amp/plugins/`; it adds
`review_with_models`, which the `pr` skill uses to run reviews on two models (deep tier) or one (light).
Existing Amp settings are left alone.

Selecting any agent links `~/.local/bin/devslot` to `ai/bin/devslot`. The `pr`
skill tells agents to work in the current checkout, except in repos that
keep `dev<N>` worktrees beside the default one: `devslot claim <branch>` takes a
free slot (lock in the slot's git dir, branch off `origin/<default>`, build cache
intact) and `devslot release` returns it once the PR is ready. Locks older than 12h
on clean, fully pushed slots are reclaimed automatically; parallelism is the slot count.

Skills kept in other repos (company or personal, not committed here) come in
through `~/.local/bin/skillsync`. List sources in `~/.config/dotfiles/skill-sources`,
one per line: `<repo-or-skills-dir> [as <prefix>] [only <skill>,<skill>]`. A repo
contributes `.agents/skills/*` and `.claude/skills/*`; each skill is copied to
`~/.agents/skills/<prefix>-<skill>` (prefix defaults to the directory name) with
its frontmatter `name` rewritten, so agents see `meridian-planning` rather than a
second `planning`. Claude gets `~/.claude/skills/<prefix>-<skill>` links to the
copies. The copies are not chezmoi-managed; `chezmoi apply` reruns `skillsync`
when the sources file exists and otherwise prints where to create it. Repos
listed but not cloned are skipped with a warning. Skills
dropped from the list are removed again; a name that already exists and was not
installed by skillsync is refused.

Both profiles install `pr`, `plan`, `execute-plan`, `agent-browser`, and `beautiful-mermaid` for
the selected agents. Each file links to its source under `ai/skills/`, including
bundled scripts, templates, and references. Individual links preserve sibling
custom files, including notes within resource directories. The source checkout
must remain available; the installer resolves the chezmoi source symlink before
locating `ai/`.

The `plan` skill reads the shared profile context below for its destination and
repo registry. It preserves the phased-plan and PR-handoff format without
depending on retired skills or any particular coding agent's research tools.
`execute-plan` runs a written plan: each phase's `**Repo:**` resolves through the
registry, slot repos are claimed with `devslot`, other repos get a branch in their
default checkout, ready slices run as a batch (implement subagents → multi-model
review in the orchestrator → open-PR subagents), CI and review comments are
watched by the orchestrator in background processes while the next batch runs,
and a `**Status:**` line is kept under the phase.

`_shared/workspace.md` is now a profile-aware reference, installed as
`~/.agents/skills/_shared/instructions.md` for any selected agent. Claude's
`skills/_shared/instructions.md` links to that file (also under a custom config
directory). It shares path definitions with the generated agent instructions,
which link to it for on-demand reading; it is not a discoverable skill by itself.
Work gets company plans/research; personal gets personal plans,
journals, and year-grouped schedules. Stale todo lists were removed by request,
and the shared instructions prohibit reconstructing them from history.

`CLAUDE_CONFIG_DIR` and `CODEX_HOME` are honored when set during apply.
Default destinations are declarative chezmoi targets; the
`30_configure_agent_overrides` hook handles non-default destinations, including
paths outside home. Use absolute paths and the same overrides when launching agents.
Codex/shared skills still live at `~/.agents/skills`, independently of `CODEX_HOME`.

Claude settings preserve existing values, including local environment, plugin,
sandbox, and permission settings. Existing allow/ask lists are not broadened;
deny rules retain local entries and add repo defaults. Only `plansDirectory` and
the old managed statusline command are migrated. Malformed settings stop the update.
Company-managed policy, credentials, and Amp/Codex settings are not modified.

### Retained skill bundles; auto-download deferred

- [`agent-browser`](https://github.com/vercel-labs/agent-browser/tree/main/skills/agent-browser):
  upstream browser automation skill. Its CLI and browser runtime need separate installation.
- [`beautiful-mermaid`](https://github.com/intellectronica/agent-skills/tree/main/skills/beautiful-mermaid):
  community rendering skill, separate from the `lukilabs/beautiful-mermaid` library.
  Keep its scripts/references together; PNG capture uses agent-browser.

The existing `agent-browser` and `beautiful-mermaid` bundles are preserved unchanged
in `ai/skills/` and installed through local file links. No upstream download or
update runs during apply. A future auto-download implementation can use chezmoi
external archives pinned to reviewed commits with checksums; no sync service is needed.

The retained Mermaid renderer still runs unpinned `npm install`/`bun add` in the
current directory when its package is missing. This move does not change that
behavior. Use a disposable rendering directory, not a coding checkout; isolating
and pinning the dependency remains future work.

### Existing-machine cutover

Review the diff before applying: changed `run_once` bootstrap scripts can run again.
`home/.chezmoiremove` deletes the retired Claude-only skills (`add`,
`immunefi-review`, `investigate`, `journal`, `prio`, `qmd`, `repos`, `workon`) and
the old `_shared/workspace.md` from the default `~/.claude` on apply; check
`chezmoi status` for the `D` lines first. Installed-only skills from older setups
(`fix-issue`, `interview`, `security`, `swarm`, `task`, `ultrathink`) and the four
old Claude review agents are not touched; remove them by hand after review.
Sibling custom notes beside managed files are preserved.
Changing profiles/agent selection does not uninstall ignored files. Check for
Codex `AGENTS.override.md` and higher-priority skill copies before declaring the
new sources active. Do not edit vendor-managed caches.

Task capture through `/add` and Latch is retired; no replacement is installed.
Uninstall the Latch Raycast extension on any machine where it remains installed
to stop its capture, issue sync, inbox triage, and background reindex commands.
Removing its source checkout does not uninstall the extension. Preserve existing
inbox, journal, and schedule files. The user separately authorized removal of all
stale todo files (including archives and habits) from both context repositories.

### Checks without applying to your home

```sh
tests/bootstrap/run.sh
python3 tests/agents/test_wiring.py
tests/devslot/run.sh
tests/skillsync/run.sh
tests/reposync/run.sh
```

The wiring tests apply only agent targets in disposable homes and run only the
override hook, never machine bootstrap or network installers. They cover both
profiles, profile switching, repeated application, existing settings/skills,
complete skill-bundle links, executable modes, shared-reference links, retired
skill removal, and native path overrides. They do not exercise browser automation
or Mermaid rendering. The devslot test builds a throwaway bare repo with `dev1`
and `dev2` worktrees and exercises claim, release, stale reclaim, and refusals.

## Repo layout

- `ai/` — company-independent coding instructions, skills, Amp plugins, and
  `bin/devslot`.
- `home/` — chezmoi source state (everything that gets applied to `$HOME`).
  - `home/.chezmoiscripts/` — `run_once_*` bootstrap scripts.
- `scripts/` — standalone installers run by hand.
- `install.sh` — one-shot bootstrap entry point.
