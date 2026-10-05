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
| Amp | Not managed for now | Shared with Codex; no additional Amp copy |

Amp can discover shared and Claude skills without Amp-specific configuration.
Its binary remains selectable, but no Amp instructions or settings are installed.
Existing Amp configuration is left alone. Skill discovery does not itself provide
Amp with the profile instructions generated for Claude and Codex on a fresh machine.

Both profiles install `pr`, `plan`, `agent-browser`, and `beautiful-mermaid` for
the selected agents. Each file links to its source under `ai/skills/`, including
bundled scripts, templates, and references. Individual links preserve sibling
custom files, including notes within resource directories. The source checkout
must remain available; the installer resolves the chezmoi source symlink before
locating `ai/`.

The `plan` skill reads the shared profile context below for its destination and
repo registry. It preserves the phased-plan and PR-handoff format without
depending on retired skills or any particular coding agent's research tools.

`_shared/workspace.md` is now a profile-aware reference, installed as
`~/.agents/skills/_shared/instructions.md` for any selected agent. Claude's
`skills/_shared/instructions.md` links to that file (also under a custom config
directory). It shares path definitions with the generated agent instructions,
which link to it for on-demand reading; it is not a discoverable skill by itself.
Work gets company plans/research; personal gets personal plans,
journals, and year-grouped schedules. The personal `journal` and `prio`
skills read this reference and no longer import company tasks or Linear activity.
Stale todo lists were removed by request; these skills no longer read or archive
them, and the shared instructions prohibit reconstructing them from history.

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
Source retirement does **not** delete installed files. During the separately
reviewed cutover, compare/back up the old owned copies before removing retired
skills (`add`, `investigate`, `repos`, `workon`, and installed-only
`fix-issue`, `interview`, `security`,
`swarm`, `task`, `ultrathink`) and the four old Claude review agents.
Do not delete same-named upstream or customized replacements blindly.

`journal`, `prio`, and `qmd` remain personal-only sources; an
existing work installation needs their old copies reviewed at cutover too.
The old installed `_shared/workspace.md` is left for that review; only the new
`instructions.md` is managed, and sibling custom notes are preserved.
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
```

The wiring tests apply only agent targets in disposable homes and run only the
override hook, never machine bootstrap or network installers. They cover both
profiles, profile switching, repeated application, existing settings/skills,
complete skill-bundle links, executable modes, shared-reference links, and native
path overrides. They do not exercise browser automation or Mermaid rendering.

## Repo layout

- `ai/` — company-independent coding instructions and skills.
- `home/` — chezmoi source state (everything that gets applied to `$HOME`).
  - `home/.chezmoiscripts/` — `run_once_*` bootstrap scripts.
- `scripts/` — standalone installers run by hand.
- `install.sh` — one-shot bootstrap entry point.
