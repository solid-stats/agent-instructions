# agent-instructions

[Русский](README.md) · **English**

The single source for AI-agent rules shared across every **Solid Stats**
repository — the replay-statistics platform for the
[Solid Games](https://sg.zone) (ArmA 3) community. These rules used to be
hand-duplicated across each repo's `AGENTS.md` (for example, the "Skills First"
paragraph was identical in `web`, `server-2`, `replays-fetcher`, and
`replay-parser-2`) or lived in the triggerable
`solidstats-shared-project-standards` skill, which is not always loaded.

This is a supporting repository: it owns no runtime boundary. It supplies
shared content that the other repositories embed into their root instructions
through a generated block.

## What lives here

- [`shared/AGENTS.md`](shared/AGENTS.md) — the source copied into a managed
  block at the start of every consumer's root `AGENTS.md`: session hygiene,
  git conventions (including the auto commit + push policy), security
  minimums, risk management, documentation language, and MCP/doc-lookup
  rules.
- [`gsd/common-config.json`](gsd/common-config.json) — the common subset of
  GSD's `.planning/config.json` keys, synced without touching repo-local keys
  (`project_code`, `agent_skills`, `test_command`, …).
- [`config/repositories.tsv`](config/repositories.tsv) — the manifest of
  consumer repos and their tier.
- [`scripts/install-bridge.sh`](scripts/install-bridge.sh) — one-time bridge
  install for a new consumer repo.
- [`scripts/sync-gsd-config.mjs`](scripts/sync-gsd-config.mjs) — a surgical
  dotted-path merge of the common GSD keys, leaving the rest untouched.
- [`.github/workflows/sync-on-release.yml`](.github/workflows/sync-on-release.yml)
  — on release publish (a `CONTRACT_VERSION` bump), opens a PR into every repo
  in the manifest. Merge is manual; nothing auto-merges.

## How content stays fresh in consumer repos

Freshness comes from **auto-PR, not a manual clone**: the generated block is
committed in each consumer repo, so diffs are visible in the PR itself.
Repository-specific instructions remain editable outside the managed markers.
The installer refuses to write a root `AGENTS.md` larger than Codex's default
32 KiB project-document limit.

## Bootstrapping a new consumer repo

```bash
git clone https://github.com/solid-stats/agent-instructions.git /tmp/agent-instructions
sh /tmp/agent-instructions/scripts/install-bridge.sh --root .
```

## Development

```sh
sh -n scripts/install-bridge.sh
sh tests/test-install-bridge.sh
node scripts/sync-gsd-config.mjs <path-to-repo> --dry-run
```

## License

MIT — see [LICENSE](LICENSE).
