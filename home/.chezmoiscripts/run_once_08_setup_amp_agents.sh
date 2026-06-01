#!/bin/bash
# Symlink CLAUDE.md as AGENTS.md so Amp reads the same global instructions as Claude Code
mkdir -p ~/.config/amp
ln -sf ~/.claude/CLAUDE.md ~/.config/amp/AGENTS.md
