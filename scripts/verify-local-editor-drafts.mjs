import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
  if (
    !url ||
    !["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname)
  ) {
    throw new Error(
      "DRAFT01 verifier requires loopback API/database/mailbox URLs.",
    );
  }
}
const sql = postgres(databaseUrl, { max: 5, onnotice: () => {} });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
let checks = 0;
function equal(actual, expected, label) {
  assert.deepEqual(actual, expected, label);
  checks++;
}
async function rpc(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error)
    throw new Error(
      "DRAFT01 " + name + ": " + error.code + " " + error.message,
    );
  return data;
}
async function denied(client, name, args, code) {
  const { error } = await client.rpc(name, args);
  equal(error?.code, code, name + " fails explicitly");
}
const [owner, peer, incomplete, staff] = await Promise.all(
  ["owner", "peer", "incomplete", "staff"].map((role) =>
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "draft01-" + role + "@planets.invalid",
      verifierName: "DRAFT01 " + role,
    }),
  ),
);
function content(actor, title = "DRAFT01 sparse draft") {
  return {
    p_expected_creator_profile_id: actor.id,
    p_title: title,
    p_summary: "",
    p_description: "",
    p_starts_at: null,
    p_ends_at: null,
    p_event_timezone: "UTC",
    p_country_code: "",
    p_locality: "",
    p_administrative_area: "",
    p_public_location_label: "",
    p_exact_meeting_text: "",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_registration_capacity: null,
    p_count_organizers_toward_capacity: false,
  };
}
const create = (actor, args) =>
  rpc(actor.client, "create_editor_proposal_draft", args);
const recoverArgs = (actor, request) => ({
  p_expected_creator_profile_id: actor.id,
  p_client_request_id: request,
});
async function totals(db = sql) {
  return (
    await db`select
    (select count(*)::int from public.proposals) as proposals,
    (select count(*)::int from public.projects) as projects,
    (select count(*)::int from public.proposal_skills) as skills,
    (select count(*)::int from private.proposal_draft_creations) as receipts,
    (select count(*)::int from private.proposal_templates) as templates,
    (select count(*)::int from private.audit_events) as audits,
    (select count(*)::int from private.outbox_events) as outbox,
    (select count(*)::int from public.notifications) as notifications`
  )[0];
}
async function txCreate(tx, args) {
  return (
    await tx`select public.create_editor_proposal_draft(
    ${args.p_expected_creator_profile_id}::uuid, ${args.p_client_request_id}::uuid,
    ${args.p_title}, ${args.p_summary}, ${args.p_description}, ${args.p_starts_at}::timestamptz, ${args.p_ends_at}::timestamptz,
    ${args.p_event_timezone}, ${args.p_country_code}, ${args.p_locality}, ${args.p_administrative_area},
    ${args.p_public_location_label}, ${args.p_exact_meeting_text}, ${args.p_exact_location_visibility},
    ${args.p_skill_ids}::uuid[], ${args.p_skill_importances}::text[], ${args.p_registration_capacity}::integer,
    ${args.p_count_organizers_toward_capacity}::boolean) as id`
  )[0].id;
}
async function waitBlocked(pid) {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
    const [{ blocked }] =
      await sql`select exists(select 1 from pg_stat_activity where ${pid}=any(pg_blocking_pids(pid))) as blocked`;
    if (blocked) {
      checks++;
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(
    "DRAFT01 recovery never reached the controlled creation lock.",
  );
}
try {
  for (const actor of [owner, peer, incomplete, staff]) {
    await sql`insert into public.profiles(id,display_name) values(${actor.id}::uuid,${actor === incomplete ? null : "DRAFT01 synthetic"})
      on conflict(id) do update set display_name=excluded.display_name`;
  }
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at)
    values(${staff.id}::uuid,'moderator',true,null) on conflict(profile_id) do update set is_active=true,deactivated_at=null`;
  await sql`delete from public.profile_photos where profile_id=${owner.id}::uuid`;
  const args = { ...content(owner), p_client_request_id: randomUUID() };
  const before = await totals();
  const ids = await Promise.all([
    create(owner, args),
    create(owner, args),
    create(owner, args),
  ]);
  equal(
    new Set(ids).size,
    1,
    "concurrent duplicate deliveries create one private draft",
  );
  const id = ids[0];
  const after = await totals();
  equal(after.proposals - before.proposals, 1, "one parent");
  equal(after.projects - before.projects, 1, "one shared project");
  equal(after.receipts - before.receipts, 1, "one creation receipt");
  for (const field of ["templates", "audits", "outbox", "notifications"])
    equal(after[field], before[field], "draft creates no " + field);
  equal(
    await rpc(
      owner.client,
      "recover_editor_proposal_draft",
      recoverArgs(owner, args.p_client_request_id),
    ),
    id,
    "narrow owner recovery",
  );
  equal(
    await rpc(
      peer.client,
      "recover_editor_proposal_draft",
      recoverArgs(peer, args.p_client_request_id),
    ),
    null,
    "peer cannot recover owner receipt",
  );
  equal(
    await rpc(
      staff.client,
      "recover_editor_proposal_draft",
      recoverArgs(staff, args.p_client_request_id),
    ),
    null,
    "no staff bypass",
  );
  await denied(
    peer.client,
    "recover_editor_proposal_draft",
    recoverArgs(owner, args.p_client_request_id),
    "42501",
  );
  await denied(
    anonymous,
    "recover_editor_proposal_draft",
    recoverArgs(owner, args.p_client_request_id),
    "42501",
  );
  await denied(anonymous, "create_editor_proposal_draft", args, "42501");
  await denied(peer.client, "create_editor_proposal_draft", args, "42501");
  await denied(
    owner.client,
    "create_editor_proposal_draft",
    { ...args, p_title: "Incompatible" },
    "22023",
  );
  for (const change of [
    { p_title: "x" },
    { p_country_code: "I" },
    { p_event_timezone: "x".repeat(101) },
    { p_registration_capacity: 0 },
    { p_count_organizers_toward_capacity: null },
    { p_client_request_id: null },
    { p_starts_at: "2027-01-02T00:00:00Z", p_ends_at: "2027-01-01T00:00:00Z" },
  ]) {
    await denied(
      owner.client,
      "create_editor_proposal_draft",
      { ...args, p_client_request_id: randomUUID(), ...change },
      "22023",
    );
  }
  await denied(
    incomplete.client,
    "create_editor_proposal_draft",
    { ...content(incomplete), p_client_request_id: randomUUID() },
    "55000",
  );
  equal(await totals(), after, "all denied creates leave zero orphan effects");
  await rpc(owner.client, "update_own_proposal", {
    ...content(owner, "Later owner edit"),
    p_proposal_id: id,
  });
  await sql`update public.profiles set display_name=null where id=${owner.id}::uuid`;
  equal(
    await create(owner, args),
    id,
    "exact recovery does not need new complete-profile creation",
  );
  equal(
    (
      await rpc(owner.client, "get_own_proposal", {
        ...recoverArgs(owner, args.p_client_request_id),
        p_client_request_id: undefined,
        p_proposal_id: id,
      })
    )[0].title,
    "Later owner edit",
    "retry never overwrites later content",
  );
  await sql`update public.profiles set display_name='DRAFT01 synthetic owner' where id=${owner.id}::uuid`;
  const fresh = await create(owner, {
    ...args,
    p_client_request_id: randomUUID(),
  });
  equal(fresh !== id, true, "explicit fresh Create creates another draft");
  equal(
    (await create(peer, {
      ...args,
      p_expected_creator_profile_id: peer.id,
    })) !== id,
    true,
    "same opaque key another actor is separate",
  );
  // Observe the real lock dependency before releasing the uncommitted create.
  // A recovery read must not report absence while acceptance is still in flight.
  const heldArgs = { ...args, p_client_request_id: randomUUID() };
  let recovery;
  let heldId;
  await sql.begin(async (tx) => {
    const [{ pid }] = await tx`select pg_backend_pid() as pid`;
    await tx`select set_config('request.jwt.claim.sub',${owner.id},true)`;
    await tx.unsafe("set local role authenticated");
    heldId = await txCreate(tx, heldArgs);
    recovery = rpc(
      owner.client,
      "recover_editor_proposal_draft",
      recoverArgs(owner, heldArgs.p_client_request_id),
    ).then(
      (data) => ({ data }),
      (error) => ({ error }),
    );
    await waitBlocked(pid);
  });
  const recovered = await recovery;
  if (recovered.error) throw recovered.error;
  equal(
    recovered.data,
    heldId,
    "recovery waits for accepted creation instead of false absence",
  );
  const [{ read, write, rls }] = await sql`select
    has_table_privilege('authenticated','private.proposal_draft_creations','select') as read,
    has_table_privilege('service_role','private.proposal_draft_creations','insert') as write,
    relrowsecurity as rls from pg_class where oid='private.proposal_draft_creations'::regclass`;
  equal(
    [read, write, rls],
    [false, false, true],
    "raw receipts are private and RLS enabled",
  );
  // Inject failure after the real canonical create, proving atomic receipt rollback.
  await sql.begin(async (tx) => {
    const prior = await totals(tx);
    await tx.unsafe(
      "create function pg_temp.draft01_fail() returns trigger language plpgsql as $$ begin raise exception 'DRAFT01 injected receipt failure' using errcode='P0001'; end; $$",
    );
    await tx.unsafe(
      "create trigger draft01_fail before insert on private.proposal_draft_creations for each row execute function pg_temp.draft01_fail()",
    );
    let code;
    try {
      await tx.savepoint(async (nested) => {
        await nested`select set_config('request.jwt.claim.sub',${owner.id},true)`;
        await nested.unsafe("set local role authenticated");
        await txCreate(nested, { ...args, p_client_request_id: randomUUID() });
      });
    } catch (error) {
      code = error.code;
    }
    equal(code, "P0001", "receipt boundary actually reached");
    equal(
      await totals(tx),
      prior,
      "canonical parent/project and receipt roll back together",
    );
    await tx.unsafe(
      "drop trigger draft01_fail on private.proposal_draft_creations",
    );
    await tx.unsafe("drop function pg_temp.draft01_fail()");
  });
  // Deliberate publication retains photo/full-content gates and accepted creation.
  await denied(
    owner.client,
    "publish_proposal",
    { p_expected_creator_profile_id: owner.id, p_proposal_id: id },
    "22023",
  );
  const full = {
    ...content(owner, "DRAFT01 published source"),
    p_summary: "Synthetic summary",
    p_description: "Synthetic description",
    p_starts_at: new Date(Date.now() + 172800000).toISOString(),
    p_ends_at: new Date(Date.now() + 176400000).toISOString(),
    p_country_code: "IT",
    p_locality: "Trento",
    p_public_location_label: "Synthetic public place",
    p_exact_meeting_text: "Synthetic private meeting",
    p_registration_capacity: 5,
  };
  await rpc(owner.client, "update_own_proposal", {
    ...full,
    p_proposal_id: id,
  });
  await denied(
    owner.client,
    "publish_proposal",
    { p_expected_creator_profile_id: owner.id, p_proposal_id: id },
    "PT422",
  );
  await ensureLocalProfilePhoto(owner);
  await rpc(owner.client, "publish_proposal", {
    p_expected_creator_profile_id: owner.id,
    p_proposal_id: id,
  });
  const publishedBefore = await totals();
  equal(
    await create(owner, args),
    id,
    "retry after publication keeps accepted ID",
  );
  equal(
    await totals(),
    publishedBefore,
    "retry after publication has no writes",
  );
  equal(
    (
      await sql`select lifecycle_state from public.proposals where id=${id}::uuid`
    )[0].lifecycle_state,
    "published",
    "never reopens published draft",
  );
  // A real TW03 draft updates normally after source removal, preserving provenance/needs.
  await rpc(owner.client, "create_project_resource_need", {
    p_expected_creator_profile_id: owner.id,
    p_project_id: id,
    p_title: "DRAFT01 synthetic need",
    p_details: "",
  });
  await sql`update public.proposals set starts_at='2020-01-01T00:00:00Z',ends_at='2020-01-01T01:00:00Z' where id=${id}::uuid`;
  const template = (
    await sql`select id from private.proposal_templates where source_proposal_id=${id}::uuid`
  )[0].id;
  const preview = (
    await rpc(anonymous, "get_public_proposal_template", {
      p_template_id: template,
    })
  )[0];
  const [application] = await rpc(
    peer.client,
    "create_proposal_draft_from_template",
    {
      p_expected_creator_profile_id: peer.id,
      p_template_id: template,
      p_content_version: preview.content_version,
      p_client_request_id: randomUUID(),
      p_prefill_capacity: true,
    },
  );
  const receiptBefore = Array.from(
    await sql`select * from private.proposal_template_applications where proposal_id=${application.proposal_id}::uuid`,
  );
  const needsBefore = Array.from(
    await sql`select id from public.project_resource_needs where project_id=${application.proposal_id}::uuid order by id`,
  );
  const [report] = await rpc(peer.client, "submit_moderation_report", {
    p_expected_reporter_profile_id: peer.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "DRAFT01 synthetic removal review",
    p_target_kind: "proposal_template",
    p_target_id: template,
    p_context_kind: null,
    p_context_id: null,
  });
  await rpc(staff.client, "remove_moderation_case_template", {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report.case_id,
    p_template_id: template,
    p_client_request_id: randomUUID(),
    p_reviewed_content_version: preview.content_version,
    p_reason: "DRAFT01 synthetic reviewed removal",
  });
  await rpc(peer.client, "update_own_proposal", {
    ...content(peer, "Saved after template removal"),
    p_proposal_id: application.proposal_id,
  });
  equal(
    (
      await rpc(peer.client, "get_own_proposal", {
        p_expected_creator_profile_id: peer.id,
        p_proposal_id: application.proposal_id,
      })
    )[0].title,
    "Saved after template removal",
    "ordinary derived draft remains editable/reopenable",
  );
  equal(
    Array.from(
      await sql`select * from private.proposal_template_applications where proposal_id=${application.proposal_id}::uuid`,
    ),
    receiptBefore,
    "TW03 receipt immutable",
  );
  equal(
    Array.from(
      await sql`select id from public.project_resource_needs where project_id=${application.proposal_id}::uuid order by id`,
    ),
    needsBefore,
    "copied need IDs unchanged",
  );
  console.log(
    "DRAFT01 authenticated editor draft verifier passed: " +
      checks +
      " assertions, including atomic rollback and removed-template reopening.",
  );
} finally {
  await sql.end({ timeout: 2 });
}
