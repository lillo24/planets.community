import assert from "node:assert/strict";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { assertSafeLocalDemoTarget } from "./lib/demo-world.mjs";

const status = readLocalSupabaseStatus(process.cwd());
assertSafeLocalDemoTarget({
  ...status,
  mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
});
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
const worker = createClient(status.apiUrl, status.serviceRoleKey, {
  auth: { persistSession: false },
});
async function drain() {
  for (let batch = 0; batch < 20; batch++) {
    const { data, error } = await worker.rpc(
      "process_notification_outbox_batch",
      { p_limit: 100 },
    );
    if (error || !Number.isInteger(data?.[0]?.processed_count))
      throw new Error(
        `Global notification worker failed (${error?.code ?? "invalid_result"}).`,
      );
    if (!data[0].processed_count) return;
  }
  throw new Error("Global notification worker exceeded 20 batches.");
}
try {
  const delegated =
    await sql`select event.id, event.payload->>'actor_profile_id' as actor
    from private.outbox_events event join public.projects project on project.id::text=event.payload->>'project_id'
    where event.event_type='project.join_request_rejected' and event.payload->>'actor_profile_id' <> project.creator_profile_id::text`;
  assert.ok(
    delegated.length > 0,
    "Run blocking/domain producers before the global worker regression.",
  );
  // No outside-row locks, event deletion or fabricated receipts. This is the
  // same unrestricted authorized worker that failed on the isolated TW05 base.
  await drain();
  for (const event of delegated) {
    const [receipt] =
      await sql`select processed_at from private.outbox_consumer_receipts where outbox_event_id=${event.id} and consumer_key='notifications.v1'`;
    assert.ok(
      receipt,
      "Delegated rejection has a real canonical worker receipt.",
    );
    const rows =
      await sql`select actor_profile_id from public.notifications where source_outbox_event_id=${event.id}`;
    assert.ok(
      rows.length > 0,
      "Delegated rejection projects an in-app notification.",
    );
    assert.ok(rows.every((row) => row.actor_profile_id === event.actor));
  }
  const before =
    await sql`select count(*)::int as count from public.notifications`;
  await drain();
  assert.deepEqual(
    await sql`select count(*)::int as count from public.notifications`,
    before,
  );
  console.log(
    `Global worker passed: ${delegated.length} delegated rejection events projected with canonical attribution; repeated drain is idempotent. Acceptance/removal/forged actor/grants are covered by 111 pgTAP.`,
  );
} finally {
  await sql.end({ timeout: 5 });
}
