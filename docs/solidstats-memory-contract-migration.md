# SolidStats memory contract cutover handoff

## Status

The canonical contract bundle is implemented and contract `1.1.0` is published
on `master` in every consumer repository. The user explicitly authorized this
rollout before the infrastructure Phase 21.1 acceptance gate because no product
work will occur before v4 completes.

Phase 21.1 client-surface verification, the approved drawer correction, and
contract UAT remain pending. Do not treat publication as acceptance.

## Canonical sources

- `CONTRACT_VERSION` is the single contract version.
- `shared/MEMORY.md` owns memory scope, recall, capture, correction, deletion,
  archive handling, and acceptance invariants.
- `shared/GSD.md` owns manual GSD coordinator integration.
- `templates/AGENTS.bridge.md` is the thin managed root entry point.
- `shared/AGENTS.md` is rendered into each consumer's committed companion
  bundle and owns shared rules plus repository-specific memory routing.
- `config/repositories.tsv` owns repository membership, active role wings, and
  primary archive wings.
- `gsd/common-config.json` disables the incompatible native GSD MemPalace
  capability. `scripts/sync-gsd-config.mjs` adds the repository-specific wing.

The companion bundle generated in every consumer is:

```text
.agent-instructions/solidstats/
├── AGENTS.md
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

## Published rollout

The rollout was published and verified at these revisions:

- `server-2`: `9915439` through PR #40;
- `replays-fetcher`: `708fefc`;
- `replay-parser-2`: `3dfa341`;
- `web`: `83ed89a`;
- `infrastructure`: `4553ded`;
- `plans`: `b6aa733`;
- `skills`: `92aa052`;
- `ts-toolchain`: `72545c6`.

`infrastructure` was updated from an isolated worktree based on `origin/master`.
The active `gsd/v4.0-solidstats-memory-isolation` checkout and its untracked
Phase 21.1 evidence files were not changed.

The final fail-closed check passed across all eight published masters:

```sh
sh scripts/sync-consumers.sh --workspace-root <clean-verification-workspace> --check
```

`server-2` Verify, contract diff, golden oracle, and master image build passed.
The other available rollout CI checks passed except `web`, whose workflow still
fails during dependency installation on the pre-existing
`ERR_PNPM_IGNORED_BUILDS` gate before project checks begin.

## Acceptance

Acceptance still requires all of the following. Publication items are complete;
runtime and UAT items remain pending:

1. **Pending:** Phase 21.1 client-surface checks pass.
2. **Pending:** The exact approved drawer correction is read back successfully.
3. **Pending:** Recall UAT searches all five active wings with the contract
   budgets and fetches relevant drawers before use.
4. **Pending:** Capture UAT writes one semantic drawer to a unique
   `uat-<nonce>` room, verifies it, and deletes it by exact ID.
5. **Pending:** No UAT drawer remains.
6. **Complete:** Every consumer carries contract `1.1.0`, the thin root bridge,
   and exact companion files.
7. **Complete:** Every platform GSD config contains the fail-closed native
   MemPalace block and its manifest-owned role wing.
8. **Complete:** Consumer changes are committed and published through the
   correct Git route.

## Cleanup after acceptance

Delete this handoff in the acceptance-closing commit after every pending item
above is complete. Its exact gate, correction, and UAT instructions are still
needed until then.

Archive distillation and any personal-data audit are separate post-cutover
work. They must not mutate archive drawers or delay this contract acceptance.
