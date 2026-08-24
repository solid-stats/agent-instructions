#!/bin/sh
# Integration check for the fail-closed local consumer rollout.
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
sync="$repo_root/scripts/sync-consumers.sh"
repositories='server-2 replays-fetcher replay-parser-2 web infrastructure plans skills ts-toolchain'
platform_repositories='server-2 replays-fetcher replay-parser-2 web infrastructure'

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
workspace="$tmp/workspace"
origins="$tmp/origins"
mkdir -p "$workspace" "$origins"

for repository in $repositories; do
    git init --bare "$origins/$repository.git" >/dev/null
    git init -b master "$workspace/$repository" >/dev/null
    git -C "$workspace/$repository" config user.name 'Contract Test'
    git -C "$workspace/$repository" config user.email 'contract-test@example.invalid'
    git -C "$workspace/$repository" config commit.gpgsign false
    printf 'tracked\n' > "$workspace/$repository/tracked.txt"
    case " $platform_repositories " in
        *" $repository "*)
            mkdir -p "$workspace/$repository/.planning"
            printf '%s\n' '{"project_code":"KEEP","mempalace":{"enabled":true}}' \
                > "$workspace/$repository/.planning/config.json"
            ;;
    esac
    git -C "$workspace/$repository" add .
    git -C "$workspace/$repository" commit -m 'test: seed consumer' >/dev/null
    git -C "$workspace/$repository" remote add origin "$origins/$repository.git"
    git -C "$workspace/$repository" push -u origin master >/dev/null
done

printf 'dirty\n' >> "$workspace/ts-toolchain/tracked.txt"
if sh "$sync" --workspace-root "$workspace" >/dev/null 2>&1; then
    fail "rollout accepted a dirty consumer"
fi
for repository in $repositories; do
    [ ! -e "$workspace/$repository/AGENTS.md" ] \
        || fail "preflight failure partially updated $repository"
done
git -C "$workspace/ts-toolchain" restore tracked.txt
pass "Git preflight validates every consumer before the first write"

printf '%s\n' '<!-- BEGIN managed by solid-stats/agent-instructions -->' \
    'malformed block' > "$workspace/ts-toolchain/AGENTS.md"
git -C "$workspace/ts-toolchain" add AGENTS.md
git -C "$workspace/ts-toolchain" commit -m 'test: add malformed bridge' >/dev/null
git -C "$workspace/ts-toolchain" push >/dev/null
if sh "$sync" --workspace-root "$workspace" >/dev/null 2>&1; then
    fail "rollout accepted a malformed consumer bridge"
fi
[ ! -e "$workspace/server-2/AGENTS.md" ] \
    || fail "bridge validation failure partially updated an earlier consumer"
git -C "$workspace/ts-toolchain" rm AGENTS.md >/dev/null
git -C "$workspace/ts-toolchain" commit -m 'test: remove malformed bridge' >/dev/null
git -C "$workspace/ts-toolchain" push >/dev/null
pass "contract validation completes for every consumer before writes"

sh "$sync" --workspace-root "$workspace" >/dev/null
for repository in $repositories; do
    [ -f "$workspace/$repository/.agent-instructions/solidstats/MEMORY.md" ] \
        || fail "$repository did not receive MEMORY.md"
    git -C "$workspace/$repository" add .
    git -C "$workspace/$repository" commit -m 'test: sync contract' >/dev/null
    git -C "$workspace/$repository" push >/dev/null
done

grep -F '`frontend`' "$workspace/web/.agent-instructions/solidstats/AGENTS.md" >/dev/null \
    || fail "web did not receive the frontend wing"
grep -F '`backend`' "$workspace/server-2/.agent-instructions/solidstats/AGENTS.md" >/dev/null \
    || fail "server-2 did not receive the backend wing"
grep -F '`common`' "$workspace/plans/.agent-instructions/solidstats/AGENTS.md" >/dev/null \
    || fail "plans did not receive the common wing"
for repository in $repositories; do
    ! grep -Fq '## Skills First' "$workspace/$repository/AGENTS.md" \
        || fail "$repository root still embeds the shared contract"
done
pass "rollout materializes thin bridges and repository-specific companions"

sh "$sync" --workspace-root "$workspace" --check >/dev/null \
    || fail "--check failed for synchronized consumers"
pass "--check accepts a fully synchronized consumer set"

echo "All sync-consumers.sh tests passed."
