import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import {
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
  existsSync,
} from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import {
  accountId,
  workerName,
  cloudflare,
  currentVersion,
} from "./cloudflare.mjs";
const require = createRequire(import.meta.url);
const app = fileURLToPath(new URL("../", import.meta.url));
const config = JSON.parse(
  readFileSync(new URL("./wrangler.jsonc", import.meta.url), "utf8").replace(
    /^\s*\/\/.*$/gmu,
    "",
  ),
);
assert.equal(config.name, workerName);
assert.equal(config.account_id, accountId);
assert(
  config.workers_dev &&
    !config.preview_urls &&
    !config.routes.length &&
    !config.observability.enabled,
  "Isolated no-logging configuration required.",
);
assert.deepEqual(config.assets.run_worker_first, ["/*", "!/assets/*"]);
assert.equal(config.assets.not_found_handling, "none");
assert.equal(config.assets.html_handling, "none");
assert.deepEqual(
  Object.keys(config).sort(),
  [
    "$schema",
    "name",
    "account_id",
    "compatibility_date",
    "main",
    "workers_dev",
    "preview_urls",
    "routes",
    "observability",
    "assets",
  ].sort(),
);
const assets = fileURLToPath(
  new URL("../dist/static-invitations/", import.meta.url),
);
assert(
  readdirSync(assets, { recursive: true }).every(
    (path) => !String(path).endsWith(".map"),
  ),
  "Source maps must never be published.",
);
const scripts = readdirSync(`${assets}/assets`)
  .filter((name) => name.endsWith(".js"))
  .map((name) => readFileSync(`${assets}/assets/${name}`, "utf8"))
  .join("\n");
assert(
  scripts.includes("https://cllpvruvrrvxczjitlqd.supabase.co") &&
    !scripts.includes("http://127.0.0.1:59121"),
  "Build staging client before deployment.",
);
assert(
  !scripts.includes("sb_secret_") && !scripts.includes("sourceMappingURL="),
  "Invalid public artifact.",
);
const logDir = fileURLToPath(
  new URL("../.wrangler/link-host03/", import.meta.url),
);
mkdirSync(logDir, { recursive: true });
const journal = `${logDir}/deployment.json`;
const owned = existsSync(journal)
  ? JSON.parse(readFileSync(journal, "utf8"))
  : null;
const remote = await cloudflare(`/workers/scripts/${workerName}/settings`);
assert(
  remote.status === 404 ||
    (remote.status === 200 &&
      owned?.worker === workerName &&
      owned.version === (await currentVersion())),
  "Trial name already exists or account access is unavailable; do not overwrite it.",
);
const revision = spawnSync("git", ["rev-parse", "HEAD"], {
  cwd: app,
  encoding: "utf8",
  windowsHide: true,
});
assert.equal(revision.status, 0);
const result = spawnSync(
  process.execPath,
  [
    resolve(
      dirname(require.resolve("wrangler/package.json")),
      "bin/wrangler.js",
    ),
    "deploy",
    "--config",
    "static-invitations/wrangler.jsonc",
  ],
  {
    cwd: app,
    encoding: "utf8",
    windowsHide: true,
    env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
  },
);
writeFileSync(`${logDir}/deploy.log`, `${result.stdout}\n${result.stderr}`);
assert.equal(
  result.status,
  0,
  "Trial deployment failed; inspect ignored deploy.log.",
);
const version = await currentVersion();
const settings = await cloudflare(`/workers/scripts/${workerName}/settings`);
assert.equal(settings.status, 200);
assert(
  !settings.data.result.observability?.enabled,
  "Request Observability must stay disabled.",
);
const subdomain = await cloudflare(`/workers/scripts/${workerName}/subdomain`);
assert.equal(subdomain.status, 200);
assert(
  subdomain.data.result.enabled && !subdomain.data.result.previews_enabled,
);
writeFileSync(
  journal,
  JSON.stringify(
    {
      worker: workerName,
      version,
      revision: revision.stdout.trim(),
      deployedAt: new Date().toISOString(),
    },
    null,
    2,
  ),
);
console.log(
  JSON.stringify({
    worker: workerName,
    version,
    sourceRevision: revision.stdout.trim(),
    configuredRoutes: 0,
    workersDev: true,
    observability: false,
  }),
);
