#!/usr/bin/env bash
# One-shot bootstrap for https://github.com/0x00101010/dotfiles
#
# Usage (recommended, keeps stdin attached to the terminal for prompts):
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/0x00101010/dotfiles/main/install.sh)"
#
# Also works (prompts are redirected from /dev/tty):
#   curl -fsSL https://raw.githubusercontent.com/0x00101010/dotfiles/main/install.sh | bash

set -euo pipefail

REPO_OWNER="0x00101010"
REPO_NAME="dotfiles"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
SRC_DIR="${HOME}/src/${REPO_NAME}"
CHEZMOI_DIR="${HOME}/.local/share/chezmoi"
CHEZMOI_SOURCE_DIR="${SRC_DIR}/home"

log() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }

# Prefer /dev/tty for interactive prompts when stdin is a pipe (curl | bash).
if [ -t 0 ]; then
  TTY_IN=/dev/stdin
elif [ -r /dev/tty ]; then
  TTY_IN=/dev/tty
else
  TTY_IN=""
fi

OS="$(uname -s)"
case "$OS" in
  Linux)  PLATFORM="linux"  ;;
  Darwin) PLATFORM="darwin" ;;
  *) die "Unsupported OS: $OS" ;;
esac

log "Detected platform: $PLATFORM"

# ---------------------------------------------------------------------------
# 1. Install minimum prerequisites: curl, git (chezmoi needs them; the rest is
#    handled by run_once_* scripts inside the repo).
# ---------------------------------------------------------------------------
if [ "$PLATFORM" = "linux" ]; then
  log "Installing prerequisites via apt (sudo required)"
  sudo apt update
  sudo apt install -y curl git ca-certificates
elif [ "$PLATFORM" = "darwin" ]; then
  if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools (provides git)"
    xcode-select --install || true
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  fi
fi

# ---------------------------------------------------------------------------
# 2. Install chezmoi to /usr/local/bin (Linux) or via brew (macOS).
# ---------------------------------------------------------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
  if [ "$PLATFORM" = "darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      log "Installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    log "Installing chezmoi via brew"
    brew install chezmoi
  else
    log "Installing chezmoi to /usr/local/bin"
    sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
  fi
else
  log "chezmoi already installed: $(command -v chezmoi)"
fi

# ---------------------------------------------------------------------------
# 3. Clone the repo to ~/src/dotfiles and point chezmoi at it.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$SRC_DIR")"
if [ ! -d "$SRC_DIR/.git" ]; then
  log "Cloning $REPO_URL to $SRC_DIR"
  git clone "$REPO_URL" "$SRC_DIR"
else
  log "Repo already present at $SRC_DIR, pulling latest"
  git -C "$SRC_DIR" pull --ff-only || true
fi

# Symlink the chezmoi source dir so `chezmoi` picks up the repo.
mkdir -p "$(dirname "$CHEZMOI_DIR")"
if [ -L "$CHEZMOI_DIR" ] || [ -d "$CHEZMOI_DIR" ]; then
  if [ "$(readlink "$CHEZMOI_DIR" 2>/dev/null || true)" != "$CHEZMOI_SOURCE_DIR" ]; then
    log "Replacing existing $CHEZMOI_DIR with symlink to $CHEZMOI_SOURCE_DIR"
    rm -rf "$CHEZMOI_DIR"
    ln -s "$CHEZMOI_SOURCE_DIR" "$CHEZMOI_DIR"
  fi
else
  ln -s "$CHEZMOI_SOURCE_DIR" "$CHEZMOI_DIR"
fi

# ---------------------------------------------------------------------------
# 4. Run chezmoi init + apply. Use /dev/tty so prompts work under `curl | bash`.
# ---------------------------------------------------------------------------
log "Running: chezmoi init && chezmoi apply -v"
if [ -n "$TTY_IN" ] && [ "$TTY_IN" != "/dev/stdin" ]; then
  chezmoi init  < "$TTY_IN"
  chezmoi apply -v < "$TTY_IN"
else
  chezmoi init
  chezmoi apply -v
fi

log "Done. Restart your shell (or 'exec zsh') to pick up the new environment."
