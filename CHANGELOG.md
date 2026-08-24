# Contract changelog

Contract versions follow Semantic Versioning. Every release also declares an
operational impact level:

- `routine`: generated content changes without lifecycle or routing changes;
- `important`: behavior changes that require consumer review;
- `system`: coordinated routing, runtime, or multi-repository cutover.

## Unreleased

Impact: `routine`

## 1.2.0 - 2026-08-25

Impact: `important`

- Standardize SolidStats GSD projects on the Codex autonomous performance
  baseline: YOLO mode, standard granularity, the effective 400K context
  window, parallel worktrees, and bounded dynamic model escalation.
- Route mapping and exploration to GPT-5.6 Luna Medium, plan execution and
  plan checks to GPT-5.6 Terra Medium, and phase-wide review and verification
  to GPT-5.6 Sol Medium.
- Remove redundant research-before-questions work, inline plans with up to
  three tasks, and use standard code-review depth by default.
- Let the autonomous coordinator choose coarse planning only for an obviously
  simple, low-risk phase and default to standard whenever classification is
  uncertain.
- Keep Smart Discuss autonomous and non-interactive instead of globally
  discarding phase context.

## 1.1.0 - 2026-08-25

Impact: `important`

- Stop self-materializing the shared consumer block into the canonical
  repository's root `AGENTS.md`.
- Replace the embedded consumer contract with a thin root bridge to a committed
  companion `AGENTS.md`.
- Make the four-file companion bundle fail-closed without adding a task-start
  remote update check or a second version number.
- Preserve the existing consumer `AGENTS.md` line-length lint scope while
  replacing the embedded block.

## 1.0.0 - 2026-08-25

Impact: `system`

- Isolate SolidStats project memory behind `solidstats_memory`.
- Replace repository-named active wings with role wings and immutable archive
  wings.
- Add the canonical `MEMORY.md` lifecycle and manual `GSD.md` adapter.
- Disable GSD's incompatible native MemPalace capability fail-closed.
- Materialize versioned companion contracts into every consumer repository.
- Replace GitHub App release PRs with a fail-closed local batch rollout.
