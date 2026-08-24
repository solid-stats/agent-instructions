# SolidStats memory contract cutover handoff

## Status

The canonical contract bundle is implemented in this repository. Consumer
rollout remains gated on the infrastructure Phase 21.1 client update that
exposes `mempalace_update_drawer` through `solidstats_memory`.

Do not run the consumer batch merely because this repository is released. Run
the acceptance sequence below first.

## Canonical sources

- `CONTRACT_VERSION` is the single contract version.
- `shared/MEMORY.md` owns memory scope, recall, capture, correction, deletion,
  archive handling, and acceptance invariants.
- `shared/GSD.md` owns manual GSD coordinator integration.
- `shared/AGENTS.md` is only the routed entry point embedded into root
  `AGENTS.md` files.
- `config/repositories.tsv` owns repository membership, active role wings, and
  primary archive wings.
- `gsd/common-config.json` disables the incompatible native GSD MemPalace
  capability. `scripts/sync-gsd-config.mjs` adds the repository-specific wing.

The companion bundle generated in every consumer is:

```text
.agent-instructions/solidstats/
├── CONTRACT_VERSION
├── GSD.md
└── MEMORY.md
```

## Runtime boundary

- SolidStats uses only `solidstats_memory`.
- Personal memory remains in `mempalace_personal`.
- VocalClub memory remains in `vocalclub_memory`.
- The generic `mempalace` registration must not remain as a SolidStats alias.
- Current repository and live operational evidence stay authoritative over
  memory.

Active role wings are `frontend`, `backend`, `fetcher`, `devops`, and `common`.
The frozen repository-bound archives are defined in `shared/MEMORY.md` and must
remain immutable.

## Phase 21.1 gate

Before consumer rollout, verify that the restricted client surface exposes the
approved update operation and still excludes unsupported generic lifecycle
operations. Then execute the already approved correction exactly once:

- drawer ID: `drawer_infrastructure_operations_234ea02816667f903010e583`;
- current wing: `infrastructure`;
- target wing: `devops`;
- room, content, and provenance: unchanged.

Re-fetch that exact drawer and verify the approved fields after mutation. Any
different ID or mutation requires new approval.

## Local rollout

The batch script preflights every consumer checkout before its first write. A
missing, dirty, untracked, ahead, behind, or diverged checkout blocks the whole
batch.

```sh
sh scripts/sync-consumers.sh --workspace-root ..
```

The script updates managed files only. Review each repository diff, run its
applicable checks, then commit and push using that repository's route:

- `server-2`: branch and pull request;
- active GSD milestone: its configured milestone branch flow;
- every other consumer: direct `master` push.

After all eight consumer commits are published, verify the same version and
content everywhere:

```sh
sh scripts/sync-consumers.sh --workspace-root .. --check
```

## Acceptance

Acceptance requires all of the following:

1. Phase 21.1 client-surface checks pass.
2. The exact approved drawer correction is read back successfully.
3. Recall UAT searches all five active wings with the contract budgets and
   fetches relevant drawers before use.
4. Capture UAT writes one semantic drawer to a unique `uat-<nonce>` room,
   verifies it, and deletes it by exact ID.
5. No UAT drawer remains.
6. Every consumer carries contract `1.0.0`, the routed root block, and exact
   companion files.
7. Every platform GSD config contains the fail-closed native MemPalace block
   and its manifest-owned role wing.
8. Consumer changes are committed and published through the correct Git route.

Archive distillation and any personal-data audit are separate post-cutover
work. They must not mutate archive drawers or delay this contract acceptance.
