#!/bin/sh
# Maintainer check for scripts/install-bridge.sh. Run from the repo root:
#   sh tests/test-install-bridge.sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
bridge="$repo_root/scripts/install-bridge.sh"
begin_marker='<!-- BEGIN managed by solid-stats/agent-instructions -->'
end_marker='<!-- END managed by solid-stats/agent-instructions -->'

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

tmp=$(mktemp -d)
tmp2=''
tmp3=''
tmp4=''
tmp5=''
tmp6=''
tmp7=''
expected=''
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$expected"' EXIT HUP INT TERM

assert_generated_block() {
    target=$1
    expected=$(mktemp)
    {
        printf '%s\n' "$begin_marker"
        sed \
            -e 's|{{SOLIDSTATS_CONTRACT_VERSION_PATH}}|.agent-instructions/solidstats/CONTRACT_VERSION|g' \
            -e 's|{{SOLIDSTATS_MEMORY_CONTRACT_PATH}}|.agent-instructions/solidstats/MEMORY.md|g' \
            -e 's|{{SOLIDSTATS_GSD_CONTRACT_PATH}}|.agent-instructions/solidstats/GSD.md|g' \
            -e 's|{{SOLIDSTATS_PRIMARY_MEMORY_WING}}|frontend|g' \
            -e 's|{{SOLIDSTATS_PRIMARY_ARCHIVE_WING}}|web-archive|g' \
            "$repo_root/shared/AGENTS.md"
        printf '%s\n' "$end_marker"
    } > "$expected"
    head -n "$(wc -l < "$expected")" "$target" | cmp -s "$expected" - \
        || fail "generated block does not match shared/AGENTS.md"
    rm -f "$expected"
    expected=''
}

assert_companions() {
    target_root=$1
    companion="$target_root/.agent-instructions/solidstats"
    cmp -s "$repo_root/CONTRACT_VERSION" "$companion/CONTRACT_VERSION" \
        || fail "CONTRACT_VERSION companion differs"
    cmp -s "$repo_root/shared/MEMORY.md" "$companion/MEMORY.md" \
        || fail "MEMORY.md companion differs"
    cmp -s "$repo_root/shared/GSD.md" "$companion/GSD.md" \
        || fail "GSD.md companion differs"
}

# 1. Syntax check.
sh -n "$bridge" || fail "install-bridge.sh has a syntax error"
pass "install-bridge.sh parses"

# 2. Fresh install into a repo with no AGENTS.md.
sh "$bridge" --root "$tmp" --repository solid-stats/web >/dev/null
[ -f "$tmp/AGENTS.md" ] || fail "AGENTS.md not created"
[ "$(stat -c '%a' "$tmp/AGENTS.md")" = '644' ] || fail "new AGENTS.md mode is not 0644"
assert_generated_block "$tmp/AGENTS.md"
[ ! -e "$tmp/.agent-instructions/AGENTS.md" ] || fail "legacy file created during fresh install"
assert_companions "$tmp"
pass "fresh install creates the routed block and companion contract"

# 3. Migrate the legacy import and vendored file.
tmp2=$(mktemp -d)
mkdir -p "$tmp2/.agent-instructions"
printf '%s\n' '@.agent-instructions/AGENTS.md' > "$tmp2/AGENTS.md"
printf 'legacy content\n' > "$tmp2/.agent-instructions/AGENTS.md"

sh "$bridge" --root "$tmp2" --repository solid-stats/web >/dev/null
assert_generated_block "$tmp2/AGENTS.md"
! grep -Fqx '@.agent-instructions/AGENTS.md' "$tmp2/AGENTS.md" \
    || fail "legacy import survived migration"
[ ! -e "$tmp2/.agent-instructions/AGENTS.md" ] || fail "legacy AGENTS.md survived migration"
[ -d "$tmp2/.agent-instructions/solidstats" ] || fail "companion directory was not created"
pass "legacy import and vendored file migrate to the generated block"

# 4. Existing consumer instructions remain outside and after the block.
tmp3=$(mktemp -d)
printf '> This repo does X.\n\n# Local rules\n\nConsumer-owned instructions.\n' > "$tmp3/AGENTS.md"
chmod 640 "$tmp3/AGENTS.md"

sh "$bridge" --root "$tmp3" --repository solid-stats/web >/dev/null
[ "$(stat -c '%a' "$tmp3/AGENTS.md")" = '640' ] || fail "existing AGENTS.md mode was not preserved"
assert_generated_block "$tmp3/AGENTS.md"
grep -Fqx '> This repo does X.' "$tmp3/AGENTS.md" || fail "existing header was lost"
grep -Fqx 'Consumer-owned instructions.' "$tmp3/AGENTS.md" || fail "existing local instructions were lost"
end_line=$(grep -Fnx -- "$end_marker" "$tmp3/AGENTS.md" | cut -d: -f1)
local_line=$(grep -Fnx -- '> This repo does X.' "$tmp3/AGENTS.md" | cut -d: -f1)
[ "$end_line" -lt "$local_line" ] || fail "local instructions did not follow the generated block"
pass "existing root content is preserved after the generated block"

# 5. An old managed block is replaced without duplicating it.
tmp4=$(mktemp -d)
printf '%s\nobsolete shared content\n%s\n# Local\nkeep this\n' "$begin_marker" "$end_marker" > "$tmp4/AGENTS.md"

sh "$bridge" --root "$tmp4" --repository solid-stats/web >/dev/null
assert_generated_block "$tmp4/AGENTS.md"
[ "$(grep -Fcx "$begin_marker" "$tmp4/AGENTS.md")" -eq 1 ] \
    || fail "managed begin marker was duplicated"
grep -Fqx 'keep this' "$tmp4/AGENTS.md" || fail "local content was lost during marker replacement"
pass "existing managed block is replaced"

# 6. Re-running is byte-for-byte idempotent and --check passes.
before=$(cksum "$tmp4/AGENTS.md" "$tmp4/.agent-instructions/solidstats/"*)
sh "$bridge" --root "$tmp4" --repository solid-stats/web >/dev/null
after=$(cksum "$tmp4/AGENTS.md" "$tmp4/.agent-instructions/solidstats/"*)
[ "$before" = "$after" ] || fail "re-running install-bridge.sh changed managed files"
sh "$bridge" --root "$tmp4" --repository solid-stats/web --check >/dev/null \
    || fail "--check should pass after install"
printf 'outdated\n' > "$tmp4/AGENTS.md"
if sh "$bridge" --root "$tmp4" --repository solid-stats/web --check >/dev/null 2>&1; then
    fail "--check passed for outdated AGENTS.md"
fi
pass "install is idempotent and --check detects drift"

# 7. A dry run performs complete validation without writing.
tmp7=$(mktemp -d)
printf 'local instructions\n' > "$tmp7/AGENTS.md"
before=$(cksum "$tmp7/AGENTS.md")
sh "$bridge" --root "$tmp7" --repository solid-stats/web --dry-run >/dev/null
[ "$before" = "$(cksum "$tmp7/AGENTS.md")" ] || fail "--dry-run changed AGENTS.md"
[ ! -e "$tmp7/.agent-instructions" ] || fail "--dry-run created companion files"
pass "--dry-run validates without writing"

# 8. The size budget fails before either root or legacy state changes.
tmp5=$(mktemp -d)
mkdir -p "$tmp5/.agent-instructions"
printf 'original root\n' > "$tmp5/AGENTS.md"
printf 'legacy\n' > "$tmp5/.agent-instructions/AGENTS.md"
dd if=/dev/zero bs=1 count=33000 2>/dev/null | tr '\0' x >> "$tmp5/AGENTS.md"
before_root=$(cksum "$tmp5/AGENTS.md")
before_legacy=$(cksum "$tmp5/.agent-instructions/AGENTS.md")
if sh "$bridge" --root "$tmp5" --repository solid-stats/web >/dev/null 2>&1; then
    fail "install unexpectedly passed the AGENTS.md size limit"
fi
[ "$before_root" = "$(cksum "$tmp5/AGENTS.md")" ] || fail "size failure partially changed AGENTS.md"
[ "$before_legacy" = "$(cksum "$tmp5/.agent-instructions/AGENTS.md")" ] \
    || fail "size failure deleted or changed the legacy file"
pass "size-budget failure leaves root and legacy files unchanged"

# 9. The legacy directory remains when it contains unrelated files.
tmp6=$(mktemp -d)
mkdir -p "$tmp6/.agent-instructions"
printf 'legacy\n' > "$tmp6/.agent-instructions/AGENTS.md"
printf 'keep\n' > "$tmp6/.agent-instructions/notes.txt"

sh "$bridge" --root "$tmp6" --repository solid-stats/web >/dev/null
[ ! -e "$tmp6/.agent-instructions/AGENTS.md" ] || fail "legacy AGENTS.md survived"
[ -f "$tmp6/.agent-instructions/notes.txt" ] || fail "unrelated legacy-directory file was removed"
pass "unrelated files in .agent-instructions are preserved"

echo "All install-bridge.sh tests passed."
