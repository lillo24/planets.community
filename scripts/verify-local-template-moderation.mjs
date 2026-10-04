import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Standalone and moderation:verify:local/hosted Database validation. Synthetic
// local fixtures only; no remote credentials, reset, or production command.
export async function verifyTemplateModeration() {
  const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
    process.cwd(),
  );
  const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
  for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
    if (
      !url ||
      !["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname)
    )
      throw new Error(
        "TW02 verifier requires local-only API/database/Mailpit URLs.",
      );
  }
  const sql = postgres(databaseUrl, { max: 8, onnotice: () => {} });
  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const users = await Promise.all(
    ["owner", "reporter", "staff", "admin", "incomplete"].map((role) =>
      signInLocalOtpUser({
        apiUrl,
        publishableKey,
        mailpitUrl,
        email: "tw02-" + role + "@planets.invalid",
        verifierName: "TW02 " + role,
      }),
    ),
  );
  const [owner, reporter, staff, admin, incomplete] = users;
  let checks = 0;
  const equal = (actual, expected, label) => {
    assert.deepEqual(actual, expected, label);
    checks++;
  };
  async function rpc(client, name, args) {
    const { data, error } = await client.rpc(name, args);
    if (error)
      throw new Error(
        "TW02 " + name + " failed: " + error.code + " " + error.message,
      );
    return data;
  }
  async function denied(client, name, args, code) {
    const { error } = await client.rpc(name, args);
    equal(error?.code, code, name + " rejects unauthorized/invalid request");
  }
  async function counts() {
    const [r] =
      await sql`select (select count(*)::int from private.moderation_cases) as cases,
      (select count(*)::int from private.moderation_reports) as reports,
      (select count(*)::int from private.moderation_case_events) as events,
      (select count(*)::int from private.moderation_evidence_requests where request_kind='group_corroboration') as corroboration,
      (select count(*)::int from private.moderation_evidence_requests where request_kind='resource_counterstatement') as counterstatement,
      (select count(*)::int from private.outbox_events) as outbox,
      (select count(*)::int from public.notifications) as notifications`;
    return r;
  }
  const reportArgs = (actor, template, id = randomUUID()) => ({
    p_expected_reporter_profile_id: actor.id,
    p_client_submission_id: id,
    p_category: "other",
    p_explanation: "TW02 private report requiring manual review.",
    p_target_kind: "proposal_template",
    p_target_id: template,
    p_context_kind: null,
    p_context_id: null,
  });
  const reviewArgs = (actor, caseId) => ({
    p_expected_staff_profile_id: actor.id,
    p_case_id: caseId,
  });
  async function review(actor, caseId) {
    return (
      await rpc(
        actor.client,
        "get_moderation_case_template",
        reviewArgs(actor, caseId),
      )
    )[0];
  }
  const removeArgs = (actor, caseId, template, token, id = randomUUID()) => ({
    ...reviewArgs(actor, caseId),
    p_template_id: template,
    p_client_request_id: id,
    p_reviewed_content_version: token,
    p_reason: "TW02 protected explicit removal reason.",
  });
  async function source(title, publish = true) {
    const [{ id: skillId }] =
      await sql`select id from public.skills order by id limit 1`;
    const sourceId = await rpc(owner.client, "create_proposal_draft", {
      p_expected_creator_profile_id: owner.id,
      p_title: title,
      p_summary: "Reusable summary",
      p_description: "TW02_BOZZA_PRIVATE",
      p_starts_at: new Date(Date.now() + 172800000).toISOString(),
      p_ends_at: new Date(Date.now() + 180000000).toISOString(),
      p_event_timezone: "Europe/Rome",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "TN",
      p_public_location_label: "Trento",
      p_exact_meeting_text: "TW02_PRIVATE_MEETING",
      p_exact_location_visibility: "participants",
      p_skill_ids: [skillId],
      p_skill_importances: ["required"],
      p_registration_capacity: 8,
      p_count_organizers_toward_capacity: false,
    });
    if (!publish) return { sourceId, template: null };
    await rpc(owner.client, "publish_proposal", {
      p_expected_creator_profile_id: owner.id,
      p_proposal_id: sourceId,
    });
    await sql`update public.proposals set description='TW02 published reusable content' where id=${sourceId}::uuid`;
    const [{ id }] =
      await sql`select id from private.proposal_templates where source_proposal_id=${sourceId}::uuid`;
    return { sourceId, template: id };
  }
  async function complete(sourceId) {
    await sql`update public.proposals set starts_at=clock_timestamp()-interval '27 hours', ends_at=clock_timestamp()-interval '25 hours' where id=${sourceId}::uuid`;
  }
  try {
    for (const [i, user] of users.entries()) {
      await sql`insert into public.profiles(id,display_name) values (${user.id}::uuid,${i === 4 ? null : "TW02 " + i}) on conflict(id) do update set display_name=excluded.display_name`;
    }
    await ensureLocalProfilePhoto(owner);
    for (const [actor, role] of [
      [staff, "moderator"],
      [admin, "admin"],
    ])
      await sql`insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at) values(${actor.id}::uuid,${role},true,null) on conflict(profile_id) do update set is_active=true,deactivated_at=null,staff_role=excluded.staff_role`;
    const primary = await source("TW02 removal target");
    const future = await source("TW02 pre-completed target");
    const cancelled = await source("TW02 cancelled target");
    await sql`update public.proposals set lifecycle_state='cancelled',cancelled_at=clock_timestamp() where id=${cancelled.sourceId}::uuid`;
    const draft = await source("TW02 independent draft", false);
    const coverPath =
      owner.id + "/projects/" + primary.sourceId + "/" + randomUUID() + ".webp";
    const { error: uploadError } = await owner.client.storage
      .from("cover-images")
      .upload(
        coverPath,
        Buffer.from(
          "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
          "base64",
        ),
        { contentType: "image/webp" },
      );
    if (uploadError)
      throw new Error("TW02 cover fixture upload failed: " + uploadError.code);
    await rpc(owner.client, "set_own_project_cover", {
      p_expected_creator_profile_id: owner.id,
      p_project_id: primary.sourceId,
      p_object_path: coverPath,
    });
    await complete(primary.sourceId);
    const needs = [];
    for (let i = 0; i < 23; i++) {
      const id = randomUUID();
      needs.push(id);
      await sql`insert into public.project_resource_needs(id,project_id,title,details) values(${id}::uuid,${primary.sourceId}::uuid,${"TW02 need " + i},'Reusable need details')`;
    }
    const beforeInvalid = await counts();
    for (const template of [
      randomUUID(),
      future.template,
      cancelled.template,
      draft.sourceId,
    ])
      await denied(
        reporter.client,
        "submit_moderation_report",
        reportArgs(reporter, template),
        "42501",
      );
    await denied(
      reporter.client,
      "submit_moderation_report",
      {
        ...reportArgs(reporter, primary.template),
        p_context_kind: "project",
        p_context_id: primary.sourceId,
      },
      "22023",
    );
    await denied(
      reporter.client,
      "submit_moderation_report",
      {
        ...reportArgs(reporter, primary.template),
        p_expected_reporter_profile_id: owner.id,
      },
      "42501",
    );
    await denied(
      incomplete.client,
      "submit_moderation_report",
      reportArgs(incomplete, primary.template),
      "42501",
    );
    await denied(
      anonymous,
      "submit_moderation_report",
      reportArgs(reporter, primary.template),
      "42501",
    );
    await denied(
      owner.client,
      "submit_moderation_report",
      {
        ...reportArgs(owner, primary.template),
        p_target_kind: "project",
        p_target_id: primary.sourceId,
      },
      "22023",
    );
    equal(
      await counts(),
      beforeInvalid,
      "invalid reports have no side effects",
    );
    const acceptedArgs = reportArgs(reporter, primary.template);
    const [deliveryA, deliveryB] = await Promise.all([
      rpc(reporter.client, "submit_moderation_report", acceptedArgs),
      rpc(reporter.client, "submit_moderation_report", acceptedArgs),
    ]);
    equal(
      deliveryA,
      deliveryB,
      "concurrent exact report delivery has one receipt",
    );
    const caseId = deliveryA[0].case_id;
    const selfArgs = reportArgs(owner, primary.template);
    const selfReport = (
      await rpc(owner.client, "submit_moderation_report", selfArgs)
    )[0];
    const afterReport = await counts();
    equal(
      afterReport.cases - beforeInvalid.cases,
      2,
      "other-user and Creator reports each establish one case",
    );
    equal(
      afterReport.reports - beforeInvalid.reports,
      2,
      "one report per accepted submission",
    );
    equal(
      afterReport.events - beforeInvalid.events,
      2,
      "one received event per report",
    );
    for (const key of [
      "corroboration",
      "counterstatement",
      "outbox",
      "notifications",
    ])
      equal(afterReport[key], beforeInvalid[key], "no " + key + " side effect");
    const [selfCase] =
      await sql`select subject_profile_id,project_context_id,resource_request_context_id,template_source_proposal_id from private.moderation_cases where id=${selfReport.case_id}::uuid`;
    equal(
      selfCase,
      {
        subject_profile_id: owner.id,
        project_context_id: null,
        resource_request_context_id: null,
        template_source_proposal_id: primary.sourceId,
      },
      "Creator remains subject with independent source provenance",
    );
    for (const changes of [
      { p_explanation: "Different sufficiently long explanation" },
      { p_target_id: future.template },
      { p_category: "spam" },
      { p_target_kind: "profile", p_target_id: owner.id },
    ])
      await denied(
        reporter.client,
        "submit_moderation_report",
        { ...acceptedArgs, ...changes },
        "22023",
      );
    for (const actor of [reporter, owner])
      await denied(
        actor.client,
        "get_moderation_case_template",
        reviewArgs(actor, caseId),
        "42501",
      );
    await denied(
      anonymous,
      "get_moderation_case_template",
      reviewArgs(staff, caseId),
      "42501",
    );
    const initial = await review(staff, caseId);
    equal(initial.content_changed, false, "report/current token matches");
    equal(
      initial.resource_blueprint_count,
      23,
      "complete need count is separate from bounded content",
    );
    equal(
      Object.keys(initial.content).sort(),
      [
        "title",
        "summary",
        "description",
        "skills",
        "registration_capacity_recommendation",
        "duration_seconds",
        "cover_object_path",
      ].sort(),
      "staff content has exactly the published scalar/skill allow-list",
    );
    equal(
      JSON.stringify(initial).includes("BOZZA_PRIVATE"),
      false,
      "no Bozza content in staff projection",
    );
    equal(
      JSON.stringify(initial).includes("PRIVATE_MEETING"),
      false,
      "no private meeting in staff projection",
    );
    const pageArgs = {
      ...reviewArgs(staff, caseId),
      p_content_version: initial.current_content_version,
      p_limit: 20,
      p_cursor_need_id: null,
    };
    const firstPage = await rpc(
      staff.client,
      "list_moderation_case_template_blueprints",
      pageArgs,
    );
    const secondPage = await rpc(
      staff.client,
      "list_moderation_case_template_blueprints",
      { ...pageArgs, p_cursor_need_id: firstPage.at(-1).source_need_id },
    );
    equal(
      [
        firstPage.length,
        secondPage.length,
        new Set([...firstPage, ...secondPage].map((r) => r.source_need_id))
          .size,
      ],
      [20, 3, 23],
      "staff resource pagination is bounded without duplicates",
    );
    await denied(
      staff.client,
      "list_moderation_case_template_blueprints",
      { ...pageArgs, p_limit: 51 },
      "22023",
    );
    const staleAction = removeArgs(
      staff,
      caseId,
      primary.template,
      initial.current_content_version,
    );
    await sql`update public.proposals set summary='Changed reusable summary' where id=${primary.sourceId}::uuid`;
    await denied(
      staff.client,
      "remove_moderation_case_template",
      staleAction,
      "PT409",
    );
    await denied(
      staff.client,
      "list_moderation_case_template_blueprints",
      pageArgs,
      "PT409",
    );
    let current = await review(staff, caseId);
    equal(
      current.content_changed,
      true,
      "changed content is reported truthfully",
    );
    async function waitBehindSource(pid) {
      const deadline = Date.now() + 5000;
      while (Date.now() < deadline) {
        const [{ blocked }] =
          await sql`select exists(select 1 from pg_stat_activity where ${pid}=any(pg_blocking_pids(pid))) as blocked`;
        if (blocked) return;
        await new Promise((resolve) => setTimeout(resolve, 25));
      }
      throw new Error("TW02 removal did not wait behind the source lock.");
    }
    let waiting;
    await sql.begin(async (tx) => {
      const [{ pid }] = await tx`select pg_backend_pid() as pid`;
      await tx`select id from public.proposals where id=${primary.sourceId}::uuid for update`;
      waiting = staff.client
        .rpc(
          "remove_moderation_case_template",
          removeArgs(
            staff,
            caseId,
            primary.template,
            current.current_content_version,
          ),
        )
        .then((result) => result);
      await waitBehindSource(pid);
      await tx`update public.proposals set summary='Content committed while removal waited' where id=${primary.sourceId}::uuid`;
    });
    equal(
      (await waiting).error?.code,
      "PT409",
      "removal rechecks token after waiting behind a committed source change",
    );
    current = await review(staff, caseId);
    await sql.begin(async (tx) => {
      const [{ pid }] = await tx`select pg_backend_pid() as pid`;
      await tx`select id from public.proposals where id=${primary.sourceId}::uuid for update`;
      waiting = staff.client
        .rpc(
          "remove_moderation_case_template",
          removeArgs(
            staff,
            caseId,
            primary.template,
            current.current_content_version,
          ),
        )
        .then((result) => result);
      await waitBehindSource(pid);
      await sql`update private.moderation_staff_roles set is_active=false,deactivated_at=clock_timestamp() where profile_id=${staff.id}::uuid`;
    });
    equal(
      (await waiting).error?.code,
      "42501",
      "staff revocation while waiting denies removal",
    );
    await sql`update private.moderation_staff_roles set is_active=true,deactivated_at=null where profile_id=${staff.id}::uuid`;
    const removal = removeArgs(
      staff,
      caseId,
      primary.template,
      current.current_content_version,
    );
    await denied(
      owner.client,
      "remove_moderation_case_template",
      { ...removal, p_expected_staff_profile_id: owner.id },
      "42501",
    );
    await denied(
      staff.client,
      "remove_moderation_case_template",
      { ...removal, p_expected_staff_profile_id: admin.id },
      "42501",
    );
    await denied(
      staff.client,
      "remove_moderation_case_template",
      { ...removal, p_template_id: future.template },
      "42501",
    );
    await denied(
      staff.client,
      "remove_moderation_case_template",
      { ...removal, p_case_id: randomUUID() },
      "42501",
    );
    await denied(
      anonymous,
      "remove_moderation_case_template",
      removal,
      "42501",
    );
    // Inject a failure at the audit write in an authenticated RPC transaction.
    // All trigger/test changes are transaction-scoped and rolled back together.
    await sql.begin(async (tx) => {
      await tx.unsafe(
        "create function pg_temp.tw02_fail_audit() returns trigger language plpgsql as $$ begin if new.action='moderation.template_removed' then raise exception 'TW02 injected audit failure' using errcode='P0001'; end if; return new; end; $$",
      );
      await tx.unsafe(
        "create trigger tw02_fail_audit before insert on private.audit_events for each row execute function pg_temp.tw02_fail_audit()",
      );
      let failed = false;
      try {
        await tx.savepoint(async (nested) => {
          await nested`select set_config('request.jwt.claim.sub',${staff.id},true)`;
          await nested.unsafe("set local role authenticated");
          await nested`select * from public.remove_moderation_case_template(${staff.id}::uuid,${caseId}::uuid,${primary.template}::uuid,${randomUUID()}::uuid,${current.current_content_version},'Injected rollback reason')`;
        });
      } catch (error) {
        if (error.code !== "P0001") throw error;
        failed = true;
      }
      equal(
        failed,
        true,
        "injected failure reaches real authenticated RPC audit boundary",
      );
      const [rollback] =
        await tx`select removed_at,(select count(*)::int from private.proposal_template_removal_actions where template_id=${primary.template}::uuid) as actions from private.proposal_templates where id=${primary.template}::uuid`;
      equal(
        rollback,
        { removed_at: null, actions: 0 },
        "failed audit rolls back removal/reason/action",
      );
      await tx.unsafe("drop trigger tw02_fail_audit on private.audit_events");
    });
    const sourceSnapshot = (
      await sql`select to_jsonb(p) as data from public.proposals p where id=${primary.sourceId}::uuid`
    )[0].data;
    const adminRemoval = removeArgs(
      admin,
      selfReport.case_id,
      primary.template,
      current.current_content_version,
    );
    const [resultA, resultB] = await Promise.all([
      rpc(staff.client, "remove_moderation_case_template", removal),
      rpc(admin.client, "remove_moderation_case_template", adminRemoval),
    ]);
    equal(
      [resultA[0].outcome, resultB[0].outcome].sort(),
      ["already_removed", "removed"],
      "different staff/cases serialize to one effective removal",
    );
    equal(
      resultA[0].effective_action_id,
      resultB[0].effective_action_id,
      "both receipts refer to one action",
    );
    equal(
      resultA[0].effective_at,
      resultB[0].effective_at,
      "later staff cannot rewrite effective time",
    );
    equal(
      resultA[0].effective_actor_profile_id,
      resultB[0].effective_actor_profile_id,
      "later staff cannot claim original attribution",
    );
    equal(
      await rpc(staff.client, "remove_moderation_case_template", removal),
      resultA,
      "same staff request recovers exact receipt",
    );
    equal(
      await rpc(admin.client, "remove_moderation_case_template", adminRemoval),
      resultB,
      "already-removed request also recovers exact receipt",
    );
    await denied(
      staff.client,
      "remove_moderation_case_template",
      { ...removal, p_reason: "Changed protected removal reason" },
      "22023",
    );
    const [consequences] =
      await sql`select (select count(*)::int from private.proposal_template_removal_actions where template_id=${primary.template}::uuid and outcome='removed') as effective,
      (select count(*)::int from private.audit_events where action='moderation.template_removed' and target_id=${primary.template}::uuid) as audit`;
    equal(
      consequences,
      { effective: 1, audit: 1 },
      "only one effective protected action/audit",
    );
    equal(
      await rpc(reporter.client, "submit_moderation_report", acceptedArgs),
      deliveryA,
      "accepted report retry succeeds after removal",
    );
    equal(
      (await rpc(owner.client, "submit_moderation_report", selfArgs))[0]
        .report_id,
      selfReport.report_id,
      "self-report retry succeeds after removal",
    );
    const beforeRemovedReport = await counts();
    await denied(
      reporter.client,
      "submit_moderation_report",
      reportArgs(reporter, primary.template),
      "42501",
    );
    equal(
      await counts(),
      beforeRemovedReport,
      "new report after removal has no side effects",
    );
    for (const client of [anonymous, reporter.client]) {
      equal(
        await rpc(client, "get_public_proposal_template", {
          p_template_id: primary.template,
        }),
        [],
        "removed public detail has no cover/token/content",
      );
      equal(
        await rpc(client, "list_public_proposal_template_resource_blueprints", {
          p_template_id: primary.template,
          p_content_version: current.current_content_version,
          p_limit: 20,
        }),
        [],
        "old blueprint token cannot read removed template",
      );
      for (const filters of [
        {},
        { p_query: "TW02 removal" },
        { p_skill_ids: [initial.content.skills[0].id] },
      ])
        equal(
          (
            await rpc(client, "list_public_proposal_templates", {
              p_limit: 50,
              ...filters,
            })
          ).some((r) => r.template_id === primary.template),
          false,
          "removed template absent from catalog/filter/search",
        );
    }
    const afterReview = await review(staff, caseId);
    equal(
      afterReview.publicly_available,
      false,
      "staff sees removed availability",
    );
    equal(
      afterReview.removal_action.action_id,
      resultA[0].effective_action_id,
      "staff sees effective typed action timeline",
    );
    equal(
      afterReview.content.cover_object_path,
      coverPath,
      "source lawful cover is still source-authorized",
    );
    const { error: downloadError } = await anonymous.storage
      .from("cover-images")
      .download(coverPath);
    equal(downloadError, null, "public source Storage delivery unchanged");
    equal(
      (
        await sql`select to_jsonb(p) as data from public.proposals p where id=${primary.sourceId}::uuid`
      )[0].data,
      sourceSnapshot,
      "removal leaves source Proposal unchanged",
    );
    equal(
      (
        await sql`select lifecycle_state from public.proposals where id=${draft.sourceId}::uuid`
      )[0].lifecycle_state,
      "draft",
      "independent draft unchanged",
    );
    equal(
      (
        await sql`select removed_at from private.proposal_templates where id=${future.template}::uuid`
      )[0].removed_at,
      null,
      "another template unchanged",
    );
    equal(
      (
        await rpc(owner.client, "get_own_proposal_template_baseline", {
          p_expected_creator_profile_id: owner.id,
          p_template_id: primary.template,
        })
      )[0].description,
      "TW02_BOZZA_PRIVATE",
      "original Creator retains private baseline",
    );
    for (const actor of [staff, reporter])
      await denied(
        actor.client,
        "get_own_proposal_template_baseline",
        {
          p_expected_creator_profile_id: actor.id,
          p_template_id: primary.template,
        },
        "42501",
      );
    const own = await rpc(reporter.client, "list_own_moderation_reports", {
      p_expected_reporter_profile_id: reporter.id,
      p_limit: 50,
    });
    equal(
      own.find((r) => r.case_id === caseId).target_kind,
      "proposal_template",
      "safe own-report parser vocabulary",
    );
    equal(
      JSON.stringify(own).includes("protected explicit removal"),
      false,
      "reporter cannot see removal reason",
    );
    equal(
      JSON.stringify(own).includes("BOZZA_PRIVATE"),
      false,
      "reporter cannot see private baseline",
    );
    let version = 0;
    for (const state of ["under_review", "completed", "under_review"]) {
      await rpc(staff.client, "transition_moderation_case", {
        ...reviewArgs(staff, caseId),
        p_expected_state_version: version++,
        p_target_state: state,
      });
      equal(
        (await review(staff, caseId)).removed_at,
        afterReview.removed_at,
        "case transition neither removes nor restores",
      );
    }
    const legacyCase = (
      await rpc(reporter.client, "submit_moderation_report", {
        ...reportArgs(reporter, future.template),
        p_target_kind: "project",
        p_target_id: future.sourceId,
      })
    )[0];
    await denied(
      staff.client,
      "remove_moderation_case_template",
      {
        ...removeArgs(
          staff,
          legacyCase.case_id,
          future.template,
          current.current_content_version,
        ),
      },
      "42501",
    );
    await complete(future.sourceId);
    const hiddenCase = (
      await rpc(
        reporter.client,
        "submit_moderation_report",
        reportArgs(reporter, future.template),
      )
    )[0];
    await sql`update public.proposals set lifecycle_state='cancelled',cancelled_at=clock_timestamp() where id=${future.sourceId}::uuid`;
    equal(
      await rpc(anonymous, "get_public_proposal_template", {
        p_template_id: future.template,
      }),
      [],
      "source visibility loss still closes public template reads",
    );
    const hiddenReview = await review(staff, hiddenCase.case_id);
    equal(
      hiddenReview.publicly_available,
      false,
      "staff sees source-unavailable template truthfully",
    );
    equal(
      hiddenReview.content.cover_object_path,
      null,
      "hidden source grants no staff cover override",
    );
    equal(
      hiddenReview.content.description,
      "TW02 published reusable content",
      "staff retains only current published content after visibility loss",
    );
    await denied(
      reporter.client,
      "submit_moderation_report",
      reportArgs(reporter, future.template),
      "42501",
    );
    equal(
      (
        await rpc(
          staff.client,
          "remove_moderation_case_template",
          removeArgs(
            staff,
            hiddenCase.case_id,
            future.template,
            hiddenReview.current_content_version,
          ),
        )
      )[0].outcome,
      "removed",
      "staff can explicitly remove an already source-unavailable template",
    );
    const [privateLeaks] =
      await sql`select count(*)::int as count from private.audit_events
      where metadata::text like any(array['%TW02 private report%', '%TW02 protected explicit%', '%TW02_BOZZA_PRIVATE%'])`;
    equal(
      privateLeaks.count,
      0,
      "generic audit metadata contains no report/reason/private baseline bodies",
    );
    await sql`update private.moderation_staff_roles set is_active=false,deactivated_at=clock_timestamp() where profile_id=${staff.id}::uuid`;
    await denied(
      staff.client,
      "remove_moderation_case_template",
      removal,
      "42501",
    );
    await denied(
      staff.client,
      "get_moderation_case_template",
      reviewArgs(staff, caseId),
      "42501",
    );
    console.log(
      "TW02 verified " +
        checks +
        " authenticated API/concurrency/privacy/rollback assertions locally.",
    );
  } finally {
    await sql.end({ timeout: 2 });
  }
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1])
  await verifyTemplateModeration();
