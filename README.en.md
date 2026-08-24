# agent-instructions

[Русский](README.md) · **English**

The single source for AI-agent rules shared across every **Solid Stats**
repository — the replay-statistics platform for the
[Solid Games](https://sg.zone) (ArmA 3) community. These rules used to be
hand-duplicated across each repo's `AGENTS.md` (for example, the "Skills First"
paragraph was identical in `web`, `server-2`, `replays-fetcher`, and
`replay-parser-2`) or lived in the triggerable
`solidstats-shared-project-standards` skill, which is not always loaded.

This is a supporting repository: it owns no runtime boundary. It supplies a
thin root bridge and a versioned contract committed as managed companion files
in every consumer.

The canonical repository does not materialize that contract back into its own
`AGENTS.md`: its root file contains only a bootstrap to `shared/*` and local
maintenance rules.

## What lives here

- [`templates/AGENTS.bridge.md`](templates/AGENTS.bridge.md) — the minimal
  managed block placed at the start of every consumer's root `AGENTS.md`.
- [`shared/AGENTS.md`](shared/AGENTS.md) — the shared rules rendered into the
  committed `.agent-instructions/solidstats/AGENTS.md` companion.
- [`shared/MEMORY.md`](shared/MEMORY.md) — the complete SolidStats MemPalace
  contract: role wings, recall, semantic capture, corrections, and frozen
  archives.
- [`shared/GSD.md`](shared/GSD.md) — the manual GSD adapter used while the
  native MemPalace capability remains disabled.
- [`gsd/common-config.json`](gsd/common-config.json) — the common subset of
  GSD's `.planning/config.json` keys, synced without touching repo-local keys
  (`project_code`, `agent_skills`, `test_command`, …).
- [`config/repositories.tsv`](config/repositories.tsv) — the manifest of
  consumer repos and their tier.
- [`scripts/install-bridge.sh`](scripts/install-bridge.sh) — one-time bridge
  install for a new consumer repo.
- [`scripts/sync-gsd-config.mjs`](scripts/sync-gsd-config.mjs) — a surgical
  dotted-path merge of the common GSD keys, leaving the rest untouched.
- [`scripts/sync-consumers.sh`](scripts/sync-consumers.sh) — the fail-closed
  local batch rollout for every consumer repository.
- [`CONTRACT_VERSION`](CONTRACT_VERSION) and [`CHANGELOG.md`](CHANGELOG.md) —
  the single SemVer contract version and each release's impact.

## How content stays fresh in consumer repos

A release is rolled out locally after its acceptance gate. The batch script
first verifies all eight checkouts: each must exist, be clean, and exactly
match its upstream. Only after the complete preflight does it update the thin
root bridge, companion bundle, and GSD config. Commits and pushes remain a
separate reviewable step routed by each repository's Git policy.

The generated contract is committed in every consumer, so its diff is visible
before publication. A consumer checkout performs no task-start remote update
check. The four-file bundle is mandatory and fail-closed: `AGENTS.md`,
`CONTRACT_VERSION`, `MEMORY.md`, and `GSD.md` must all be present and readable.
Repository-specific root instructions remain outside the managed markers. The
installer refuses to write a root `AGENTS.md` larger than 32 KiB.

## Bootstrapping a new consumer repo

```sh
git clone https://github.com/solid-stats/agent-instructions.git /tmp/agent-instructions
sh /tmp/agent-instructions/scripts/install-bridge.sh --root . --repository solid-stats/<repo>
```

## Development

```sh
sh -n scripts/install-bridge.sh
sh -n scripts/sync-consumers.sh
sh tests/test-install-bridge.sh
sh tests/test-sync-gsd-config.sh
sh tests/test-sync-consumers.sh
node tests/test-contract.mjs
sh scripts/sync-consumers.sh --workspace-root .. --check
```

## License

MIT — see [LICENSE](LICENSE).
