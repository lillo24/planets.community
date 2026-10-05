import assert from "node:assert/strict";
import {
  seedLocalDemoWorld,
  verifyLocalDemoWorld,
  exerciseLocalDemoWorkshop,
  withLocalDemoWorldLock,
  DEMO_PERSONAS,
  DEMO_SCENARIOS,
} from "./lib/demo-world.mjs";
import {
  snapshotDemoDomain,
  workshopRequestId,
  workshopRpc,
  workshopContent,
  WORKSHOP_SOURCES,
} from "./lib/demo-workshop.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Explicit bounded mutation check. Never resets; safe to compose with PI05 later.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
const options = {
  repositoryRoot: process.cwd(),
  status,
  mailpitUrl,
  sessionPool: new Map(),
};
const started = performance.now();
await withLocalDemoWorldLock(status, mailpitUrl, async (sql) => {
  options.coordinationSql = sql;
  const concurrent = { ...options, coordinationSql: undefined };
  await assert.rejects(
    verifyLocalDemoWorld(concurrent),
    /concurrent world mutation/,
  );
  await assert.rejects(seedLocalDemoWorld(concurrent), /already running/);
  await assert.rejects(
    exerciseLocalDemoWorkshop(concurrent),
    /concurrent world mutation/,
  );
  const [{ missing }] =
    await sql`select not exists(select 1 from auth.users where email=${DEMO_PERSONAS.planets.email}) as missing`;
  if (missing) {
    const empty = await snapshotDemoDomain(sql);
    await assert.rejects(
      verifyLocalDemoWorld(options),
      /identities are missing/,
    );
    assert.deepEqual(
      await snapshotDemoDomain(sql),
      empty,
      "Missing-world verification creates no product data.",
    );
    console.log(
      "Workshop demo: expected missing-world verification failed without repair.",
    );
  }
  const sentinelActor = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: "tw05-unrelated-sentinel@planets.invalid",
    verifierName: "TW05 unrelated sentinel",
  });
  const [anchor] =
    await sql`select id from public.profiles where id=${sentinelActor.id}`;
  if (!anchor) {
    const { error } = await sentinelActor.client
      .from("profiles")
      .insert({ id: sentinelActor.id });
    if (error)
      throw new Error(`Sentinel profile anchor failed (${error.code}).`);
    await workshopRpc(sentinelActor.client, "update_own_profile", {
      p_expected_profile_id: sentinelActor.id,
      p_display_name: "TW05 unrelated synthetic sentinel",
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "private",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
  }
  const sentinelRequest = workshopRequestId(
    sentinelActor.id,
    "unrelated-sentinel",
  );
  let sentinelId = await workshopRpc(
    sentinelActor.client,
    "recover_editor_proposal_draft",
    {
      p_expected_creator_profile_id: sentinelActor.id,
      p_client_request_id: sentinelRequest,
    },
  );
  if (!sentinelId)
    sentinelId = await workshopRpc(
      sentinelActor.client,
      "create_editor_proposal_draft",
      {
        p_expected_creator_profile_id: sentinelActor.id,
        p_client_request_id: sentinelRequest,
        p_title: "Unrelated TW05 private sentinel",
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
      },
    );
  const sentinel =
    await sql`select to_jsonb(p) as content from public.proposals p where id=${sentinelId}`;
  const [{ count }] =
    await sql`select count(*)::int as count from private.proposal_template_applications a join auth.users u on u.id=a.applicant_profile_id where u.email=${DEMO_PERSONAS.bob.email}`;
  // The first pass explicitly rehearses an older nine-scenario installation.
  if (!count) {
    await seedLocalDemoWorld({ ...options, includeWorkshop: false });
    const oldTitles = [
      ...Object.values(DEMO_SCENARIOS.proposals),
      ...Object.values(DEMO_SCENARIOS.tavoli),
      ...Object.values(DEMO_SCENARIOS.listings),
    ].map((s) => s.title);
    const original =
      await sql`select id,title from public.proposals p where title=any(${oldTitles}::text[]) and not exists(select 1 from private.proposal_template_applications a where a.proposal_id=p.id) union all select id,title from public.recurring_activities where title=any(${oldTitles}::text[]) union all select id,title from public.resource_listings where title=any(${oldTitles}::text[]) order by id`;
    assert.equal(original.length, 9);
    const injected = new Error(
      "Intentional interruption after committed copy before seed acknowledgement.",
    );
    await assert.rejects(
      seedLocalDemoWorld({
        ...options,
        onWorkshopCheckpoint: ({ purpose }) => {
          if (purpose === "removed-copy") throw injected;
        },
      }),
      (e) => e === injected,
    );
    const partial = await snapshotDemoDomain(sql);
    await assert.rejects(
      verifyLocalDemoWorld(options),
      /Workshop|removed|application/,
    );
    assert.deepEqual(
      await snapshotDemoDomain(sql),
      partial,
      "Failed verification must not repair any product table.",
    );
    const [committed] =
      await sql`select a.proposal_id from private.proposal_template_applications a join auth.users u on u.id=a.applicant_profile_id where u.email=${DEMO_PERSONAS.bob.email} and a.client_request_id=${workshopRequestId((await sql`select id from auth.users where email=${DEMO_PERSONAS.bob.email}`)[0].id, "removed-copy")}`;
    await seedLocalDemoWorld(options);
    assert.ok(
      (
        await sql`select id from public.proposals where id=${committed.proposal_id}`
      )[0],
      "Recovery reuses the committed destination.",
    );
    assert.deepEqual(
      await sql`select id,title from public.proposals p where title=any(${oldTitles}::text[]) and not exists(select 1 from private.proposal_template_applications a where a.proposal_id=p.id) union all select id,title from public.recurring_activities where title=any(${oldTitles}::text[]) union all select id,title from public.resource_listings where title=any(${oldTitles}::text[]) order by id`,
      original,
      "Original nine IDs/titles survive extension.",
    );
    console.log(
      "Workshop demo: original-nine upgrade, committed-copy interruption and non-repairing verification passed.",
    );
  } else await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  // Owner-edited copies can legitimately have an original demo title. They
  // must never be adopted as sources or receive source clock refreshes.
  const alice = options.sessionPool.get(
    `${status.apiUrl}:${DEMO_PERSONAS.alice.email}`,
  );
  const collisionKey = workshopRequestId(alice.id, "self-copy-title-collision");
  let [collision] = await workshopRpc(
    alice.client,
    "get_own_proposal_template_application",
    {
      p_expected_creator_profile_id: alice.id,
      p_client_request_id: collisionKey,
    },
  );
  if (!collision) {
    const sourceId = await workshopRpc(
      alice.client,
      "recover_editor_proposal_draft",
      {
        p_expected_creator_profile_id: alice.id,
        p_client_request_id: workshopRequestId(alice.id, "source:mural"),
      },
    );
    const [source] =
      await sql`select p.id,t.id as template_id from public.proposals p join private.proposal_templates t on t.source_proposal_id=p.id where p.creator_profile_id=${alice.id} and p.id=${sourceId}`;
    const content = await workshopContent({ sql }, source.id);
    [collision] = await workshopRpc(
      alice.client,
      "create_proposal_draft_from_template",
      {
        p_expected_creator_profile_id: alice.id,
        p_template_id: source.template_id,
        p_content_version: content.token,
        p_client_request_id: collisionKey,
        p_prefill_capacity: false,
      },
    );
  }
  const [copy] =
    await sql`select * from public.proposals where id=${collision.proposal_id}`;
  if (copy.title !== DEMO_SCENARIOS.proposals.repairCafe.title) {
    assert.equal(
      copy.title,
      WORKSHOP_SOURCES.find((s) => s.key === "mural").title,
    );
    assert.ok(
      new Date(copy.updated_at) <= new Date(collision.accepted_at),
      "Do not overwrite owner edits while resuming collision fixture.",
    );
    const skills =
      await sql`select skill_id,importance from public.proposal_skills where proposal_id=${copy.id}`;
    await workshopRpc(alice.client, "update_own_proposal", {
      p_expected_creator_profile_id: alice.id,
      p_proposal_id: copy.id,
      p_title: DEMO_SCENARIOS.proposals.repairCafe.title,
      p_summary: copy.summary,
      p_description: copy.description,
      p_starts_at: null,
      p_ends_at: null,
      p_event_timezone: null,
      p_country_code: null,
      p_locality: null,
      p_administrative_area: null,
      p_public_location_label: null,
      p_exact_meeting_text: null,
      p_exact_location_visibility: "participants",
      p_skill_ids: skills.map((s) => s.skill_id),
      p_skill_importances: skills.map((s) => s.importance),
      p_registration_capacity: null,
      p_count_organizers_toward_capacity: false,
    });
  }
  const first = await snapshotDemoDomain(sql);
  await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  assert.deepEqual(
    await snapshotDemoDomain(sql),
    first,
    "Unchanged seed rewrote or duplicated product state/history.",
  );
  await exerciseLocalDemoWorkshop(options);
  await verifyLocalDemoWorld(options);
  const transitioned = await snapshotDemoDomain(sql);
  await seedLocalDemoWorld(options);
  await verifyLocalDemoWorld(options);
  assert.deepEqual(
    await snapshotDemoDomain(sql),
    transitioned,
    "Subsequent seed must retain the version transition and independent copies.",
  );
  assert.deepEqual(
    await sql`select to_jsonb(p) as content from public.proposals p where id=${sentinelId}`,
    sentinel,
    "Unrelated sentinel must remain byte-equivalent across seed/interruption/transition.",
  );
  console.log(
    `Workshop demo: stable IDs/tokens/Bozza/needs/receipts/reports/removal/audit/outbox/notifications across ${Object.keys(first).length} tables; unrelated sentinel, stale-token refresh, exact replay after removal and A/B independence passed (${((performance.now() - started) / 1000).toFixed(1)}s).`,
  );
});
