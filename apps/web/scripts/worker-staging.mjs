import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { parsePublicEnv } from "../src/lib/config/public-env.ts";

// Env is loaded by Node's --env-file; only public values are compiled into the
// browser bundle. Binding/config secrets never become NEXT_PUBLIC values.
const config = parsePublicEnv(process.env);
if (
  config.appEnv !== "staging" ||
  config.supabaseUrl !== "https://cllpvruvrrvxczjitlqd.supabase.co"
)
  throw new Error(
    "Worker trial requires the canonical planets-staging backend.",
  );
if (!config.supabasePublishableKey.startsWith("sb_publishable_"))
  throw new Error("Worker trial requires a public publishable key.");
if (config.sentryDsn)
  throw new Error(
    "Staging trial requires empty Sentry DSN; real monitoring delivery is not verified.",
  );
for (const name of [
  "PLANETS_ANDROID_APP_LINK_PACKAGE_ID",
  "PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS",
  "PLANETS_IOS_TEAM_ID",
  "PLANETS_IOS_BUNDLE_ID",
  "NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL",
  "NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL",
]) {
  if (process.env[name]?.trim())
    throw new Error(
      "Worker trial keeps unverified store and native identities disabled.",
    );
}

const require = createRequire(import.meta.url);
const mode = process.argv[2];
let binary, args;
if (mode === "build" || mode === "profile-build") {
  binary = resolve(
    dirname(require.resolve("vite/package.json")),
    "bin/vite.js",
  );
  args = [
    "build",
    "--config",
    "vite.worker.config.mts",
    "--mode",
    "worker-staging",
  ];
  // Diagnostic maps stay local; rebuild normally before deploying.
  if (mode === "profile-build") args.push("--sourcemap", "hidden");
} else {
  const output = "dist/server/wrangler.json";
  const wrangler = JSON.parse(readFileSync(output, "utf8"));
  if (
    wrangler.name !== "planets-web-link-host01-staging" ||
    wrangler.routes?.length ||
    !wrangler.workers_dev ||
    wrangler.observability?.enabled
  )
    throw new Error("Refusing non-isolated Worker configuration.");
  binary = resolve(
    dirname(require.resolve("wrangler/package.json")),
    "bin/wrangler.js",
  );
  if (mode === "preview")
    args = [
      "dev",
      "--config",
      output,
      "--local",
      "--port",
      "8796",
      "--log-level",
      "error",
    ];
  else if (mode === "dry-run")
    args = ["deploy", "--config", output, "--dry-run"];
  else if (mode === "deploy") {
    if (
      readdirSync("dist/client", { recursive: true }).some((path) =>
        path.endsWith(".map"),
      )
    )
      throw new Error(
        "Rebuild without diagnostic source maps before deployment.",
      );
    args = ["deploy", "--config", output];
  } else
    throw new Error(
      "Expected build, profile-build, preview, dry-run or deploy.",
    );
}
const result = spawnSync(process.execPath, [binary, ...args], {
  stdio: "inherit",
  env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
});
if (result.error) throw result.error;
process.exit(result.status ?? 1);
