import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { classifyAccountRpc } from "./lib/account-suspension-audit.mjs";

const { databaseUrl, apiUrl } = readLocalSupabaseStatus(process.cwd());
if (
  !databaseUrl ||
  !/^https?:\/\/(127\.0\.0\.1|localhost)(:|\/)/u.test(apiUrl)
) {
  throw new Error(
    "The suspension audit requires the project-scoped local stack.",
  );
}
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
try {
  const functions = await sql`select n.nspname as schema, p.proname as name,
    p.oid::regprocedure::text as signature, p.prosrc as source,
    has_function_privilege('authenticated', p.oid, 'execute') as auth,
    has_function_privilege('anon', p.oid, 'execute') as anon
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.prokind='f'`;
  const inventory = functions
    .filter((entry) => entry.schema === "public")
    .map((entry) => ({
      signature: entry.signature,
      ...classifyAccountRpc(functions, entry),
    }))
    .sort((a, b) => a.signature.localeCompare(b.signature, "en"));
  // SQL call-chain detection is heuristic. The explicit signature inventory and
  // real-auth tests are separate safeguards; new RPCs require human classification.
  if (process.argv.includes("--inventory"))
    console.log(JSON.stringify(inventory, null, 2));
  else {
    const committed = JSON.parse(
      await readFile(
        new URL(
          "../docs/development/account-suspension-rpc-inventory.json",
          import.meta.url,
        ),
        "utf8",
      ),
    );
    assert.deepEqual(
      inventory,
      committed,
      "RPC/grant/call-chain inventory changed: review and regenerate explicitly",
    );
    const directBroadcasters = functions.filter((entry) =>
      /\brealtime\.send\s*\(/u.test(entry.source),
    );
    assert.deepEqual(
      directBroadcasters.map((entry) => `${entry.schema}.${entry.name}`),
      ["private.send_account_active_realtime"],
      "Private broadcasts must use suspended-recipient filtering",
    );
    console.log(
      `Account suspension RPC audit passed: ${inventory.length} public signatures; one explicit own-status exception; canonical private broadcasters filtered.`,
    );
  }
} finally {
  await sql.end({ timeout: 5 });
}
