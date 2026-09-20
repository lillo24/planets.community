import { demoReadyMessage, seedLocalDemoWorld } from "./lib/demo-world.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const status = readLocalSupabaseStatus(repositoryRoot);

await seedLocalDemoWorld({
  repositoryRoot,
  status,
  mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
});

console.log(demoReadyMessage());
