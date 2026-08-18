#!/usr/bin/env node
// Partial-key sync of gsd/common-config.json into a target repo's .planning/config.json.
// Dotted-path aware (same convention gsd-core's federated-config.cjs uses for schema keys):
// every key in common-config.json is written into the target file at that exact nested path.
// Every key ABSENT from common-config.json is left completely untouched — this is a surgical
// patch, never a whole-file overwrite, because .planning/config.json also carries live,
// repo-local GSD state (project_code, agent_skills, test_command, active workstream, ...).
//
// Usage:
//   node sync-gsd-config.mjs <path-to-repo> [--dry-run]
//
// <path-to-repo> is the repo root (the script reads <path>/.planning/config.json).

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

function fail(message) {
  console.error(`sync-gsd-config: ${message}`);
  process.exit(1);
}

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const repoPath = args.find((a) => !a.startsWith("--"));

if (!repoPath) {
  fail("missing <path-to-repo> argument. Usage: sync-gsd-config.mjs <path-to-repo> [--dry-run]");
}

const commonConfigPath = join(__dirname, "..", "gsd", "common-config.json");
const targetConfigPath = join(repoPath, ".planning", "config.json");

if (!existsSync(commonConfigPath)) fail(`common config not found at ${commonConfigPath}`);
if (!existsSync(targetConfigPath)) fail(`target config not found at ${targetConfigPath}`);

const common = JSON.parse(readFileSync(commonConfigPath, "utf8"));
const target = JSON.parse(readFileSync(targetConfigPath, "utf8"));

const FORBIDDEN = new Set(["__proto__", "constructor", "prototype"]);

function setNested(obj, dottedKey, value) {
  const segments = dottedKey.split(".");
  if (segments.some((s) => FORBIDDEN.has(s))) {
    console.warn(`sync-gsd-config: skipping unsafe key "${dottedKey}"`);
    return false;
  }
  let cursor = obj;
  for (let i = 0; i < segments.length - 1; i++) {
    const seg = segments[i];
    if (typeof cursor[seg] !== "object" || cursor[seg] === null || Array.isArray(cursor[seg])) {
      cursor[seg] = {};
    }
    cursor = cursor[seg];
  }
  cursor[segments[segments.length - 1]] = value;
  return true;
}

function getNested(obj, dottedKey) {
  const segments = dottedKey.split(".");
  let cursor = obj;
  for (const seg of segments) {
    if (typeof cursor !== "object" || cursor === null || !(seg in cursor)) return undefined;
    cursor = cursor[seg];
  }
  return cursor;
}

const changes = [];
for (const key of Object.keys(common)) {
  if (key === "_comment") continue;
  const before = getNested(target, key);
  const after = common[key];
  if (JSON.stringify(before) !== JSON.stringify(after)) {
    changes.push({ key, before, after });
    setNested(target, key, after);
  }
}

if (changes.length === 0) {
  console.log(`sync-gsd-config: ${targetConfigPath} already matches common-config.json.`);
  process.exit(0);
}

console.log(`sync-gsd-config: ${changes.length} key(s) would change in ${targetConfigPath}:`);
for (const { key, before, after } of changes) {
  console.log(`  ${key}: ${JSON.stringify(before)} -> ${JSON.stringify(after)}`);
}

if (dryRun) {
  console.log("sync-gsd-config: --dry-run set, not writing.");
  process.exit(0);
}

writeFileSync(targetConfigPath, JSON.stringify(target, null, 2) + "\n", "utf8");
console.log(`sync-gsd-config: wrote ${targetConfigPath}.`);
