---
name: beautiful-mermaid
description: Render Mermaid diagrams as SVG and PNG using the Beautiful Mermaid library. Use when the user asks to render a Mermaid diagram.
---

Requires `agent-browser` skill for PNG capture.

## Themes

default, dracula, solarized, zinc-dark, tokyo-night, tokyo-night-storm, tokyo-night-light, catppuccin-latte, nord, nord-light, github-dark, github-light, one-dark. Default: `default`.

## Syntax tips

- Edge labels: use `-->|label|` (not `-- label -->`)
- Special chars in labels: wrap in quotes `A["Label (parens)"]`
- See `references/mermaid-syntax.md` for full syntax

## Workflow

### 1. Render SVG

```bash
bun run scripts/render.ts --code "graph TD; A-->B" --output diagram --theme default
# Or from file: --input diagram.mmd
# Alt runtimes: npx tsx, deno run
```

### 2. Create HTML wrapper

```bash
bun run scripts/create-html.ts --svg diagram.svg --output diagram.html
```

### 3. Capture PNG

```bash
agent-browser set viewport 3840 2160
agent-browser open "file://$(pwd)/diagram.html"
agent-browser wait 1000
agent-browser screenshot --full diagram.png
agent-browser close
```

### 4. Clean up

Remove intermediary files (`.html`, `.mmd`). Only `.svg` and `.png` remain.

## Troubleshooting

- Cut off → check edge label syntax, unique node IDs, closed brackets
- Empty SVG → validate at https://mermaid.live, check special chars, ensure direction (`graph TD`)
