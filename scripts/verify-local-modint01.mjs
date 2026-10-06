import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import {
  applyConsequence,
  asConsequenceActor,
  createConsequenceFixture,
} from "./lib/moderation-consequence-fixtures.mjs";

// Real pre-existing Auth sessions plus isolated, synthetic local domain rows.
// Never print bearer invitation tokens, Auth credentials, or staff evidence.
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
assert.match(apiUrl, /^http:\/\/(localhost|127\.0\.0\.1):/u);
assert.ok(databaseUrl, "MODINT01 requires the project-scoped local database");
const sql = postgres(databaseUrl, { max: 6, onnotice: () => {} });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const users = {};
try {
  for (const role of [
    "admin",
    "moderator",
    "owner",
    "cocreator",
    "coorganizer",
    "requester",
    "unrelated",
  ]) {
    const user = await signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl: process.env.MAILPIT_URL ?? "http://127.0.0.1:54324",
      email: `modint01-${role}@planets.invalid`,
      verifierName: `MODINT01 ${role}`,
    });
    await sql`insert into public.profiles(id,display_name)
      values(${user.id},${`Synthetic MODINT01 ${role}`}) on conflict(id) do nothing`;
    users[role] = user;
  }
  const f = await createConsequenceFixture(
    sql,
    Object.fromEntries(
      Object.entries(users).map(([role, user]) => [role, user.id]),
    ),
  );
  const [link] = await rpc(
    users.owner,
    "create_project_participant_invitation",
    projectArgs(users.owner, f),
  );
  const action = randomUUID();
  const admitArgs = {
    p_expected_profile_id: users.requester.id,
    p_token: link.invite_token,
    p_client_action_id: action,
  };
  const [admission] = await rpc(
    users.requester,
    "accept_project_participant_invitation",
    admitArgs,
  );
  assert.equal(admission.outcome, "joined");
  const [{ originating_request_id: requestOrigin }] =
    await sql`select originating_request_id
    from public.project_memberships where id=${admission.membership_id}`;
  assert.equal(
    requestOrigin,
    null,
    "direct admission never fabricates a request",
  );
  const offer = await rpc(users.owner, "create_project_role_offer", {
    p_expected_structural_profile_id: users.owner.id,
    p_project_id: f.projectId,
    p_membership_id: admission.membership_id,
    p_authority_role: "co_organizer",
  });

  for (const client of [anonymous, users.unrelated.client]) {
    assert.equal((await preview(client, link))[0].available, true);
  }
  const [{ id: hide }] = await asConsequenceActor(sql, f.moderator, (tx) =>
    applyConsequence(tx, f, "content_hide"),
  );
  for (const client of [anonymous, users.unrelated.client]) {
    assert.deepEqual(
      await preview(client, link),
      [
        {
          available: false,
          project_id: null,
          project_kind: null,
          project_title: null,
        },
      ],
      "a hidden Project must not leak title/ID through participant preview",
    );
  }
  await denied(
    users.unrelated,
    "accept_project_participant_invitation",
    {
      p_expected_profile_id: users.unrelated.id,
      p_token: link.invite_token,
      p_client_action_id: randomUUID(),
    },
    "PT409",
  );
  const [chat] = await rpc(
    users.requester,
    "get_own_project_group_chat",
    projectArgs(users.requester, f),
  );
  assert.equal(
    chat.has_current_entitlement,
    true,
    "hide preserves existing membership/chat entitlement",
  );
  await revokeConsequence(f, hide);

  const [{ id: restriction }] = await asConsequenceActor(
    sql,
    f.moderator,
    (tx) => applyConsequence(tx, f, "interaction_restriction"),
  );
  const before = await domainCounts(f);
  await denied(
    users.requester,
    "accept_project_participant_invitation",
    { ...admitArgs, p_client_action_id: randomUUID() },
    "PT409",
  );
  assert.deepEqual(
    await domainCounts(f),
    before,
    "denied fresh admission has no episode/receipt/event side effects",
  );
  const [replayed] = await rpc(
    users.requester,
    "accept_project_participant_invitation",
    admitArgs,
  );
  assert.equal(replayed.replayed, true);
  assert.equal(replayed.membership_id, admission.membership_id);
  assert.deepEqual(
    await domainCounts(f),
    before,
    "receipt replay is strictly read-only while restricted",
  );
  await revokeConsequence(f, restriction);

  await rpc(users.cocreator, "block_user", {
    p_expected_blocker_profile_id: users.cocreator.id,
    p_blocked_profile_id: users.unrelated.id,
  });
  await denied(
    users.unrelated,
    "accept_project_participant_invitation",
    {
      p_expected_profile_id: users.unrelated.id,
      p_token: link.invite_token,
      p_client_action_id: randomUUID(),
    },
    "PT409",
  );

  const ownerCase = randomUUID();
  await sql`insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_profile_id)
    values(${ownerCase},'under_review',${f.owner},'profile',${f.owner})`;
  const ownerSuspension = await suspend(users.admin, ownerCase);
  const memberSuspension = await suspend(users.admin, f.cases.profile);
  // Every new authenticated signature from main has a real HTTP denial using
  // the session obtained before suspension. No token refresh/sign-in workaround.
  const owner = users.owner;
  const member = users.requester;
  const checks = [
    [owner, "create_project_participant_invitation", projectArgs(owner, f)],
    [
      owner,
      "get_current_project_participant_invitation",
      projectArgs(owner, f),
    ],
    [owner, "regenerate_project_participant_invitation", projectArgs(owner, f)],
    [
      owner,
      "revoke_project_participant_invitation",
      { ...projectArgs(owner, f), p_invitation_id: link.invitation_id },
    ],
    [
      owner,
      "list_project_participant_invitation_history",
      projectArgs(owner, f),
    ],
    [member, "accept_project_participant_invitation", admitArgs],
    [
      member,
      "get_project_join_request_resolution_context",
      { p_expected_profile_id: member.id, p_request_id: randomUUID() },
    ],
    [
      owner,
      "list_current_project_people",
      {
        ...projectArgs(owner, f),
        p_after_role_rank: null,
        p_after_profile_id: null,
      },
    ],
    [
      owner,
      "create_project_role_offer",
      {
        p_expected_structural_profile_id: owner.id,
        p_project_id: f.projectId,
        p_membership_id: admission.membership_id,
        p_authority_role: "co_creator",
      },
    ],
    [
      member,
      "accept_project_role_offer",
      { p_expected_profile_id: member.id, p_offer_id: offer },
    ],
    [
      member,
      "decline_project_role_offer",
      { p_expected_profile_id: member.id, p_offer_id: offer },
    ],
    [owner, "list_project_role_offers", projectArgs(owner, f)],
    [owner, "page_project_requests_for_manager", projectArgs(owner, f)],
    [owner, "page_project_history_for_manager", projectArgs(owner, f)],
    [
      owner,
      "step_down_project_authority",
      { p_expected_profile_id: owner.id, p_delegate_id: randomUUID() },
    ],
  ];
  for (const [user, name, args] of checks)
    await denied(user, name, args, "PT403");
  // PostgREST resolves each compatibility overload by its complete argument
  // names. Exercise both shapes; a call-chain inventory is not HTTP evidence.
  const triage = {
    p_needed_skill_ids: [],
    p_already_found_skill_ids: [],
    p_extra_skill_ids: [],
    p_needed_resource_need_ids: [],
    p_already_found_resource_need_ids: [],
    p_extra_resource_need_ids: [],
  };
  for (const [name, expectedKey] of [
    ["accept_project_join_request", "p_expected_creator_profile_id"],
    ["accept_project_join_request_as_manager", "p_expected_manager_profile_id"],
  ]) {
    const args = { [expectedKey]: owner.id, p_request_id: randomUUID() };
    await denied(owner, name, args, "PT403");
    await denied(owner, name, { ...args, ...triage }, "PT403");
  }
  const delegateArgs = {
    p_expected_owner_profile_id: owner.id,
    p_project_id: f.projectId,
  };
  await denied(
    owner,
    "create_project_delegate_invitation",
    delegateArgs,
    "PT403",
  );
  await denied(
    owner,
    "create_project_delegate_invitation",
    { ...delegateArgs, p_requested_authority_role: "co_creator" },
    "PT403",
  );
  for (const user of [owner, member]) {
    const [status] = await rpc(user, "get_own_account_suspension_status", {
      p_expected_profile_id: user.id,
    });
    assert.equal(status.is_suspended, true);
    assert.deepEqual(Object.keys(status).sort(), [
      "applied_at",
      "consequence_id",
      "is_suspended",
      "user_reason",
    ]);
  }
  for (const episode of [ownerSuspension, memberSuspension]) {
    await rpc(users.admin, "revoke_account_suspension", {
      p_expected_staff_profile_id: users.admin.id,
      p_consequence_id: episode,
      p_user_reason: "Synthetic restored access",
      p_internal_note: "Synthetic private revocation note",
    });
  }
  assert.ok(
    (
      await rpc(owner, "list_current_project_people", {
        ...projectArgs(owner, f),
        p_after_role_rank: null,
        p_after_profile_id: null,
      })
    ).length >= 4,
  );
  assert.equal(
    (await rpc(member, "accept_project_participant_invitation", admitArgs))[0]
      .replayed,
    true,
  );
  await rpc(member, "leave_project", {
    p_expected_participant_profile_id: member.id,
    p_membership_id: admission.membership_id,
  });
  await rpc(owner, "revoke_project_participant_invitation", {
    ...projectArgs(owner, f),
    p_invitation_id: link.invitation_id,
  });
  const endedBefore = await domainCounts(f);
  const [ended] = await rpc(
    member,
    "accept_project_participant_invitation",
    admitArgs,
  );
  assert.equal(ended.membership_status, "left");
  assert.equal(ended.replayed, true);
  assert.deepEqual(
    await domainCounts(f),
    endedBefore,
    "ended receipt replay never restores membership/capacity/chat",
  );
  await denied(
    member,
    "accept_project_participant_invitation",
    { ...admitArgs, p_client_action_id: randomUUID() },
    "PT409",
  );

  console.log(
    "MODINT01 authenticated integration passed: hidden anonymous/authenticated preview; fresh restriction/block/hide denial; read-only receipt replay; 15 new private RPC and 6 compatibility overload denials on pre-existing suspended sessions; safe own-status/revoke recovery; truthful membership origins.",
  );
} finally {
  await sql.end({ timeout: 5 });
}

function projectArgs(user, f) {
  return { p_expected_profile_id: user.id, p_project_id: f.projectId };
}
async function rpc(user, name, args) {
  const { data, error } = await user.client.rpc(name, args);
  if (error) throw new Error(`MODINT01 ${name} failed (code ${error.code})`);
  return data;
}
async function denied(user, name, args, code) {
  const { error } = await user.client.rpc(name, args);
  assert.equal(error?.code, code, `MODINT01 ${name} must deny with ${code}`);
}
async function preview(client, link) {
  const { data, error } = await client.rpc(
    "get_project_participant_invitation_preview",
    { p_token: link.invite_token },
  );
  if (error) throw new Error(`MODINT01 preview failed (code ${error.code})`);
  return data;
}
async function revokeConsequence(f, id) {
  await rpc(users.moderator, "revoke_moderation_consequence", {
    p_expected_staff_profile_id: f.moderator,
    p_consequence_id: id,
    p_user_reason: "Synthetic restriction ended",
    p_internal_note: "Synthetic private note",
  });
}
async function suspend(admin, caseId) {
  return rpc(admin, "apply_account_suspension", {
    p_expected_staff_profile_id: admin.id,
    p_case_id: caseId,
    p_user_reason: "Synthetic suspended access",
    p_internal_note: "Synthetic private note",
  });
}
async function domainCounts(f) {
  const [row] = await sql`select
    (select count(*)::int from public.project_memberships where project_id=${f.projectId}) as episodes,
    (select count(*)::int from public.project_memberships where project_id=${f.projectId} and left_at is null and removed_at is null) as current,
    (select count(*)::int from private.project_participant_admissions where project_id=${f.projectId}) as receipts,
    (select count(*)::int from private.outbox_events where payload->>'project_id'=${f.projectId}) as events`;
  return row;
}
