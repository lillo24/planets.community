import { withLocalDemoWorldLock } from "./lib/demo-world.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { verifyDemoInvitations } from "./verify-local-demo-idempotency.mjs";
import { verifyWorkshopDemo } from "./verify-local-workshop-demo.mjs";

const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
const started = performance.now();
await withLocalDemoWorldLock(status, mailpitUrl, async (coordinationSql) => {
  const options = {
    repositoryRoot: process.cwd(),
    status,
    mailpitUrl,
    coordinationSql,
    sessionPool: new Map(),
  };
  // Invitation interruption/recovery precedes Workshop construction, so both
  // committed-response-loss proofs run without rebuilding the combined world.
  await verifyDemoInvitations(options);
  await verifyWorkshopDemo(options);
});
console.log(
  `Combined demo proofs passed (${((performance.now() - started) / 1000).toFixed(1)}s).`,
);
