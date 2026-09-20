import { verifyLocalDemoWorld } from "./lib/demo-world.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const status = readLocalSupabaseStatus(repositoryRoot);

await verifyLocalDemoWorld({
  repositoryRoot,
  status,
  mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
});

console.log(
  "Confirmed the local demo personas, connected project states, Messages, projected notifications, authorized chat, public listings, RLS denial, and restricted exact-location boundary.",
);
