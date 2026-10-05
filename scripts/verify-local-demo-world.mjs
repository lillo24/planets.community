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
  "Confirmed local demo photo states, invitation generations/provenance/episodes, superseded offers, zero commitments, Messages, notifications, authorized chat, discovery and private RLS/location boundaries without repairing domain state.",
);
