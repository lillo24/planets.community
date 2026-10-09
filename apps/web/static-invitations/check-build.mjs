import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
const require = createRequire(import.meta.url);
// CI build-only public settings. This is never a deployable staging artifact.
const result = spawnSync(
  process.execPath,
  [
    resolve(dirname(require.resolve("vite/package.json")), "bin/vite.js"),
    "build",
    "--config",
    "static-invitations/vite.config.mts",
    "--mode",
    "trial-local",
  ],
  {
    cwd: fileURLToPath(new URL("../", import.meta.url)),
    stdio: "inherit",
    windowsHide: true,
    env: {
      ...process.env,
      NEXT_PUBLIC_APP_ENV: "local",
      NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:59121",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
        "sb_publishable_build_only_synthetic",
    },
  },
);
if (result.error) throw result.error;
process.exit(result.status ?? 1);
