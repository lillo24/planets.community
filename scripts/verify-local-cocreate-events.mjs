import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { openCocreateLocalBackend } from "./lib/cocreate-local-backend.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
const { sql, status } = openCocreateLocalBackend();
// Keep ACTAPI01's genuine pipeline guard; never impersonate CI to reuse a
// retained default-port development stack.
if (
  process.env.CI !== "true" &&
  (process.env.PLANETS_DISPOSABLE_QA !== "1" ||
    new URL(status.apiUrl).port === "54321")
) {
  await sql.end();
  throw Error(
    "Event handoff verification requires explicit disposable QA on a non-default task-owned API port.",
  );
}
const run = randomUUID().slice(0, 8),
  sourceId = "cocreate-event-qa-" + run;
const options = { auth: { persistSession: false, autoRefreshToken: false } },
  service = createClient(status.apiUrl, status.serviceRoleKey, options),
  guest = createClient(status.apiUrl, status.publishableKey, options);
let checks = 0,
  created = false;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
async function rpc(client, name, args) {
  const r = await client.rpc(name, args);
  equal(r.error?.code ?? null, null, name + " succeeds");
  return r.data;
}
async function denied(client, name, args, code = "42501") {
  const r = await client.rpc(name, args);
  equal(r.error?.code, code, name + " denies");
}
const record = () => ({
  upstream_id: "synthetic",
  title: "Synthetic public event",
  description: "Synthetic provider description not copied",
  canonical_url: "https://calendar.example.org/events/synthetic",
  category: "culture",
  source_categories: ["Synthetic"],
  city: "Trento",
  address: "Public venue address not copied",
  status: "scheduled",
  publishable: true,
  occurrences: [
    {
      kind: "timed",
      start: new Date(Date.now() + 86400000).toISOString(),
      end: new Date(Date.now() + 90000000).toISOString(),
      timezone: "Europe/Rome",
    },
  ],
});
async function publishRecord(entry) {
  const claimed = await rpc(service, "begin_external_activity_import", {
    p_source_id: sourceId,
  });
  return rpc(service, "finish_external_activity_import", {
    p_run_id: claimed.run_id,
    p_state: "success",
    p_records: [entry],
    p_fetched: 1,
  });
}
try {
  equal(
    (await sql`select enabled from private.cocreate_settings`)[0].enabled,
    false,
    "Starts with co-creation OFF",
  );
  equal(
    (
      await sql`select count(*)::int n from private.external_activity_sources where enabled`
    )[0].n,
    0,
    "No existing configured source is changed",
  );
  await sql`insert into private.external_activity_sources(source_id,display_name,official_origin,enabled,rights_confirmed,attribution,license_url)
  values(${sourceId},'Synthetic co-creation QA calendar','https://calendar.example.org',true,true,'Synthetic local fixture only','https://calendar.example.org/license')`;
  created = true;
  const item = record();
  await publishRecord(item);
  const [snapshot] =
    await sql`select activity_id,to_jsonb(a) body from private.external_activities a where source_id=${sourceId}`;
  const activity = snapshot.activity_id;
  await denied(guest, "get_cocreate_event_context", {
    p_activity_id: activity,
  });
  await sql`update private.cocreate_settings set enabled=true`;
  equal(
    (
      await rpc(guest, "get_cocreate_event_context", {
        p_activity_id: activity,
      })
    ).id,
    activity,
    "Public context uses the actual catalogue identity",
  );
  await denied(guest, "create_cocreate_post_from_event", {
    p_expected_profile_id: randomUUID(),
    p_command_id: randomUUID(),
    p_activity_id: activity,
    p_content: {},
  });
  const user = await signInLocalOtpUser({
    ...status,
    mailpitUrl: "http://127.0.0.1:54324",
    email: "cocreate-event-" + run + "@planets.invalid",
    verifierName: "cocreate-events",
  });
  await sql`insert into public.profiles(id,display_name) values(${user.id}::uuid,'Synthetic event author')`;
  await rpc(user.client, "accept_policy_bundle", {
    p_expected_account_id: user.id,
    p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  await denied(user.client, "begin_external_activity_import", {
    p_source_id: sourceId,
  });
  const [nativeBefore] = await sql`select count(*)::int n from public.projects`;
  const args = {
    p_expected_profile_id: user.id,
    p_command_id: randomUUID(),
    p_activity_id: activity,
    p_content: {
      title: "My reviewed public intent",
      body: "My edited public text",
      locality: "Trento",
    },
  };
  const results = await Promise.all([
    rpc(user.client, "create_cocreate_post_from_event", args),
    rpc(user.client, "create_cocreate_post_from_event", args),
  ]);
  equal(results[0], results[1], "Concurrent exact handoff creates one draft");
  equal(results[0].state, "draft", "No automatic publication");
  const post = results[0].post_id;
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_post_events where post_id=${post}::uuid`
    )[0].n,
    1,
    "One source reference",
  );
  equal(
    await rpc(guest, "get_cocreate_post_event", { p_post_id: post }),
    null,
    "Private draft reference is not public",
  );
  await denied(
    user.client,
    "create_cocreate_post_from_event",
    { ...args, p_content: { ...args.p_content, title: "Changed intent" } },
    "22023",
  );
  await rpc(user.client, "mutate_cocreate_post", {
    p_expected_profile_id: user.id,
    p_command_id: randomUUID(),
    p_operation: "publish",
    p_post_id: post,
    p_expected_version: 1,
  });
  const reference = await rpc(guest, "get_cocreate_post_event", {
    p_post_id: post,
  });
  equal(reference.post_id, post, "Exact post reference binding");
  equal(reference.event.activity_id, activity, "Canonical event destination");
  equal(
    Object.keys(reference.event).sort(),
    [
      "activity_id",
      "attribution",
      "canonical_url",
      "license_url",
      "source_name",
      "stale",
      "status",
      "title",
    ],
    "Minimal public reference excludes addresses and descriptions",
  );
  equal(
    (
      await sql`select to_jsonb(a) body from private.external_activities a where activity_id=${activity}::uuid`
    )[0].body,
    snapshot.body,
    "Co-creation never mutates the imported event",
  );
  equal(
    (await sql`select count(*)::int n from public.projects`)[0].n,
    nativeBefore.n,
    "No native Project/Event conversion",
  );
  equal(
    (
      await sql`select count(*)::int n from private.cocreate_room_episodes where actor_id=${user.id}::uuid`
    )[0].n,
    0,
    "No automatic hub/group enrollment",
  );
  await publishRecord({ ...item, status: "cancelled" });
  equal(
    await rpc(guest, "get_cocreate_event_context", { p_activity_id: activity }),
    null,
    "Cancelled source is unavailable for a new handoff",
  );
  await denied(user.client, "create_cocreate_post_from_event", {
    ...args,
    p_command_id: randomUUID(),
  });
  equal(
    (await rpc(guest, "get_cocreate_post_event", { p_post_id: post })).event
      .status,
    "cancelled",
    "Existing reference truthfully shows cancellation",
  );
  await sql`update private.external_activity_sources set enabled=false where source_id=${sourceId}`;
  equal(
    await rpc(guest, "get_cocreate_post_event", { p_post_id: post }),
    { post_id: post, state: "unavailable" },
    "Disabled source has no functioning fabricated link",
  );
  equal(
    await rpc(user.client, "create_cocreate_post_from_event", args),
    results[0],
    "Source withdrawal preserves an already-created draft receipt",
  );
  await sql`update private.cocreate_settings set enabled=false`;
  await denied(guest, "get_cocreate_post_event", { p_post_id: post });
  console.log(
    "Co-creation event handoff verification passed: " +
      checks +
      " assertions; activation OFF; synthetic licensed fixture only, no official feed fetched.",
  );
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  if (created) {
    await sql`delete from private.external_activities where source_id=${sourceId}`;
    await sql`delete from private.external_activity_runs where source_id=${sourceId}`;
    await sql`delete from private.external_activity_sources where source_id=${sourceId} and display_name='Synthetic co-creation QA calendar'`;
  }
  await sql.end();
}
