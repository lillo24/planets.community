import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Synthetic local-only API and authenticated transaction tests, also run in CI.
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [apiUrl, databaseUrl, mailpitUrl])
  if (
    !url ||
    !["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname)
  )
    throw new Error(
      "TW03 verifier requires loopback API/database/mailbox URLs.",
    );
const sql = postgres(databaseUrl, { max: 8, onnotice: () => {} });
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
    throw new Error("TW03 " + name + ": " + error.code + " " + error.message);
  return data;
}
async function denied(client, name, args, code) {
  const { error } = await client.rpc(name, args);
  equal(error?.code, code, name + " fails explicitly");
}
const users = await Promise.all(
  ["owner", "applicant", "peer", "staff", "incomplete"].map((role) =>
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "tw03-" + role + "@planets.invalid",
      verifierName: "TW03 " + role,
    }),
  ),
);
const [owner, applicant, peer, staff, incomplete] = users;
const applyArgs = (
  actor,
  template,
  version,
  key = randomUUID(),
  prefill = true,
) => ({
  p_expected_creator_profile_id: actor.id,
  p_template_id: template,
  p_content_version: version,
  p_client_request_id: key,
  p_prefill_capacity: prefill,
});
async function apply(actor, args) {
  return (
    await rpc(actor.client, "create_proposal_draft_from_template", args)
  )[0];
}
async function detail(template) {
  return (
    await rpc(anonymous, "get_public_proposal_template", {
      p_template_id: template,
    })
  )[0];
}
async function totals(db = sql) {
  const [row] = await db`select
    (select count(*)::int from public.proposals) as proposals,
    (select count(*)::int from public.projects) as projects,
    (select count(*)::int from public.proposal_skills) as skills,
    (select count(*)::int from public.project_resource_needs) as needs,
    (select count(*)::int from private.proposal_template_applications) as receipts,
    (select count(*)::int from private.audit_events) as audits,
    (select count(*)::int from private.outbox_events) as outbox,
    (select count(*)::int from public.notifications) as notifications`;
  return row;
}
async function authenticated(tx, actor) {
  await tx`select set_config('request.jwt.claim.sub', ${actor.id}, true)`;
  await tx.unsafe("set local role authenticated");
}
async function txApply(tx, args) {
  return (
    await tx`select * from public.create_proposal_draft_from_template(
    ${args.p_expected_creator_profile_id}::uuid,${args.p_template_id}::uuid,${args.p_content_version},
    ${args.p_client_request_id}::uuid,${args.p_prefill_capacity})`
  )[0];
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
    "TW03 expected transaction never blocked behind controlled lock.",
  );
}
let skillIds;
function contentArgs(
  actor,
  title,
  description = "TW03 published reusable description",
) {
  return {
    p_expected_creator_profile_id: actor.id,
    p_title: title,
    p_summary: "TW03 reusable summary",
    p_description: description,
    p_starts_at: new Date(Date.now() + 172800000).toISOString(),
    p_ends_at: new Date(Date.now() + 180000001).toISOString(),
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "TN",
    p_public_location_label: "Source public location",
    p_exact_meeting_text: "TW03_PRIVATE_MEETING",
    p_exact_location_visibility: "public",
    p_skill_ids: skillIds,
    p_skill_importances: ["required", "useful"],
    p_registration_capacity: 9,
    p_count_organizers_toward_capacity: true,
  };
}
async function source(
  title,
  { completed = true, publish = true, needs = 0, operational = false } = {},
) {
  const sourceId = await rpc(
    owner.client,
    "create_proposal_draft",
    contentArgs(owner, title, "TW03_PRIVATE_BOZZA"),
  );
  for (let i = 0; i < needs; i++)
    await rpc(owner.client, "create_project_resource_need", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: sourceId,
      p_title: "TW03 need " + i,
      p_details: "Reusable details " + i,
    });
  if (!publish) return { sourceId, template: sourceId };
  await rpc(owner.client, "publish_proposal", {
    p_expected_creator_profile_id: owner.id,
    p_proposal_id: sourceId,
  });
  if (operational) {
    const path =
      owner.id + "/projects/" + sourceId + "/" + randomUUID() + ".webp";
    const { error } = await owner.client.storage
      .from("cover-images")
      .upload(
        path,
        Buffer.from(
          "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
          "base64",
        ),
        { contentType: "image/webp" },
      );
    if (error)
      throw new Error(
        "TW03 synthetic source cover upload failed: " + error.code,
      );
    await rpc(owner.client, "set_own_project_cover", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: sourceId,
      p_object_path: path,
    });
    await rpc(owner.client, "set_project_shared_workspace", {
      p_expected_manager_profile_id: owner.id,
      p_project_id: sourceId,
      p_workspace_url: "https://drive.google.com/drive/folders/tw03-synthetic",
    });
    await ensureLocalProfilePhoto(peer);
    const request = await rpc(peer.client, "request_to_join_project", {
      p_expected_requester_profile_id: peer.id,
      p_project_id: sourceId,
      p_request_message: "TW03 source-only participation",
    });
    await rpc(owner.client, "accept_project_join_request_as_manager", {
      p_expected_manager_profile_id: owner.id,
      p_request_id: request,
    });
    const [invite] = await rpc(
      owner.client,
      "create_project_delegate_invitation",
      {
        p_expected_owner_profile_id: owner.id,
        p_project_id: sourceId,
        p_requested_authority_role: "co_organizer",
      },
    );
    await rpc(staff.client, "accept_project_delegate_invitation", {
      p_expected_delegate_profile_id: staff.id,
      p_token: invite.invite_token,
    });
  }
  // Explicit trusted synthetic adjustment; ordinary post-start editing stays locked.
  await sql`update public.proposals set description='TW03 published reusable description' where id=${sourceId}::uuid`;
  if (completed)
    await sql`update public.proposals set starts_at='2020-01-01T00:00:00Z',ends_at='2020-01-01T02:00:00.001Z' where id=${sourceId}::uuid`;
  const [{ id }] =
    await sql`select id from private.proposal_templates where source_proposal_id=${sourceId}::uuid`;
  return { sourceId, template: id };
}
async function reportAndRemoval(sourceRecord) {
  const [report] = await rpc(applicant.client, "submit_moderation_report", {
    p_expected_reporter_profile_id: applicant.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "TW03 synthetic explicit removal review.",
    p_target_kind: "proposal_template",
    p_target_id: sourceRecord.template,
    p_context_kind: null,
    p_context_id: null,
  });
  return {
    p_expected_staff_profile_id: staff.id,
    p_case_id: report.case_id,
    p_template_id: sourceRecord.template,
    p_client_request_id: randomUUID(),
    p_reviewed_content_version: (await detail(sourceRecord.template))
      .content_version,
    p_reason: "TW03 synthetic protected removal reason.",
  };
}
async function txRemove(tx, args) {
  return tx`select * from public.remove_moderation_case_template(
    ${args.p_expected_staff_profile_id}::uuid,${args.p_case_id}::uuid,${args.p_template_id}::uuid,
    ${args.p_client_request_id}::uuid,${args.p_reviewed_content_version},${args.p_reason})`;
}
try {
  for (const [i, user] of users.entries())
    await sql`insert into public.profiles(id,display_name)
    values(${user.id}::uuid,${i === 4 ? null : "TW03 " + i}) on conflict(id) do update set display_name=excluded.display_name`;
  await ensureLocalProfilePhoto(owner);
  await sql`delete from public.profile_photos where profile_id=${applicant.id}::uuid`;
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at)
    values(${staff.id}::uuid,'moderator',true,null) on conflict(profile_id) do update set is_active=true,deactivated_at=null`;
  skillIds = (await sql`select id from public.skills order by id limit 2`).map(
    (row) => row.id,
  );
  const primary = await source("TW03 complete reusable source", {
    needs: 61,
    operational: true,
  });
  const [{ id: closedId }] =
    await sql`select id from public.project_resource_needs where project_id=${primary.sourceId}::uuid order by title limit 1`;
  await sql`update public.project_resource_needs set state='closed',closed_at=statement_timestamp() where id=${closedId}::uuid`;
  const preview = await detail(primary.template);
  equal(preview.duration_seconds, 7200.001, "fractional duration is canonical");
  equal(
    preview.resource_blueprint_count,
    60,
    "full collection exceeds one public page",
  );
  const acceptedArgs = applyArgs(
    applicant,
    primary.template,
    preview.content_version,
  );
  const before = await totals();
  const defaultArgs = { ...acceptedArgs };
  delete defaultArgs.p_prefill_capacity;
  const deliveries = await Promise.all([
    apply(applicant, defaultArgs),
    apply(applicant, acceptedArgs),
  ]);
  equal(
    deliveries.map((r) => r.outcome).sort(),
    ["created", "recovered"],
    "concurrent duplicates truthful outcomes",
  );
  equal(
    deliveries[0].proposal_id,
    deliveries[1].proposal_id,
    "one draft for concurrent duplicate",
  );
  equal(
    { ...deliveries[0], outcome: null },
    { ...deliveries[1], outcome: null },
    "one immutable acceptance receipt",
  );
  const receipt = deliveries[0];
  const after = await totals();
  for (const [key, delta] of Object.entries({
    proposals: 1,
    projects: 1,
    skills: 2,
    needs: 60,
    receipts: 1,
    audits: 60,
    outbox: 60,
    notifications: 0,
  }))
    equal(after[key] - before[key], delta, "exact ordinary effects: " + key);
  equal(
    receipt.duration_seconds,
    7200.001,
    "receipt retains fractional recommendation",
  );
  equal(
    receipt.capacity_recommendation,
    9,
    "receipt retains capacity recommendation",
  );
  const [draft] =
    await sql`select to_jsonb(p) as proposal,to_jsonb(project) as project,to_jsonb(meeting) as meeting
    from public.proposals p join public.projects project on project.id=p.id
    join public.proposal_meeting_details meeting on meeting.proposal_id=p.id where p.id=${receipt.proposal_id}::uuid`;
  equal(
    draft.proposal.creator_profile_id,
    applicant.id,
    "sole applicant Creator",
  );
  for (const key of ["title", "summary", "description"])
    equal(draft.proposal[key], preview[key], "exact published " + key);
  for (const key of [
    "starts_at",
    "ends_at",
    "country_code",
    "locality",
    "administrative_area",
    "public_location_label",
    "approximate_location",
    "published_at",
    "cancelled_at",
  ])
    equal(draft.proposal[key], null, "reset " + key);
  equal(
    draft.proposal.event_timezone,
    "Europe/Rome",
    "new template Italy default",
  );
  equal(draft.proposal.lifecycle_state, "draft", "private unpublished draft");
  equal(draft.meeting.exact_meeting_text, null, "no source meeting text");
  equal(
    draft.meeting.exact_location_visibility,
    "participants",
    "ordinary privacy default",
  );
  equal(
    draft.project.registration_capacity,
    9,
    "capacity defaults to recommendation",
  );
  equal(
    draft.project.count_organizers_toward_capacity,
    false,
    "organizer counting always Off",
  );
  const [headcount] =
    await sql`select * from private.project_registration_capacity_snapshot(${receipt.proposal_id}::uuid)`;
  equal(
    headcount.organizer_count,
    1,
    "Creator contributes ordinary social headcount",
  );
  equal(
    headcount.capacity_used_count,
    0,
    "Creator consumes no registration slot",
  );
  equal(
    Array.from(
      await sql`select skill_id,importance from public.proposal_skills where proposal_id=${receipt.proposal_id}::uuid order by skill_id`,
    ),
    Array.from(
      await sql`select skill_id,importance from public.proposal_skills where proposal_id=${primary.sourceId}::uuid order by skill_id`,
    ),
    "controlled importance copied",
  );
  equal(
    Array.from(
      await sql`select title,details from public.project_resource_needs where project_id=${receipt.proposal_id}::uuid order by title`,
    ),
    Array.from(
      await sql`select title,details from public.project_resource_needs where project_id=${primary.sourceId}::uuid and state='open' order by title`,
    ),
    "all 60 open blueprints exact",
  );
  const [{ overlap, closed }] = await sql`select
    (select count(*)::int from public.project_resource_needs a join public.project_resource_needs b on a.id=b.id where a.project_id=${primary.sourceId}::uuid and b.project_id=${receipt.proposal_id}::uuid) as overlap,
    (select count(*)::int from public.project_resource_needs where project_id=${receipt.proposal_id}::uuid and state<>'open') as closed`;
  equal(
    { overlap, closed },
    { overlap: 0, closed: 0 },
    "fresh IDs and open-only needs",
  );
  // Inspect every existing Project-owned operational table; ordinary need rows are the sole copy.
  const projectTables =
    await sql`select n.nspname as schema,c.relname as name from pg_class c
    join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid
    where n.nspname in ('public','private') and c.relkind='r' and a.attname='project_id'
    and c.relname<>'project_resource_needs'`;
  for (const table of projectTables) {
    const [row] =
      await sql`select count(*)::int as count from ${sql(table.schema + "." + table.name)} where project_id=${receipt.proposal_id}::uuid`;
    equal(row.count, 0, "no inherited " + table.name);
  }
  equal(
    await rpc(anonymous, "get_public_proposal", {
      p_proposal_id: receipt.proposal_id,
    }),
    [],
    "draft stays nonpublic",
  );
  equal(
    (
      await rpc(applicant.client, "get_own_proposal", {
        p_expected_creator_profile_id: applicant.id,
        p_proposal_id: receipt.proposal_id,
      })
    )[0].title,
    preview.title,
    "ordinary editor owner read",
  );
  await denied(
    peer.client,
    "get_own_proposal",
    {
      p_expected_creator_profile_id: applicant.id,
      p_proposal_id: receipt.proposal_id,
    },
    "42501",
  );
  const ownReceiptArgs = {
    p_expected_creator_profile_id: applicant.id,
    p_client_request_id: acceptedArgs.p_client_request_id,
  };
  equal(
    (
      await rpc(
        applicant.client,
        "get_own_proposal_template_application",
        ownReceiptArgs,
      )
    )[0].proposal_id,
    receipt.proposal_id,
    "narrow owner receipt",
  );
  for (const actor of [owner, peer, staff]) {
    equal(
      await rpc(actor.client, "get_own_proposal_template_application", {
        ...ownReceiptArgs,
        p_expected_creator_profile_id: actor.id,
      }),
      [],
      "no source/staff/peer receipt exception",
    );
    await denied(
      actor.client,
      "get_own_proposal_template_application",
      ownReceiptArgs,
      "42501",
    );
  }
  await denied(
    anonymous,
    "get_own_proposal_template_application",
    ownReceiptArgs,
    "42501",
  );
  const noEffects = await totals();
  for (const change of [
    { p_template_id: randomUUID() },
    { p_content_version: "tw01:" + "0".repeat(64) },
    { p_prefill_capacity: false },
  ])
    await denied(
      applicant.client,
      "create_proposal_draft_from_template",
      { ...acceptedArgs, ...change },
      "22023",
    );
  await denied(
    applicant.client,
    "create_proposal_draft_from_template",
    applyArgs(applicant, primary.template, "tw01:" + "0".repeat(64)),
    "PT409",
  );
  for (const change of [
    { p_template_id: null },
    { p_client_request_id: null },
    { p_content_version: "x" },
    { p_prefill_capacity: null },
  ])
    await denied(
      applicant.client,
      "create_proposal_draft_from_template",
      { ...acceptedArgs, ...change },
      "22023",
    );
  await denied(
    applicant.client,
    "create_proposal_draft_from_template",
    { ...acceptedArgs, p_expected_creator_profile_id: owner.id },
    "42501",
  );
  await denied(
    anonymous,
    "create_proposal_draft_from_template",
    acceptedArgs,
    "42501",
  );
  await denied(
    incomplete.client,
    "create_proposal_draft_from_template",
    applyArgs(incomplete, primary.template, preview.content_version),
    "55000",
  );
  await denied(
    applicant.client,
    "create_proposal_draft_from_template",
    {
      ...applyArgs(applicant, primary.template, preview.content_version),
      p_title: "Forged content",
    },
    "PGRST202",
  );
  equal(await totals(), noEffects, "invalid and stale requests leave nothing");
  const self = await apply(
    owner,
    applyArgs(owner, primary.template, preview.content_version),
  );
  equal(
    (
      await sql`select creator_profile_id from public.proposals where id=${self.proposal_id}::uuid`
    )[0].creator_profile_id,
    owner.id,
    "source Creator can independently apply",
  );
  const peerReceipt = await apply(
    peer,
    applyArgs(
      peer,
      primary.template,
      preview.content_version,
      acceptedArgs.p_client_request_id,
      false,
    ),
  );
  equal(
    peerReceipt.proposal_id === receipt.proposal_id,
    false,
    "same UUID another identity creates separate draft",
  );
  equal(
    (
      await sql`select registration_capacity from public.projects where id=${peerReceipt.proposal_id}::uuid`
    )[0].registration_capacity,
    null,
    "explicit capacity opt-out",
  );
  equal(
    peerReceipt.capacity_recommendation,
    9,
    "opt-out still reports accepted recommendation",
  );
  const another = await apply(
    applicant,
    applyArgs(applicant, primary.template, preview.content_version),
  );
  equal(
    another.proposal_id === receipt.proposal_id,
    false,
    "fresh explicit key creates second draft",
  );
  const lostAcknowledgement = applyArgs(
    applicant,
    primary.template,
    preview.content_version,
  );
  // Intentionally discard a successful response to model an unacknowledged commit.
  await rpc(
    applicant.client,
    "create_proposal_draft_from_template",
    lostAcknowledgement,
  );
  const afterLostResponse = await totals();
  equal(
    (await apply(applicant, lostAcknowledgement)).outcome,
    "recovered",
    "lost acknowledgement recovers accepted action",
  );
  equal(
    await totals(),
    afterLostResponse,
    "ambiguous retry has no repeated effects",
  );
  await denied(
    applicant.client,
    "publish_proposal",
    {
      p_expected_creator_profile_id: applicant.id,
      p_proposal_id: receipt.proposal_id,
    },
    "22023",
  );
  const future = await source("TW03 future", { completed: false });
  const cancelled = await source("TW03 cancelled");
  await sql`update public.proposals set lifecycle_state='cancelled',cancelled_at=clock_timestamp() where id=${cancelled.sourceId}::uuid`;
  const ordinary = await source("TW03 ordinary draft", { publish: false });
  const nullCapacity = await source("TW03 legacy null capacity");
  await sql`update public.projects set registration_capacity=null where id=${nullCapacity.sourceId}::uuid`;
  const nullPreview = await detail(nullCapacity.template);
  const nullReceipt = await apply(
    applicant,
    applyArgs(applicant, nullCapacity.template, nullPreview.content_version),
  );
  equal(
    nullReceipt.capacity_recommendation,
    null,
    "legacy null recommendation retained",
  );
  equal(
    (
      await sql`select registration_capacity from public.projects where id=${nullReceipt.proposal_id}::uuid`
    )[0].registration_capacity,
    null,
    "legacy null stays unset",
  );
  const invalidBefore = await totals();
  for (const template of [
    future.template,
    cancelled.template,
    ordinary.template,
    randomUUID(),
  ])
    await denied(
      applicant.client,
      "create_proposal_draft_from_template",
      applyArgs(applicant, template, preview.content_version),
      "42501",
    );
  equal(await totals(), invalidBefore, "ineligible sources have no effects");
  const [{ before_boundary, at_boundary }] = await sql`select
    private.is_proposal_template_publicly_usable(${primary.template}::uuid,'2020-01-02T02:00:00.000999Z') as before_boundary,
    private.is_proposal_template_publicly_usable(${primary.template}::uuid,'2020-01-02T02:00:00.001Z') as at_boundary`;
  equal(
    { before_boundary, at_boundary },
    { before_boundary: false, at_boundary: true },
    "exact Completed microsecond boundary",
  );

  // Controlled source barrier: changed snapshot, profile gate and availability refresh.
  for (const mode of [
    "token",
    "profile",
    "unavailable",
    "completed_after_wait",
  ]) {
    const item = await source("TW03 waiting " + mode);
    const token = (await detail(item.template)).content_version;
    if (mode === "completed_after_wait")
      await sql`update public.proposals set starts_at=clock_timestamp()-interval '2 hours',ends_at=clock_timestamp()-interval '1 hour' where id=${item.sourceId}::uuid`;
    const beforeWait = await totals();
    let pending;
    await sql.begin(async (tx) => {
      const [{ pid }] = await tx`select pg_backend_pid() as pid`;
      await tx`select id from public.proposals where id=${item.sourceId}::uuid for update`;
      // For time/eligibility test use the content token for the exact state committed by blocker.
      let nextToken = token;
      if (mode === "completed_after_wait") {
        await tx`update public.proposals set starts_at='2020-01-01T00:00:00Z',ends_at='2020-01-01T02:00:00.001Z' where id=${item.sourceId}::uuid`;
        nextToken = (
          await tx`select private.proposal_template_content_version(private.proposal_template_reusable_content(${item.sourceId}::uuid)) as token`
        )[0].token;
      }
      pending = applicant.client
        .rpc(
          "create_proposal_draft_from_template",
          applyArgs(applicant, item.template, nextToken),
        )
        .then((r) => r);
      await waitBlocked(pid);
      if (mode === "token") {
        await tx`update public.proposals set summary='Fresh content committed while copying waited' where id=${item.sourceId}::uuid`;
        await tx`insert into public.project_resource_needs(project_id,title,details) values(${item.sourceId}::uuid,'Fresh coherent need','Fresh coherent details')`;
      }
      if (mode === "profile")
        await tx`update public.profiles set display_name=null where id=${applicant.id}::uuid`;
      if (mode === "unavailable")
        await tx`update public.proposals set lifecycle_state='cancelled',cancelled_at=clock_timestamp() where id=${item.sourceId}::uuid`;
    });
    const result = await pending;
    if (mode === "completed_after_wait")
      equal(
        result.data?.[0]?.outcome,
        "created",
        "post-wait current eligibility permits creation",
      );
    else {
      equal(
        result.error?.code,
        mode === "token" ? "PT409" : mode === "profile" ? "55000" : "42501",
        "post-wait refresh " + mode,
      );
      equal(
        (await totals()).receipts,
        beforeWait.receipts,
        "blocked failure adds no receipt",
      );
    }
    if (mode === "profile")
      await sql`update public.profiles set display_name='TW03 applicant' where id=${applicant.id}::uuid`;
    if (mode === "token") {
      const refreshed = await detail(item.template);
      const copied = await apply(
        applicant,
        applyArgs(applicant, item.template, refreshed.content_version),
      );
      const [row] =
        await sql`select p.summary,(select count(*)::int from public.project_resource_needs where project_id=p.id) as needs from public.proposals p where id=${copied.proposal_id}::uuid`;
      equal(
        row,
        { summary: "Fresh content committed while copying waited", needs: 1 },
        "one coherent refreshed payload",
      );
    }
  }

  // Copy wins: run authenticated RPC in an open transaction, prove removal waits.
  const copyFirst = await source("TW03 copy wins", { needs: 2 });
  const copyRemoveArgs = await reportAndRemoval(copyFirst);
  const copyArgs = applyArgs(
    applicant,
    copyFirst.template,
    copyRemoveArgs.p_reviewed_content_version,
  );
  let waitingRemoval, copyReceipt;
  await sql.begin(async (tx) => {
    const [{ pid }] = await tx`select pg_backend_pid() as pid`;
    await authenticated(tx, applicant);
    copyReceipt = await txApply(tx, copyArgs);
    waitingRemoval = staff.client
      .rpc("remove_moderation_case_template", copyRemoveArgs)
      .then((r) => r);
    await waitBlocked(pid);
  });
  equal(
    (await waitingRemoval).data?.[0]?.outcome,
    "removed",
    "copy commit then removal succeeds",
  );
  equal(
    (await apply(applicant, copyArgs)).proposal_id,
    copyReceipt.proposal_id,
    "accepted retry survives removal",
  );
  await denied(
    applicant.client,
    "create_proposal_draft_from_template",
    { ...copyArgs, p_client_request_id: randomUUID() },
    "42501",
  );
  equal(
    (
      await rpc(applicant.client, "get_own_proposal", {
        p_expected_creator_profile_id: applicant.id,
        p_proposal_id: copyReceipt.proposal_id,
      })
    )[0].title,
    "TW03 copy wins",
    "independent owner draft survives removal",
  );
  // Removal wins: its uncommitted canonical action blocks a fresh application.
  const removeFirst = await source("TW03 removal wins");
  const removal = await reportAndRemoval(removeFirst);
  let waitingCopy;
  const removalBefore = await totals();
  await sql.begin(async (tx) => {
    const [{ pid }] = await tx`select pg_backend_pid() as pid`;
    await authenticated(tx, staff);
    await txRemove(tx, removal);
    waitingCopy = applicant.client
      .rpc(
        "create_proposal_draft_from_template",
        applyArgs(
          applicant,
          removeFirst.template,
          removal.p_reviewed_content_version,
        ),
      )
      .then((r) => r);
    await waitBlocked(pid);
  });
  equal(
    (await waitingCopy).error?.code,
    "42501",
    "removal commit prevents queued first creation",
  );
  equal(
    (await totals()).proposals,
    removalBefore.proposals,
    "removal-first no partial draft",
  );

  // Failure injection remains local, transactional and rolls trigger DDL back.
  for (const boundary of ["need", "receipt", "outbox"]) {
    const item = await source("TW03 injected " + boundary, { needs: 3 });
    const args = applyArgs(
      applicant,
      item.template,
      (await detail(item.template)).content_version,
    );
    await sql.begin(async (tx) => {
      const prior = await totals(tx);
      if (boundary === "need")
        await tx.unsafe("create temporary sequence tw03_attempts");
      const table =
        boundary === "need"
          ? "public.project_resource_needs"
          : boundary === "receipt"
            ? "private.proposal_template_applications"
            : "private.outbox_events";
      const condition =
        boundary === "need"
          ? "nextval('pg_temp.tw03_attempts')=3"
          : boundary === "outbox"
            ? "new.event_type='project.resource_need_created'"
            : "true";
      await tx.unsafe(
        "create function pg_temp.tw03_fail() returns trigger language plpgsql as $$ begin if " +
          condition +
          " then raise exception 'TW03 injected failure' using errcode='P0001'; end if; return new; end; $$",
      );
      await tx.unsafe(
        "create trigger tw03_fail before insert on " +
          table +
          " for each row execute function pg_temp.tw03_fail()",
      );
      let code;
      try {
        await tx.savepoint(async (nested) => {
          await authenticated(nested, applicant);
          await txApply(nested, args);
        });
      } catch (error) {
        code = error.code;
      }
      equal(code, "P0001", "failure reaches real " + boundary + " boundary");
      if (boundary === "need") {
        equal(
          (
            await tx`select last_value::int as count from pg_temp.tw03_attempts`
          )[0].count,
          3,
          "two destination needs were inserted before third failed",
        );
        await tx.unsafe("drop sequence pg_temp.tw03_attempts");
      }
      equal(
        await totals(tx),
        prior,
        "all partial writes roll back at " + boundary,
      );
      await tx.unsafe("drop trigger tw03_fail on " + table);
      await tx.unsafe("drop function pg_temp.tw03_fail()");
    });
  }

  // Owner edits, profile incompleteness, source changes and publication never reset acceptance.
  await rpc(applicant.client, "update_own_proposal", {
    ...contentArgs(
      applicant,
      "TW03 edited independent draft",
      "Applicant own saved draft",
    ),
    p_proposal_id: receipt.proposal_id,
  });
  equal(
    (await detail(primary.template)).title,
    preview.title,
    "derived edit leaves source untouched",
  );
  await sql`update public.proposals set summary='TW03 later source change' where id=${primary.sourceId}::uuid`;
  await sql`update public.profiles set display_name=null where id=${applicant.id}::uuid`;
  const recoveryBefore = await totals();
  const recovered = await apply(applicant, acceptedArgs);
  equal(
    recovered.proposal_id,
    receipt.proposal_id,
    "accepted retry survives source changes and incomplete profile",
  );
  equal(recovered.outcome, "recovered", "truthful recovery");
  equal(await totals(), recoveryBefore, "recovery has zero effects");
  equal(
    (
      await rpc(applicant.client, "get_own_proposal", {
        p_expected_creator_profile_id: applicant.id,
        p_proposal_id: receipt.proposal_id,
      })
    )[0].title,
    "TW03 edited independent draft",
    "retry preserves owner edits",
  );
  await sql`update public.profiles set display_name='TW03 applicant' where id=${applicant.id}::uuid`;
  await denied(
    applicant.client,
    "publish_proposal",
    {
      p_expected_creator_profile_id: applicant.id,
      p_proposal_id: receipt.proposal_id,
    },
    "PT422",
  );
  await ensureLocalProfilePhoto(applicant);
  await rpc(applicant.client, "publish_proposal", {
    p_expected_creator_profile_id: applicant.id,
    p_proposal_id: receipt.proposal_id,
  });
  const [derivedTemplate] =
    await sql`select id,original_creator_profile_id from private.proposal_templates where source_proposal_id=${receipt.proposal_id}::uuid`;
  equal(
    derivedTemplate.original_creator_profile_id,
    applicant.id,
    "own publication has own template identity",
  );
  equal(
    derivedTemplate.id === primary.template,
    false,
    "derived template distinct from source",
  );
  const [baseline] = await rpc(
    applicant.client,
    "get_own_proposal_template_baseline",
    {
      p_expected_creator_profile_id: applicant.id,
      p_template_id: derivedTemplate.id,
    },
  );
  equal(
    baseline.description,
    "Applicant own saved draft",
    "new Creator own pre-publication Bozza",
  );
  const publishBefore = await totals();
  equal(
    (await apply(applicant, acceptedArgs)).proposal_id,
    receipt.proposal_id,
    "retry after publication same Proposal",
  );
  equal(
    await totals(),
    publishBefore,
    "published retry never reopens/recreates",
  );
  equal(
    (
      await sql`select lifecycle_state from public.proposals where id=${receipt.proposal_id}::uuid`
    )[0].lifecycle_state,
    "published",
    "retry retains publication",
  );
  await sql`update public.proposals set lifecycle_state='cancelled',cancelled_at=clock_timestamp() where id=${primary.sourceId}::uuid`;
  equal(
    (await apply(applicant, acceptedArgs)).proposal_id,
    receipt.proposal_id,
    "retry survives source availability loss",
  );
  equal(
    (
      await sql`select count(*)::int as count from private.proposal_template_baselines where template_id=${primary.template}::uuid`
    )[0].count,
    1,
    "original baseline unchanged",
  );
  equal(
    await rpc(staff.client, "get_own_proposal_template_application", {
      p_expected_creator_profile_id: staff.id,
      p_client_request_id: acceptedArgs.p_client_request_id,
    }),
    [],
    "staff still has no provenance exception",
  );
  console.log(
    "TW03 authenticated template application verifier passed: " +
      checks +
      " assertions, including controlled copy/removal barriers and rollback injection.",
  );
} finally {
  await sql.end({ timeout: 2 });
}
