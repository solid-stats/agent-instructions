# Contract changelog

Contract versions follow Semantic Versioning. Every release also declares an
operational impact level:

- `routine`: generated content changes without lifecycle or routing changes;
- `important`: behavior changes that require consumer review;
- `system`: coordinated routing, runtime, or multi-repository cutover.

## Unreleased

Impact: `routine`

- Stop self-materializing the shared consumer block into the canonical
  repository's root `AGENTS.md`.

## 1.0.0 - 2026-08-25

Impact: `system`

- Isolate SolidStats project memory behind `solidstats_memory`.
- Replace repository-named active wings with role wings and immutable archive
  wings.
- Add the canonical `MEMORY.md` lifecycle and manual `GSD.md` adapter.
- Disable GSD's incompatible native MemPalace capability fail-closed.
- Materialize versioned companion contracts into every consumer repository.
- Replace GitHub App release PRs with a fail-closed local batch rollout.
