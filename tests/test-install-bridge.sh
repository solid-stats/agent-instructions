#!/bin/sh
# Maintainer check for scripts/install-bridge.sh. Run from the repo root:
#   sh tests/test-install-bridge.sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
bridge="$repo_root/scripts/install-bridge.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

# 1. Syntax check.
sh -n "$bridge" || fail "install-bridge.sh has a syntax error"
pass "install-bridge.sh parses"

# 2. Fresh install into a repo with no AGENTS.md.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

sh "$bridge" --root "$tmp" >/dev/null
[ -f "$tmp/.agent-instructions/AGENTS.md" ] || fail "vendored file not created"
cmp -s "$repo_root/shared/AGENTS.md" "$tmp/.agent-instructions/AGENTS.md" || fail "vendored file does not match source"
grep -Fqx '@.agent-instructions/AGENTS.md' "$tmp/AGENTS.md" || fail "import line not present after fresh install"
pass "fresh install creates vendored file + import line"

sh "$bridge" --root "$tmp" --check >/dev/null || fail "--check should pass right after install"
pass "--check passes after a current install"

# 3. Install into a repo with an existing AGENTS.md (repo-specific header preserved).
tmp2=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2"' EXIT HUP INT TERM
printf '> This repo does X.\n> Boundary: owns Y.\n\n# AGENTS instructions\n\nSome body.\n' > "$tmp2/AGENTS.md"

sh "$bridge" --root "$tmp2" >/dev/null
grep -Fqx '@.agent-instructions/AGENTS.md' "$tmp2/AGENTS.md" || fail "import line not added to existing AGENTS.md"
grep -Fq 'This repo does X.' "$tmp2/AGENTS.md" || fail "existing repo-specific header was lost"
pass "install into an existing AGENTS.md preserves the repo-specific header"

# 4. Idempotency — re-running does not duplicate the import line.
sh "$bridge" --root "$tmp2" >/dev/null
count=$(grep -Fcx '@.agent-instructions/AGENTS.md' "$tmp2/AGENTS.md")
[ "$count" -eq 1 ] || fail "import line duplicated on re-run (found $count)"
pass "re-running install-bridge.sh is idempotent"

echo "All install-bridge.sh tests passed."
