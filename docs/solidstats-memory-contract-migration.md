# SolidStats Memory Contract Migration

## Purpose

This document is the durable handoff for the pending SolidStats memory contract
migration. It records the accepted behavior that must later be implemented in
`shared/AGENTS.md`, the shared GSD configuration or adapter, repository bridges,
and machine-local MCP registration.

It is intentionally separate from the runtime migration owned by the
`infrastructure` repository. Do not mark this handoff complete merely because
Qdrant is deployed: the agent contract, GSD lifecycle, and client routing must
also be updated and verified.

The current VocalClub v7 contract is the behavioral reference. Older
VocalClub infrastructure documentation describes an earlier recall policy and
must not override the current contract.

## Confirmed boundaries

- Keep three logically separate palaces:
  - SolidStats: `solidstats_memory`;
  - personal state: `mempalace_personal`;
  - VocalClub: `vocalclub_memory`.
- Do not merge their stores, credentials, backups, retrieval, or lifecycle.
- Rename the current generic SolidStats MCP registration from `mempalace` to
  `solidstats_memory` atomically at cutover.
- Do not leave `mempalace` as an alias after cutover.
- Keep personal and VocalClub routing unchanged.
- Current repository content and other primary sources remain authoritative.
  Palace content is context to verify, never a replacement for current code,
  schemas, APIs, plans, or operational evidence.

## Legacy write freeze and migration boundary

- The existing Chroma-backed SolidStats palace is frozen against all new
  writes while the replacement is prepared.
- Read-only recall may continue from the old palace until cutover.
- Build, clean, classify, and embed the replacement locally on the more
  powerful workstation. Do not perform the rebuild on the VPS.
- Preserve the stopped old Chroma volume or snapshot as rollback material.
- Do not run the old Chroma palace and the new Qdrant palace concurrently on
  the VPS as long-lived services.
- Do not migrate the existing temporal KG, diary, semantic tunnels, or agent
  wings blindly.
- Audit existing KG content separately. Delete personal facts only through an
  explicitly approved exact-ID batch.
- Audit and remove existing tunnels only through an explicitly approved
  exact-ID batch.

## Wing model

### Active wings

- Every canonical SolidStats repository keeps an active wing named after the
  repository.
- The `SolidStats` wing is the platform/common wing. It contains only curated
  cross-repository semantic conclusions and has no raw seeded corpus.
- The authoritative repository registry must come from
  `config/repositories.tsv`; the contract must not rely on an independently
  maintained prose list.
- Agent-created wings are forbidden.

### Frozen archive wings

- Preserve the useful legacy raw corpus in a separate archive wing per source
  repository, for example `web-archive` and `server-2-archive`.
- Do not create one shared archive wing.
- Archive material is an untrusted historical lead, not current semantic
  truth.
- Do not automatically mine, sync, or append to archive wings after migration.
- A future archive addition requires an explicit curator-approved operation.

### Active room taxonomy

Agent-created active memory may use only these rooms:

- `decisions`;
- `contracts`;
- `conventions`;
- `operations`;
- `incidents`;
- `migrations`.

Legacy archive rooms do not become active semantic rooms merely because their
content was migrated.

## Task ownership

- The main agent owns at most one recall sequence and one closure capture
  sequence for a top-level task.
- Recall begins in the first tool batch, in parallel with the repository
  bridge, applicable skills, and current primary evidence.
- Specialists and subagents receive filtered, provenance-bearing context from
  the main agent. They must not independently recall or capture memory.
- The managed repository bridge declares the primary active wing.
- If `solidstats_memory` is unavailable, retry once later in the session,
  continue from primary evidence, and report the failure in the handoff.
- Never substitute personal, VocalClub, flat global memory, or a stale local
  outbox for unavailable SolidStats memory.

## Federated scoped recall

Run separate wing-filtered searches. Unfiltered top-k search is forbidden
because differently sized wings would suppress smaller but relevant scopes.

Initial discovery budgets are:

1. up to 5 results from the primary active repository wing;
2. up to 3 results from the platform/common `SolidStats` wing;
3. up to 2 results from every other active repository wing;
4. up to 2 results from the primary repository's archive wing;
5. up to 2 results from a foreign archive wing only after current evidence
   proves the dependency and promotes that archive.

These are candidate budgets, not quotas for working context. A candidate may
influence the task only when its content is relevant and its provenance is
usable.

For every relevant candidate:

- treat similarity only as candidate ordering;
- fetch the complete drawer before relying on it;
- verify the drawer against current primary evidence;
- treat archive results as weaker than active semantic results;
- keep only the filtered content needed by the task.

MemPalace semantic tunnels are not part of recall. Do not create, query, or
follow them as a substitute for federated search.

## Evidence-seeded term expansion

The final contract must preserve the complete VocalClub query discipline, not
reduce it to a generic instruction to retry search.

### Initial queries

- Use the same task identifiers and keywords in every initial active-wing
  query.
- Keep `query` short and identifier-heavy. Keep task background in `context`.
- Seed the initial query from identifiers already carried by the task, such as
  an issue key, branch or commit, endpoint, entity, service name, exact error,
  or symptom.
- Do not wait for a complete task model before starting first-batch recall.

### Promotion and additional searches

- Promote another active wing when a relevant candidate or verified current
  primary source proves a cross-repository dependency.
- A promoted wing may introduce additional terms only from:
  - the user request;
  - a relevant retrieved drawer;
  - a verified current primary source.
- Follow-up searches in a promoted active wing have no fixed numeric limit.
- Continue while new results add relevant information to the task model.
- Stop when results repeat, become irrelevant, or no longer change that model.
- Promotion applies only to the current top-level task.

### Scoped miss fallback

A semantic search miss is not evidence that memory is absent. For the primary
wing, the `SolidStats` wing, the primary archive, and any promoted wing:

1. run an evidence-seeded alternate query;
2. inspect scoped rooms;
3. inspect bounded entries in the relevant wing and room;
4. fetch only relevant drawers in full;
5. report no relevant memory only after these scoped fallbacks fail.

Do not expand an unpromoted foreign active or archive wing beyond its initial
budget without verified current evidence of the dependency.

## Semantic closure capture

For SolidStats, `capture_artifacts: true` means that GSD triggers semantic
closure capture. It must never mean storing a raw GSD artifact.

### Durability gate

Capture only a verified conclusion that is useful beyond the current task:

- a decision;
- a contract;
- a convention;
- an operational invariant or procedure;
- an incident root cause and prevention;
- migration state that future work must know.

If a task produces no durable semantic conclusion, write nothing.

Never store:

- raw `CONTEXT.md`, `PLAN.md`, `SUMMARY.md`, or other `.planning` artifacts;
- prompts, transcripts, patches, source code, generated code, or logs;
- routine edits, temporary status, passing-check narration, or speculation;
- secrets, credentials, personal information, or unpublished sensitive data.

### Record shape and ownership

- Store one independently durable fact per drawer.
- Route it to the active wing of the repository that owns the conclusion.
- Use `SolidStats` only for genuinely platform-wide conclusions.
- Use the matching fixed semantic room.
- Deduplicate before writing and re-fetch the stored drawer after mutation.
- Every record must use this structure:

  ```text
  Task: <stable task identity and scope>
  Outcome: <verified result>
  Decisions: <durable conclusions>
  Validation: <how the conclusion was verified>
  Sources: <exact current provenance references>
  ```

- Sources must use stable repository-relative paths, issue IDs, commit IDs, or
  other durable references, never ephemeral worktree paths.

## Historical correction and curation

- Ordinary task agents must not silently rewrite, delete, or invalidate old
  memory.
- A suspected error becomes a correction candidate containing:
  - the exact drawer ID or temporal fact;
  - the current primary evidence;
  - the proposed action and replacement;
  - a verification query.
- Only the curator may preview the correction and request approval.
- Approval applies only to the exact IDs, facts, actions, and replacements
  shown in that preview.
- Re-fetch or re-query after every approved mutation.
- Exact disposable UAT records may be removed by exact drawer ID as part of
  their own verified test cleanup.

## GSD integration requirements

The shared GSD layer must enforce or audit these values across every consumer
repository:

- MemPalace enabled;
- recall on discuss enabled;
- recall on plan disabled;
- semantic closure capture enabled;
- memory mode `augment`;
- cross-project semantic tunnels disabled;
- temporal KG mirroring disabled;
- diary journaling disabled;
- generic automatic capture hooks disabled.

If a value cannot safely live in `gsd/common-config.json`, the shared adapter or
validation must still prove that every consumer has the required local value.
Do not leave lifecycle correctness dependent on undocumented per-repository
configuration.

The GSD coordinator performs the one recall sequence before discussion and
carries filtered, provenance-bearing context into planning and execution.
Planning must not launch a second recall. Wave completion triggers the semantic
closure gate, not raw artifact capture. Ship-time curation follows the
correction rules above.

## Required implementation surfaces

After the new runtime is verified and ready for cutover, update all affected
surfaces atomically:

1. `shared/AGENTS.md` with the scoped palace boundary, source hierarchy, wing
   model, full federated recall, term expansion, fallback, capture, and
   correction contract;
2. `gsd/common-config.json` and any shared GSD adapter or validator required to
   enforce the lifecycle values;
3. repository bridge generation so each consumer declares its primary wing;
4. tests for bridge installation and shared GSD configuration;
5. `CONTRACT_VERSION` and release notes;
6. machine-local MCP registration from `mempalace` to
   `solidstats_memory`, with a dedicated token;
7. recall/capture UAT against the resulting
   `mcp__solidstats_memory__*` tool surface.

Do not switch the shared contract before the new endpoint is deployable and
verified. Do not leave the old and new MCP names active together after cutover.

## Acceptance checklist

- The generic `mempalace` registration is gone and
  `solidstats_memory` is the only SolidStats MCP server name.
- Personal and VocalClub palaces remain isolated and unchanged.
- Initial recall searches every active wing with the accepted fairness
  budgets.
- Archive lookup follows its stricter budgets and verification rules.
- Evidence-seeded term expansion and scoped miss fallback pass UAT.
- An unfiltered search is neither required nor recommended by the contract.
- Tunnels, KG, diary, raw GSD artifacts, and agent wings are absent from the
  normal lifecycle.
- A durable conclusion is captured once with exact provenance and read-back
  verification.
- A task without a durable conclusion creates no drawer.
- A correction cannot mutate history without exact curator approval.
- Every consumer repository receives the same enforced GSD lifecycle.
- The old palace remains recoverable offline until post-cutover acceptance and
  rollback expiry are explicitly approved.

## Reference sources

Use the current versions of these repositories when implementing the contract:

- `vocalclub/agent-instructions`: current `AGENTS.md` and `GSD.md`;
- `vocalclub/vc-mempalace`: deployment, migration, seed, verification, and
  client UAT documentation;
- `SolidGames/infrastructure`: the new runtime migration and verification
  artifacts;
- this repository: `config/repositories.tsv`, `shared/AGENTS.md`, and
  `gsd/common-config.json`.
