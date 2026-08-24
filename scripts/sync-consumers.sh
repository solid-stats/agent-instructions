#!/bin/sh
# Fail-closed local rollout of the current contract to every consumer checkout.
# This script writes managed files only; callers review, commit, and push each repo.
#
# Usage: sync-consumers.sh [--workspace-root DIR] [--check]
set -eu

workspace_root=''
mode='apply'

usage() {
    echo 'Usage: sync-consumers.sh [--workspace-root DIR] [--check]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --workspace-root)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            workspace_root=$2
            shift 2
            ;;
        --check)
            mode='check'
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

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
contract_root=$(CDPATH= cd "$script_dir/.." && pwd)
[ -n "$workspace_root" ] || workspace_root=$(dirname "$contract_root")
[ -d "$workspace_root" ] || {
    echo "sync-consumers: workspace root does not exist: $workspace_root" >&2
    exit 1
}

manifest="$contract_root/config/repositories.tsv"
expected_header='# repository	tier	gsd_config_sync	memory_wing	archive_wing'
[ "$(sed -n '1p' "$manifest")" = "$expected_header" ] || {
    echo 'sync-consumers: repositories.tsv has an unexpected header.' >&2
    exit 1
}

tmp_dir=${TMPDIR:-/tmp}
consumers=$(mktemp "$tmp_dir/sync-consumers.XXXXXX")
trap 'rm -f "$consumers"' EXIT HUP INT TERM
awk -F '\t' '
    NR == 1 { next }
    NF != 5 { exit 2 }
    $1 != "solid-stats/agent-instructions" { print }
' "$manifest" > "$consumers" || {
    echo 'sync-consumers: repositories.tsv contains an invalid row.' >&2
    exit 1
}

consumer_count=$(wc -l < "$consumers")
echo "sync-consumers: preflighting $consumer_count consumer repositories."
while IFS='	' read -r repository tier gsd_config_sync memory_wing archive_wing; do
    repo_name=${repository#*/}
    checkout="$workspace_root/$repo_name"
    [ -d "$checkout" ] || {
        echo "sync-consumers: missing checkout for $repository at $checkout" >&2
        exit 1
    }
    [ "$(git -C "$checkout" rev-parse --is-inside-work-tree 2>/dev/null)" = 'true' ] || {
        echo "sync-consumers: $repository is not a Git checkout at $checkout" >&2
        exit 1
    }
    [ -z "$(git -C "$checkout" status --porcelain=v1)" ] || {
        echo "sync-consumers: $repository has uncommitted changes" >&2
        exit 1
    }

    upstream=$(git -C "$checkout" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || {
        echo "sync-consumers: $repository has no upstream" >&2
        exit 1
    }
    remote=${upstream%%/*}
    git -C "$checkout" fetch --prune "$remote" || {
        echo "sync-consumers: cannot refresh $repository from $remote" >&2
        exit 1
    }
    divergence=$(git -C "$checkout" rev-list --left-right --count "HEAD...$upstream")
    set -- $divergence
    [ "$#" -eq 2 ] && [ "$1" -eq 0 ] && [ "$2" -eq 0 ] || {
        echo "sync-consumers: $repository is not synchronized with $upstream: $divergence" >&2
        exit 1
    }

    sh "$contract_root/scripts/install-bridge.sh" \
        --root "$checkout" --repository "$repository" --dry-run >/dev/null || {
        echo "sync-consumers: bridge validation failed for $repository" >&2
        exit 1
    }
    if [ "$gsd_config_sync" = 'yes' ]; then
        node "$contract_root/scripts/sync-gsd-config.mjs" "$checkout" \
            --repository "$repository" --dry-run >/dev/null || {
            echo "sync-consumers: GSD config validation failed for $repository" >&2
            exit 1
        }
    fi
done < "$consumers"

echo "sync-consumers: preflight passed; $mode contract pass starting."
while IFS='	' read -r repository tier gsd_config_sync memory_wing archive_wing; do
    repo_name=${repository#*/}
    checkout="$workspace_root/$repo_name"
    if [ "$mode" = 'check' ]; then
        sh "$contract_root/scripts/install-bridge.sh" \
            --root "$checkout" --repository "$repository" --check || {
            echo "sync-consumers: bridge check failed for $repository" >&2
            exit 1
        }
    else
        sh "$contract_root/scripts/install-bridge.sh" \
            --root "$checkout" --repository "$repository" || {
            echo "sync-consumers: bridge update failed for $repository" >&2
            exit 1
        }
    fi

    if [ "$gsd_config_sync" = 'yes' ]; then
        if [ "$mode" = 'check' ]; then
            node "$contract_root/scripts/sync-gsd-config.mjs" "$checkout" \
                --repository "$repository" --check || {
                echo "sync-consumers: GSD config check failed for $repository" >&2
                exit 1
            }
        else
            node "$contract_root/scripts/sync-gsd-config.mjs" "$checkout" \
                --repository "$repository" || {
                echo "sync-consumers: GSD config update failed for $repository" >&2
                exit 1
            }
        fi
    fi
done < "$consumers"

echo "sync-consumers: all $consumer_count consumer repositories completed the $mode pass."
