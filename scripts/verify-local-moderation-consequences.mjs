import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { createConsequenceFixture } from "./lib/moderation-consequence-fixtures.mjs";

const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
if (
  !databaseUrl ||
  !/^https?:\/\/(127\.0\.0\.1|localhost)(:|\/)/u.test(apiUrl)
) {
  throw new Error(
    "Consequence verifier requires an explicit local Supabase stack.",
  );
}
const sql = postgres(databaseUrl, { max: 2, onnotice: () => {} });
const users = {};
const roles = [
  "moderator",
  "admin",
  "owner",
  "cocreator",
  "coorganizer",
  "requester",
  "member",
  "resourceOwner",
  "resourceRequester",
  "unrelated",
];
const publicClient = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const coverPaths = [];
try {
  for (const role of roles) {
    const user = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
      email: `consequence-${role.toLowerCase()}@planets.invalid`,
      verifierName: `consequence ${role}`,
    });
    const anchor = await user.client.from("profiles").insert({ id: user.id });
    if (anchor.error && anchor.error.code !== "23505")
      throw safeFailure("create profile", anchor.error);
    await rpc(user, "update_own_profile", {
      p_expected_profile_id: user.id,
      p_display_name: `Consequence ${role}`,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "private",
    });
    users[role] = user;
  }
  const fixture = await createConsequenceFixture(
    sql,
    Object.fromEntries(roles.map((role) => [role, users[role].id])),
  );
  const pendingProject = await projectRequest(
    users.requester,
    fixture.projectId,
  );
  const pendingResource = await resourceRequest(
    users.requester,
    fixture.listingId,
  );
  const memberProject = await projectRequest(users.member, fixture.projectId);
  const memberResource = await resourceRequest(users.member, fixture.listingId);
  await rpc(users.owner, "accept_project_join_request", {
    p_expected_creator_profile_id: users.owner.id,
    p_request_id: memberProject,
  });
  await rpc(users.resourceOwner, "accept_resource_listing_request", {
    p_expected_owner_profile_id: users.resourceOwner.id,
    p_request_id: memberResource,
  });
  await rpc(users.owner, "set_project_shared_workspace", {
    p_expected_manager_profile_id: users.owner.id,
    p_project_id: fixture.projectId,
    p_workspace_url: "https://example.invalid/moderation-verifier",
  });
  const args = {
    p_case_id: fixture.cases.profile,
    p_consequence_type: "safety_notice",
    p_user_reason: "Synthetic affected-user reason",
    p_internal_note: "Synthetic private staff note",
  };
  await denied(
    users.unrelated,
    "apply_moderation_consequence",
    { ...args, p_expected_staff_profile_id: users.unrelated.id },
    "42501",
  );
  await denied(
    users.moderator,
    "apply_moderation_consequence",
    { ...args, p_expected_staff_profile_id: users.admin.id },
    "42501",
  );
  const notice = await apply(
    users.moderator,
    fixture.cases.profile,
    "safety_notice",
  );
  await denied(
    users.admin,
    "apply_moderation_consequence",
    { ...args, p_expected_staff_profile_id: users.admin.id },
    "PT409",
  );
  await revoke(users.admin, notice);
  const restriction = await apply(
    users.admin,
    fixture.cases.profile,
    "interaction_restriction",
  );
  const subjectHistory = await rpc(
    users.requester,
    "list_own_moderation_consequences",
    {
      p_expected_profile_id: users.requester.id,
    },
  );
  assert.ok(
    subjectHistory.some(
      (row) => row.consequence_id === notice && !row.is_active,
    ),
  );
  assert.ok(
    subjectHistory.some(
      (row) => row.consequence_id === restriction && row.is_active,
    ),
  );
  await denied(
    users.requester,
    "list_own_moderation_consequences",
    {
      p_expected_profile_id: users.owner.id,
    },
    "42501",
  );
  const [projectState] =
    await sql`select status from public.project_join_requests where id=${pendingProject}::uuid`;
  const [resourceState] =
    await sql`select status from public.resource_listing_requests where id=${pendingResource}::uuid`;
  assert.equal(projectState.status, "withdrawn");
  assert.equal(resourceState.status, "withdrawn");
  await denied(
    users.requester,
    "request_to_join_project",
    {
      p_expected_requester_profile_id: users.requester.id,
      p_project_id: fixture.projectId,
    },
    "PT409",
  );
  await denied(
    users.requester,
    "request_resource_listing",
    {
      p_expected_requester_profile_id: users.requester.id,
      p_listing_id: fixture.listingId,
    },
    "PT409",
  );
  for (const role of ["owner", "cocreator", "coorganizer"]) {
    const user = users[role];
    const name =
      role === "owner"
        ? "accept_project_join_request"
        : "accept_project_join_request_as_manager";
    const identity =
      role === "owner"
        ? "p_expected_creator_profile_id"
        : "p_expected_manager_profile_id";
    for (const triaged of [false, true]) {
      await denied(
        user,
        name,
        {
          [identity]: user.id,
          p_request_id: pendingProject,
          ...(triaged
            ? Object.fromEntries(
                [
                  "p_needed_skill_ids",
                  "p_already_found_skill_ids",
                  "p_extra_skill_ids",
                  "p_needed_resource_need_ids",
                  "p_already_found_resource_need_ids",
                  "p_extra_resource_need_ids",
                ].map((key) => [key, []]),
              )
            : {}),
        },
        "PT409",
      );
    }
  }
  await revoke(users.moderator, restriction);
  const hiddenPendingProject = await projectRequest(
    users.unrelated,
    fixture.projectId,
  );
  const hiddenPendingResource = await resourceRequest(
    users.resourceRequester,
    fixture.listingId,
  );
  for (const [resource, owner] of [
    [false, users.owner],
    [true, users.resourceOwner],
  ]) {
    const parent = resource ? fixture.listingId : fixture.projectId;
    const path = `${owner.id}/${resource ? "resources" : "projects"}/${parent}/${randomUUID()}.webp`;
    const bytes = Buffer.from(
      "UklGRhwAAABXRUJQVlA4IBAAAACwAQCdASoBAAEAAUAmJQBOgCHAAAD+8AAA",
      "base64",
    );
    const upload = await owner.client.storage
      .from("cover-images")
      .upload(path, bytes, { contentType: "image/webp" });
    if (upload.error) throw safeFailure("upload synthetic cover", upload.error);
    coverPaths.push({ owner, path });
    await rpc(
      owner,
      resource ? "set_own_resource_listing_cover" : "set_own_project_cover",
      {
        [resource
          ? "p_expected_owner_profile_id"
          : "p_expected_creator_profile_id"]: owner.id,
        [resource ? "p_listing_id" : "p_project_id"]: parent,
        p_object_path: path,
      },
    );
    const initial = await publicClient.storage
      .from("cover-images")
      .download(path);
    assert.ok(
      !initial.error && initial.data,
      "Visible canonical cover can be downloaded",
    );
  }
  const projectHide = await apply(
    users.moderator,
    fixture.cases.project,
    "content_hide",
  );
  const resourceHide = await apply(
    users.moderator,
    fixture.cases.resource_listing,
    "content_hide",
  );
  assert.deepEqual(
    await rpc(publicClient, "get_public_proposal", {
      p_proposal_id: fixture.projectId,
    }),
    [],
  );
  assert.deepEqual(
    await rpc(publicClient, "get_public_resource_listing", {
      p_listing_id: fixture.listingId,
    }),
    [],
  );
  for (const { path, owner } of coverPaths) {
    const hidden = await publicClient.storage
      .from("cover-images")
      .download(path);
    assert.ok(
      hidden.error,
      "Known hidden cover path is denied over actual HTTP Storage",
    );
    const own = await owner.client.storage.from("cover-images").download(path);
    assert.ok(!own.error && own.data, "Owner retains hidden cover access");
  }
  const ownProject = await rpc(
    users.owner,
    "list_own_moderation_consequences",
    { p_expected_profile_id: users.owner.id },
  );
  const ownResource = await rpc(
    users.resourceOwner,
    "list_own_moderation_consequences",
    { p_expected_profile_id: users.resourceOwner.id },
  );
  assert.ok(ownProject.some((row) => row.consequence_id === projectHide));
  assert.ok(ownResource.some((row) => row.consequence_id === resourceHide));
  for (const role of ["cocreator", "coorganizer", "unrelated"]) {
    const own = await rpc(users[role], "list_own_moderation_consequences", {
      p_expected_profile_id: users[role].id,
    });
    assert.ok(
      !own.some(
        (row) =>
          row.consequence_id === projectHide ||
          row.consequence_id === resourceHide,
      ),
    );
  }
  assert.ok(
    ownProject.every(
      (row) =>
        !Object.hasOwn(row, "note_id") &&
        !Object.hasOwn(row, "actor_profile_id") &&
        !Object.hasOwn(row, "case_id"),
    ),
  );
  await denied(
    users.cocreator,
    "accept_project_join_request_as_manager",
    {
      p_expected_manager_profile_id: users.cocreator.id,
      p_request_id: hiddenPendingProject,
    },
    "PT409",
  );
  await denied(
    users.resourceOwner,
    "accept_resource_listing_request",
    {
      p_expected_owner_profile_id: users.resourceOwner.id,
      p_request_id: hiddenPendingResource,
    },
    "PT409",
  );
  await rpc(users.unrelated, "withdraw_project_join_request", {
    p_expected_requester_profile_id: users.unrelated.id,
    p_request_id: hiddenPendingProject,
  });
  await rpc(users.resourceOwner, "reject_resource_listing_request", {
    p_expected_owner_profile_id: users.resourceOwner.id,
    p_request_id: hiddenPendingResource,
  });
  const [memberCase] =
    await sql`insert into private.moderation_cases(state, subject_profile_id, target_kind, target_profile_id)
    values('under_review', ${users.member.id}::uuid, 'profile', ${users.member.id}::uuid) returning id`;
  const memberRestriction = await apply(
    users.moderator,
    memberCase.id,
    "interaction_restriction",
  );
  const workspace = await rpc(
    users.member,
    "get_own_project_shared_workspace",
    { p_expected_profile_id: users.member.id, p_project_id: fixture.projectId },
  );
  assert.equal(workspace.length, 1);
  const chat = await rpc(users.member, "get_own_project_group_chat", {
    p_expected_profile_id: users.member.id,
    p_project_id: fixture.projectId,
  });
  assert.equal(chat.length, 1);
  assert.equal(chat[0].has_current_entitlement, true);
  const agreement = await rpc(users.member, "get_resource_exchange_agreement", {
    p_expected_profile_id: users.member.id,
    p_request_id: memberResource,
  });
  assert.equal(agreement.length, 1);
  const [resourceChat] =
    await sql`select id from public.resource_request_chats where request_id = ${memberResource}::uuid`;
  const agreementChat = await rpc(
    users.member,
    "get_own_resource_request_chat",
    { p_expected_profile_id: users.member.id, p_chat_id: resourceChat.id },
  );
  assert.equal(agreementChat[0].has_send_entitlement, true);
  await revoke(users.admin, memberRestriction);
  await revoke(users.admin, projectHide);
  await revoke(users.admin, resourceHide);
  for (const { path } of coverPaths)
    assert.ok(
      !(await publicClient.storage.from("cover-images").download(path)).error,
    );
  await sql`update private.moderation_staff_roles set is_active = false, deactivated_at = statement_timestamp() where profile_id = ${users.moderator.id}::uuid`;
  await denied(
    users.moderator,
    "apply_moderation_consequence",
    { ...args, p_expected_staff_profile_id: users.moderator.id },
    "42501",
  );
  const [leak] =
    await sql`select count(*)::int as count from private.outbox_events where event_type like 'moderation.%'
    and (payload::text like '%Synthetic affected-user reason%' or payload::text like '%Synthetic private staff note%')`;
  assert.equal(leak.count, 0);
  console.log(
    "Authenticated consequence verifier passed: ten real OTP identities, staff apply/revoke, all acceptance overloads, own-reason privacy, pending semantics, accepted coordination, and HTTP cover denial/restoration.",
  );
} finally {
  let cleanupFailure;
  for (const { owner, path } of coverPaths) {
    const removal = await owner.client.storage
      .from("cover-images")
      .remove([path]);
    if (removal.error)
      cleanupFailure = safeFailure("remove synthetic cover", removal.error);
  }
  await sql.end({ timeout: 5 });
  if (cleanupFailure) throw cleanupFailure;
}
async function rpc(user, name, args) {
  const { data, error } = await (user.client ?? user).rpc(name, args);
  if (error) throw safeFailure(name, error);
  return data;
}
async function denied(user, name, args, code) {
  const { error } = await user.client.rpc(name, args);
  assert.equal(error?.code, code, `${name} denies safely`);
}
function projectRequest(user, projectId) {
  return rpc(user, "request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
  });
}
function resourceRequest(user, listingId) {
  return rpc(user, "request_resource_listing", {
    p_expected_requester_profile_id: user.id,
    p_listing_id: listingId,
  });
}
function apply(user, caseId, type) {
  return rpc(user, "apply_moderation_consequence", {
    p_expected_staff_profile_id: user.id,
    p_case_id: caseId,
    p_consequence_type: type,
    p_user_reason: "Synthetic affected-user reason",
    p_internal_note: "Synthetic private staff note",
  });
}
function revoke(user, consequenceId) {
  return rpc(user, "revoke_moderation_consequence", {
    p_expected_staff_profile_id: user.id,
    p_consequence_id: consequenceId,
    p_user_reason: "Synthetic revocation reason",
    p_internal_note: "Synthetic private revoke note",
  });
}
function safeFailure(step, error) {
  const code = /^[a-z0-9_]+$/iu.test(error?.code ?? "")
    ? error.code
    : "unknown";
  return new Error(`Consequence verifier failed at ${step} (code ${code}).`);
}
