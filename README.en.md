# agent-instructions

[Русский](README.md) · **English**

The single source for AI-agent rules shared across every **Solid Stats** repository — the
replay-statistics platform for the [Solid Games](https://sg.zone) (ArmA 3) community. These rules
used to be either hand-duplicated across each repo's `AGENTS.md` (e.g. the "Skills First"
paragraph — verbatim-identical in `web`, `server-2`, `replays-fetcher`, `replay-parser-2`) or
living in the wrong place (inside the triggerable `solidstats-shared-project-standards` skill,
which isn't meant for always-loaded root context).

This is a supporting repository: it owns no runtime boundary — it supplies shared content that
the other repositories import.

## What lives here

- [`shared/AGENTS.md`](shared/AGENTS.md) — the fragment every consumer repo imports via
  `@.agent-instructions/AGENTS.md` in its root `AGENTS.md`: session hygiene, git conventions
  (including the auto commit + push policy), security minimums, risk management, documentation
  language, MCP/doc-lookup rules.
- [`gsd/common-config.json`](gsd/common-config.json) — the common subset of GSD's
  `.planning/config.json` keys, synced by a dedicated script without touching repo-local keys
  (`project_code`, `agent_skills`, `test_command`, …).
- [`config/repositories.tsv`](config/repositories.tsv) — the manifest of consumer repos and
  their tier.
- [`scripts/install-bridge.sh`](scripts/install-bridge.sh) — one-time bridge install for a new
  consumer repo.
- [`scripts/sync-gsd-config.mjs`](scripts/sync-gsd-config.mjs) — a surgical dotted-path merge of
  the common GSD keys, leaving the rest of the target file untouched.
- [`.github/workflows/sync-on-release.yml`](.github/workflows/sync-on-release.yml) — on release
  publish (a `CONTRACT_VERSION` bump), opens a PR into every repo in the manifest. Merge is
  manual — nothing auto-merges.

## How content stays fresh in consumer repos

Freshness comes from **auto-PR, not a manual clone**: content is vendored (committed in the
consumer repo, not gitignored), so diffs are visible in the PR itself. The VocalClub-style
manual-clone bridge pattern was deliberately not reused here — see this repo's `.planning/` for
the decision history.

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
