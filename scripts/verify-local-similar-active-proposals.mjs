import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { readFile } from "node:fs/promises";

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
      "SIM01 verifier requires loopback API/database/mailbox URLs.",
    );
  }
}
const sql = postgres(databaseUrl, { max: 3, onnotice: () => {} });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const rpcName = "list_similar_active_proposals";
const allowedFields = [
  "proposal_id",
  "cover_object_path",
  "title",
  "summary",
  "starts_at",
  "ends_at",
  "event_timezone",
  "country_code",
  "locality",
  "administrative_area",
  "public_location_label",
  "derived_status",
  "availability",
  "title_evidence",
  "shared_skill_ids",
  "location_relation",
].sort();
let checks = 0;
function equal(actual, expected, label) {
  // No raw submitted idea text, tokens or RPC arguments in failure diagnostics.
  assert.ok(isDeepStrictEqual(actual, expected), label);
  checks++;
}
async function rpc(user, name, args) {
  const { data, error } = await user.client.rpc(name, args);
  if (error) throw new Error("SIM01 " + name + " failed: " + error.code);
  return data;
}
async function denied(client, name, args, code) {
  const { error } = await client.rpc(name, args);
  equal(error?.code, code, name + " rejects invalid/auth input");
}
const actors = await Promise.all(
  ["owner", "reader", "peer", "delegate"].map((role) =>
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "sim01-" + role + "@planets.invalid",
      verifierName: "SIM01 " + role,
    }),
  ),
);
const [owner, reader, peer, delegate] = actors;
const fixtures = [];
const content = new Map();
const rollbackScale = new Error("SIM01 synthetic scale rollback");
const skillRows =
  await sql`select id,slug from public.skills order by id limit 3`;
const [skill, otherSkill] = skillRows.map((row) => row.id);
function input(title, overrides = {}) {
  return { p_expected_profile_id: reader.id, p_title: title, ...overrides };
}
async function lookup(title, overrides = {}, actor = reader) {
  const args = input(title, { p_expected_profile_id: actor.id, ...overrides });
  const rows = await rpc(actor, rpcName, args);
  equal(
    Array.isArray(rows) && rows.length <= (args.p_limit ?? 5),
    true,
    "bounded result",
  );
  for (const row of rows) {
    equal(
      Object.keys(row).sort(),
      allowedFields,
      "exact HTTP payload allow-list",
    );
    equal(row.derived_status, "upcoming", "only Upcoming");
    equal(
      ["available", "full", "capacity_unknown"].includes(row.availability),
      true,
      "canonical capacity enum",
    );
    equal(
      ["title_topic", "multiple_title_terms"].includes(row.title_evidence),
      true,
      "stable title reason",
    );
  }
  return rows;
}
const ids = (rows) => rows.map((row) => row.proposal_id);
async function create(title, changes = {}, publish = true) {
  const args = {
    p_expected_creator_profile_id: owner.id,
    p_title: title,
    p_summary: "SIM01 synthetic public preview",
    p_description: "PRIVATE_DESCRIPTION",
    p_starts_at: "2098-03-01T10:00:00Z",
    p_ends_at: "2098-03-01T12:00:00Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "TN",
    p_public_location_label: "Rough public area",
    p_exact_meeting_text: "MEETING_SECRET",
    p_exact_location_visibility: "public",
    p_skill_ids: [],
    p_skill_importances: [],
    p_registration_capacity: 4,
    p_count_organizers_toward_capacity: false,
    ...changes,
  };
  const id = await rpc(owner, "create_proposal_draft", args);
  fixtures.push(id);
  content.set(id, args);
  if (publish)
    await rpc(owner, "publish_proposal", {
      p_expected_creator_profile_id: owner.id,
      p_proposal_id: id,
    });
  return id;
}
async function edit(id, changes) {
  const args = { ...content.get(id), ...changes };
  await rpc(owner, "update_own_proposal", { ...args, p_proposal_id: id });
  content.set(id, args);
}
async function request(actor, id) {
  return rpc(actor, "request_to_join_project", {
    p_expected_requester_profile_id: actor.id,
    p_project_id: id,
    p_request_message: "PRIVATE_REQUEST_MESSAGE",
  });
}
async function accept(id) {
  return rpc(owner, "accept_project_join_request_as_manager", {
    p_expected_manager_profile_id: owner.id,
    p_request_id: id,
  });
}
async function availability(id) {
  const rows = await lookup(content.get(id).p_title, { p_limit: 10 });
  return rows.find((row) => row.proposal_id === id)?.availability;
}
async function totals() {
  return (
    await sql`select
    (select count(*)::int from public.proposals) as proposals,
    (select count(*)::int from public.projects) as projects,
    (select count(*)::int from public.proposal_skills) as skills,
    (select count(*)::int from public.project_join_requests) as requests,
    (select count(*)::int from public.project_memberships) as memberships,
    (select count(*)::int from private.proposal_templates) as templates,
    (select count(*)::int from private.proposal_template_applications) as applications,
    (select count(*)::int from private.proposal_draft_creations) as editor_receipts,
    (select count(*)::int from private.moderation_reports) as reports,
    (select count(*)::int from private.audit_events) as audits,
    (select count(*)::int from private.outbox_events) as outbox,
    (select count(*)::int from public.notifications) as notifications,
    (select md5(coalesce(jsonb_agg(to_jsonb(p) order by p.id)::text,'')) from public.proposals p) as source_digest,
    (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.id)::text,'')) from private.proposal_templates t) as template_digest`
  )[0];
}
try {
  for (const actor of actors) {
    const { data, error } = await actor.client
      .from("profiles")
      .select("id")
      .eq("id", actor.id)
      .maybeSingle();
    if (error)
      throw new Error("SIM01 profile read fixture failed: " + error.code);
    if (!data) {
      const { error: insertError } = await actor.client
        .from("profiles")
        .insert({ id: actor.id });
      if (insertError)
        throw new Error("SIM01 profile fixture failed: " + insertError.code);
    }
    await rpc(actor, "update_own_profile", {
      p_expected_profile_id: actor.id,
      p_display_name: "SIM01 synthetic actor",
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
  }
  await Promise.all(
    [owner, peer, delegate].map((actor) => ensureLocalProfilePhoto(actor)),
  );
  await rpc(owner, "unblock_user", {
    p_expected_blocker_profile_id: owner.id,
    p_blocked_profile_id: peer.id,
  });
  equal(
    (
      await sql`select count(*)::int as n from public.profile_photos where profile_id=${reader.id}::uuid`
    )[0].n,
    0,
    "reader has no publication photo",
  );
  equal(
    (
      await rpc(reader, "list_own_proposals", {
        p_expected_creator_profile_id: reader.id,
      })
    ).length,
    0,
    "reader has no saved draft",
  );
  // Repeat-safe cleanup is restricted to these synthetic owner's old verifier sources.
  await sql`update public.projects set registration_capacity=4 where registration_capacity is null and id in (
    select id from public.proposals where creator_profile_id=${owner.id}::uuid
      and lifecycle_state='published' and summary='SIM01 synthetic public preview')`;
  await sql`update public.proposals set starts_at='2020-01-01',ends_at='2020-01-02'
    where creator_profile_id=${owner.id}::uuid and lifecycle_state='published'
      and summary='SIM01 synthetic public preview' and starts_at>statement_timestamp()`;

  await denied(anonymous, rpcName, input("murale"), "42501");
  await denied(
    reader.client,
    rpcName,
    input("murale", { p_expected_profile_id: owner.id }),
    "42501",
  );
  await denied(
    reader.client,
    rpcName,
    input("murale", { p_expected_profile_id: null }),
    "42501",
  );
  for (const overrides of [
    { p_title: null },
    { p_title: "a".repeat(101) },
    { p_skill_ids: [null] },
    { p_skill_ids: [randomUUID()] },
    { p_skill_ids: Array(51).fill(skill) },
    { p_skill_ids: [[skill]] },
    { p_country_code: "" },
    { p_country_code: "ITA" },
    { p_country_code: "1T" },
    { p_locality: "x".repeat(121) },
    { p_limit: null },
    { p_limit: 0 },
    { p_limit: 11 },
  ])
    await denied(reader.client, rpcName, input("", overrides), "22023");
  for (const title of [
    "",
    "   ",
    "!!! % _ & | :* 12345",
    "the and with community project",
    "Progetto comunitario a Trento",
  ]) {
    equal(
      (
        await lookup(title, {
          p_skill_ids: [skill],
          p_country_code: "IT",
          p_locality: "Trento",
        })
      ).length,
      0,
      "weak title never returns unfiltered catalog",
    );
  }
  equal(
    (
      await lookup("a".repeat(100), {
        p_skill_ids: [],
        p_locality: "x".repeat(120),
        p_limit: 10,
      })
    ).length,
    0,
    "maximum bounds accepted",
  );

  const repairPlain = await create("Repair Café del sabato");
  const repairSkilled = await create("Repair Café di quartiere", {
    p_skill_ids: [skill],
    p_skill_importances: ["useful"],
  });
  // Other domain verifiers may leave legitimate public repair activities.
  // Compare this controlled pair's relative order without deleting their rows.
  const repairPair = (rows) =>
    ids(rows).filter((id) => [repairPlain, repairSkilled].includes(id));
  equal(
    repairPair(await lookup("Repair Café di quartiere", { p_limit: 10 })),
    [repairPlain, repairSkilled].sort(),
    "equal title-only ties end in UUID",
  );
  equal(
    repairPair(
      await lookup("Repair Café di quartiere", {
        p_skill_ids: [skill],
        p_limit: 10,
      }),
    ),
    [repairSkilled, repairPlain],
    "shared skills refine plausible title",
  );
  equal(
    await lookup("Repair Café di quartiere", { p_skill_ids: [skill, skill] }),
    await lookup("Repair Café di quartiere", { p_skill_ids: [skill] }),
    "repeated skills do not inflate rank/reasons",
  );
  equal(
    await lookup("repair", { p_skill_ids: Array(50).fill(skill) }),
    await lookup("repair", { p_skill_ids: [skill] }),
    "maximum skill list deduplicates without added weight",
  );
  equal(
    await lookup("repair repair REPAIR cafe di quartiere"),
    await lookup("repair cafe di quartiere"),
    "repeated words and generic padding do not inflate results",
  );
  equal(
    ids(await lookup("quartiere CAFÉ, REPAIR!")),
    ids(await lookup("repair cafe")),
    "word order, accents and punctuation normalize",
  );
  equal(
    ids(await lookup("repair ' % _ & | :*")),
    ids(await lookup("repair")),
    "user operators are literal/safe",
  );
  equal(
    ids(await lookup("repair quasarpadding")),
    ids(await lookup("repair")),
    "unmatched title padding cannot increase candidate evidence",
  );
  equal(ids(await lookup("riparazione")), [], "no synonym/translation claim");

  const local = await create("Murale comunitario", {
    p_starts_at: "2098-04-01T10:00:00Z",
    p_ends_at: "2098-04-01T12:00:00Z",
  });
  const far = await create("Murale comunitario", { p_locality: "Verona" });
  const unknown = await create("Murale comunitario");
  await sql`update public.projects set registration_capacity=null where id=${unknown}::uuid`;
  const full = await create("Murale comunitario", {
    p_registration_capacity: 1,
    p_count_organizers_toward_capacity: true,
  });
  const expectedOrder = [local, far, unknown, full];
  const geo = { p_country_code: " it ", p_locality: "  Trento  ", p_limit: 10 };
  equal(
    ids(await lookup("Murale comunitario", geo)),
    expectedOrder,
    "available local/far, unknown, Full order",
  );
  equal(
    (await lookup("murale", geo)).map((row) => row.availability),
    ["available", "available", "capacity_unknown", "full"],
    "capacity states remain distinct",
  );
  equal(
    await lookup("murale", geo),
    await lookup("murale", geo),
    "fixed snapshot deterministic",
  );
  equal(
    (await lookup("murale", geo))[0].location_relation,
    "same_locality",
    "rough locality reason",
  );
  equal(
    (await lookup("murale", { p_country_code: "FR", p_locality: "Trento" }))[0]
      .location_relation,
    "other",
    "different country is not nearby",
  );
  equal(
    (await lookup("murale"))[0].location_relation,
    "not_provided",
    "no geography still useful",
  );
  equal(
    ids(await lookup("murale", { ...geo, p_excluded_proposal_id: local })),
    [far, unknown, full],
    "current destination excluded",
  );
  equal(
    await lookup("murale", { ...geo, p_excluded_proposal_id: randomUUID() }),
    await lookup("murale", geo),
    "absent excluded ID is not probed",
  );
  equal(
    ids(await lookup("murale", geo, owner)),
    expectedOrder,
    "own Projects stay relevant",
  );

  const garden = await create("Aiuola condivisa", {
    p_skill_ids: [skill],
    p_skill_importances: ["useful"],
  });
  const unrelated = await create("Costruire una libreria", {
    p_skill_ids: [skill],
    p_skill_importances: ["useful"],
  });
  await create("Cena del quartiere");
  await create("Concerto comunitario");
  equal(
    ids(
      await lookup("Aiuola condivisa", {
        p_skill_ids: [skill],
        p_locality: "Trento",
      }),
    ),
    [garden],
    "shared broad skill/locality cannot admit woodworking/dinner/concert",
  );
  equal(
    ids(await lookup("aiuola", { p_skill_ids: [otherSkill] })),
    [garden],
    "different skills preserve strong title topic",
  );
  equal(
    ids(await lookup("comunitario", { p_skill_ids: [skill] })),
    [],
    "generic common token cannot admit",
  );
  const english = await create("Community garden at the weekend");
  equal(
    ids(await lookup("garden community")),
    [english],
    "useful English title-only matching",
  );
  equal(ids(await lookup("gardening community")), [], "honest stemming limit");
  const unicode = await create("Laboratorio ceramica 東京");
  equal(
    ids(await lookup("ceramica l'artista 東京 %_")),
    [unicode],
    "Unicode/apostrophe input safe",
  );
  equal(
    ids(await lookup("PRIVATE_DESCRIPTION")),
    [],
    "description enrichment deferred",
  );

  const draft = await create("Murale comunitario", {}, false);
  const cancelled = await create("Murale comunitario");
  await rpc(owner, "cancel_proposal", {
    p_expected_creator_profile_id: owner.id,
    p_proposal_id: cancelled,
  });
  const negative = [];
  for (const [start, end] of [
    ["2020-01-01", "2020-01-02"],
    [
      new Date(Date.now() - 7200000).toISOString(),
      new Date(Date.now() - 3600000).toISOString(),
    ],
    [
      new Date(Date.now() - 3600000).toISOString(),
      new Date(Date.now() + 3600000).toISOString(),
    ],
  ]) {
    const id = await create("Murale comunitario");
    await sql`update public.proposals set starts_at=${start}::timestamptz,ends_at=${end}::timestamptz where id=${id}::uuid`;
    negative.push(id);
  }
  const invalidSchedule = await create("Murale comunitario", {}, false);
  // Trusted local-only malformed legacy row; no valid client can publish this.
  await sql`update public.proposals set starts_at='2098-03-01T10:00:00Z',ends_at='infinity',lifecycle_state='published',published_at=clock_timestamp()
    where id=${invalidSchedule}::uuid`;
  const tavolo = await rpc(owner, "create_recurring_activity_draft", {
    p_expected_creator_profile_id: owner.id,
    p_title: "Murale comunitario",
    p_summary: "SIM01 synthetic Tavolo",
    p_description: "PRIVATE_TAVOLO",
    p_topic: "Art",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "TN",
    p_public_location_label: "Rough area",
    p_exact_meeting_text: "MEETING_SECRET",
    p_exact_location_visibility: "public",
    p_recurrence_type: "weekly",
    p_weekday: 1,
    p_day_of_month: null,
    p_local_start_time: "10:00",
    p_duration_minutes: 60,
    p_event_timezone: "Europe/Rome",
    p_effective_from: "2098-01-01",
    p_registration_capacity: 4,
    p_count_organizers_toward_capacity: false,
  });
  await rpc(owner, "publish_recurring_activity", {
    p_expected_creator_profile_id: owner.id,
    p_recurring_activity_id: tavolo,
  });
  equal(
    ids(await lookup("murale", geo)),
    expectedOrder,
    "draft/cancelled/all later statuses/nonfinite/Tavolo excluded",
  );
  equal(
    ids(await lookup("murale", { ...geo, p_excluded_proposal_id: draft })),
    expectedOrder,
    "private excluded ID gives no existence information",
  );
  equal(
    [cancelled, draft, ...negative, invalidSchedule, tavolo].some((id) =>
      expectedOrder.includes(id),
    ),
    false,
    "negative fixture identities remain outside response",
  );

  const capacityProject = await create("Ceramica artigianale", {
    p_registration_capacity: 2,
  });
  const peerRequest = await request(peer, capacityProject);
  equal(
    await availability(capacityProject),
    "available",
    "pending request occupies no place",
  );
  const peerMembership = await accept(peerRequest);
  equal(
    await availability(capacityProject),
    "available",
    "near-full is available",
  );
  equal(
    ids(await lookup("Ceramica artigianale", {}, peer))[0],
    capacityProject,
    "accepted participant still sees strongest related Project",
  );
  equal(
    (
      await rpc(peer, "list_own_project_memberships", {
        p_expected_participant_profile_id: peer.id,
      })
    ).some((row) => row.project_id === capacityProject),
    true,
    "ordinary own participation read remains authoritative",
  );
  const delegateRequest = await request(delegate, capacityProject);
  const delegateMembership = await accept(delegateRequest);
  equal(
    await availability(capacityProject),
    "full",
    "two ordinary participants fill two slots",
  );
  const offer = await rpc(owner, "create_project_role_offer", {
    p_expected_structural_profile_id: owner.id,
    p_project_id: capacityProject,
    p_membership_id: delegateMembership,
    p_authority_role: "co_organizer",
  });
  const authority = await rpc(delegate, "accept_project_role_offer", {
    p_expected_profile_id: delegate.id,
    p_offer_id: offer,
  });
  equal(
    await availability(capacityProject),
    "available",
    "organizer/participant overlap not double-counted with toggle Off",
  );
  await edit(capacityProject, {
    p_count_organizers_toward_capacity: true,
    p_registration_capacity: 3,
  });
  equal(
    await availability(capacityProject),
    "full",
    "Creator plus active delegate plus ordinary participant consume canonical slots",
  );
  await rpc(owner, "revoke_project_delegate", {
    p_expected_owner_profile_id: owner.id,
    p_delegate_id: authority,
  });
  equal(
    await availability(capacityProject),
    "full",
    "revoked delegate is ordinary participant, Creator still counts",
  );
  await rpc(peer, "leave_project", {
    p_expected_participant_profile_id: peer.id,
    p_membership_id: peerMembership,
  });
  equal(
    await availability(capacityProject),
    "available",
    "left membership no longer occupies a slot",
  );
  await rpc(owner, "remove_project_member", {
    p_expected_creator_profile_id: owner.id,
    p_membership_id: delegateMembership,
  });
  equal(
    await availability(capacityProject),
    "available",
    "removed membership excluded",
  );
  const pending = await request(peer, unrelated);
  equal(
    ids(await lookup("libreria", {}, peer)),
    [unrelated],
    "actor's pending candidate stays relevant",
  );
  equal(typeof pending, "string", "ordinary pending request exists");
  await rpc(owner, "block_user", {
    p_expected_blocker_profile_id: owner.id,
    p_blocked_profile_id: peer.id,
  });
  equal(
    ids(await lookup("murale", geo, peer)),
    expectedOrder,
    "public lookup does not hide inbound blocked-manager sources",
  );
  await denied(
    peer.client,
    "request_to_join_project",
    { p_expected_requester_profile_id: peer.id, p_project_id: local },
    "PT409",
  );

  const coverId = randomUUID();
  const coverPath = owner.id + "/projects/" + local + "/" + coverId + ".webp";
  const image = Buffer.from(
    "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
    "base64",
  );
  const { error: uploadError } = await owner.client.storage
    .from("cover-images")
    .upload(coverPath, image, { contentType: "image/webp" });
  if (uploadError)
    throw new Error(
      "SIM01 cover upload fixture failed: " + uploadError.statusCode,
    );
  await rpc(owner, "set_own_project_cover", {
    p_expected_creator_profile_id: owner.id,
    p_project_id: local,
    p_object_path: coverPath,
  });
  equal(
    (await lookup("murale", geo))[0].cover_object_path,
    coverPath,
    "current canonical source cover only",
  );
  equal(
    (await lookup("murale", geo)).find((row) => row.proposal_id === far)
      .cover_object_path,
    null,
    "missing cover remains null",
  );
  const { error: downloadError } = await anonymous.storage
    .from("cover-images")
    .download(coverPath);
  equal(
    downloadError,
    null,
    "authorized independently public source cover remains readable",
  );
  const removedSource = await create("Origami community workshop");
  await rpc(owner, "set_project_shared_workspace", {
    p_expected_manager_profile_id: owner.id,
    p_project_id: removedSource,
    p_workspace_url: "https://drive.google.com/drive/folders/sim01-synthetic",
  });
  // Synthetic time reversal exercises domain independence; real source history
  // is never altered. Removal itself uses the audited canonical staff command.
  await sql`update public.proposals set starts_at='2020-01-01',ends_at='2020-01-02' where id=${removedSource}::uuid`;
  const [{ template }] =
    await sql`select id as template from private.proposal_templates where source_proposal_id=${removedSource}::uuid`;
  const [preview] = await rpc(reader, "get_public_proposal_template", {
    p_template_id: template,
  });
  const [report] = await rpc(reader, "submit_moderation_report", {
    p_expected_reporter_profile_id: reader.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "SIM01 synthetic review",
    p_target_kind: "proposal_template",
    p_target_id: template,
    p_context_kind: null,
    p_context_id: null,
  });
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at)
    values(${owner.id}::uuid,'moderator',true,null) on conflict(profile_id) do update set is_active=true,deactivated_at=null`;
  await rpc(owner, "remove_moderation_case_template", {
    p_expected_staff_profile_id: owner.id,
    p_case_id: report.case_id,
    p_template_id: template,
    p_client_request_id: randomUUID(),
    p_reviewed_content_version: preview.content_version,
    p_reason: "SIM01 synthetic audited removal",
  });
  await sql`update public.proposals set starts_at='2098-03-01T10:00:00Z',ends_at='2098-03-01T12:00:00Z' where id=${removedSource}::uuid`;
  equal(
    ids(await lookup("origami")),
    [removedSource],
    "removed template does not hide independently public upcoming source",
  );
  equal(
    (
      await rpc(reader, "get_public_proposal_template", {
        p_template_id: template,
      })
    ).length,
    0,
    "template remains removed",
  );
  const before = await totals();
  for (let n = 0; n < 3; n++) await lookup("murale", geo);
  equal(
    await totals(),
    before,
    "lookup creates no drafts/templates/receipts/reports/requests/notifications/outbox or source changes",
  );
  await verifyPlans();
  console.log(
    "SIM01 authenticated matching verifier passed: " +
      checks +
      " assertions, including capacity, privacy, exact input and query-plan checks.",
  );
} finally {
  // Narrow synthetic cleanup keeps repeat runs from competing with these titles.
  if (fixtures.length)
    await sql`update public.projects set registration_capacity=4
    where id=any(${fixtures}::uuid[]) and registration_capacity is null`;
  if (fixtures.length)
    await sql`update public.proposals set starts_at='2020-01-01',ends_at='2020-01-02'
    where id=any(${fixtures}::uuid[]) and lifecycle_state='published'
      and starts_at>statement_timestamp() and isfinite(starts_at)`;
  await sql.end();
}

async function verifyPlans() {
  await sql
    .begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub',${owner.id},true)`;
      const fixture = await readFile(
        new URL("./fixtures/sim01-query-plan.sql", import.meta.url),
        "utf8",
      );
      await tx.unsafe(fixture);
      await tx.unsafe("analyze public.proposals");
      await tx.unsafe("analyze public.projects");
      const [{ definition }] =
        await tx`select pg_get_functiondef('public.list_similar_active_proposals(uuid,text,uuid[],text,text,uuid,integer)'::regprocedure) as definition`;
      const query = definition.match(/return query\s+([\s\S]*?);\s*end;/i)?.[1];
      if (!query)
        throw new Error(
          "SIM01 plan verifier could not locate the canonical candidate query.",
        );
      const slots = {
        p_excluded_proposal_id: "$1::uuid",
        reference_time: "$2::timestamptz",
        idea_words: "$3::text[]",
        selected_skills: "$4::uuid[]",
        country: "$5::text",
        locality_hint: "$6::text",
        p_limit: "$7::integer",
      };
      const prepared = query.replace(
        /\b(p_excluded_proposal_id|reference_time|idea_words|selected_skills|country|locality_hint|p_limit)\b/g,
        (key) => slots[key],
      );
      for (const [label, words] of [
        ["topic", ["clockwork"]],
        ["common_topic", ["garden"]],
        ["weak", []],
      ]) {
        const result = await tx.unsafe(
          "explain (analyze,buffers,format json) " + prepared,
          [null, new Date().toISOString(), words, [], "IT", "trento", 5],
        );
        const plan = result[0]["QUERY PLAN"][0];
        const nodes = flatten(plan.Plan);
        const indexes = [
          ...new Set(nodes.map((node) => node["Index Name"]).filter(Boolean)),
        ];
        equal(
          indexes.some((name) =>
            [
              "proposals_published_idea_lexemes_idx",
              "proposals_published_starts_at_id_idx",
            ].includes(name),
          ),
          true,
          label + " uses indexed title/future narrowing",
        );
        const admitted = nodes.find(
          (node) => node["Subplan Name"] === "CTE admitted",
        );
        equal(
          (admitted?.["Actual Rows"] ?? 0) <= 61,
          true,
          label + " bounds meaningful eligibility before ranking/capacity",
        );
        console.log(
          "SIM01 plan " +
            label +
            ": indexes=" +
            indexes.join(",") +
            "; admitted=" +
            (admitted?.["Actual Rows"] ?? 0) +
            "; buffers=" +
            (plan.Plan["Shared Hit Blocks"] ?? 0) +
            "; ms=" +
            plan["Execution Time"],
        );
      }
      const rows =
        await tx`select proposal_id from public.list_similar_active_proposals(${owner.id}::uuid,'clockwork',null,'IT','Trento')`;
      const tenRows =
        await tx`select proposal_id from public.list_similar_active_proposals(${owner.id}::uuid,'clockwork',null,'IT','Trento',null,10)`;
      const discovery =
        await tx`select proposal_id from public.list_public_proposals(p_limit => 20)`;
      const [{ best }] =
        await tx`select current_setting('test.sim01_best')::uuid as best`;
      equal(rows.length, 5, "default top-five is bounded on the scale fixture");
      equal(tenRows.length, 10, "top-ten is bounded on the scale fixture");
      equal(
        ids(rows),
        ids(tenRows).slice(0, 5),
        "top-five and top-ten share the same total order",
      );
      equal(
        discovery.length === 20 && !ids(discovery).includes(best),
        true,
        "strongest later candidate is outside ordinary discovery first page",
      );
      equal(
        rows[0]?.proposal_id,
        best,
        "strongest later candidate survives beyond ordinary discovery first page",
      );
      equal(
        tenRows[0]?.proposal_id,
        best,
        "strongest later candidate leads top-ten too",
      );
      // Roll back every scale row and its domain effects. ANALYZE estimates may
      // outlive rollback; this is a disposable local stack, as documented.
      throw rollbackScale;
    })
    .catch((error) => {
      if (error !== rollbackScale) throw error;
    });
}
function flatten(node) {
  return [node, ...(node.Plans ?? []).flatMap(flatten)];
}
