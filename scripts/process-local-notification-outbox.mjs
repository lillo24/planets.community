import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { apiUrl, serviceRoleKey } = readLocalSupabaseStatus(process.cwd());

if (!serviceRoleKey) {
  throw new Error(
    "Local Supabase status is missing its service-role key. Update the project-scoped CLI if the status format has changed.",
  );
}

const localServiceClient = createClient(apiUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

let processed = 0;
let created = 0;
let suppressed = 0;
let drained = false;

for (let batch = 0; batch < 20; batch += 1) {
  const { data, error } = await localServiceClient.rpc(
    "process_notification_outbox_batch",
    { p_limit: 100 },
  );
  const result = data?.[0];
  if (
    error ||
    !result ||
    !Number.isInteger(result.processed_count) ||
    !Number.isInteger(result.notifications_created) ||
    !Number.isInteger(result.notifications_suppressed)
  ) {
    const code =
      typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
        ? error.code
        : "unknown";
    throw new Error(
      `Failed to process the local notification outbox (code ${code}).`,
    );
  }

  processed += result.processed_count;
  created += result.notifications_created;
  suppressed += result.notifications_suppressed;
  if (result.processed_count === 0) {
    drained = true;
    break;
  }
}

if (!drained) {
  throw new Error(
    "The local notification backlog did not drain within 20 projector batches.",
  );
}

console.log(
  `Local notification projection complete: ${processed} processed, ${created} created, ${suppressed} suppressed. Refresh the mobile inbox.`,
);
