import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import postgres from "postgres";

import { signInLocalOtpUser } from "../../../scripts/lib/local-authenticated-user.mjs";
import { createConsequenceFixture } from "../../../scripts/lib/moderation-consequence-fixtures.mjs";
import { readHostingBackend } from "./local-hosting-backend.mjs";
import { privateFixtureMarkers } from "./hosting-private-fixture.mjs";

const target =
  process.argv[2] === "--disposable-modint01" ? "modint01" : "webhost01";
assert.deepEqual(
  process.argv.slice(2),
  [`--disposable-${target}`],
  "Explicit disposable WEBHOST-01 scope is required.",
);
const { apiUrl, publishableKey, databaseUrl, mailpitUrl, emailPrefix } =
  await readHostingBackend(target);
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
const users = {};

async function rpc(user, name, parameters) {
  const { data, error } = await user.client.rpc(name, parameters);
  if (error)
    throw new Error(
      `Synthetic hosting fixture ${name} failed (${error.code ?? "unknown"}).`,
    );
  return data;
}

async function report(reporter, kind, target, explanation, context = null) {
  const rows = await rpc(reporter, "submit_moderation_report", {
    p_expected_reporter_profile_id: reporter.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: explanation,
    p_target_kind: kind,
    p_target_id: target,
    p_context_kind: context ? "project" : null,
    p_context_id: context,
  });
  assert.equal(rows.length, 1);
  return rows[0].case_id;
}

async function review(caseId) {
  await rpc(users.moderator, "transition_moderation_case", {
    p_expected_staff_profile_id: users.moderator.id,
    p_case_id: caseId,
    p_expected_state_version: 0,
    p_target_state: "under_review",
  });
}

try {
  for (const role of [
    "moderator",
    "admin",
    "owner",
    "cocreator",
    "coorganizer",
    "requester",
    "unrelated",
    ...(target === "modint01" ? ["participant"] : []),
  ]) {
    const user = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: `${emailPrefix}-${role}@planets.invalid`,
      verifierName: "synthetic hosting QA",
    });
    const anchor = await user.client.from("profiles").insert({ id: user.id });
    if (anchor.error && anchor.error.code !== "23505")
      throw new Error("Hosting fixture profile anchor failed.");
    await rpc(user, "update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: `WEBHOST QA ${role}`,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    users[role] = user;
  }
  // Existing repository fixture bootstraps only disposable staff/content/membership state.
  // Reports, review transitions, notes and evidence submissions use real-session RPCs.
  const fixture = await createConsequenceFixture(
    sql,
    Object.fromEntries(
      // The browser applicant must remain photo-free. The moderation helper
      // bootstraps photo metadata for its relationship actors, not this applicant.
      Object.entries(users)
        .filter(([role]) => role !== "participant")
        .map(([role, user]) => [role, user.id]),
    ),
  );
  // A real Storage object plus canonical metadata, not a fabricated cover row.
  const coverPath = `${users.owner.id}/resources/${fixture.listingId}/${randomUUID()}.webp`;
  const coverUpload = await users.owner.client.storage
    .from("cover-images")
    .upload(
      coverPath,
      Buffer.from(
        "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
        "base64",
      ),
      { contentType: "image/webp" },
    );
  assert.ok(!coverUpload.error, "Synthetic Resource cover upload failed.");
  await rpc(users.owner, "set_own_resource_listing_cover", {
    p_expected_owner_profile_id: users.owner.id,
    p_listing_id: fixture.listingId,
    p_object_path: coverPath,
  });
  const cases = {};
  cases.profile = await report(
    users.unrelated,
    "profile",
    users.requester.id,
    "Synthetic hosting QA: reported profile, no real personal data.",
  );
  cases.project = await report(
    users.unrelated,
    "project",
    fixture.projectId,
    "Synthetic hosting QA: direct Project content report.",
  );
  cases.resource = await report(
    users.unrelated,
    "resource_listing",
    fixture.listingId,
    "Synthetic hosting QA: direct Resource listing content report.",
  );
  cases.self = await report(
    users.unrelated,
    "profile",
    users.admin.id,
    "Synthetic hosting QA: admin is the subject, self-suspension forbidden.",
  );
  for (const id of Object.values(cases)) await review(id);
  cases.received = await report(
    users.unrelated,
    "profile",
    users.requester.id,
    "Synthetic hosting QA: unreviewed received case remains distinct.",
  );
  for (let index = 0; index < 28; index++) {
    await report(
      users.unrelated,
      "profile",
      users.requester.id,
      `Synthetic hosting QA queue item ${index + 1}. Each report creates a separate case in the current domain; do not invent report aggregation.`,
    );
  }
  for (let index = 0; index < 8; index++) {
    await rpc(users.moderator, "add_moderation_case_note", {
      p_expected_staff_profile_id: users.moderator.id,
      p_case_id: cases.profile,
      p_body: `${privateFixtureMarkers.notes[index]} ${"Local review context, no real personal data. ".repeat(24)}`,
    });
  }

  for (const role of ["requester", "unrelated", "cocreator"]) {
    const requestId = randomUUID();
    await sql`insert into public.project_join_requests(id, project_id, requester_profile_id, status, resolved_at, resolved_by_profile_id)
      values(${requestId}::uuid, ${fixture.projectId}::uuid, ${users[role].id}::uuid, 'accepted', statement_timestamp(), ${users.owner.id}::uuid)`;
    await sql`insert into public.project_memberships(project_id, participant_profile_id, originating_request_id, joined_at)
      values(${fixture.projectId}::uuid, ${users[role].id}::uuid, ${requestId}::uuid, statement_timestamp())`;
  }
  cases.corroboration = await report(
    users.unrelated,
    "profile",
    users.requester.id,
    "Synthetic hosting QA: Project-context report with private witness evidence.",
    fixture.projectId,
  );
  const pending = await rpc(
    users.cocreator,
    "list_own_group_corroboration_requests",
    {
      p_expected_recipient_profile_id: users.cocreator.id,
      p_pending_only: true,
      p_limit: 20,
      p_before_created_at: null,
      p_before_request_id: null,
    },
  );
  const witness = pending.find((row) => row.case_id === cases.corroboration);
  assert.ok(witness, "Missing synthetic corroboration request.");
  await rpc(users.cocreator, "submit_group_corroboration_response", {
    p_expected_recipient_profile_id: users.cocreator.id,
    p_request_id: witness.request_id,
    p_client_submission_id: randomUUID(),
    p_choice: "unsure",
    p_explanation: privateFixtureMarkers.witness,
  });
  await review(cases.corroboration);

  const resourceRequest = randomUUID();
  await sql`insert into public.resource_listing_requests(id, listing_id, requester_profile_id, status, resolved_at, resolved_by_profile_id)
    values(${resourceRequest}::uuid, ${fixture.listingId}::uuid, ${users.requester.id}::uuid, 'accepted', statement_timestamp(), ${users.owner.id}::uuid)`;
  cases.counterstatement = await report(
    users.owner,
    "resource_request",
    resourceRequest,
    "Synthetic hosting QA: accepted Resource-request counterparty report.",
  );
  const evidence = await rpc(
    users.requester,
    "list_own_moderation_evidence_requests",
    {
      p_expected_recipient_profile_id: users.requester.id,
      p_pending_only: true,
      p_limit: 20,
    },
  );
  const counterstatement = evidence.find(
    (row) => row.request_kind === "resource_counterstatement",
  );
  assert.ok(counterstatement, "Missing synthetic counterstatement request.");
  const assigned = await rpc(
    users.requester,
    "get_own_resource_counterstatement_request",
    {
      p_expected_recipient_profile_id: users.requester.id,
      p_request_id: counterstatement.request_id,
    },
  );
  assert.equal(
    assigned[0]?.case_id,
    cases.counterstatement,
    "Wrong synthetic evidence case.",
  );
  await rpc(users.requester, "submit_resource_counterstatement", {
    p_expected_recipient_profile_id: users.requester.id,
    p_request_id: counterstatement.request_id,
    p_client_submission_id: randomUUID(),
    p_statement: privateFixtureMarkers.counterstatement,
  });
  await review(cases.counterstatement);

  if (target === "modint01") {
    const [link] = await rpc(
      users.owner,
      "create_project_participant_invitation",
      {
        p_expected_profile_id: users.owner.id,
        p_project_id: fixture.projectId,
      },
    );
    await writeFile(
      new URL(
        "../../../supabase/.temp/modint01-browser-fixture.json",
        import.meta.url,
      ),
      JSON.stringify({
        token: link.invite_token,
        projectId: fixture.projectId,
        cases,
        participantId: users.participant.id,
      }),
    );
    console.log(
      "MODINT01 participant token retained only in ignored supabase/.temp/modint01-browser-fixture.json; never publish it or invitation URLs.",
    );
  }

  console.log(
    JSON.stringify({
      synthetic: true,
      projectId: fixture.projectId,
      listingId: fixture.listingId,
      coverPath,
      cases,
      profiles: Object.fromEntries(
        Object.entries(users).map(([role, user]) => [role, user.id]),
      ),
      reportsCreated: 35,
      notesOnProfileCase: 8,
      queuePageSize: 25,
    }),
  );
  console.log(
    `Use browser OTP for ${emailPrefix}-moderator@planets.invalid and ${emailPrefix}-admin@planets.invalid. No tokens or passwords were recorded. Re-running adds a new disposable fixture set.`,
  );
} catch (error) {
  console.error(
    `Synthetic hosting fixture failed: ${error instanceof postgres.PostgresError ? `local SQL bootstrap (${error.code})` : error.message}`,
  );
  process.exitCode = 1;
} finally {
  await sql.end({ timeout: 2 });
}
