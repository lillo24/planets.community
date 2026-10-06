import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Also runs from proposal:verify:local, including hosted Database validation.
// Only synthetic local fixtures. Does not reset a stack or use a remote client.
export async function verifyProposalTemplateWorkshop() {
  const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
    process.cwd(),
  );
  if (!databaseUrl) throw new Error("TW01 local database URL is missing.");
  const sql = postgres(databaseUrl, { max: 6 });
  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const owner = await signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
    email: "tw01-integration-owner@planets.invalid",
    verifierName: "TW01 Workshop",
  });
  async function asOwner(operation) {
    return sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub', ${owner.id}, true)`;
      await tx.unsafe("set local role authenticated");
      return operation(tx);
    });
  }
  async function rpc(client, name, args) {
    const { data, error } = await client.rpc(name, args);
    if (error)
      throw new Error(`TW01 ${name} failed: ${error.code} ${error.message}`);
    return data;
  }
  async function linked(sourceId) {
    const [row] =
      await sql`select id from private.proposal_templates where source_proposal_id=${sourceId}::uuid`;
    assert.ok(row, `TW01 source ${sourceId} has no identity`);
    return row.id;
  }
  async function currentContent(sourceId) {
    const [row] =
      await sql`select private.proposal_template_reusable_content(${sourceId}::uuid) as payload,
        private.proposal_template_content_version(private.proposal_template_reusable_content(${sourceId}::uuid)) as token`;
    return row;
  }
  async function detail(templateId) {
    return rpc(anonymous, "get_public_proposal_template", {
      p_template_id: templateId,
    });
  }
  try {
    await sql`insert into public.profiles(id,display_name) values (${owner.id}::uuid,'TW01 integration owner') on conflict(id) do nothing`;
    await ensureLocalProfilePhoto(owner);
    const skills = await sql`select id from public.skills order by id limit 2`;
    const start = new Date(Date.now() + 172800000).toISOString();
    const end = new Date(Date.now() + 180000000).toISOString();
    const source = await rpc(owner.client, "create_proposal_draft", {
      p_expected_creator_profile_id: owner.id,
      p_title: "TW01 HTTP saved idea",
      p_summary: "Reusable idea",
      p_description: "Draft comparison marker",
      p_starts_at: start,
      p_ends_at: end,
      p_event_timezone: "Europe/Rome",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "TN",
      p_public_location_label: "Trento",
      p_exact_meeting_text: "TW01_PRIVATE_MEETING",
      p_exact_location_visibility: "public",
      p_skill_ids: [skills[0].id],
      p_skill_importances: ["required"],
      p_registration_capacity: 8,
      p_count_organizers_toward_capacity: false,
    });
    const coverA = `${owner.id}/projects/${source}/${randomUUID()}.webp`;
    const coverB = `${owner.id}/projects/${source}/${randomUUID()}.webp`;
    const webp = Buffer.from(
      "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
      "base64",
    );
    for (const path of [coverA, coverB]) {
      const { error } = await owner.client.storage
        .from("cover-images")
        .upload(path, webp, { contentType: "image/webp", upsert: false });
      if (error) throw new Error(`TW01 cover upload failed: ${error.message}`);
    }
    await rpc(owner.client, "set_own_project_cover", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: source,
      p_object_path: coverA,
    });

    // A publication queued behind a draft save must capture that last committed
    // save, and concurrent retries must leave only one identity/baseline/event.
    let publication, retry;
    await sql.begin(async (tx) => {
      const [{ pid }] = await tx`select pg_backend_pid() as pid`;
      await tx`select id from public.proposals where id=${source}::uuid for update`;
      await tx`update public.proposals set title='TW01 last persisted draft' where id=${source}::uuid`;
      publication = asOwner(
        (pending) =>
          pending`select public.publish_proposal(${owner.id}::uuid,${source}::uuid)`,
      );
      await waitForBlocked(sql, pid);
      retry = asOwner(
        (pending) =>
          pending`select public.publish_proposal(${owner.id}::uuid,${source}::uuid)`,
      );
      const [count] =
        await sql`select count(*)::int as count from private.proposal_templates where source_proposal_id=${source}::uuid`;
      assert.equal(
        count.count,
        0,
        "uncommitted draft save/publication has no visible template side effect",
      );
    });
    await Promise.all([publication, retry]);
    const template = await linked(source);
    const baseline = await rpc(
      owner.client,
      "get_own_proposal_template_baseline",
      { p_expected_creator_profile_id: owner.id, p_template_id: template },
    );
    assert.equal(baseline[0].title, "TW01 last persisted draft");
    assert.deepEqual(Object.keys(baseline[0]).sort(), [
      "captured_at",
      "description",
      "skill_selections",
      "source_proposal_id",
      "summary",
      "template_id",
      "title",
    ]);
    const [counts] = await sql`select
      (select count(*)::int from private.proposal_templates where source_proposal_id=${source}::uuid) as identities,
      (select count(*)::int from private.proposal_template_baselines where template_id=${template}::uuid) as baselines,
      (select count(*)::int from private.outbox_events where event_type='proposal.published' and payload->>'proposal_id'=${source}) as events`;
    assert.deepEqual(counts, { identities: 1, baselines: 1, events: 1 });

    const beforeCoverChange = await currentContent(source);
    await rpc(owner.client, "set_own_project_cover", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: source,
      p_object_path: coverB,
    });
    const changedCover = await currentContent(source);
    assert.notEqual(changedCover.token, beforeCoverChange.token);
    assert.equal(changedCover.payload.cover_object_path, coverB);
    await rpc(owner.client, "clear_own_project_cover", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: source,
    });
    const clearedCover = await currentContent(source);
    assert.equal(clearedCover.payload.cover_object_path, null);
    assert.notEqual(clearedCover.token, changedCover.token);
    await rpc(owner.client, "set_own_project_cover", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: source,
      p_object_path: coverB,
    });
    assert.equal(
      (await currentContent(source)).token,
      changedCover.token,
      "restoring identical copied content restores identical token",
    );

    // Skill-only changes affect the token even when scalar text stays identical.
    await asOwner(
      (
        tx,
      ) => tx`select public.update_own_proposal(${owner.id}::uuid,${source}::uuid,
      'TW01 last persisted draft','Reusable idea','Draft comparison marker',${start}::timestamptz,${end}::timestamptz,
      'Europe/Rome','IT','Trento','TN','Trento','TW01_PRIVATE_MEETING','public',
      ${[skills[1].id]}::uuid[],${["useful"]}::text[])`,
    );
    assert.notEqual((await currentContent(source)).token, changedCover.token);
    assert.deepEqual(
      await detail(template),
      [],
      "future source is not Workshop usable",
    );

    // Trusted time-only fixture: eligibility changes without any second write.
    const [{ boundary }] = await sql`update public.proposals set
      starts_at=clock_timestamp()-interval '26 hours',
      ends_at=clock_timestamp()-interval '24 hours'+interval '2 seconds'
      where id=${source}::uuid returning ends_at+interval '24 hours' as boundary`;
    assert.deepEqual(await detail(template), []);
    const deadline = Date.now() + 7000;
    let completed;
    while (Date.now() < deadline) {
      completed = await detail(template);
      if (completed.length) break;
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.equal(
      completed.length,
      1,
      `TW01 source did not appear after ${boundary.toISOString()}`,
    );
    assert.equal(completed[0].cover_object_path, coverB);
    assert.equal(
      completed[0].content_version,
      (await currentContent(source)).token,
    );
    assert.equal(completed[0].skills[0].id, skills[1].id);
    assert.ok(!JSON.stringify(completed).includes("TW01_PRIVATE_MEETING"));

    // Overlapping trusted source fixture changes prove that stable public reads
    // never see new text with old needs/version. Normal completed-source writes
    // remain prohibited by the source domain; this is a local snapshot probe.
    const oldDetail = completed[0];
    const needId = randomUUID();
    await sql.begin(async (tx) => {
      await tx`update public.proposals set title='TW01 committed coherent idea' where id=${source}::uuid`;
      await tx`insert into public.project_resource_needs(id,project_id,title,details) values (${needId}::uuid,${source}::uuid,'Coherent blueprint','Reusable details')`;
      assert.deepEqual((await detail(template))[0], oldDetail);
    });
    const coherent = (await detail(template))[0];
    assert.equal(coherent.title, "TW01 committed coherent idea");
    assert.equal(coherent.resource_blueprint_count, 1);
    assert.equal(
      coherent.content_version,
      (await currentContent(source)).token,
    );
    const pages = await rpc(
      anonymous,
      "list_public_proposal_template_resource_blueprints",
      {
        p_template_id: template,
        p_content_version: coherent.content_version,
      },
    );
    assert.deepEqual(pages, [
      {
        source_need_id: needId,
        title: "Coherent blueprint",
        details: "Reusable details",
      },
    ]);
    const stale = await anonymous.rpc(
      "list_public_proposal_template_resource_blueprints",
      { p_template_id: template, p_content_version: oldDetail.content_version },
    );
    assert.equal(stale.error?.code, "PT409");

    // Equal ordering times must paginate using the unique template tie-breaker.
    const catalogSources = Array.from({ length: 4 }, () => randomUUID());
    const catalogQuery = `TW01catalog-${randomUUID()}`;
    for (const id of catalogSources) {
      await sql`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,starts_at,ends_at,published_at)
        values (${id}::uuid,${owner.id}::uuid,'published',${catalogQuery},'Reusable card','Reusable text',
        now()-interval '4 days',now()-interval '3 days','2026-01-01T00:00:00Z')`;
    }
    const expected =
      await sql`select id from private.proposal_templates where source_proposal_id=any(${catalogSources}::uuid[]) order by linked_at desc,id desc`;
    let cursor = {},
      observed = [];
    for (let page = 0; page < 3; page++) {
      const rows = await rpc(anonymous, "list_public_proposal_templates", {
        p_limit: 2,
        p_query: catalogQuery,
        ...cursor,
      });
      observed.push(...rows.map((row) => row.template_id));
      if (!rows.length) break;
      const last = rows.at(-1);
      cursor = {
        p_cursor_linked_at: last.linked_at,
        p_cursor_id: last.template_id,
      };
    }
    assert.deepEqual(
      observed,
      expected.map((row) => row.id),
    );
    assert.equal(new Set(observed).size, 4);

    // Removal hides the template-specific projection but leaves the independently
    // public source's canonical image download authorized. No copied ownership.
    const firstDownload = await anonymous.storage
      .from("cover-images")
      .download(coverB);
    assert.ifError(firstDownload.error);
    await sql`update private.proposal_templates set removed_at=statement_timestamp() where id=${template}::uuid`;
    assert.deepEqual(await detail(template), []);
    const removedPages = await rpc(
      anonymous,
      "list_public_proposal_template_resource_blueprints",
      { p_template_id: template, p_content_version: coherent.content_version },
    );
    assert.deepEqual(removedPages, []);
    const retainedSource = await rpc(anonymous, "get_public_proposal", {
      p_proposal_id: source,
    });
    assert.equal(retainedSource[0].cover_object_path, coverB);
    const sourceDownload = await anonymous.storage
      .from("cover-images")
      .download(coverB);
    assert.ifError(sourceDownload.error);
    const obsoleteDownload = await anonymous.storage
      .from("cover-images")
      .download(coverA);
    assert.ok(
      obsoleteDownload.error,
      "obsolete owner cover is not public media",
    );
    // The source has its own existing creator-photo context. Workshop never
    // returns photo metadata or expands that independent authorization policy.
    assert.ok(!Object.keys(coherent).some((key) => key.includes("photo")));
    assert.deepEqual(
      await rpc(owner.client, "get_own_proposal_template_baseline", {
        p_expected_creator_profile_id: owner.id,
        p_template_id: template,
      }),
      baseline,
    );
    console.log(
      "TW01 Workshop verification passed: queued publication/retries, coherent snapshots, time-only completion, paired catalog pagination, version conflict and canonical Storage boundaries.",
    );
  } finally {
    await sql.end();
  }
}

async function waitForBlocked(sql, blockerPid) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const [{ blocked }] = await sql`select exists (
      select 1 from pg_stat_activity where ${blockerPid}::integer=any(pg_blocking_pids(pid))
        and query like '%publish_proposal%'
    ) as blocked`;
    if (blocked) return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(
    "TW01 publication never queued behind the draft-save source lock.",
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await verifyProposalTemplateWorkshop();
}
