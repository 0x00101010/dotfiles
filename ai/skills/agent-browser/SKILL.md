---
name: agent-browser
description: Automates browser interactions for web testing, form filling, screenshots, and data extraction. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages.
allowed-tools: Bash(agent-browser:*)
---

## Core workflow

1. `agent-browser open <url>` — navigate
2. `agent-browser snapshot -i` — get interactive elements with refs (`@e1`, `@e2`)
3. Interact using refs
4. Re-snapshot after navigation or DOM changes

## Commands

```bash
# Navigation
open <url>          back          forward          reload          close
connect <port>      # CDP connection

# Snapshot
snapshot            # Full tree
snapshot -i         # Interactive only (recommended)
snapshot -c         # Compact
snapshot -d 3       # Depth limit
snapshot -s "#id"   # Scope to selector

# Interact (use @refs)
click @e1           dblclick @e1      hover @e1         focus @e1
fill @e2 "text"     # Clear + type
type @e2 "text"     # Type without clearing
press Enter         press Control+a
check @e1           uncheck @e1       select @e1 "val"
scroll down 500     scrollintoview @e1
drag @e1 @e2        upload @e1 file.pdf

# Get info
get text @e1        get html @e1      get value @e1     get attr @e1 href
get title           get url           get count ".item"
get box @e1         get styles @e1
is visible @e1      is enabled @e1    is checked @e1

# Screenshots & capture
screenshot [path]               screenshot --full
pdf output.pdf
record start ./demo.webm        record stop

# Wait
wait @e1                        wait 2000
wait --text "Success"           wait --url "**/dash"
wait --load networkidle         wait --fn "window.ready"

# Semantic locators (alt to refs)
find role button click --name "Submit"
find text "Sign In" click       find label "Email" fill "val"
find testid "btn" click         find placeholder "Search" type "q"

# Settings
set viewport 1920 1080          set device "iPhone 14"
set geo 37.7 -122.4             set offline on
set credentials user pass       set media dark

# Storage & cookies
cookies             cookies set k v         cookies clear
storage local       storage local set k v   storage local clear

# Network
network route <url>             network route <url> --abort
network route <url> --body '{}' network requests [--filter api]

# Tabs & frames
tab [new|close|N]   frame "#iframe"   frame main

# Other
dialog accept [text]   dialog dismiss   eval "js"
```

## Global options

`--session <name>`, `--json`, `--headed`, `--full`, `--cdp <port>`, `--proxy <url>`, `--ignore-https-errors`

## Auth state persistence

```bash
agent-browser state save auth.json    # After login
agent-browser state load auth.json    # Reuse later
```

## References

See `references/` for: snapshot-refs, session-management, authentication, video-recording, proxy-support.
See `templates/` for: form-automation, authenticated-session, capture-workflow.
