#!/bin/sh
# Maintainer check for scripts/sync-gsd-config.mjs.
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
sync="$repo_root/scripts/sync-gsd-config.mjs"

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/.planning"
printf '%s\n' '{"project_code":"KEEP","mempalace":{"enabled":true,"wing":"old"}}' \
    > "$tmp/.planning/config.json"

if node "$sync" "$tmp" --repository solid-stats/web --check >/dev/null 2>&1; then
    fail "--check passed for a stale config"
fi
pass "--check detects managed GSD drift"

before=$(cksum "$tmp/.planning/config.json")
node "$sync" "$tmp" --repository solid-stats/web --dry-run >/dev/null
[ "$before" = "$(cksum "$tmp/.planning/config.json")" ] \
    || fail "--dry-run changed the target config"
pass "--dry-run is non-mutating"

node "$sync" "$tmp" --repository solid-stats/web >/dev/null
node "$sync" "$tmp" --repository solid-stats/web --check >/dev/null \
    || fail "--check failed after sync"

node -e '
const fs = require("node:fs");
const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (value.project_code !== "KEEP") process.exit(1);
if (value.mempalace.wing !== "frontend") process.exit(1);
for (const key of [
  "enabled",
  "recall_on_discuss",
  "recall_on_plan",
  "capture_artifacts",
  "mirror_kg",
  "cross_project_tunnels",
  "diary_journal",
  "auto_capture_hooks",
]) {
  if (value.mempalace[key] !== false) process.exit(1);
}
if (value.mempalace.memory_mode !== "augment") process.exit(1);
' "$tmp/.planning/config.json" || fail "sync wrote the wrong managed values"
pass "sync writes the role wing, fail-closed flags, and preserves local keys"

if node "$sync" "$tmp" --repository solid-stats/plans >/dev/null 2>&1; then
    fail "sync accepted a supporting repository without GSD config management"
fi
pass "non-GSD repositories are rejected"

echo "All sync-gsd-config.mjs tests passed."
