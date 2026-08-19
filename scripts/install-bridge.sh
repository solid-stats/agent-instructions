#!/bin/sh
# One-time per-repo bootstrap: copy shared/AGENTS.md into a managed block at the top of the
# target repository's root AGENTS.md. Content outside the block belongs to the consumer repo.
#
# Usage: install-bridge.sh --root DIR [--check]
#   --check   exit 0 only if the generated block is already current, else exit 1
set -eu

root='.'
mode='apply'
max_agents_size=32768
begin_marker='<!-- BEGIN managed by solid-stats/agent-instructions -->'
end_marker='<!-- END managed by solid-stats/agent-instructions -->'
legacy_import='@.agent-instructions/AGENTS.md'

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

agents_target="$root/AGENTS.md"
legacy_dir="$root/.agent-instructions"
legacy_file="$legacy_dir/AGENTS.md"
[ ! -e "$agents_target" ] || [ -f "$agents_target" ] || {
    echo "Target AGENTS.md is not a regular file: $agents_target" >&2
    exit 2
}

tmp_dir=${TMPDIR:-/tmp}
local_content=$(mktemp "$tmp_dir/install-bridge-local.XXXXXX")
new_agents=$(mktemp "$tmp_dir/install-bridge-agents.XXXXXX")
trap 'rm -f "$local_content" "$new_agents"' EXIT HUP INT TERM

if [ -f "$agents_target" ]; then
    # Remove old generated blocks and the retired import line. Malformed markers are rejected
    # instead of risking loss of consumer-owned instructions.
    if ! awk -v begin="$begin_marker" -v end="$end_marker" -v legacy="$legacy_import" '
        $0 == begin {
            if (inside) exit 2
            inside = 1
            next
        }
        $0 == end {
            if (!inside) exit 2
            inside = 0
            next
        }
        inside { next }
        $0 == legacy { next }
        { print }
        END { if (inside) exit 2 }
    ' "$agents_target" > "$local_content"; then
        echo "Cannot update $agents_target: managed block markers are malformed." >&2
        exit 2
    fi
fi

{
    printf '%s\n' "$begin_marker"
    cat "$source_file"
    printf '%s\n' "$end_marker"
    cat "$local_content"
} > "$new_agents"

new_agents_size=$(wc -c < "$new_agents")
if [ "$new_agents_size" -gt "$max_agents_size" ]; then
    echo "Refusing to write $agents_target: generated file is ${new_agents_size} bytes; limit is ${max_agents_size}." >&2
    exit 1
fi

legacy_dir_is_empty='false'
if [ -d "$legacy_dir" ] && [ -z "$(find "$legacy_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    legacy_dir_is_empty='true'
fi

if [ "$mode" = 'check' ]; then
    if [ -f "$agents_target" ] && cmp -s "$new_agents" "$agents_target" \
        && [ ! -e "$legacy_file" ] && [ "$legacy_dir_is_empty" = 'false' ]; then
        echo "agent-instructions bridge is current."
        exit 0
    fi
    echo "agent-instructions bridge is missing or outdated." >&2
    exit 1
fi

# Stage the replacement in the destination directory so the final move is atomic. All validation
# above completes before this point, so a size or marker failure cannot change either legacy file.
target_tmp=$(mktemp "$root/.AGENTS.md.install-bridge.XXXXXX")
trap 'rm -f "$local_content" "$new_agents" "$target_tmp"' EXIT HUP INT TERM
if [ -f "$agents_target" ]; then
    cp -p "$agents_target" "$target_tmp"
    cat "$new_agents" > "$target_tmp"
else
    cp "$new_agents" "$target_tmp"
    chmod 644 "$target_tmp"
fi
mv "$target_tmp" "$agents_target"

if [ -e "$legacy_file" ]; then
    rm -f "$legacy_file"
fi
if [ "$legacy_dir_is_empty" = 'true' ] || { [ -d "$legacy_dir" ] && [ -z "$(find "$legacy_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; }; then
    rmdir "$legacy_dir" 2>/dev/null || :
fi

echo "agent-instructions bridge installed/updated."
