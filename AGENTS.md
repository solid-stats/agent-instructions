> **What this repo is.** `agent-instructions` is the canonical source of AI-agent rules shared
> across every `solid-stats` repository — the `shared/AGENTS.md` fragment every repo imports, the
> common subset of GSD `.planning/config.json`, and the sync mechanism that keeps both current.
>
> **Boundary.** A **supporting** repo — it owns no runtime boundary. It owns only the shared
> content and the scripts/workflow that distribute it. It does not hold product source code,
> secrets, or single-developer workflows — those live in the consuming repos.

---

@shared/AGENTS.md

# AGENTS instructions — maintaining this repo

## Editing the shared fragment

`shared/AGENTS.md` is the file every consumer repo vendors verbatim. Edit it here, never in a
consumer repo (a consumer's copy is overwritten by the next sync PR). Keep it project-agnostic —
anything specific to one repo's boundary or stack belongs in that repo's own `AGENTS.md`, not
here.

## Cutting a release (propagates to every consumer repo)

1. Bump [`CONTRACT_VERSION`](CONTRACT_VERSION) by one.
2. If the change touches `gsd/common-config.json`, verify it against a couple of real consumer
   `.planning/config.json` files first — a key only belongs there if it is genuinely meant to be
   identical everywhere, not merely identical today by coincidence.
3. Commit, push, then `gh release create v<N>` — publishing the release is what fires
   [`sync-on-release.yml`](.github/workflows/sync-on-release.yml) and opens the PRs.

## Adding a new consumer repo

Add a row to [`config/repositories.tsv`](config/repositories.tsv), then run
`scripts/install-bridge.sh --root <path>` once in that repo to bootstrap it.

## Testing changes

```sh
sh -n scripts/install-bridge.sh
sh tests/test-install-bridge.sh
node scripts/sync-gsd-config.mjs <path-to-a-real-repo> --dry-run
```

## Documentation Language

Documentation in this repo is English only (see the imported `shared/AGENTS.md` for the
project-wide rule), except this repo's own bilingual `README.md`/`README.en.md`.
