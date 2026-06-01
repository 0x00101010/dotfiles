# dotfiles

Cross-platform dotfiles and environment setup for macOS & Linux. Managed with
chezmoi and mise for consistent tooling, shells, and developer workflows across
all machines.

## Quick install (macOS & Linux)

Run this on a fresh machine — it installs prerequisites, clones the repo to
`~/src/dotfiles`, and applies everything via chezmoi:

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
4. Clones this repo to `~/src/dotfiles` and symlinks
   `~/.local/share/chezmoi → ~/src/dotfiles`.
5. Runs `chezmoi init && chezmoi apply -v`, which triggers the
   `run_once_*` bootstrap scripts (Homebrew packages, apt packages, mise,
   tmux/oh-my-zsh plugins, Docker, etc.).

## Manual / legacy entry points

The OS-specific helpers still exist if you prefer to read or tweak them
before running anything:

- `./setup-mac.sh`
- `./setup-linux.sh`
