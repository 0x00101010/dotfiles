#!/usr/bin/env bash
set -euo pipefail

# Change shell to zsh for the user
sudo passwd ubuntu
chsh -s /bin/zsh ubuntu