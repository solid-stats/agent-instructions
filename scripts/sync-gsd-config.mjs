#!/usr/bin/env node
// Merge canonical common GSD keys and the repository-specific memory wing.
// Keys absent from common-config.json stay untouched because they are local GSD state.
//
// Usage:
//   node sync-gsd-config.mjs <path> --repository ORG/REPO [--dry-run|--check]

import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const contractRoot = realpathSync(join(scriptDir, ".."));

function fail(message) {
  console.error(`sync-gsd-config: ${message}`);
  process.exit(1);
}

function parseManifest(path) {
  const lines = readFileSync(path, "utf8")
    .split(/\r?\n/u)
    .filter((line) => line.length > 0);
  const expectedHeader =
    "# repository\ttier\tgsd_config_sync\tmemory_wing\tarchive_wing";
  if (lines.shift() !== expectedHeader) fail("repositories.tsv has an unexpected header");

  return lines.map((line, index) => {
    const fields = line.split("\t");
    if (fields.length !== 5) fail(`repositories.tsv line ${index + 2} must have 5 fields`);
    const [repository, tier, gsdConfigSync, memoryWing, archiveWing] = fields;
    if (!/^[a-z0-9-]+\/[a-z0-9-]+$/u.test(repository)) {
      fail(`invalid repository at repositories.tsv line ${index + 2}`);
    }
    if (!/^[a-z0-9-]+$/u.test(memoryWing)) {
      fail(`invalid memory wing at repositories.tsv line ${index + 2}`);
    }
    if (!/^(?:[a-z0-9-]+|none)$/u.test(archiveWing)) {
      fail(`invalid archive wing at repositories.tsv line ${index + 2}`);
    }
    if (!new Set(["platform", "supporting"]).has(tier)) {
      fail(`invalid tier at repositories.tsv line ${index + 2}`);
    }
    if (!new Set(["yes", "no"]).has(gsdConfigSync)) {
      fail(`invalid gsd_config_sync at repositories.tsv line ${index + 2}`);
    }
    return { repository, tier, gsdConfigSync, memoryWing, archiveWing };
  });
}

const args = process.argv.slice(2);
let dryRun = false;
let check = false;
let repository;
const positional = [];
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--dry-run") {
    dryRun = true;
  } else if (arg === "--check") {
    check = true;
  } else if (arg === "--repository") {
    repository = args[index + 1];
    if (!repository || repository.startsWith("--")) fail("--repository requires a value");
    index += 1;
  } else if (arg.startsWith("--")) {
    fail(`unknown option ${arg}`);
  } else {
    positional.push(arg);
  }
}
if (dryRun && check) fail("--dry-run and --check are mutually exclusive");
if (positional.length !== 1) fail("expected exactly one <path-to-repo> argument");
const [repoPathArg] = positional;
if (!existsSync(repoPathArg)) fail(`repository path not found at ${repoPathArg}`);

const repoPath = realpathSync(repoPathArg);
const manifest = parseManifest(join(contractRoot, "config", "repositories.tsv"));
if (!repository) {
  if (repoPath === contractRoot) {
    repository = "solid-stats/agent-instructions";
  } else {
    const matches = manifest.filter((row) => basename(row.repository) === basename(repoPath));
    if (matches.length !== 1) {
      fail("cannot infer repository identity; pass --repository ORG/REPO");
    }
    repository = matches[0].repository;
  }
}

const manifestRow = manifest.find((row) => row.repository === repository);
if (!manifestRow) fail(`repository ${repository} is absent from repositories.tsv`);
if (manifestRow.gsdConfigSync !== "yes") {
  fail(`repository ${repository} is not configured for GSD config sync`);
}

const commonConfigPath = join(contractRoot, "gsd", "common-config.json");
const targetConfigPath = join(repoPath, ".planning", "config.json");
if (!existsSync(targetConfigPath)) fail(`target config not found at ${targetConfigPath}`);

const common = JSON.parse(readFileSync(commonConfigPath, "utf8"));
const target = JSON.parse(readFileSync(targetConfigPath, "utf8"));
const forbidden = new Set(["__proto__", "constructor", "prototype"]);

function setNested(obj, dottedKey, value) {
  const segments = dottedKey.split(".");
  if (segments.some((segment) => forbidden.has(segment))) {
    fail(`unsafe common-config key ${dottedKey}`);
  }
  let cursor = obj;
  for (let index = 0; index < segments.length - 1; index += 1) {
    const segment = segments[index];
    if (
      typeof cursor[segment] !== "object" ||
      cursor[segment] === null ||
      Array.isArray(cursor[segment])
    ) {
      cursor[segment] = {};
    }
    cursor = cursor[segment];
  }
  cursor[segments.at(-1)] = value;
}

function getNested(obj, dottedKey) {
  let cursor = obj;
  for (const segment of dottedKey.split(".")) {
    if (typeof cursor !== "object" || cursor === null || !(segment in cursor)) {
      return undefined;
    }
    cursor = cursor[segment];
  }
  return cursor;
}

const desired = new Map(
  Object.entries(common).filter(([key]) => key !== "_comment"),
);
desired.set("mempalace.wing", manifestRow.memoryWing);

const changes = [];
for (const [key, after] of desired) {
  const before = getNested(target, key);
  if (JSON.stringify(before) !== JSON.stringify(after)) {
    changes.push({ key, before, after });
    setNested(target, key, after);
  }
}

if (changes.length === 0) {
  console.log(`sync-gsd-config: ${targetConfigPath} is current.`);
  process.exit(0);
}

console.log(`sync-gsd-config: ${changes.length} key(s) differ in ${targetConfigPath}:`);
for (const { key, before, after } of changes) {
  console.log(`  ${key}: ${JSON.stringify(before)} -> ${JSON.stringify(after)}`);
}

if (check) {
  console.error("sync-gsd-config: managed GSD config is outdated.");
  process.exit(1);
}
if (dryRun) {
  console.log("sync-gsd-config: --dry-run set, not writing.");
  process.exit(0);
}

writeFileSync(targetConfigPath, `${JSON.stringify(target, null, 2)}\n`, "utf8");
console.log(`sync-gsd-config: wrote ${targetConfigPath}.`);
