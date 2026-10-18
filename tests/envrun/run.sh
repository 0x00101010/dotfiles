#!/usr/bin/env bash
# envrun checks with a fake ssh that runs "remote" commands locally against a
# throwaway bare repo with dev1/dev2 slots, and real tmux on a private socket.
# Usage: tests/envrun/run.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
ENVRUN="$REPO/ai/bin/envrun"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
export ENVRUN_TMUX_SOCKET="envrun-test-$$" ENVRUN_POLL_SECS=1
trap 'tmux -L "$ENVRUN_TMUX_SOCKET" kill-server 2>/dev/null || true; rm -rf "$TMP"' EXIT
fails=0

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
       GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t HOME="$TMP"

# Fake ssh: drop -o options, refuse host "down", run the rest locally.
mkdir -p "$TMP/bin" "$TMP/.local/bin"
cat > "$TMP/bin/ssh" <<'EOF'
#!/usr/bin/env bash
while [ "$1" = -o ]; do shift 2; done
host=$1; shift
[ "$host" = down ] && exit 255
exec bash -c "$*"
EOF
chmod +x "$TMP/bin/ssh"
export ENVRUN_SSH="$TMP/bin/ssh"
ln -s "$REPO/ai/bin/devslot" "$TMP/.local/bin/devslot"

git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/local" 2>/dev/null
printf 'target/\n' > "$TMP/local/.gitignore"
echo one > "$TMP/local/a.txt"; echo old > "$TMP/local/gone.txt"
git -C "$TMP/local" add -A && git -C "$TMP/local" commit -qm init && git -C "$TMP/local" push -q origin main
base=$(git -C "$TMP/local" rev-parse HEAD)

# "Remote" checkout in the slot layout: .bare plus main, dev1, dev2.
ROOT="$TMP/src/org/repo"
mkdir -p "$ROOT"
git clone -q --bare "$TMP/origin.git" "$ROOT/.bare"
echo "gitdir: ./.bare" > "$ROOT/.git"
git -C "$ROOT" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$ROOT" fetch -q origin && git -C "$ROOT" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git -C "$ROOT" worktree add -q "$ROOT/main" main
git -C "$ROOT" worktree add -q --detach "$ROOT/dev1"
git -C "$ROOT" worktree add -q --detach "$ROOT/dev2"

export ENVRUN_CONFIG="$TMP/environments"
cat > "$ENVRUN_CONFIG" <<EOF
env local kind=local
env fw kind=ssh host=down fallback=up root=$TMP/src
repo org/repo env=fw
EOF

check "repo maps to its environment" [ "$("$ENVRUN" env org/repo)" = fw ]
check "unmapped repo is local" [ "$("$ENVRUN" env org/other)" = local ]

slot=$("$ENVRUN" claim fw org/repo feat/x origin/main --note test)
check "claim falls back to the reachable host and takes dev1 at the base ref" \
  [ "$slot" = "$ROOT/dev1" ] && [ "$(git -C "$slot" branch --show-current)" = feat/x ] \
  && [ "$(git -C "$slot" rev-parse HEAD)" = "$base" ]

check "exec runs in the slot and returns output" [ "$("$ENVRUN" exec fw "$slot" -- 'cat a.txt')" = one ]
set +e; "$ENVRUN" exec fw "$slot" -- 'false | cat' >/dev/null 2>&1; code=$?; set -e
check "exec keeps a failure inside a pipe" [ "$code" != 0 ]

printf -- '--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-one\n+two\n' | "$ENVRUN" patch fw "$slot"
check "patch applies a diff in the slot" [ "$(cat "$slot/a.txt")" = two ]
set +e; printf -- '--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-one\n+three\n' | "$ENVRUN" patch fw "$slot" >/dev/null 2>&1; code=$?; set -e
check "a stale patch is rejected and changes nothing" [ "$code" != 0 ] && [ "$(cat "$slot/a.txt")" = two ]

"$ENVRUN" run fw "$slot" ok -- 'cat a.txt; echo done'
out=$("$ENVRUN" wait fw ok); code=$?
check "wait returns the log and exit 0" [ "$code" = 0 ] && grep -q '^two$' <<<"$out" && grep -q '^done$' <<<"$out"

"$ENVRUN" run fw "$slot" bad -- 'echo failing >&2; exit 3'
set +e; out=$("$ENVRUN" wait fw bad 2>&1); code=$?; set -e
check "wait passes the command's exit code through" [ "$code" = 3 ] && grep -q failing <<<"$out"

"$ENVRUN" run fw "$slot" piped -- 'false | cat'
set +e; "$ENVRUN" wait fw piped >/dev/null 2>&1; code=$?; set -e
check "a failure inside a pipe is not hidden" [ "$code" != 0 ]

"$ENVRUN" run fw "$slot" slow -- 'sleep 3; echo late'
check "status reports running" [ "$("$ENVRUN" status fw slow)" = running ]
check "a running name cannot start twice" bash -c "! '$ENVRUN' run fw '$slot' slow -- true 2>/dev/null"
"$ENVRUN" wait fw slow >/dev/null
check "status reports the exit code" [ "$("$ENVRUN" status fw slow)" = exit=0 ]

check "release refuses uncommitted work" bash -c "! '$ENVRUN' release fw '$slot' 2>/dev/null"
"$ENVRUN" exec fw "$slot" -- 'git commit -qam work' >/dev/null
check "release refuses unpushed work" bash -c "! '$ENVRUN' release fw '$slot' 2>/dev/null"
"$ENVRUN" release fw "$slot" --keep-branch >/dev/null
check "release --keep-branch frees the slot and keeps the commit on the branch" \
  [ -z "$(git -C "$slot" branch --show-current)" ] \
  && [ "$(git -C "$slot" log -1 --format=%s feat/x)" = work ] \
  && [ "$("$REPO/ai/bin/devslot" list "$ROOT" | awk '$1=="dev1"{print $2}')" = free ]

[ "$fails" = 0 ] && echo "all envrun checks passed" || { echo "$fails envrun check(s) failed"; exit 1; }
