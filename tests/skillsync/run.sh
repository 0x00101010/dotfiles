#!/usr/bin/env bash
# skillsync checks in a disposable home with two fake source repos.
# Usage: tests/skillsync/run.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLSYNC="$REPO/ai/bin/skillsync"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
fails=0

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

export HOME="$TMP/home"
unset XDG_CONFIG_HOME XDG_STATE_HOME CLAUDE_CONFIG_DIR SKILL_SOURCES
mkdir -p "$HOME/.claude" "$HOME/.agents/skills/plan" "$HOME/.config/dotfiles"
echo "dotfiles plan" > "$HOME/.agents/skills/plan/SKILL.md"
SOURCES="$HOME/.config/dotfiles/skill-sources"

skill() {  # dir name [frontmatter-name]
  mkdir -p "$1/$2/scripts"
  printf -- '---\nname: %s\ndescription: %s skill\n---\n\nBody of %s.\n' "${3:-$2}" "$2" "$2" > "$1/$2/SKILL.md"
  echo "echo $2" > "$1/$2/scripts/run.sh"
}
skill "$TMP/src/meridian/.agents/skills" planning
skill "$TMP/src/factory/.claude/skills" test
skill "$TMP/src/factory/.claude/skills" style
mkdir -p "$TMP/src/factory/.claude/skills/plain" && echo "no frontmatter" > "$TMP/src/factory/.claude/skills/plain/SKILL.md"
skill "$TMP/src/loose" direct

check "missing sources file is an error" bash -c "! '$SKILLSYNC' 2>/dev/null"

: > "$SOURCES"
"$SKILLSYNC" >/dev/null && "$SKILLSYNC" >/dev/null
check "empty sources twice leaves other skills alone" [ -f "$HOME/.agents/skills/plan/SKILL.md" ]

cat > "$SOURCES" <<EOF
# comment line
~/../src/meridian
$TMP/src/factory as fac only test,plain
$TMP/src/loose
$TMP/src/not-cloned
EOF
out=$("$SKILLSYNC" 2>&1)
check "summary names count and skills" grep -q "4 skill(s) from 3 source(s)" <<< "$out"
check "missing repo is skipped with a warning" grep -q "skipping $TMP/src/not-cloned (not found)" <<< "$out"
check "repo prefix from dir name" [ -f "$HOME/.agents/skills/meridian-planning/SKILL.md" ]
check "frontmatter name rewritten" grep -qx "name: meridian-planning" "$HOME/.agents/skills/meridian-planning/SKILL.md"
check "body and support files copied" bash -c "grep -q 'Body of planning' '$HOME/.agents/skills/meridian-planning/SKILL.md' && [ -f '$HOME/.agents/skills/meridian-planning/scripts/run.sh' ]"
check "as overrides prefix, only filters" bash -c "[ -d '$HOME/.agents/skills/fac-test' ] && [ -d '$HOME/.agents/skills/fac-plain' ] && [ ! -e '$HOME/.agents/skills/fac-style' ]"
check "skill without frontmatter copied as is" [ "$(cat "$HOME/.agents/skills/fac-plain/SKILL.md")" = "no frontmatter" ]
check "skills dir given directly" [ -f "$HOME/.agents/skills/loose-direct/SKILL.md" ]
check "claude links point at copies" [ "$(readlink "$HOME/.claude/skills/fac-test")" = "$HOME/.agents/skills/fac-test" ]
check "dotfiles skill untouched" [ "$(cat "$HOME/.agents/skills/plan/SKILL.md")" = "dotfiles plan" ]

echo "Edited." >> "$TMP/src/meridian/.agents/skills/planning/SKILL.md"
"$SKILLSYNC" >/dev/null
check "rerun refreshes copies" grep -q "Edited." "$HOME/.agents/skills/meridian-planning/SKILL.md"

printf '%s\n' "$TMP/src/loose" > "$SOURCES"
"$SKILLSYNC" >/dev/null
check "dropped sources are removed" bash -c "[ ! -e '$HOME/.agents/skills/meridian-planning' ] && [ ! -e '$HOME/.claude/skills/fac-test' ] && [ -d '$HOME/.agents/skills/loose-direct' ]"

skill "$TMP/src/other/.agents/skills" direct
printf '%s\n' "$TMP/src/loose" "$TMP/src/other as loose" > "$SOURCES"
check "duplicate names are refused" bash -c "! '$SKILLSYNC' 2>/dev/null"
printf '%s\n' "$TMP/src/other" "$TMP/src/loose bogus" > "$SOURCES"
"$SKILLSYNC" 2>/dev/null && fail "bad token should abort"
printf '%s\n' "$TMP/src/other" > "$SOURCES"
check "copies from an aborted run are still recognized" bash -c "'$SKILLSYNC' >/dev/null 2>&1 && [ -f '$HOME/.agents/skills/other-direct/SKILL.md' ]"

mkdir -p "$TMP/src/dotfiles-clash/.agents/skills" && skill "$TMP/src/dotfiles-clash/.agents/skills" x
printf '%s\n' "$TMP/src/dotfiles-clash as foo" > "$SOURCES"
mkdir -p "$HOME/.agents/skills/foo-x" && echo mine > "$HOME/.agents/skills/foo-x/SKILL.md"
check "existing foreign dir is refused" bash -c "! '$SKILLSYNC' 2>/dev/null && [ \"\$(cat '$HOME/.agents/skills/foo-x/SKILL.md')\" = mine ]"

printf '%s\n' "$TMP/src/loose" > "$SOURCES"
rm -rf "$HOME/.agents/skills/loose-direct"
check "dry run prints actions and changes nothing" bash -c "'$SKILLSYNC' --dry-run | grep -q '^+ cp' && [ ! -e '$HOME/.agents/skills/loose-direct' ]"

[ "$fails" = 0 ] || { echo "$fails failure(s)"; exit 1; }
