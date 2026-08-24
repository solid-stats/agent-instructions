<!-- markdownlint-disable MD013 MD041 -->

# AGENTS instructions — maintaining this repo

This is the canonical source repository, not a generated consumer. Before
acting on any request here, read these canonical files completely:

1. [`shared/AGENTS.md`](shared/AGENTS.md) for the shared SolidStats rules;
2. [`CONTRACT_VERSION`](CONTRACT_VERSION) and
   [`shared/MEMORY.md`](shared/MEMORY.md) for the memory contract;
3. [`shared/GSD.md`](shared/GSD.md) only when a `.planning/config.json` exists.

Do not materialize `shared/AGENTS.md` back into this file. This repository's
primary active memory wing is `common`; it has no primary archive wing.

> **What this repo is.** `agent-instructions` is the canonical source of
> AI-agent rules shared across every `solid-stats` repository: the
> `shared/AGENTS.md` source materialized into committed consumer bundles, the
> thin root bridge that loads it, the common subset of GSD
> `.planning/config.json`, and the sync mechanism that keeps them current.
>
> **Boundary.** A **supporting** repo with no runtime boundary. It owns only the
> shared content and the scripts that distribute it. Product source, secrets,
> and single-developer workflows live in the consuming repositories.

## Editing the shared fragment

`shared/AGENTS.md` is the source for the committed
`.agent-instructions/solidstats/AGENTS.md` companion generated in every
consumer. The consumer's root `AGENTS.md` contains only the thin managed bridge
from `templates/AGENTS.bridge.md`. Edit both sources here, never inside generated
consumer files. Keep shared rules project-agnostic: anything specific to one
repository's boundary or stack belongs outside the managed markers in that
repository's root `AGENTS.md`.

Documentation in this repository is English except for its bilingual
`README.md` and `README.en.md`.

## Cutting and rolling out a release

1. Bump [`CONTRACT_VERSION`](CONTRACT_VERSION) using Semantic Versioning and
   add the release plus its `routine`, `important`, or `system` impact to
   [`CHANGELOG.md`](CHANGELOG.md).
2. If the change touches `gsd/common-config.json`, verify it against real
   consumer `.planning/config.json` files. A key belongs there only when it is
   universally required.
3. Run the complete test suite, commit, and push this canonical repository.
4. Complete any release-specific acceptance gate, then run
   `sh scripts/sync-consumers.sh --workspace-root ..`.
5. Review, test, commit, and publish every consumer through its applicable Git
   route. Finish with
   `sh scripts/sync-consumers.sh --workspace-root .. --check`.

There is no GitHub App or automatic release PR. The local batch preflights all
consumers before its first managed-file write and never commits or pushes them.

## Adding a new consumer repo

Add a row to [`config/repositories.tsv`](config/repositories.tsv), then run
`scripts/install-bridge.sh --root <path> --repository solid-stats/<repo>` once
in that repository.

## Testing changes

```sh
sh -n scripts/install-bridge.sh
sh -n scripts/sync-consumers.sh
sh tests/test-install-bridge.sh
sh tests/test-sync-gsd-config.sh
sh tests/test-sync-consumers.sh
node tests/test-contract.mjs
sh scripts/sync-consumers.sh --workspace-root .. --check
```
