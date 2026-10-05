#!/usr/bin/env bash
# Bootstrap checks using disposable homes and stubbed commands. Never touches
# the real home, package managers, network, or disks.
# Usage: tests/bootstrap/run.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS="$REPO/home/.chezmoiscripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }
has() { grep -qF -- "$2" "$1"; }
lacks() { ! grep -qF -- "$2" "$1"; }

# Stub that appends "name args" to $LOG and exits 0.
stub() { printf '#!/bin/sh\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$3/$1"; chmod +x "$3/$1"; }

# --- install.sh: runs under sh (dash), orders prerequisites before chezmoi --
install_case() { # <shell> <os> <name>
  local sh=$1 os=$2 dir="$TMP/install-$1-$2-$3"
  mkdir -p "$dir/bin" "$dir/home"
  export LOG="$dir/log"; : > "$LOG"
  stub uname "echo $os" "$dir/bin"
  stub sudo 'exec "$@"' "$dir/bin"
  for c in apt brew xcode-select curl chezmoi; do stub "$c" "" "$dir/bin"; done
  stub git '[ "$1" = clone ] && mkdir -p "$3/.git"; exit 0' "$dir/bin"
  # Existing checkout with local work must survive.
  if [ "$3" = existing ]; then
    mkdir -p "$dir/home/src/dotfiles/.git" "$dir/home/src/dotfiles/home"
    echo wip > "$dir/home/src/dotfiles/local-change"
  fi
  # Same form as the README: sh -c "$(curl …)".
  HOME="$dir/home" PATH="$dir/bin:/usr/bin:/bin" \
    "$sh" -c "$(cat "$REPO/install.sh")" </dev/null >"$dir/out" 2>&1 || { cat "$dir/out"; return 1; }
}

for sh in dash bash; do
  for os in Linux Darwin; do
    if install_case "$sh" "$os" fresh; then pass "install.sh $sh $os runs"; else fail "install.sh $sh $os runs"; continue; fi
    log="$TMP/install-$sh-$os-fresh/log"
    if [ "$os" = Linux ]; then prereq='apt install -y curl git ca-certificates gpg jq'; else prereq='brew install gnupg jq'; fi
    check "install.sh $sh $os installs gpg/jq before chezmoi init" \
      bash -c "grep -nF -- '$prereq' '$log' | cut -d: -f1 | head -1 | { read p; i=\$(grep -n '^chezmoi init' '$log' | cut -d: -f1); [ -n \"\$p\" ] && [ \"\$p\" -lt \"\$i\" ]; }"
    check "install.sh $sh $os applies after init" bash -c "grep -A1 '^chezmoi init' '$log' | grep -q '^chezmoi apply -v'"
    check "install.sh $sh $os clones only dotfiles" bash -c "[ \"\$(grep -c '^git clone' '$log')\" = 1 ] && grep -q '^git clone https://github.com/0x00101010/dotfiles.git' '$log'"
    check "install.sh $sh $os touches no context repo" bash -c "! grep -Eq 'workspace|coinbase' '$log'"
  done
done
install_case dash Linux existing || true
check "install.sh keeps existing checkout and only fast-forwards" \
  bash -c "[ -f '$TMP/install-dash-Linux-existing/home/src/dotfiles/local-change' ] && grep -q '^git -C .* pull --ff-only' '$TMP/install-dash-Linux-existing/log' && ! grep -q '^git clone' '$TMP/install-dash-Linux-existing/log'"
check "legacy setup scripts delegate to install.sh" \
  bash -c "grep -q 'exec sh .*install.sh' '$REPO/scripts/setup-mac.sh' && grep -q 'exec sh .*install.sh' '$REPO/scripts/setup-linux.sh'"

# --- chezmoi config: explicit profile, agents, profile-specific context ----
init_home() { # <dir> <profile> <agents>
  mkdir -p "$1"
  HOME="$1" XDG_CONFIG_HOME="$1/.config" chezmoi init --source "$REPO" --no-tty --prompt \
    --promptChoice "Machine profile=$2" --promptMultichoice "Coding agents to install=$3" \
    --promptString "What is your email address=t@example.com" \
    --promptString "What is your name=Test" \
    --promptString "What is your GPG signing key=ABC" >/dev/null
}
cfg() { echo "$1/.config/chezmoi/chezmoi.toml"; }

init_home "$TMP/work" work claude/amp
init_home "$TMP/personal" personal claude/codex/amp
check "work config" bash -c "grep -q 'profile = \"work\"' '$(cfg "$TMP/work")' && grep -q 'agents = \[\"claude\", \"amp\"\]' '$(cfg "$TMP/work")' && grep -q \"contextRoot = \\\"$TMP/work/src/0x00101010/coinbase\\\"\" '$(cfg "$TMP/work")'"
check "personal config" bash -c "grep -q 'profile = \"personal\"' '$(cfg "$TMP/personal")' && grep -q \"contextRoot = \\\"$TMP/personal/src/workspace\\\"\" '$(cfg "$TMP/personal")'"
check "re-init preserves profile without prompting" bash -c \
  "HOME='$TMP/work' XDG_CONFIG_HOME='$TMP/work/.config' chezmoi init --source '$REPO' --no-tty >/dev/null 2>&1 && grep -q 'profile = \"work\"' '$(cfg "$TMP/work")'"
check "init without a profile answer fails instead of guessing" bash -c \
  "mkdir -p '$TMP/none' && ! HOME='$TMP/none' XDG_CONFIG_HOME='$TMP/none/.config' chezmoi init --source '$REPO' --no-tty </dev/null >/dev/null 2>&1"

# Isolate PATH so the real machine's agents cannot affect detection checks.
chezmoi_bin=$(command -v chezmoi)
mkdir -p "$TMP/detect-bin" "$TMP/detected" "$TMP/explicit" "$TMP/empty"
ln -s "$(command -v git)" "$TMP/detect-bin/git"
detect_init() { # <home> [init flags]
  local home=$1; shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" PATH="$TMP/detect-bin" \
    "$chezmoi_bin" init --source "$REPO" --no-tty \
    --promptChoice "Machine profile=work" \
    --promptString "What is your email address=t@example.com" \
    --promptString "What is your name=Test" \
    --promptString "What is your GPG signing key=ABC" "$@" \
    </dev/null >"$TMP/detect.out" 2>&1
}
if ! detect_init "$TMP/detected" && has "$TMP/detect.out" 'Coding agents to install'; then
  pass "no installed agents still requires a selection"
else fail "no installed agents still requires a selection"; fi
if detect_init "$TMP/explicit" --prompt --promptMultichoice 'Coding agents to install=codex/amp' &&
  has "$(cfg "$TMP/explicit")" 'agents = ["codex", "amp"]'; then
  pass "fresh-machine agent selection remains multi-select"
else fail "fresh-machine agent selection remains multi-select"; fi
for agent in claude codex amp; do printf '#!/bin/sh\nexit 97\n' > "$TMP/detect-bin/$agent"; done
chmod +x "$TMP/detect-bin/claude" "$TMP/detect-bin/amp"
if detect_init "$TMP/detected" && has "$(cfg "$TMP/detected")" 'agents = ["claude", "amp"]'; then
  pass "installed agents selected without prompting or executing; non-executable ignored"
else cat "$TMP/detect.out"; fail "installed agents selected without prompting or executing; non-executable ignored"; fi
rm "$TMP/detect-bin/amp"; chmod +x "$TMP/detect-bin/codex"
if detect_init "$TMP/detected" && has "$(cfg "$TMP/detected")" 'agents = ["claude", "amp"]'; then
  pass "saved selection survives changed installed agents"
else fail "saved selection survives changed installed agents"; fi
mkdir -p "$TMP/empty/.config/chezmoi"
printf '[data]\nprofile = "work"\nagents = []\n' > "$(cfg "$TMP/empty")"
if detect_init "$TMP/empty" && has "$(cfg "$TMP/empty")" 'agents = []'; then
  pass "saved empty selection stays empty despite installed agents"
else fail "saved empty selection stays empty despite installed agents"; fi
if ! detect_init "$TMP/detected" --prompt && has "$TMP/detect.out" 'Coding agents to install'; then
  pass "--prompt still asks despite installed agents and saved selection"
else fail "--prompt still asks despite installed agents and saved selection"; fi
if detect_init "$TMP/detected" --prompt --promptMultichoice 'Coding agents to install=codex' &&
  has "$(cfg "$TMP/detected")" 'agents = ["codex"]'; then
  pass "manual selection overrides detected and saved agents"
else fail "manual selection overrides detected and saved agents"; fi

# --- agent install script: only selected, missing agents; context checks ----
render() { HOME="$1" XDG_CONFIG_HOME="$1/.config" chezmoi execute-template --source "$REPO" < "$2"; }
run_agents() { # <home> -> writes $1/agents.log and $1/agents.out
  mkdir -p "$1/stub"
  export LOG="$1/agents.log"; : > "$LOG"
  stub curl "" "$1/stub"
  render "$1" "$SCRIPTS/run_after_20_install_agents.sh.tmpl" > "$1/agents.sh"
  HOME="$1" PATH="$1/stub:/usr/bin:/bin" bash "$1/agents.sh" >"$1/agents.out" 2>&1
}
mkdir -p "$TMP/work/.local/bin"; printf '#!/bin/sh\n' > "$TMP/work/.local/bin/claude"; chmod +x "$TMP/work/.local/bin/claude"
run_agents "$TMP/work"
check "work installs only missing selected agents (amp)" bash -c \
  "[ \"\$(cat '$TMP/work/agents.log')\" = 'curl -fsSL https://ampcode.com/install.sh' ]"
check "work reports cbcode as not installed" has "$TMP/work/agents.out" "cbcode: not installed"
check "work warns about missing coinbase context" has "$TMP/work/agents.out" "context checkout is missing: $TMP/work/src/0x00101010/coinbase"
check "work never references workspace" lacks "$TMP/work/agents.out" "workspace"
run_agents "$TMP/personal"
check "personal installs all three selected agents" bash -c \
  "[ \"\$(wc -l < '$TMP/personal/agents.log')\" = 3 ] && grep -q claude.ai '$TMP/personal/agents.log' && grep -q chatgpt.com/codex '$TMP/personal/agents.log' && grep -q ampcode.com '$TMP/personal/agents.log'"
check "personal never references coinbase or cbcode" bash -c "! grep -Eq 'coinbase|cbcode' '$TMP/personal/agents.out'"
mkdir -p "$TMP/personal/src/workspace"; run_agents "$TMP/personal"
check "no warning once the context checkout exists" lacks "$TMP/personal/agents.out" "missing"
mkdir -p "$TMP/legacy/.config/chezmoi"; printf '[data]\n  email = "t@example.com"\n' > "$(cfg "$TMP/legacy")"
render "$TMP/legacy" "$SCRIPTS/run_after_20_install_agents.sh.tmpl" > "$TMP/legacy/agents.sh"
check "apply without a profile stops with an init hint" bash -c \
  "! HOME='$TMP/legacy' bash '$TMP/legacy/agents.sh' > '$TMP/legacy/out' 2>&1 && grep -q \"Run 'chezmoi init'\" '$TMP/legacy/out'"

# --- RAID script: hosts without extra NVMe drives exit 0 -------------------
# Only the detection prefix runs; mdadm/mkfs lines are never executed.
render "$TMP/work" "$SCRIPTS/run_once_02_raid0.linux.sh.tmpl" | sed -n '2,/^fi/p' > "$TMP/raid-head.sh"
for drives in "" "/dev/nvme0n1"; do
  check "raid detection exits 0 with drives [$drives]" bash -c "ls() { printf '%s\n' $drives; }; source '$TMP/raid-head.sh'; exit 1"
done

echo
if [ "$fails" -eq 0 ]; then echo "all bootstrap checks passed"; else echo "$fails bootstrap check(s) failed"; exit 1; fi
