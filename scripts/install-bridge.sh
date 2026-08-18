#!/bin/sh
# One-time per-repo bootstrap: vendor shared/AGENTS.md into the target repo and make sure its
# root AGENTS.md imports it exactly once. Idempotent — safe to re-run.
#
# Usage: install-bridge.sh --root DIR [--check]
#   --check   exit 0 only if the vendored file + import line are already current, else exit 1
set -eu

root='.'
mode='apply'

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            [ "$#" -ge 2 ] || { echo "Usage: install-bridge.sh --root DIR [--check]" >&2; exit 2; }
            root=$2
            shift 2
            ;;
        --check)
            mode='check'
            shift
            ;;
        -h|--help)
            echo "Usage: install-bridge.sh --root DIR [--check]"
            exit 0
            ;;
        *)
            echo "Usage: install-bridge.sh --root DIR [--check]" >&2
            exit 2
            ;;
    esac
done

[ -d "$root" ] || { echo "Repository root does not exist: $root" >&2; exit 2; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
contract_root=$(CDPATH= cd "$script_dir/.." && pwd)
source_file="$contract_root/shared/AGENTS.md"
[ -r "$source_file" ] || { echo 'Contract repository is incomplete: shared/AGENTS.md missing.' >&2; exit 2; }

vendored_dir="$root/.agent-instructions"
vendored_file="$vendored_dir/AGENTS.md"
import_line='@.agent-instructions/AGENTS.md'
agents_target="$root/AGENTS.md"

if [ "$mode" = 'check' ]; then
    if [ -f "$vendored_file" ] && cmp -s "$source_file" "$vendored_file" \
        && [ -f "$agents_target" ] && grep -Fqx "$import_line" "$agents_target"; then
        echo "agent-instructions bridge is current."
        exit 0
    fi
    echo "agent-instructions bridge is missing or outdated." >&2
    exit 1
fi

mkdir -p "$vendored_dir"
cp "$source_file" "$vendored_file"

if [ ! -f "$agents_target" ]; then
    printf '%s\n' "$import_line" > "$agents_target"
    echo "Created $agents_target with the import line."
elif ! grep -Fqx "$import_line" "$agents_target"; then
    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT HUP INT TERM
    # Insert the import line right after the repo's own opening blockquote (the first line that
    # is not a blockquote), so it reads: repo header, then the shared-contract import.
    awk -v line="$import_line" '
        !inserted && $0 !~ /^>/ && NF > 0 {
            print line
            print ""
            inserted = 1
        }
        { print }
        END { if (!inserted) print line }
    ' "$agents_target" > "$tmp_file"
    cp "$tmp_file" "$agents_target"
    echo "Added the import line to $agents_target."
else
    echo "Import line already present in $agents_target."
fi

echo "agent-instructions bridge installed/updated."
