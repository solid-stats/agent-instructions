#!/bin/sh
# Materialize the managed SolidStats contract into a repository.
#
# Usage: install-bridge.sh --root DIR [--repository ORG/REPO] [--dry-run|--check]
set -eu

root='.'
repository=''
mode='apply'
max_agents_size=32768
begin_marker='<!-- BEGIN managed by solid-stats/agent-instructions -->'
end_marker='<!-- END managed by solid-stats/agent-instructions -->'
legacy_import='@.agent-instructions/AGENTS.md'

usage() {
    echo 'Usage: install-bridge.sh --root DIR [--repository ORG/REPO] [--dry-run|--check]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            root=$2
            shift 2
            ;;
        --repository)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            repository=$2
            shift 2
            ;;
        --check)
            mode='check'
            shift
            ;;
        --dry-run)
            mode='dry-run'
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[ -d "$root" ] || { echo "Repository root does not exist: $root" >&2; exit 2; }

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
contract_root=$(CDPATH= cd "$script_dir/.." && pwd)
root_real=$(CDPATH= cd "$root" && pwd)
manifest="$contract_root/config/repositories.tsv"
shared_agents="$contract_root/shared/AGENTS.md"
shared_memory="$contract_root/shared/MEMORY.md"
shared_gsd="$contract_root/shared/GSD.md"
shared_version="$contract_root/CONTRACT_VERSION"
bridge_template="$contract_root/templates/AGENTS.bridge.md"

for required_file in \
    "$manifest" \
    "$shared_agents" \
    "$shared_memory" \
    "$shared_gsd" \
    "$shared_version" \
    "$bridge_template"; do
    [ -r "$required_file" ] || {
        echo "Contract repository is incomplete: $required_file missing." >&2
        exit 2
    }
done
grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' "$shared_version" || {
    echo 'CONTRACT_VERSION must contain one Semantic Version.' >&2
    exit 2
}

expected_header='# repository	tier	gsd_config_sync	memory_wing	archive_wing'
actual_header=$(sed -n '1p' "$manifest")
[ "$actual_header" = "$expected_header" ] || {
    echo 'config/repositories.tsv has an unexpected header.' >&2
    exit 2
}

if [ -z "$repository" ]; then
    if [ "$root_real" = "$contract_root" ]; then
        repository='solid-stats/agent-instructions'
    else
        repo_name=$(basename "$root_real")
        matches=$(awk -F '\t' -v name="$repo_name" '
            NR > 1 {
                count = split($1, parts, "/")
                if (parts[count] == name) print $1
            }
        ' "$manifest")
        match_count=$(printf '%s\n' "$matches" | awk 'NF { count += 1 } END { print count + 0 }')
        [ "$match_count" -eq 1 ] || {
            echo 'Cannot infer repository identity; pass --repository ORG/REPO.' >&2
            exit 2
        }
        repository=$matches
    fi
fi

manifest_row=$(awk -F '\t' -v repository="$repository" '$1 == repository { print; count += 1 } END { if (count != 1) exit 1 }' "$manifest") || {
    echo "Repository $repository is absent or duplicated in config/repositories.tsv." >&2
    exit 2
}

field_count=$(printf '%s\n' "$manifest_row" | awk -F '\t' '{ print NF }')
[ "$field_count" -eq 5 ] || {
    echo "Manifest row for $repository must have exactly 5 fields." >&2
    exit 2
}
memory_wing=$(printf '%s\n' "$manifest_row" | cut -f4)
archive_wing=$(printf '%s\n' "$manifest_row" | cut -f5)
case "$memory_wing" in *[!a-z0-9-]*|'') echo "Invalid memory wing: $memory_wing" >&2; exit 2;; esac
case "$archive_wing" in *[!a-z0-9-]*|'') echo "Invalid archive wing: $archive_wing" >&2; exit 2;; esac

if [ "$repository" = 'solid-stats/agent-instructions' ]; then
    [ "$root_real" = "$contract_root" ] || {
        echo 'The canonical repository identity cannot target another checkout.' >&2
        exit 2
    }
    [ -f "$root/AGENTS.md" ] || {
        echo 'Canonical AGENTS.md is missing.' >&2
        exit 2
    }
    if grep -F "$begin_marker" "$root/AGENTS.md" >/dev/null \
        || grep -F "$end_marker" "$root/AGENTS.md" >/dev/null; then
        echo 'Canonical AGENTS.md must not contain a generated consumer block.' >&2
        exit 1
    fi
    for canonical_pointer in \
        'shared/AGENTS.md' \
        'shared/MEMORY.md' \
        'shared/GSD.md' \
        'CONTRACT_VERSION'; do
        grep -F "$canonical_pointer" "$root/AGENTS.md" >/dev/null || {
            echo "Canonical AGENTS.md is missing pointer: $canonical_pointer" >&2
            exit 1
        }
    done
    echo 'Canonical source repository does not self-materialize.'
    exit 0
fi

companion_dir="$root/.agent-instructions/solidstats"
agents_path='.agent-instructions/solidstats/AGENTS.md'
version_path='.agent-instructions/solidstats/CONTRACT_VERSION'
memory_path='.agent-instructions/solidstats/MEMORY.md'
gsd_path='.agent-instructions/solidstats/GSD.md'
agents_companion_target="$companion_dir/AGENTS.md"
version_target="$companion_dir/CONTRACT_VERSION"
memory_target="$companion_dir/MEMORY.md"
gsd_target="$companion_dir/GSD.md"

agents_target="$root/AGENTS.md"
legacy_dir="$root/.agent-instructions"
legacy_file="$legacy_dir/AGENTS.md"
[ ! -e "$agents_target" ] || [ -f "$agents_target" ] || {
    echo "Target AGENTS.md is not a regular file: $agents_target" >&2
    exit 2
}

tmp_dir=${TMPDIR:-/tmp}
local_content=$(mktemp "$tmp_dir/install-bridge-local.XXXXXX")
rendered_companion_agents=$(mktemp "$tmp_dir/install-bridge-agents-companion.XXXXXX")
new_agents=$(mktemp "$tmp_dir/install-bridge-agents.XXXXXX")
trap 'rm -f "$local_content" "$rendered_companion_agents" "$new_agents"' EXIT HUP INT TERM

if [ -f "$agents_target" ]; then
    if ! awk -v begin="$begin_marker" -v end="$end_marker" -v legacy="$legacy_import" '
        $0 == begin { if (inside) exit 2; inside = 1; next }
        $0 == end { if (!inside) exit 2; inside = 0; next }
        inside { next }
        $0 == legacy { next }
        { print }
        END { if (inside) exit 2 }
    ' "$agents_target" > "$local_content"; then
        echo "Cannot update $agents_target: managed block markers are malformed." >&2
        exit 2
    fi
fi

awk \
    -v agents_path="$agents_path" \
    -v version_path="$version_path" \
    -v memory_path="$memory_path" \
    -v gsd_path="$gsd_path" \
    -v memory_wing="$memory_wing" \
    -v archive_wing="$archive_wing" '
    {
        gsub(/\{\{SOLIDSTATS_AGENT_CONTRACT_PATH\}\}/, agents_path)
        gsub(/\{\{SOLIDSTATS_CONTRACT_VERSION_PATH\}\}/, version_path)
        gsub(/\{\{SOLIDSTATS_MEMORY_CONTRACT_PATH\}\}/, memory_path)
        gsub(/\{\{SOLIDSTATS_GSD_CONTRACT_PATH\}\}/, gsd_path)
        gsub(/\{\{SOLIDSTATS_PRIMARY_MEMORY_WING\}\}/, memory_wing)
        gsub(/\{\{SOLIDSTATS_PRIMARY_ARCHIVE_WING\}\}/, archive_wing)
        print
    }
' "$shared_agents" > "$rendered_companion_agents"

if grep -F '{{SOLIDSTATS_' "$rendered_companion_agents" >/dev/null; then
    echo 'Unresolved SolidStats contract placeholder.' >&2
    exit 2
fi

{
    printf '%s\n' "$begin_marker"
    cat "$bridge_template"
    printf '%s\n' "$end_marker"
    cat "$local_content"
} > "$new_agents"

new_agents_size=$(wc -c < "$new_agents")
if [ "$new_agents_size" -gt "$max_agents_size" ]; then
    echo "Refusing to write $agents_target: generated file is ${new_agents_size} bytes; limit is ${max_agents_size}." >&2
    exit 1
fi

companions_current='false'
if cmp -s "$rendered_companion_agents" "$agents_companion_target" \
    && cmp -s "$shared_version" "$version_target" \
    && cmp -s "$shared_memory" "$memory_target" \
    && cmp -s "$shared_gsd" "$gsd_target"; then
    companions_current='true'
fi

if [ "$mode" = 'check' ]; then
    if [ -f "$agents_target" ] \
        && cmp -s "$new_agents" "$agents_target" \
        && [ "$companions_current" = 'true' ] \
        && [ ! -e "$legacy_file" ]; then
        echo "agent-instructions contract $repository is current."
        exit 0
    fi
    echo "agent-instructions contract $repository is missing or outdated." >&2
    exit 1
fi

if [ "$mode" = 'dry-run' ]; then
    echo "agent-instructions contract $repository passed validation; not writing."
    exit 0
fi

mkdir -p "$companion_dir"
for source_target in \
    "$rendered_companion_agents:$agents_companion_target" \
    "$shared_version:$version_target" \
    "$shared_memory:$memory_target" \
    "$shared_gsd:$gsd_target"; do
    source=${source_target%%:*}
    target=${source_target#*:}
    target_tmp=$(mktemp "$companion_dir/.install-bridge.XXXXXX")
    cp "$source" "$target_tmp"
    chmod 644 "$target_tmp"
    mv "$target_tmp" "$target"
done

target_tmp=$(mktemp "$root/.AGENTS.md.install-bridge.XXXXXX")
trap 'rm -f "$local_content" "$rendered_companion_agents" "$new_agents" "$target_tmp"' EXIT HUP INT TERM
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

echo "agent-instructions contract $repository installed/updated."
