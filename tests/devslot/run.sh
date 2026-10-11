#!/usr/bin/env bash
# devslot checks against a throwaway bare repo with dev1/dev2 worktrees.
# Usage: tests/devslot/run.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DEVSLOT="$REPO/ai/bin/devslot"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
fails=0

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }
branch() { git -C "$1" branch --show-current; }
states() { "$DEVSLOT" list "$ROOT" | cut -f1,2 | tr '\t\n' '= ' | sed 's/ $//'; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
       GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t HOME="$TMP"
git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/seed" 2>/dev/null
git -C "$TMP/seed" commit -q --allow-empty -m init && git -C "$TMP/seed" push -q origin main

# Same layout as ~/src/base/base: .git -> .bare, worktrees main + dev<N> beside it.
ROOT="$TMP/repo"
mkdir "$ROOT"
git clone -q --bare "$TMP/origin.git" "$ROOT/.bare"
echo "gitdir: ./.bare" > "$ROOT/.git"
git -C "$ROOT" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$ROOT" fetch -q origin && git -C "$ROOT" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git -C "$ROOT" worktree add -q "$ROOT/main" main
git -C "$ROOT" worktree add -q --detach "$ROOT/dev1"
git -C "$ROOT" worktree add -q --detach "$ROOT/dev2"

check "lists free slots" [ "$(states)" = "dev1=free dev2=free" ]

s1=$("$DEVSLOT" claim feat/a "$ROOT" --note "agent a")
check "first claim takes dev1 on a new branch" [ "$s1" = "$ROOT/dev1" ] && [ "$(branch "$s1")" = feat/a ]
check "list shows claim" [ "$(states)" = "dev1=claimed dev2=free" ]
check "note is listed" [ "$("$DEVSLOT" list "$ROOT" | sed -n 's/^dev1.*\t//p')" = "agent a" ]

s2=$("$DEVSLOT" claim feat/b "$ROOT")
check "second claim takes dev2" [ "$s2" = "$ROOT/dev2" ]
check "no-wait fails fast when all busy" bash -c "'$DEVSLOT' claim feat/c '$ROOT' --no-wait 2>/dev/null; [ \$? = 3 ]"

echo dirty > "$s1/f"
check "release refuses dirty slot" bash -c "! '$DEVSLOT' release '$s1' 2>/dev/null"
git -C "$s1" add f && git -C "$s1" commit -qm work
check "release refuses unpushed slot" bash -c "! '$DEVSLOT' release '$s1' 2>/dev/null"
git -C "$s1" push -q origin feat/a 2>/dev/null
check "release accepts pushed slot" "$DEVSLOT" release "$s1"
check "released slot is free and detached at default" \
  [ "$(states)" = "dev1=free dev2=claimed" ] && [ -z "$(branch "$s1")" ] \
  && [ "$(git -C "$s1" rev-parse HEAD)" = "$(git -C "$s1" rev-parse origin/main)" ]

lock="$(git -C "$s2" rev-parse --path-format=absolute --git-dir)/devslot.lock"
sed -i.bak "s/^started=.*/started=$(( $(date +%s) - 13 * 3600 ))/" "$lock" && rm "$lock.bak"
check "old clean lock reads stale" [ "$(states)" = "dev1=free dev2=stale" ]
echo dirty > "$s2/g"
check "old dirty lock stays claimed" [ "$(states)" = "dev1=free dev2=claimed" ]
rm "$s2/g"
"$DEVSLOT" claim feat/d "$ROOT" >/dev/null   # takes free dev1
s3=$("$DEVSLOT" claim feat/a "$ROOT")
check "claim reuses stale slot and checks out existing branch" \
  [ "$s3" = "$ROOT/dev2" ] && [ "$(branch "$s3")" = feat/a ] && [ -e "$s3/f" ]

# feat/a is now checked out in dev2; claiming it elsewhere must fail without leaving a lock.
"$DEVSLOT" release "$ROOT/dev1" >/dev/null
check "claim of a branch checked out elsewhere fails cleanly" \
  bash -c "! '$DEVSLOT' claim feat/a '$ROOT' --no-wait 2>/dev/null; [ \"\$('$DEVSLOT' list '$ROOT' | head -1)\" = \$'dev1\tfree' ]"

(cd "$s3" && check "release defaults to the current slot" "$DEVSLOT" release)
check "all free at end" [ "$(states)" = "dev1=free dev2=free" ]

[ "$fails" = 0 ] || { echo "$fails failure(s)"; exit 1; }
