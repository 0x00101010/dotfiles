#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Devin Review
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName Devin
# @raycast.argument1 { "type": "text", "placeholder": "GitHub PR URL" }

url="$1"

devin_url=$(echo "$url" | sed 's|https://github.com/|https://app.devin.ai/review/|')

echo "$devin_url"
open "$devin_url"
