import { spawnSync } from "node:child_process";
import {
  assertSafeLocalDemoTarget,
  seedLocalDemoWorld,
  demoReadyMessage,
} from "./lib/demo-world.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const status = readLocalSupabaseStatus(repositoryRoot);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
// Refuse unknown/non-loopback targets before the destructive CLI invocation.
assertSafeLocalDemoTarget({ ...status, mailpitUrl, environment: "local" });
const reset = spawnSync("supabase", ["db", "reset", "--local"], {
  cwd: repositoryRoot,
  stdio: "inherit",
  shell: process.platform === "win32", // npm supplies the Windows .cmd shim; arguments above are fixed.
});
if (reset.error || reset.status !== 0)
  throw new Error("Disposable local demo reset failed.");
await seedLocalDemoWorld({
  repositoryRoot,
  status: readLocalSupabaseStatus(repositoryRoot),
  mailpitUrl,
});
console.log(demoReadyMessage());
