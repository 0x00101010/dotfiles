#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Chrome Sidebar
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🌐
# @raycast.packageName Chrome

binary="$HOME/.local/bin/toggle-chrome-sidebar"

if [[ ! -x "$binary" ]]; then
  echo "Missing $binary. Run chezmoi apply to build it."
  exit 1
fi

exec "$binary"
