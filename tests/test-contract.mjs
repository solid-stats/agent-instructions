#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const version = readFileSync(join(repoRoot, "CONTRACT_VERSION"), "utf8").trim();
assert(/^\d+\.\d+\.\d+$/u.test(version), "CONTRACT_VERSION must be SemVer");

const rootAgents = readFileSync(join(repoRoot, "AGENTS.md"), "utf8");
assert(
  !rootAgents.includes("<!-- BEGIN managed by solid-stats/agent-instructions -->"),
  "canonical AGENTS.md must not self-materialize the consumer block",
);
for (const pointer of [
  "shared/AGENTS.md",
  "shared/MEMORY.md",
  "shared/GSD.md",
  "CONTRACT_VERSION",
]) {
  assert(rootAgents.includes(pointer), `canonical AGENTS.md is missing ${pointer}`);
}

const bridgeTemplate = readFileSync(join(repoRoot, "templates", "AGENTS.bridge.md"), "utf8");
assert(
  bridgeTemplate.includes(".agent-instructions/solidstats/AGENTS.md"),
  "thin bridge must route to the committed companion AGENTS.md",
);
assert(
  !bridgeTemplate.includes("{{SOLIDSTATS_"),
  "thin bridge must not carry repository metadata",
);

const sharedAgents = readFileSync(join(repoRoot, "shared", "AGENTS.md"), "utf8");
for (const path of [
  "{{SOLIDSTATS_AGENT_CONTRACT_PATH}}",
  "{{SOLIDSTATS_CONTRACT_VERSION_PATH}}",
  "{{SOLIDSTATS_MEMORY_CONTRACT_PATH}}",
  "{{SOLIDSTATS_GSD_CONTRACT_PATH}}",
]) {
  assert(sharedAgents.includes(path), `shared AGENTS.md is missing bundle member ${path}`);
}
assert(
  sharedAgents.includes("stop product work"),
  "incomplete companion bundles must block product work",
);

const manifestLines = readFileSync(join(repoRoot, "config", "repositories.tsv"), "utf8")
  .trimEnd()
  .split(/\r?\n/u);
assert(
  manifestLines.shift() ===
    "# repository\ttier\tgsd_config_sync\tmemory_wing\tarchive_wing",
  "unexpected repository manifest header",
);

const expected = new Map([
  ["solid-stats/agent-instructions", ["supporting", "no", "common", "none"]],
  ["solid-stats/server-2", ["platform", "yes", "backend", "server-2-archive"]],
  ["solid-stats/replays-fetcher", ["platform", "yes", "fetcher", "replays-fetcher-archive"]],
  ["solid-stats/replay-parser-2", ["platform", "yes", "backend", "replay-parser-2-archive"]],
  ["solid-stats/web", ["platform", "yes", "frontend", "web-archive"]],
  ["solid-stats/infrastructure", ["platform", "yes", "devops", "infrastructure-archive"]],
  ["solid-stats/plans", ["supporting", "no", "common", "none"]],
  ["solid-stats/skills", ["supporting", "no", "common", "none"]],
  ["solid-stats/ts-toolchain", ["supporting", "no", "common", "none"]],
]);

for (const line of manifestLines) {
  const [repository, ...fields] = line.split("\t");
  assert(expected.has(repository), `unexpected repository ${repository}`);
  assert(JSON.stringify(fields) === JSON.stringify(expected.get(repository)), `bad route for ${repository}`);
  expected.delete(repository);
}
assert(expected.size === 0, `missing repositories: ${[...expected.keys()].join(", ")}`);

const common = JSON.parse(readFileSync(join(repoRoot, "gsd", "common-config.json"), "utf8"));
for (const key of [
  "mempalace.enabled",
  "mempalace.recall_on_discuss",
  "mempalace.recall_on_plan",
  "mempalace.capture_artifacts",
  "mempalace.mirror_kg",
  "mempalace.cross_project_tunnels",
  "mempalace.diary_journal",
  "mempalace.auto_capture_hooks",
]) {
  assert(common[key] === false, `${key} must remain false`);
}
assert(common["mempalace.memory_mode"] === "augment", "memory mode must remain augment");
assert(!("mempalace.wing" in common), "repository-specific wing leaked into common config");

const memory = readFileSync(join(repoRoot, "shared", "MEMORY.md"), "utf8");
for (const room of ["decisions", "contracts", "conventions", "operations", "incidents", "migrations"]) {
  assert(memory.includes(`\`${room}\``), `MEMORY.md does not declare ${room}`);
}
for (const forbidden of ["mempalace_create_tunnel", "mempalace_kg_add", "mempalace_checkpoint"]) {
  assert(!memory.includes(`call \`${forbidden}\``), `MEMORY.md authorizes forbidden tool ${forbidden}`);
}

console.log("Contract invariants passed.");
